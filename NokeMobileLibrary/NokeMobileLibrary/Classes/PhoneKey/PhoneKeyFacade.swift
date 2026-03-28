//
//  PhoneKeyFacade.swift
//  NokeMobileLibrary
//
//  Created by Noke Inc. on 3/26/26.
//  Copyright © 2026 Noke Inc. All rights reserved.
//

import Foundation
import PhoneKeyCore

/// Callback for when ACLs are loaded
public typealias AclLoadCallback = ([BulkPhoneKeyAcl]) -> Void

/// Public manager for phone key provisioning and ACL lifecycle in NokeMobileLibrary
/// **Zero-Config:** Works out of the box with default implementations
/// **For Third-Party Use:** Call this from your app to manage phone keys and ACLs
///
/// **Usage:**
/// ```swift
/// // Simple usage (completion handler - iOS 12+)
/// PhoneKeyFacade.shared.ensureProvisioned(
///     userId: "user123",
///     deviceId: "device456"
/// ) { result in
///     switch result {
///     case .success(let acls):
///         print("Provisioned with \(acls.count) ACLs")
///     case .failure(let error):
///         print("Error: \(error)")
///     }
/// }
/// ```
public final class PhoneKeyFacade {
    
    // MARK: - Singleton
    
    public static let shared = PhoneKeyFacade()
    
    // MARK: - Dependencies (Internal)
    
    /// Access to underlying persistence layer (for advanced usage)
    private let persistence: PhoneKeyPersistence
    
    private let keyManager: PhoneKeyCore.PhoneKeyManager
    private let serialQueue: DispatchQueue
    
    // MARK: - Initialization
    
    public init(
        persistence: PhoneKeyPersistence = DefaultPhoneKeyPersistence.default
    ) {
        self.persistence = persistence
        self.keyManager = PhoneKeyCore.PhoneKeyManager(serviceName: "com.noke.PhoneKeyCore", provider: nil)
        self.serialQueue = DispatchQueue(label: "com.noke.PhoneKeyManager", qos: .userInitiated)
    }
    
    // MARK: - Public API (Thread-Safe)
    
    /// Ensures phone key is provisioned and returns cached ACLs (if available)
    /// **Zero-Config:** Just provide userId and deviceId
    ///
    /// **Flow:**
    /// 1. Generate/validate key pair (keychain)
    /// 2. Check if phone key info exists (keychain)
    /// 3. Return cached ACLs if available
    /// 4. Third parties then call their API to provision if needed
    ///
    /// - Parameters:
    ///   - userId: User identifier
    ///   - deviceId: Device identifier (UUID)
    ///   - completion: Result with cached ACLs or error
    public func ensureProvisioned(
        userId: String,
        deviceId: String,
        completion: @escaping (Result<[BulkPhoneKeyAcl], Error>) -> Void
    ) {
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                // 1. Ensure key pair exists
                let keyInfo = try self.keyManager.ensureP256Keys(userId: userId, deviceID: Data(deviceId.utf8))
                let publicKey = keyInfo.publicKeyRaw.base64EncodedString()
                print("[PhoneKeyManager] Key ensured: \(publicKey.prefix(20))...")
                
                // 2. Check if phone key info exists
                if let phoneKeyInfo = try self.persistence.getPhoneKeyInfo(userId: userId) {
                    print("[PhoneKeyManager] Phone key exists: keyId=\(phoneKeyInfo.keyId ?? 0)")
                    
                    // 3. Return cached ACLs
                    let cachedAcls = try self.persistence.listACLs().filter { $0.expiresAt > Date() }
                    print("[PhoneKeyManager] Found \(cachedAcls.count) valid ACLs in cache")
                    
                    DispatchQueue.main.async {
                        completion(.success(cachedAcls))
                    }
                } else {
                    print("[PhoneKeyManager] No phone key info found - provision required")
                    DispatchQueue.main.async {
                        completion(.success([]))  // Empty ACLs - third party should provision
                    }
                }
            } catch {
                print("[PhoneKeyManager] Error: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Get public key for current user (for API provisioning)
    /// - Parameters:
    ///   - userId: User identifier
    ///   - deviceId: Device identifier
    /// - Returns: Base64-encoded public key or nil
    public func getPublicKey(userId: String, deviceId: String) -> String? {
        do {
            let keyInfo = try keyManager.ensureP256Keys(userId: userId, deviceID: Data(deviceId.utf8))
            return keyInfo.publicKeyRaw.base64EncodedString()
        } catch {
            print("[PhoneKeyManager] Error getting public key: \(error)")
            return nil
        }
    }
    
    /// Save phone key info after provisioning from API
    /// - Parameters:
    ///   - userId: User identifier
    ///   - info: Phone key info response from API
    public func savePhoneKeyInfo(userId: String, info: PhoneKeyInfoResponse) throws {
        try persistence.savePhoneKeyInfo(userId: userId, info: info)
        print("[PhoneKeyManager] Phone key info saved: keyId=\(info.keyId ?? 0)")
    }
    
    /// Save ACL to cache
    /// - Parameters:
    ///   - userId: User identifier
    ///   - lockMac: Lock MAC address
    ///   - acl: ACL to save
    public func saveACL(userId: String, lockMac: String, acl: BulkPhoneKeyAcl) throws {
        try persistence.saveACL(userId: userId, lockMac: lockMac, acl: acl)
        print("[PhoneKeyManager] ACL saved for lock: \(lockMac)")
    }
    
    /// Get ACL for specific lock
    /// - Parameters:
    ///   - userId: User identifier
    ///   - lockMac: Lock MAC address
    /// - Returns: ACL if found and not expired
    public func getACL(userId: String, lockMac: String) -> BulkPhoneKeyAcl? {
        guard let acl = try? persistence.getACL(userId: userId, lockMac: lockMac),
              acl.expiresAt > Date() else {
            return nil
        }
        return acl
    }
    
    /// List all valid (non-expired) ACLs
    /// - Returns: Array of valid ACLs
    public func listValidACLs() -> [BulkPhoneKeyAcl] {
        guard let acls = try? persistence.listACLs() else {
            return []
        }
        return acls.filter { $0.expiresAt > Date() }
    }
    
    /// Clear all phone key data (call on logout)
    /// - Parameter userId: User identifier
    public func clearAll(userId: String) {
        do {
            try persistence.deletePhoneKeyInfo(userId: userId)
            try persistence.deleteAllACLs()
            print("[PhoneKeyManager] Cleared all phone key data for user: \(userId)")
        } catch {
            print("[PhoneKeyManager] Error clearing data: \(error)")
        }
    }
    
    public func getPhoneKeyInfo(userId: String) throws -> PhoneKeyInfoResponse? {
        return try? persistence.getPhoneKeyInfo(userId: userId)
    }
}
