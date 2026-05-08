//
//  PhoneKeyAccessService.swift
//  NokeMobileLibrary
//
//  Created by Noke Inc. on 3/25/26.
//  Copyright © 2026 Noke Inc. All rights reserved.
//

import Foundation
import PhoneKeyCore

/// Public façade service for all Phone Key operations in NokeMobileLibrary.
///
/// **Setup Required:**
/// ```swift
/// // In AppDelegate:
/// let client = PhoneKeyCoreClientImpl()
/// PhoneKeyAccessService.setSharedClient(client)
/// ```
///
/// **iOS 12+ Compatible** - Uses completion handlers for maximum compatibility.
public class PhoneKeyAccessService {
    
    // MARK: - Singleton
    
    /// Shared singleton instance (must call setSharedClient before use)
    public static var shared: PhoneKeyAccessService = PhoneKeyAccessService(client: nil)
    
    /// Set the client implementation (required - call in AppDelegate)
    /// - Parameter client: PhoneKeyCoreClient implementation
    public static func setSharedClient(_ client: PhoneKeyCoreClient) {
        shared = PhoneKeyAccessService(client: client)
    }
    
    // MARK: - Properties
    
    private let client: PhoneKeyCoreClient?
    private let completionQueue: DispatchQueue
    
    // MARK: - Initialization
    
    init(client: PhoneKeyCoreClient?, completionQueue: DispatchQueue = .main) {
        self.client = client
        self.completionQueue = completionQueue
    }
    
    // MARK: - Public API (Completion Handlers - iOS 12+)
    
    /// Initialize the Phone Key service.
    /// - Parameter completion: Called with Result containing public key or error
    public func initialize(completion: @escaping (Result<String, Error>) -> Void) {
        guard let client = client else {
            completionQueue.async {
                completion(.failure(NokeMobileLibraryError.notInitialized))
            }
            return
        }
        
        client.initialize { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let publicKey):
                self.completionQueue.async {
                    completion(.success(publicKey))
                }
            case .failure(let error):
                self.completionQueue.async {
                    completion(.failure(self.translateError(error, context: "initialization")))
                }
            }
        }
    }
    
    /// Check if the service has been initialized
    public var isInitialized: Bool {
        return client?.isInitialized ?? false
    }
    
    /// Validate and retrieve the current key
    /// - Returns: Public key as base64 encoded string, or nil if no valid key exists
    public func validateCurrentKey() -> String? {
        return client?.validateCurrentKey()
    }
    
    /// Provision a new phone key for a device
    /// - Parameters:
    ///   - request: PhoneKeyInfoRequest with user ID, device ID, and public key
    ///   - completion: Called with Result containing PhoneKeyInfoResponse or error
    public func provisionPhoneKey(
        _ request: PhoneKeyInfoRequest,
        completion: @escaping (Result<PhoneKeyInfoResponse, Error>) -> Void
    ) {
        guard let client = client else {
            completionQueue.async {
                completion(.failure(NokeMobileLibraryError.notInitialized))
            }
            return
        }
        
        client.provisionPhoneKey(
            userId: request.userId,
            deviceId: request.phoneUdid,
            publicKey: request.publicKey
        ) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let response):
                self.completionQueue.async {
                    completion(.success(response))
                }
            case .failure(let error):
                self.completionQueue.async {
                    completion(.failure(self.translateError(error, context: "phone key provisioning")))
                }
            }
        }
    }
    
    /// Generate a single ACL for lock access
    /// - Parameters:
    ///   - request: PhoneKeyAclRequest with user ID, lock MAC, and phone key ID
    ///   - completion: Called with Result containing BulkPhoneKeyAcl or error
    public func generateAcl(
        _ request: PhoneKeyAclRequest,
        completion: @escaping (Result<BulkPhoneKeyAcl, Error>) -> Void
    ) {
        guard let client = client else {
            completionQueue.async {
                completion(.failure(NokeMobileLibraryError.notInitialized))
            }
            return
        }
        
        client.generateAcl(
            userId: request.userId,
            lockMac: request.lockMac,
            phoneKeyId: request.phoneKeyId
        ) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let acl):
                self.completionQueue.async {
                    completion(.success(acl))
                }
            case .failure(let error):
                self.completionQueue.async {
                    completion(.failure(self.translateError(error, context: "ACL generation")))
                }
            }
        }
    }
    
    /// Generate multiple ACLs in bulk
    /// - Parameters:
    ///   - request: PhoneKeyBulkAclRequest with phone key ID
    ///   - completion: Called with Result containing BulkAclResponse or error
    public func generateBulkAcls(
        _ request: PhoneKeyBulkAclRequest,
        completion: @escaping (Result<BulkAclResponse, Error>) -> Void
    ) {
        guard let client = client else {
            completionQueue.async {
                completion(.failure(NokeMobileLibraryError.notInitialized))
            }
            return
        }
        
        client.generateBulkAcls(phoneKeyId: request.phoneKeyId) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let bulkRoot):
                let response = BulkAclResponse(from: bulkRoot)
                self.completionQueue.async {
                    completion(.success(response))
                }
            case .failure(let error):
                self.completionQueue.async {
                    completion(.failure(self.translateError(error, context: "bulk ACL generation")))
                }
            }
        }
    }
    
    // MARK: - Error Translation
    
    private func translateError(_ error: Error, context: String) -> NokeMobileLibraryError {
        if let nmlError = error as? NokeMobileLibraryError {
            return nmlError
        }
        return .internalError(underlyingError: "\(context): \(error.localizedDescription)")
    }
}

// MARK: - Async/Await Extensions (iOS 13+)

#if compiler(>=5.5) && canImport(_Concurrency)
@available(iOS 13.0, watchOS 6.0, *)
extension PhoneKeyAccessService {
    
    /// Initialize the Phone Key service (async/await version)
    public func initializeAsync() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            self.initialize { result in
                continuation.resume(with: result)
            }
        }
    }
    
    /// Provision a new phone key (async/await version)
    public func provisionPhoneKeyAsync(_ request: PhoneKeyInfoRequest) async throws -> PhoneKeyInfoResponse {
        return try await withCheckedThrowingContinuation { continuation in
            self.provisionPhoneKey(request) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    /// Generate a single ACL (async/await version)
    public func generateAclAsync(_ request: PhoneKeyAclRequest) async throws -> BulkPhoneKeyAcl {
        return try await withCheckedThrowingContinuation { continuation in
            self.generateAcl(request) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    /// Generate multiple ACLs in bulk (async/await version)
    public func generateBulkAclsAsync(_ request: PhoneKeyBulkAclRequest) async throws -> BulkAclResponse {
        return try await withCheckedThrowingContinuation { continuation in
            self.generateBulkAcls(request) { result in
                continuation.resume(with: result)
            }
        }
    }
}
#endif

// MARK: - Logging Support

extension PhoneKeyAccessService {
    
    private func log(_ message: String, level: LogLevel = .info) {
        let prefix: String
        switch level {
        case .info:
            prefix = "[PhoneKeyAccess]"
        case .warning:
            prefix = "[PhoneKeyAccess WARNING]"
        case .error:
            prefix = "[PhoneKeyAccess ERROR]"
        }
        print("\(prefix) \(message)")
    }
    
    private enum LogLevel {
        case info
        case warning
        case error
    }
}
