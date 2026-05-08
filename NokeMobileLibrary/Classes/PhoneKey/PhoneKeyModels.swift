//
//  PhoneKeyModels.swift
//  NokeMobileLibrary
//
//  Created by Noke Inc. on 3/25/26.
//  Copyright © 2026 Noke Inc. All rights reserved.
//

import Foundation
import PhoneKeyCore

// MARK: - Public Type Aliases

/// Re-export PhoneKeyCore types for convenience
/// These are the ONLY types consumers should use - no duplicate models

// Request types from PhoneKeyCore
public typealias PhoneKeyProvisionRequest = PhoneKeyInfoRequest
public typealias AclRequest = PhoneKeyAclRequest
public typealias BulkAclRequest = PhoneKeyBulkAclRequest

// Response types from PhoneKeyCore
public typealias PhoneKeyProvisionResponse = PhoneKeyInfoResponse
public typealias Acl = BulkPhoneKeyAcl
public typealias BulkAclRoot = BulkPhoneKeyAclRoot

// MARK: - Domain Helper Extensions

// MARK: PhoneKeyInfoRequest Extensions

extension PhoneKeyInfoRequest {
    /// Convenience initializer with clearer naming for provisioning
    public static func forProvisioning(userId: String, deviceId: String, publicKey: String) -> PhoneKeyInfoRequest {
        return PhoneKeyInfoRequest(userId: userId, phoneUdid: deviceId, publicKey: publicKey)
    }
}

// MARK: PhoneKeyInfoResponse Extensions

extension PhoneKeyInfoResponse {
    /// Whether the provisioning was successful
    public var isSuccess: Bool {
        return keyId != nil && error == nil
    }
    
    /// User-friendly status message
    public var statusMessage: String {
        if let error = error {
            return error
        }
        if let detail = detail {
            return detail
        }
        return status
    }
}

// MARK: PhoneKeyAclRequest Extensions

extension PhoneKeyAclRequest {
    /// Convenience initializer with String userId (converts to Int)
    public init?(userIdString: String, lockMac: String, phoneKeyId: Int) {
        guard let userId = Int(userIdString) else {
            return nil
        }
        self.init(userId: userId, lockMac: lockMac, phoneKeyId: phoneKeyId)
    }
}

// MARK: BulkPhoneKeyAcl Extensions

extension BulkPhoneKeyAcl {
    /// Whether this ACL is currently valid (not expired)
    public var isValid: Bool {
        return expiresAt > Date()
    }
    
    /// Whether this ACL has expired
    public var isExpired: Bool {
        return !isValid
    }
    
    /// Time remaining until expiration
    public var timeUntilExpiration: TimeInterval {
        return expiresAt.timeIntervalSinceNow
    }
    
    /// Whether this ACL was successful (has result = "success")
    public var isSuccess: Bool {
        return result?.lowercased() == "success"
    }
}

// MARK: BulkPhoneKeyAclRoot Extensions

extension BulkPhoneKeyAclRoot {
    /// Whether the bulk operation was successful
    public var isSuccess: Bool {
        return result.lowercased() == "success"
    }
    
    /// Count of ACLs returned
    public var count: Int {
        return acls.count
    }
    
    /// All valid (non-expired) ACLs
    public var validAcls: [BulkPhoneKeyAcl] {
        return acls.filter { $0.isValid }
    }
    
    /// All expired ACLs
    public var expiredAcls: [BulkPhoneKeyAcl] {
        return acls.filter { $0.isExpired }
    }
    
    /// Get ACL by lock MAC address
    public func acl(forLockMac mac: String) -> BulkPhoneKeyAcl? {
        return acls.first { $0.lockMac.lowercased() == mac.lowercased() }
    }
}

// MARK: - Bulk ACL Result Modeling

/// Result of a single ACL operation in a bulk request
/// This provides a clearer way to model partial success scenarios
public enum BulkAclItemResult {
    /// ACL was successfully generated
    case success(BulkPhoneKeyAcl)
    
    /// ACL generation failed for this item
    case failure(lockMac: String, error: NokeMobileLibraryError)
    
    /// Lock MAC address for this result
    public var lockMac: String {
        switch self {
        case .success(let acl):
            return acl.lockMac
        case .failure(let lockMac, _):
            return lockMac
        }
    }
    
    /// Whether this result is a success
    public var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }
    
    /// Whether this result is a failure
    public var isFailure: Bool {
        return !isSuccess
    }
    
    /// The successful ACL if this is a success case
    public var acl: BulkPhoneKeyAcl? {
        if case .success(let acl) = self {
            return acl
        }
        return nil
    }
    
    /// The error if this is a failure case
    public var error: NokeMobileLibraryError? {
        if case .failure(_, let error) = self {
            return error
        }
        return nil
    }
}

/// Response from bulk ACL generation with status tracking
public struct BulkAclResponse {
    /// Overall status of the bulk operation
    public let status: BulkAclStatus
    
    /// Results for each requested ACL
    public let results: [BulkAclItemResult]
    
    /// The underlying root response from PhoneKeyCore
    public let root: BulkPhoneKeyAclRoot
    
    public init(status: BulkAclStatus, results: [BulkAclItemResult], root: BulkPhoneKeyAclRoot) {
        self.status = status
        self.results = results
        self.root = root
    }
    
    /// Convenience initializer from BulkPhoneKeyAclRoot
    public init(from root: BulkPhoneKeyAclRoot) {
        self.root = root
        
        // Convert all ACLs to success results
        let results: [BulkAclItemResult] = root.acls.map { .success($0) }
        
        // Determine status
        let status: BulkAclStatus
        if results.isEmpty {
            status = .fullFailure
        } else if results.allSatisfy({ $0.isSuccess }) {
            status = .fullSuccess
        } else {
            let successCount = results.filter { $0.isSuccess }.count
            let failureCount = results.count - successCount
            status = .partialSuccess(successCount: successCount, failureCount: failureCount)
        }
        
        self.status = status
        self.results = results
    }
    
    /// Count of successful ACL generations
    public var successCount: Int {
        results.filter { $0.isSuccess }.count
    }
    
    /// Count of failed ACL generations
    public var failureCount: Int {
        results.filter { $0.isFailure }.count
    }
    
    /// All successfully generated ACLs
    public var successfulAcls: [BulkPhoneKeyAcl] {
        results.compactMap { $0.acl }
    }
    
    /// All failed ACL requests with their errors
    public var failures: [(lockMac: String, error: NokeMobileLibraryError)] {
        results.compactMap {
            if case .failure(let lockMac, let error) = $0 {
                return (lockMac, error)
            }
            return nil
        }
    }
}

/// Status of bulk ACL operation
public enum BulkAclStatus: Equatable {
    /// All ACLs were generated successfully
    case fullSuccess
    
    /// Some ACLs were generated, but some failed
    case partialSuccess(successCount: Int, failureCount: Int)
    
    /// All ACLs failed to generate
    case fullFailure
    
    /// Whether any ACLs were successfully generated
    public var hasSuccesses: Bool {
        switch self {
        case .fullSuccess, .partialSuccess:
            return true
        case .fullFailure:
            return false
        }
    }
    
    /// Whether any ACLs failed to generate
    public var hasFailures: Bool {
        switch self {
        case .fullFailure, .partialSuccess:
            return true
        case .fullSuccess:
            return false
        }
    }
}
