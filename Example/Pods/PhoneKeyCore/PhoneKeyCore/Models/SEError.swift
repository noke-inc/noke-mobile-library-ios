//
//  SmartStorageError.swift
//  StorageSmartEntry
//
//  Created by Sean Calkins on 4/1/19.
//  Copyright © 2019 Noke Inc. All rights reserved.
//

import Foundation

public enum SEPhoneKeyErrorCode: Int {
    case NoError                        =  0
    case ErrCryptoProviderNotSet          =  1
    case ErrFailedToSignData             =  2
    case ErrFailedToDerivePublicKey      =  3
    case Unknown                        = 99
}

public struct SEPhoneKeyError: Error {
    public var rawCode: Int = 0
    public var code: SEPhoneKeyErrorCode = .NoError
    public var userFacingValue: String = ""
    public var subcode: Int = 0
    public var type: String = ""
    public var jsonSent: [String: Any]?
    public var jsonReceived: [String: Any]?
    public var url: String = ""
    public var endpoint: String = ""
    public var errorID: Int = 0
    public var custom: String = ""
    public var messageString: String = ""
    
    public init(message: String) {
        self.custom = message
    }
    
    public init(userFacingValue: String, code: SEPhoneKeyErrorCode) {
        self.userFacingValue = userFacingValue
        self.code = code
    }
    
    public init(code: Int, subcode: Int, type: String, messageString: String = "") {
        self.rawCode = code
        self.code = SEPhoneKeyErrorCode(rawValue: code) ?? .Unknown
        self.subcode = subcode
        self.type = type
        self.messageString = messageString
    }
    
    public init(rawCode: Int) {
        self.rawCode = rawCode
        self.code = SEPhoneKeyErrorCode(rawValue: rawCode) ?? .Unknown
    }
    
    public static func string(from code: SEPhoneKeyErrorCode) -> String {
        var errorMessage = ""
        if (code != .NoError) {
            switch code {
                case .ErrCryptoProviderNotSet:
                    errorMessage = "Crypto provider not set."
                case .ErrFailedToSignData:
                    errorMessage = "Failed to sign data."
                case .ErrFailedToDerivePublicKey:
                    errorMessage = "Failed to derive public key from seed."
                case .Unknown:
                    errorMessage = "An unknown error occurred."
                default:
                    errorMessage = "An unspecified error occurred."
            }
        }
        
        return errorMessage
    }
    
    public static func cryptoProviderNotSet() -> SEPhoneKeyError {
        return SEPhoneKeyError(rawCode: SEPhoneKeyErrorCode.ErrCryptoProviderNotSet.rawValue)
    }
    
    public static func failedToSignData() -> SEPhoneKeyError {
        return SEPhoneKeyError(rawCode: SEPhoneKeyErrorCode.ErrFailedToSignData.rawValue)
    }
    
    public static func failedToDerivePublicKey() -> SEPhoneKeyError {
        return SEPhoneKeyError(rawCode: SEPhoneKeyErrorCode.ErrFailedToDerivePublicKey.rawValue)
    }
}
