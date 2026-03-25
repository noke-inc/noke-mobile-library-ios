//
//  NokeMobileLibraryError.swift
//  NokeMobileLibrary
//
//  Created by Noke Inc. on 3/25/26.
//  Copyright © 2026 Noke Inc. All rights reserved.
//

import Foundation

/// Public error type for all PhoneKey operations in NokeMobileLibrary.
/// Hides PhoneKeyCore implementation details and provides user-friendly error messages.
public enum NokeMobileLibraryError: Error, Equatable {
    // MARK: - Initialization Errors
    
    /// The library has not been initialized. Call initialize() before using PhoneKey features.
    case notInitialized
    
    /// Failed to initialize PhoneKeyCore. Check device keychain access and security settings.
    case initializationFailed(underlyingError: String?)
    
    // MARK: - Input Validation Errors
    
    /// Invalid input provided. Check that all required fields are present and valid.
    case invalidInput(reason: String)
    
    /// Invalid time window. End time must be after start time, and times must be in the future.
    case invalidTimeWindow(reason: String)
    
    /// Empty bulk request. At least one ACL must be requested.
    case emptyBulkRequest
    
    // MARK: - Authentication & Authorization Errors
    
    /// Authentication failed. Check credentials and try again.
    case unauthorized
    
    /// Access forbidden. User does not have permission to perform this operation.
    case forbidden
    
    // MARK: - Network & Communication Errors
    
    /// Network request failed. Check internet connection and try again.
    case networkError(underlyingError: String?)
    
    /// Request timeout. The operation took too long to complete.
    case timeout
    
    /// Server returned an error. Check server logs for details.
    case serverError(statusCode: Int, message: String?)
    
    // MARK: - Data Processing Errors
    
    /// Failed to decode response from server. The data may be malformed or incompatible.
    case decodingFailed(underlyingError: String?)
    
    /// Failed to encode request data. Check input parameters.
    case encodingFailed(underlyingError: String?)
    
    // MARK: - Phone Key Specific Errors
    
    /// Failed to provision phone key. Check device security settings and try again.
    case provisioningFailed(reason: String?)
    
    /// Failed to generate ACL. Check lock MAC address and permissions.
    case aclGenerationFailed(reason: String?)
    
    /// ACL signature verification failed. The lock may reject this ACL.
    case signatureVerificationFailed
    
    // MARK: - System & Internal Errors
    
    /// An unexpected internal error occurred. Contact support if this persists.
    case internalError(underlyingError: String?)
    
    /// Operation was cancelled by the system or user.
    case cancelled
    
    /// Unknown error occurred. Check logs for details.
    case unknown
    
    // MARK: - Public Properties
    
    /// User-friendly description of the error
    public var localizedDescription: String {
        switch self {
        case .notInitialized:
            return "PhoneKey service is not initialized. Please initialize the library before use."
            
        case .initializationFailed(let error):
            let base = "Failed to initialize PhoneKey service."
            return error.map { "\(base) Details: \($0)" } ?? base
            
        case .invalidInput(let reason):
            return "Invalid input: \(reason)"
            
        case .invalidTimeWindow(let reason):
            return "Invalid time window: \(reason)"
            
        case .emptyBulkRequest:
            return "Bulk ACL request must contain at least one item."
            
        case .unauthorized:
            return "Authentication failed. Please check your credentials."
            
        case .forbidden:
            return "Access forbidden. You do not have permission to perform this operation."
            
        case .networkError(let error):
            let base = "Network error occurred."
            return error.map { "\(base) Details: \($0)" } ?? base
            
        case .timeout:
            return "The operation timed out. Please try again."
            
        case .serverError(let code, let message):
            let base = "Server error (\(code))."
            return message.map { "\(base) \($0)" } ?? base
            
        case .decodingFailed(let error):
            let base = "Failed to decode server response."
            return error.map { "\(base) Details: \($0)" } ?? base
            
        case .encodingFailed(let error):
            let base = "Failed to encode request data."
            return error.map { "\(base) Details: \($0)" } ?? base
            
        case .provisioningFailed(let reason):
            let base = "Phone key provisioning failed."
            return reason.map { "\(base) \($0)" } ?? base
            
        case .aclGenerationFailed(let reason):
            let base = "ACL generation failed."
            return reason.map { "\(base) \($0)" } ?? base
            
        case .signatureVerificationFailed:
            return "ACL signature verification failed. The lock may reject this ACL."
            
        case .internalError(let error):
            let base = "An internal error occurred."
            return error.map { "\(base) Details: \($0)" } ?? base
            
        case .cancelled:
            return "Operation was cancelled."
            
        case .unknown:
            return "An unknown error occurred. Please try again."
        }
    }
    
    /// Optional diagnostic code for logging and support
    public var diagnosticCode: String {
        switch self {
        case .notInitialized: return "NML_001"
        case .initializationFailed: return "NML_002"
        case .invalidInput: return "NML_100"
        case .invalidTimeWindow: return "NML_101"
        case .emptyBulkRequest: return "NML_102"
        case .unauthorized: return "NML_200"
        case .forbidden: return "NML_201"
        case .networkError: return "NML_300"
        case .timeout: return "NML_301"
        case .serverError: return "NML_302"
        case .decodingFailed: return "NML_400"
        case .encodingFailed: return "NML_401"
        case .provisioningFailed: return "NML_500"
        case .aclGenerationFailed: return "NML_501"
        case .signatureVerificationFailed: return "NML_502"
        case .internalError: return "NML_900"
        case .cancelled: return "NML_901"
        case .unknown: return "NML_999"
        }
    }
}
