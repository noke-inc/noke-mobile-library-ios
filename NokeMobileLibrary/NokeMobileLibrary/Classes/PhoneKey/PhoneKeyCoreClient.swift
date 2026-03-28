//
//  PhoneKeyCoreClient.swift
//  NokeMobileLibrary
//
//  Created by Noke Inc. on 3/25/26.
//  Copyright © 2026 Noke Inc. All rights reserved.
//

import Foundation
import PhoneKeyCore

// MARK: - Protocol Definition

/// Internal protocol for abstracting all PhoneKeyCore interactions.
/// **iOS 12 Compatibility:** Uses completion handlers for full iOS 12+ support.
public protocol PhoneKeyCoreClient: AnyObject {
    
    /// Initialize the PhoneKeyCore library and ensure keys are generated
    func initialize(completion: @escaping (Result<String, Error>) -> Void)
    
    /// Check if the client has been initialized
    var isInitialized: Bool { get }
    
    /// Provision a new phone key
    func provisionPhoneKey(
        userId: String,
        deviceId: String,
        publicKey: String,
        completion: @escaping (Result<PhoneKeyInfoResponse, Error>) -> Void
    )
    
    /// Generate a single ACL
    func generateAcl(
        userId: Int,
        lockMac: String,
        phoneKeyId: Int,
        completion: @escaping (Result<BulkPhoneKeyAcl, Error>) -> Void
    )
    
    /// Generate multiple ACLs in bulk
    func generateBulkAcls(
        phoneKeyId: Int,
        completion: @escaping (Result<BulkPhoneKeyAclRoot, Error>) -> Void
    )
    
    /// Validate and retrieve the current key
    func validateCurrentKey() -> String?
}
