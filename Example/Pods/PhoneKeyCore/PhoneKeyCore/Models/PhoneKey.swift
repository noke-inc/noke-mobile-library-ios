//
//  PhoneKey.swift
//  SmartEntryCore
//
//  Created by Joffrey Mann on 12/22/25.
//  Copyright © 2025 Noke Inc. All rights reserved.
//

import Foundation
import Security
import CryptoKit // used for SHA256 and Ed25519 where available (iOS 13+)

public enum KeychainKeys {
    static let ed25519Seed = "ed25519.seed"
    // Legacy, single P-256 key tag (kept for backward compatibility)
    static let p256PrivateKeyTag = "p256.signing.privatekey"
}

/// Signature algorithm (kept for future extensibility).
public enum SignatureAlgorithm: String, Codable {
    case ed25519 = "Ed25519"
    case ecdsaP256 = "ECDSA_P256"
}

public enum PhoneKeyStatus: String, Codable {
    case active = "active"
    case revoked = "revoked"
    case expired = "expired"
}

public protocol CryptoProvider: AnyObject {
    func generateEd25519Seed() throws -> Data
    func derivePublicKey(fromSeed seed: Data) throws -> Data
    func sign(message: Data, withSeed seed: Data) throws -> Data
    func getHash(of data: Data) throws -> Data
}

/// Unified key info for Ed25519 across OS versions; extended for P-256 via keyTag
public struct PhoneKeyInfo: Codable {
    public let keyId: String
    public let algorithm: SignatureAlgorithm
    public let publicKeyRaw: Data  // Ed25519: 32 bytes; P-256: 65 bytes (0x04 || X || Y)
    public let seed: Data          // Ed25519: 32-byte seed; P-256: unused/empty (kept for compatibility)
    public var status: PhoneKeyStatus
    public let keyTag: Data? = nil
}

public final class PhoneKeyManager {
    private let keychain: KeychainHelper
    private var provider: CryptoProvider?
    private let serviceName: String
    private let accessGroup: String?
    private let preferredAlgorithm: SignatureAlgorithm

    /// Cached key info (derived from seed for Ed25519; from SecKey for P-256)
    private(set) var keyInfo: PhoneKeyInfo?

    // Local, non-synced identifiers we may use (no UIKit/WatchKit)
    private let deviceUUIDAccount = "DeviceUUIDForSalt"
    private let deviceUUIDTag = "com.noke.PhoneKeyCore.device.uuid".data(using: .utf8)!

    /// Initialize with existing KeychainHelper (service + optional access group).
    public init(serviceName: String,
                accessGroup: String? = nil,
                provider: CryptoProvider?,
                preferredAlgorithm: SignatureAlgorithm = .ecdsaP256) {
        let queryable = GenericPasswordQueryable(
            service: KeychainHelper.nokeKeychainService,
            accessGroup: nil,
            accessibility: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        )
        self.keychain = KeychainHelper(keychainQueryable: queryable)
        self.serviceName = serviceName
        self.provider = provider
        self.accessGroup = accessGroup
        self.preferredAlgorithm = preferredAlgorithm
    }

    // MARK: Public API (existing path)

    /// Ensure a keypair exists for the preferred algorithm. Backward compatible with Ed25519-only flow.
    @discardableResult
    public func ensureKeys() throws -> PhoneKeyInfo {
        return try ensureKeys(algorithm: preferredAlgorithm)
    }

    /// Ensure a keypair exists for the requested algorithm.
    @discardableResult
    public func ensureKeys(algorithm: SignatureAlgorithm) throws -> PhoneKeyInfo {
        switch algorithm {
        case .ed25519:
            return try ensureEd25519Keys()
        case .ecdsaP256:
            // Legacy, single-key path (global tag)
            return try ensureP256KeysLegacy()
        }
    }

    // MARK: 🆕 Public API — per-user, per-device P-256 key

    /// Ensure a P-256 key exists for this (deviceID, userId) pair.
    /// - Parameters:
    ///   - userId: Server user identifier (stable).
    ///   - deviceID: 16–32 bytes preferred (e.g., UUID raw bytes). If nil, a Keychain UUID is used.
    /// - Returns: PhoneKeyInfo for the namespaced keypair.
    @discardableResult
    public func ensureP256Keys(userId: String, deviceID: Data?) throws -> PhoneKeyInfo {
        let devId = deviceID ?? (try? loadOrCreateFallbackDeviceUUID()) ?? Data("fallback-device-id".utf8)
        let tagData = makeP256Tag(deviceID: devId, userId: userId)

        if let privateKey = try fetchExistingP256PrivateKey(tag: tagData) {
            let pubRaw = try exportP256PublicKeyRaw(privateKey: privateKey)
            let keyId = keyIdFromPublicKey(pubRaw)
            let info = PhoneKeyInfo(
                keyId: keyId,
                algorithm: .ecdsaP256,
                publicKeyRaw: pubRaw,
                seed: Data(),
                status: .active
            )
            self.keyInfo = info
            return info
        }

        let privateKey = try generateP256PrivateKey(tag: tagData, accessGroup: accessGroup)
        let pubRaw = try exportP256PublicKeyRaw(privateKey: privateKey)
        let keyId = keyIdFromPublicKey(pubRaw)
        let info = PhoneKeyInfo(
            keyId: keyId,
            algorithm: .ecdsaP256,
            publicKeyRaw: pubRaw,
            seed: Data(),
            status: .active
        )
        self.keyInfo = info
        return info
    }

    /// Sign using a P-256 key namespaced by (deviceID, userId).
    /// - Note: For Ed25519, continue to use the existing `sign(_:, algorithm:)`.
    public func sign(_ data: Data, userId: String, deviceID: Data?) throws -> Data {
        // Ensure namespaced key exists
        _ = try ensureP256Keys(userId: userId, deviceID: deviceID)

        let devId = deviceID ?? (try? loadOrCreateFallbackDeviceUUID()) ?? Data("fallback-device-id".utf8)
        let tagData = makeP256Tag(deviceID: devId, userId: userId)

        guard let privateKey = try fetchExistingP256PrivateKey(tag: tagData) else {
            throw SEPhoneKeyError.failedToSignData()
        }
        let derSig = try signP256WithSecKey(privateKey: privateKey, message: data)
        return derSig
    }

    // MARK: - Ed25519 path (unchanged behavior)

    @discardableResult
    private func ensureEd25519Keys() throws -> PhoneKeyInfo {
        if let base64 = try keychain.getValue(forKey: KeychainKeys.ed25519Seed),
           let seed = Data(base64Encoded: base64) {
            let pub = try derivePublicKeyEd25519(fromSeed: seed)
            let existing = PhoneKeyInfo(
                keyId: keyIdFromEd25519Seed(seed),
                algorithm: .ed25519,
                publicKeyRaw: pub,
                seed: seed,
                status: .active
            )
            self.keyInfo = existing
            return existing
        }

        guard let provider = provider else {
            throw SEPhoneKeyError.cryptoProviderNotSet()
        }
        let seed = try provider.generateEd25519Seed()
        try keychain.setValue(seed.base64EncodedString(), forKey: KeychainKeys.ed25519Seed)
        let pub = try derivePublicKeyEd25519(fromSeed: seed)

        let newKeyInfo = PhoneKeyInfo(
            keyId: keyIdFromEd25519Seed(seed),
            algorithm: .ed25519,
            publicKeyRaw: pub,
            seed: seed,
            status: .active
        )
        self.keyInfo = newKeyInfo
        return newKeyInfo
    }

    // MARK: - P-256 legacy path (global tag, kept for compatibility)

    @discardableResult
    private func ensureP256KeysLegacy() throws -> PhoneKeyInfo {
        let tagData = Data(KeychainKeys.p256PrivateKeyTag.utf8)
        if let privateKey = try fetchExistingP256PrivateKey(tag: tagData) {
            let pubRaw = try exportP256PublicKeyRaw(privateKey: privateKey)
            let keyId = keyIdFromPublicKey(pubRaw)
            let info = PhoneKeyInfo(
                keyId: keyId,
                algorithm: .ecdsaP256,
                publicKeyRaw: pubRaw,
                seed: Data(),
                status: .active
            )
            self.keyInfo = info
            return info
        }

        let privateKey = try generateP256PrivateKey(tag: tagData, accessGroup: accessGroup)
        let pubRaw = try exportP256PublicKeyRaw(privateKey: privateKey)
        let keyId = keyIdFromPublicKey(pubRaw)
        let info = PhoneKeyInfo(
            keyId: keyId,
            algorithm: .ecdsaP256,
            publicKeyRaw: pubRaw,
            seed: Data(),
            status: .active
        )
        self.keyInfo = info
        return info
    }

    /// Remove the Ed25519 seed from Keychain and clear cache.
    public func destroyKeys() throws {
        try keychain.removeValue(for: KeychainKeys.ed25519Seed)
        // Also attempt to delete legacy P-256 key (no-throw if not found)
        try? deleteP256Key()
        self.keyInfo = nil
    }

    // MARK: - Existing sign (unchanged for compatibility)

    /// Signs arbitrary data with the current or preferred algorithm.
    /// - Returns: Signature bytes (Ed25519: 64; P-256: DER-encoded ECDSA).
    public func sign(_ data: Data, userId: String, deviceID: Data? = nil, algorithm: SignatureAlgorithm? = nil) throws -> Data {
        let info = try self.keyInfo ?? ensureP256Keys(userId: userId, deviceID: deviceID)

        switch info.algorithm {
        case .ed25519:
            if #available(iOS 13.0, *) {
                let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: info.seed)
                return try privateKey.signature(for: data)
            } else {
                guard let provider = provider else {
                    throw SEPhoneKeyError.cryptoProviderNotSet()
                }
                do { return try provider.sign(message: data, withSeed: info.seed) }
                catch { throw SEPhoneKeyError.failedToSignData() }
            }

        case .ecdsaP256:
            // Legacy global tag lookup (not the namespaced one).
            let tagData = Data(KeychainKeys.p256PrivateKeyTag.utf8)
            guard let privateKey = try fetchExistingP256PrivateKey(tag: tagData) else {
                throw SEPhoneKeyError.failedToSignData()
            }
            return try signP256WithSecKey(privateKey: privateKey, message: data)
        }
    }

    public func loadExistingKey(_ seed: Data) throws -> PhoneKeyInfo? {
        let pub = try derivePublicKeyEd25519(fromSeed: seed)
        return PhoneKeyInfo(
            keyId: keyIdFromEd25519Seed(seed),
            algorithm: .ecdsaP256, // kept as-is from your file
            publicKeyRaw: pub,
            seed: seed,
            status: .active
        )
    }

    public func expireCurrentKeyPOC(expiresAt: Date? = Date()) {
        guard var info = self.keyInfo else { return }
        info.status = .expired
        self.keyInfo = info
    }

    public func revokeCurrentKeyPOC(reason: String? = nil) {
        guard var info = self.keyInfo else { return }
        info.status = .revoked
        self.keyInfo = info
    }

    func deleteAllKeys() throws {
        try deleteSeed()
        try? deleteP256Key()
        self.keyInfo = nil
    }

    public func deleteSeed() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: "ed25519.seed"
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(domain: "Keychain", code: Int(status))
        }
    }

    // Delete legacy P-256 SecKey by global tag
    public func deleteP256Key() throws {
        let tagData = Data(KeychainKeys.p256PrivateKeyTag.utf8)
        var query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrApplicationTag as String: tagData
        ]
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(domain: "Keychain", code: Int(status))
        }
    }

    // MARK: - Helpers

    // Ed25519 public derivation
    private func derivePublicKeyEd25519(fromSeed seed: Data) throws -> Data {
        if #available(iOS 13.0, *) {
            let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
            return privateKey.publicKey.rawRepresentation
        } else {
            guard let provider = provider else { throw SEPhoneKeyError.cryptoProviderNotSet() }
            do { return try provider.derivePublicKey(fromSeed: seed) }
            catch { throw SEPhoneKeyError.failedToDerivePublicKey() }
        }
    }

    private func keyIdFromEd25519Seed(_ seed: Data) -> String {
        if #available(iOS 13.0, *) {
            let digest = SHA256.hash(data: seed)
            return uuidFromDigest(Data(digest))
        } else {
            if let provider = provider, let hash = try? provider.getHash(of: seed) {
                return uuidFromDigest(Data(hash))
            }
            return uuidFromDigest(Data(Array(repeating: 0, count: 16)))
        }
    }

    private func keyIdFromPublicKey(_ pubRaw: Data) -> String {
        if #available(iOS 13.0, *) {
            let digest = SHA256.hash(data: pubRaw)
            return uuidFromDigest(Data(digest))
        } else {
            if let provider = provider, let hash = try? provider.getHash(of: pubRaw) {
                return uuidFromDigest(Data(hash))
            }
            return uuidFromDigest(Data(Array(repeating: 0, count: 16)))
        }
    }

    private func uuidFromDigest(_ data: Data) -> String {
        var bytes: [UInt8] = Array(data)
        if bytes.count < 16 { bytes += Array(repeating: 0, count: 16 - bytes.count) }
        let u = UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
        return u.uuidString
    }

    // MARK: - P-256 Security helpers

    private func fetchExistingP256PrivateKey(tag: Data) throws -> SecKey? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrApplicationTag as String: tag,
            kSecReturnRef as String: true
        ]
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw NSError(domain: "Keychain", code: Int(status))
        }
        return (item as! SecKey)
    }

    private func generateP256PrivateKey(tag: Data, accessGroup: String?) throws -> SecKey {
        var privateAttrs: [String: Any] = [
            kSecAttrIsPermanent as String: true,
            kSecAttrApplicationTag as String: tag,
            // Keep device-local (no iCloud sync)
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        if let accessGroup = accessGroup {
            privateAttrs[kSecAttrAccessGroup as String] = accessGroup
        }

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: privateAttrs
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw (error?.takeRetainedValue() as Error?) ?? SEPhoneKeyError.failedToDerivePublicKey()
        }
        return privateKey
    }

    /// Export P-256 public key in X9.63 (uncompressed, 65 bytes: 0x04 || X || Y)
    private func exportP256PublicKeyRaw(privateKey: SecKey) throws -> Data {
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw SEPhoneKeyError.failedToDerivePublicKey()
        }
        var error: Unmanaged<CFError>?
        guard let data = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            throw (error?.takeRetainedValue() as Error?) ?? SEPhoneKeyError.failedToDerivePublicKey()
        }
        return data
    }

    /// Sign with SecKey using ECDSA + SHA-256; returns DER-encoded signature
    private func signP256WithSecKey(privateKey: SecKey, message: Data) throws -> Data {
        let algorithm = SecKeyAlgorithm.ecdsaSignatureMessageX962SHA256
        guard SecKeyIsAlgorithmSupported(privateKey, .sign, algorithm) else {
            throw SEPhoneKeyError.failedToSignData()
        }
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(privateKey, algorithm, message as CFData, &error) as Data? else {
            throw (error?.takeRetainedValue() as Error?) ?? SEPhoneKeyError.failedToSignData()
        }
        return signature
    }

    // MARK: - Tag derivation & fallback device UUID

    /// tag = SHA256("p256|v1|" + deviceID + "|" + userId)  → 32 bytes
    private func makeP256Tag(deviceID: Data, userId: String) -> Data {
        var data = Data("p256|v1|".utf8)
        data.append(deviceID)
        data.append(Data("|".utf8))
        data.append(Data(userId.utf8))
        if #available(iOS 13.0, *) {
            let digest = SHA256.hash(data: data)
            return Data(digest)
        } else {
            // Fallback to provider hash if available; otherwise a naive fallback.
            if let h = try? provider?.getHash(of: data) {
                return Data(h)
            }
            return data.prefix(32) // last-ditch; sufficient for tag identity
        }
    }

    /// Local fallback device UUID (ThisDeviceOnly). No UIKit.
    private func loadOrCreateFallbackDeviceUUID() throws -> Data {
        // Fetch
        var q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: deviceUUIDAccount,
            kSecAttrApplicationTag as String: deviceUUIDTag,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data {
            return data
        }

        // Create new UUID (16 bytes raw)
        var uuid = UUID().uuid
        let data = withUnsafeBytes(of: &uuid) { Data($0) }

        // Store (ThisDeviceOnly)
        q = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: deviceUUIDAccount,
            kSecAttrApplicationTag as String: deviceUUIDTag,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data
        ]
        let addStatus = SecItemAdd(q as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw NSError(domain: "Keychain", code: Int(addStatus))
        }
        return data
    }
}

// MARK: - ACL Chunking / Signing
public extension PhoneKeyManager {

    /// Build a signed ACL payload and return it chunked into 128-byte hex packets.
    ///
    /// The format required by the lock:
    ///   • Chunk 0..N-1:   "NN" + 128 hex bytes
    ///   • Final chunk:    "xx" + 4 hex digits of total ACL length (ACL only, not including signature)
    ///   • Signature:      Appended after ACL:
    ///         - Ed25519: 64 bytes
    ///         - ECDSA P-256: 64 bytes raw (r||s)
    ///
    func buildACLChunks(acl: Data, algorithm: SignatureAlgorithm? = nil) throws -> [String] {

        // 1. Ensure keys exist
        let keyInfo = try ensureKeys(algorithm: algorithm ?? preferredAlgorithm)

        // 2. Compute signature over entire ACL
        let signature = try sign(acl, userId: "", algorithm: keyInfo.algorithm)

        // 3. Final payload = ACL + signature (length depends on algorithm)
        var fullPayload = Data()
        fullPayload.append(acl)
        fullPayload.append(signature)

        // 4. Chunking parameters
        let chunkSize = 128
        let totalLen = acl.count    // IMPORTANT: spec says "length of ACL only"
        let chunkCount = Int(ceil(Double(fullPayload.count) / Double(chunkSize)))

        var result: [String] = []

        for chunkIndex in 0..<chunkCount {
            let start = chunkIndex * chunkSize
            let end = min(start + chunkSize, fullPayload.count)

            let chunkBytes = fullPayload[start..<end]
            let hexPayload = chunkBytes.map { String(format:"%02x", $0) }.joined()

            if chunkIndex < chunkCount - 1 {
                let header = String(format: "%02x", chunkIndex)
                result.append(header + hexPayload)
            } else {
                // FINAL chunk: "xx" + 4 hex digits of ACL length
                let lengthField = String(format: "%04x", totalLen)
                let header = "xx" + lengthField
                result.append(header + hexPayload)
            }
        }

        return result
    }
}

// MARK: - ACL Local Persistence (Keychain) – Non-invasive CRUD (strengthened)

public extension PhoneKeyManager {

    private enum ACLStoreKeys {
        static let index = "acl.index"
        static func item(_ trackingId: String) -> String { "acl.item.\(trackingId)" }
    }

    private enum ACLError: LocalizedError {
        case missingEnvelopeId
        case identicalIds
        case notFound
        case migrateNeedsSourceId
        case invalidId

        var errorDescription: String? {
            switch self {
            case .missingEnvelopeId:
                return "ACL must have a non-empty 'envelopeId' for this operation."
            case .identicalIds:
                return "Source and destination trackingId are identical; nothing to migrate."
            case .notFound:
                return "ACL not found for the given trackingId."
            case .migrateNeedsSourceId:
                return "Migration requires a valid source trackingId."
            case .invalidId:
                return "Invalid trackingId."
            }
        }
    }

    private var aclEncoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = []
        return e
    }
    private var aclDecoder: JSONDecoder { JSONDecoder() }

    /// Save a bulk ACL for a specific userId and mac, replacing any existing ACL.
    func saveBulkACL(userId: String, mac: String, _ bulkACL: BulkPhoneKeyAcl) throws {
        let envelopeId = normalize("\(userId)-\(mac)")
        guard !envelopeId.isEmpty else { throw ACLError.missingEnvelopeId }
        let data = try aclEncoder.encode(bulkACL)
        let itemKey = ACLStoreKeys.item(envelopeId)
        try keychain.setValue(data.base64EncodedString(), forKey: itemKey)

        var index = try loadACLIndex()
        if !index.contains(envelopeId) {
            index.append(envelopeId)
            try storeACLIndex(index)
        }
    }

    /// Update bulk ACL for a userId and mac. If merge closure is provided, it will be called with existing ACL.
    @discardableResult
    func updateBulkACL(userId: String, mac: String, _ updatedACL: BulkPhoneKeyAcl,
                       merge: ((BulkPhoneKeyAcl) -> BulkPhoneKeyAcl)? = nil) throws -> BulkPhoneKeyAcl {
        guard !userId.isEmpty, !mac.isEmpty else { throw ACLError.missingEnvelopeId }
        if let existing = try getBulkACL(userId: userId, mac: mac), let merge = merge {
            let merged = merge(existing)
            try saveBulkACL(userId: userId, mac: mac, merged)
            return merged
        } else {
            try saveBulkACL(userId: userId, mac: mac, updatedACL)
            return updatedACL
        }
    }

    /// Get a specific bulk ACL by userId and mac.
    func getBulkACL(userId: String, mac: String) throws -> BulkPhoneKeyAcl? {
        let envelopeId = normalize("\(userId)-\(mac)")
        let itemKey = ACLStoreKeys.item(envelopeId)
        guard let b64 = try keychain.getValue(forKey: itemKey),
              let data = Data(base64Encoded: b64) else {
            return nil
        }
        return try aclDecoder.decode(BulkPhoneKeyAcl.self, from: data)
    }

    /// Delete ACL for a specific userId and mac.
    func deleteACL(userId: String, mac: String) throws {
        let envelopeId = normalize("\(userId)-\(mac)")
        let itemKey = ACLStoreKeys.item(envelopeId)
        try keychain.removeValue(for: itemKey)

        var index = try loadACLIndex()
        if let i = index.firstIndex(of: envelopeId) {
            index.remove(at: i)
            try storeACLIndex(index)
        }
    }
    
    /// Delete all ACLs for all users.
    func deleteAllACLs() throws {
        let ids = try loadACLIndex()
        for id in ids {
            let itemKey = ACLStoreKeys.item(id)
            try keychain.removeValue(for: itemKey)
        }
        try storeACLIndex([])
    }

    /// List all bulk ACLs stored in the keychain.
    func listBulkACLs() throws -> [BulkPhoneKeyAcl] {
        let ids = try loadACLIndex()
        var out: [BulkPhoneKeyAcl] = []
        out.reserveCapacity(ids.count)

        for envelopeId in ids {
            // Parse envelopeId back to userId and mac
            let components = envelopeId.split(separator: "-", maxSplits: 1)
            guard components.count == 2 else { continue }
            let userId = String(components[0])
            let mac = String(components[1])
            
            if let acl = try getBulkACL(userId: userId, mac: mac) {
                out.append(acl)
            } else {
                try removeIdFromIndex(userId: userId, mac: mac)
            }
        }
        return out
    }

    /// List all bulk ACLs for a specific userId.
    func listBulkACLs(userId: String) throws -> [BulkPhoneKeyAcl] {
        let normalizedUserId = normalize(userId)
        let ids = try loadACLIndex()
        var out: [BulkPhoneKeyAcl] = []

        for envelopeId in ids {
            // Check if this envelopeId starts with the userId
            if envelopeId.hasPrefix(normalizedUserId + "-") {
                let components = envelopeId.split(separator: "-", maxSplits: 1)
                guard components.count == 2 else { continue }
                let mac = String(components[1])
                
                if let acl = try getBulkACL(userId: userId, mac: mac) {
                    out.append(acl)
                } else {
                    try removeIdFromIndex(userId: userId, mac: mac)
                }
            }
        }
        return out
    }
    
    
    
    
    
    // MARK: - Phone Key Info persistence
    
    func savePhoneKeyInfo(userId: String, info: PhoneKeyInfoResponse) throws {
        let data = try JSONEncoder().encode(info)
        try keychain.setValue(data.base64EncodedString(), forKey: "\(userId)-phoneKeyInfo")
    }
    
    func getPhoneKeyInfo(userId: String) throws -> PhoneKeyInfoResponse? {
        guard let b64 = try? keychain.getValue(forKey: "\(userId)-phoneKeyInfo"),
              let data = Data(base64Encoded: b64) else {
            return nil
        }
        return try? JSONDecoder().decode(PhoneKeyInfoResponse.self, from: data)
    }
    
    func deletePhoneKeyInfo(userId: String) throws {
        try keychain.removeValue(for: "\(userId)-phoneKeyInfo")
    }

    // MARK: - Index helpers

    private func loadACLIndex() throws -> [String] {
        if let b64 = try keychain.getValue(forKey: ACLStoreKeys.index),
           let data = Data(base64Encoded: b64),
           let array = try? JSONSerialization.jsonObject(with: data) as? [String] {
            let unique = Array(Set(array.map(normalize))).sorted()
            return unique
        }
        return []
    }

    private func storeACLIndex(_ ids: [String]) throws {
        let unique = Array(Set(ids.map(normalize))).sorted()
        let data = try JSONSerialization.data(withJSONObject: unique, options: [])
        try keychain.setValue(data.base64EncodedString(), forKey: ACLStoreKeys.index)
    }

    private func removeIdFromIndex(userId: String, mac: String) throws {
        let envelopeId = normalize("\(userId)-\(mac)")
        var index = try loadACLIndex()
        if let i = index.firstIndex(of: envelopeId) {
            index.remove(at: i)
            try storeACLIndex(index)
        }
    }

    // MARK: - Utilities

    private func normalize(_ id: String?) -> String {
        (id ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
