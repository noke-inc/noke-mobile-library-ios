//
//  PhoneKeyPersistence.swift
//  NokeMobileLibrary
//
//  Created by Noke Inc. on 3/26/26.
//  Copyright © 2026 Noke Inc. All rights reserved.
//

import Foundation
import PhoneKeyCore

/// Protocol for persisting phone key data (keys, ACLs, metadata)
/// Abstracts storage mechanism (keychain, UserDefaults, etc.)
public protocol PhoneKeyPersistence {
    
    // MARK: - Phone Key Info
    
    /// Retrieve phone key info for a user
    func getPhoneKeyInfo(userId: String) throws -> PhoneKeyInfoResponse?
    
    /// Save phone key info for a user
    func savePhoneKeyInfo(userId: String, info: PhoneKeyInfoResponse) throws
    
    /// Delete phone key info for a user
    func deletePhoneKeyInfo(userId: String) throws
    
    // MARK: - Bulk ACLs
    
    /// Get ACL for a specific lock
    func getACL(userId: String, lockMac: String) throws -> BulkPhoneKeyAcl?
    
    /// List all ACLs for current user
    func listACLs() throws -> [BulkPhoneKeyAcl]
    
    /// Save ACL for a lock
    func saveACL(userId: String, lockMac: String, acl: BulkPhoneKeyAcl) throws
    
    /// Delete ACL for a specific lock
    func deleteACL(userId: String, lockMac: String) throws
    
    /// Delete all ACLs for current user
    func deleteAllACLs() throws
}

/// Default implementation using PhoneKeyCore's PhoneKeyManager
/// Stores data in keychain via PhoneKeyCore
public final class DefaultPhoneKeyPersistence: PhoneKeyPersistence {
    
    private let phoneKeyManager: PhoneKeyManager
    
    
    /// Shared default instance for zero-config usage
    public static let `default` = DefaultPhoneKeyPersistence()

    public init(serviceName: String = "com.noke.PhoneKeyCore") {
        self.phoneKeyManager = PhoneKeyManager(serviceName: serviceName, provider: nil)
    }
    
    // MARK: - Phone Key Info
    
    public func getPhoneKeyInfo(userId: String) throws -> PhoneKeyInfoResponse? {
        return try phoneKeyManager.getPhoneKeyInfo(userId: userId)
    }
    
    public func savePhoneKeyInfo(userId: String, info: PhoneKeyInfoResponse) throws {
        try phoneKeyManager.savePhoneKeyInfo(userId: userId, info: info)
    }
    
    public func deletePhoneKeyInfo(userId: String) throws {
        try phoneKeyManager.deletePhoneKeyInfo(userId: userId)
    }
    
    // MARK: - Bulk ACLs
    
    public func getACL(userId: String, lockMac: String) throws -> BulkPhoneKeyAcl? {
        return try phoneKeyManager.getBulkACL(userId: userId, mac: lockMac)
    }
    
    public func listACLs() throws -> [BulkPhoneKeyAcl] {
        return try phoneKeyManager.listBulkACLs()
    }
    
    public func saveACL(userId: String, lockMac: String, acl: BulkPhoneKeyAcl) throws {
        if let existingACL = try? getACL(userId: userId, lockMac: lockMac) {
            return
        }
        try phoneKeyManager.saveBulkACL(userId: userId, mac: lockMac, acl)
    }
    
    public func deleteACL(userId: String, lockMac: String) throws {
        try phoneKeyManager.deleteACL(userId: userId, mac: lockMac)
    }
    
    public func deleteAllACLs() throws {
        try phoneKeyManager.deleteAllACLs()
    }
}
