//
//  PhoneKey.swift
//  SmartEntryCore
//
//  Created by Joffrey Mann on 12/22/25.
//  Copyright © 2025 Noke Inc. All rights reserved.
//

import Foundation
import Security
// CryptoKit exists in the SDK; guarded at use sites for iOS 13+
import CryptoKit

public enum KeychainKeys {
    static let ed25519Seed = "ed25519.seed"
}

/// Signature algorithm (kept for future extensibility).
public enum SignatureAlgorithm: String, Codable {
    case ed25519 = "Ed25519"
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

//struct PhoneKeyInfoRequest: Codable {
//    let keyId: String
//    let algorithm: String   // "Ed25519"
//    let publicKey: String   // Base64
//    let phoneId: String
//    let userId: String
//}

/// Unified key info for Ed25519 across OS versions
public struct PhoneKeyInfo: Codable {
    public let keyId: String
    public let algorithm: SignatureAlgorithm
    public let publicKeyRaw: Data
    public let seed: Data
    public var status: PhoneKeyStatus
//    let phoneId: String
//    let userId: String
//    let createdAt: String  // ISO 8601
//    let updatedAt: String  // ISO 8601
//    let keyStatus: String // "active"
//    let comments: String?
}

public final class PhoneKeyManager {
    private let keychain: KeychainHelper
    private var provider: CryptoProvider?
    private let serviceName: String
    
    /// Cached key info (derived from seed).
    private(set) var keyInfo: PhoneKeyInfo?
    
    /// Initialize with existing KeychainHelper (service + optional access group).
    public init(serviceName: String, accessGroup: String? = nil, provider: CryptoProvider?) {
        let queryable = GenericPasswordQueryable(service: serviceName, accessGroup: accessGroup)
        self.keychain = KeychainHelper(keychainQueryable: queryable)
        self.serviceName = serviceName
        self.provider = provider
    }
    
    // MARK: Public API
    
    // Ensure an Ed25519 keypair exists, generating and storing one if needed.
    
    @discardableResult
    public func ensureKeys() throws -> PhoneKeyInfo {

        // 1. Try loading existing seed from Keychain
        if let base64 = try keychain.getValue(forKey: KeychainKeys.ed25519Seed),
           let seed = Data(base64Encoded: base64) {

            let pub = try derivePublicKey(fromSeed: seed)

            let existing = PhoneKeyInfo(
                keyId: keyIdFromSeed(seed),
                algorithm: .ed25519,
                publicKeyRaw: pub,
                seed: seed,
                status: .active
            )

            self.keyInfo = existing
            return existing
        }

        // 2. We need to generate a new seed. Provider MUST exist.
        guard let provider = provider else {
            throw SEError(message: "CryptoProvider not set for key generation.")
        }

        // 3. Generate fresh Ed25519 seed (32 bytes)
        let seed = try provider.generateEd25519Seed()

        // 4. Save to Keychain (Base64)
        try keychain.setValue(seed.base64EncodedString(), forKey: KeychainKeys.ed25519Seed)

        // 5. Derive public key from seed
        let pub = try derivePublicKey(fromSeed: seed)

        let newKeyInfo = PhoneKeyInfo(
            keyId: keyIdFromSeed(seed),
            algorithm: .ed25519,
            publicKeyRaw: pub,
            seed: seed,
            status: .active
        )

        self.keyInfo = newKeyInfo
        return newKeyInfo
    }
    
    /// Remove the seed from Keychain and clear cache.
    public func destroyKeys() throws {
        try keychain.removeValue(for: KeychainKeys.ed25519Seed)
        self.keyInfo = nil
    }
    
    /// Signs arbitrary data with Ed25519 using CryptoKit on iOS 13+ or Swift-Sodium otherwise.
    /// - Parameter data: The canonicalized bytes to sign.
    /// - Returns: 64-byte Ed25519 signature as Data.
    public func sign(_ data: Data) throws -> Data {
        let info = try self.keyInfo ?? ensureKeys()
        
        if #available(iOS 13.0, *) {
            // CryptoKit path: reconstruct from 32-byte seed
            let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: info.seed)
            let signature = try privateKey.signature(for: data)
            return signature
        } else {
            // Swift-Sodium path: derive secretKey from seed and sign
            guard let provider = provider else {
                throw SEError(message: "CryptoProvider not set.")
            }
            do {
                return try provider.sign(message: data, withSeed: info.seed)
            } catch {
                throw SEError(message: "Failed to sign data with Ed25519.")
            }
        }
    }
    
    
    public func loadExistingKey(_ seed: Data) throws -> PhoneKeyInfo? {
        let pub = try derivePublicKey(fromSeed: seed)
        return PhoneKeyInfo(keyId: keyIdFromSeed(seed),
                            algorithm: .ed25519,
                            publicKeyRaw: pub,
                            seed: seed,
                            status: .active)
    }
    
    // Soft-expire: mark status and/or expiry timestamp (POC only)
    public func expireCurrentKeyPOC(expiresAt: Date? = Date()) {
        guard var info = self.keyInfo else {
            return
        }
        info.status = .expired
        self.keyInfo = info
    }
    
    // Soft-revoke (POC): status revoked
    public func revokeCurrentKeyPOC(reason: String? = nil) {
        guard var info = self.keyInfo else {
            return
        }
        info.status = .revoked
        self.keyInfo = info
    }
    
    // Hard-expire: delete seed and derived keys (from earlier guidance)
    func deleteAllKeys() throws {
        try deleteSeed()
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
    
    // MARK: - Helpers
    private func derivePublicKey(fromSeed seed: Data) throws -> Data {
        if #available(iOS 13.0, *) {
            let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
            let publicKey = privateKey.publicKey
            return publicKey.rawRepresentation
        } else {
            do {
                guard let provider = provider else {
                    throw SEError(message: "CryptoProvider not set.")
                }
                return try provider.derivePublicKey(fromSeed: seed)
            } catch {
                throw SEError(message: "Failed to derive public key from seed.")
            }
        }
    }
    
    private func keyIdFromSeed(_ seed: Data) -> String {
        if #available(iOS 13.0, *) {
            let digest = SHA256.hash(data: seed)
            return uuidFromDigest(Data(digest))
        } else {
            guard let provider = provider, let hash = try? provider.getHash(of: seed) else {
                return uuidFromDigest(Data(Array(repeating: 0, count: 16)))
            }
            return uuidFromDigest(Data(hash))
        }
    }
    
    private func uuidFromDigest(_ data: Data) -> String {
        // Convert Data to [UInt8]
        var bytes: [UInt8] = Array(data)
        
        // Ensure we have at least 16 bytes (UUID requires 16)
        if bytes.count < 16 {
            bytes += Array(repeating: 0, count: 16 - bytes.count)
        }
        
        // Use only the first 16 bytes
        let u = UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
        
        return u.uuidString
    }
}
