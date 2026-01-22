//
//  KeyChainHelper.swift
//  loto-ios
//
//  Created by Sean Calkins on 3/14/19.
//  Copyright © 2019 Noke Inc. All rights reserved.
//

import Foundation
import Security

public protocol KeychainQueryable {
    var query: [String: Any] { get }
}

public struct KeychainHelper {
    static public let legacyNokeKeychainService = "NokeKeychainService"
    static public let nokeKeychainService = "SmartEntryKeychainService"
    let keychainQueryable: KeychainQueryable
    
    public init (keychainQueryable: KeychainQueryable) {
        self.keychainQueryable = keychainQueryable
        
    }
    
    public func setValue(_ value: String, forKey: String) throws {
        guard let encodedPassword = value.data(using: .utf8) else {
            throw KeychainHelperError.stringToDataConversionError
        }
        var query = keychainQueryable.query
        query[String(kSecAttrAccount)] = forKey
        
        var status = SecItemCopyMatching(query as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            var attributesToUpdate: [String: Any] = [:]
            attributesToUpdate[String(kSecValueData)] = encodedPassword
            
            status = SecItemUpdate(query as CFDictionary,
                                   attributesToUpdate as CFDictionary)
            if status != errSecSuccess {
                throw error(from: status)
            }
//            UserDefaults.withSuite().set(true, forKey: UserDefaults.Keys.hasStoredPassword)
        case errSecItemNotFound:
            query[String(kSecValueData)] = encodedPassword
            status = SecItemAdd(query as CFDictionary, nil)
            if status != errSecSuccess {
                throw error(from: status)
            }
//            UserDefaults.withSuite().set(true, forKey: UserDefaults.Keys.hasStoredPassword)
        default:
            throw error(from: status)
        }
    }
    
    public func getValue(forKey: String) throws -> String? {
        var query = keychainQueryable.query
        query[String(kSecMatchLimit)] = kSecMatchLimitOne
        query[String(kSecReturnAttributes)] = kCFBooleanTrue
        query[String(kSecReturnData)] = kCFBooleanTrue
        query[String(kSecAttrAccount)] = forKey
        var queryResult: AnyObject?
        let status = withUnsafeMutablePointer(to: &queryResult) {
            SecItemCopyMatching(query as CFDictionary, $0)
        }
        
        switch status {
        case errSecSuccess:
            guard
                let queriedItem = queryResult as? [String: Any],
                let passwordData = queriedItem[String(kSecValueData)] as? Data,
                let password = String(data: passwordData, encoding: .utf8)
                else {
                    throw KeychainHelperError.dataToStringConversionError
            }
            return password
        case errSecItemNotFound:
            return nil
        default:
            print("KEYCHAIN STATUS")
            print(status)
            throw error(from: status)
        }
    }
    
    public func removeValue(for userAccount: String) throws {
        var query = keychainQueryable.query
        query[String(kSecAttrAccount)] = userAccount
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw error(from: status)
        }
    }
    
    public func removeAllValues() throws {
        let query = keychainQueryable.query
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw error(from: status)
        }
//        UserDefaults.withSuite().set(false, forKey: UserDefaults.Keys.hasStoredPassword)
    }
   
    func error(from status: OSStatus) -> KeychainHelperError {
        if status == -25308 {
            return .userInteractionNotAllowed
        }
        if #available(iOS 11.3, *) {
            let message = SecCopyErrorMessageString(status, nil) as String? ?? NSLocalizedString("Unhandled Error", comment: "")
            return KeychainHelperError.unhandledError(message: message)
        } else {
            let message = "Unhandled Error: \(status)"
            return KeychainHelperError.unhandledError(message: message)
        }
    }

}

public struct GenericPasswordQueryable {
    let service: String
    let accessGroup: String?
    
    public init(service: String, accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }
}

extension GenericPasswordQueryable: KeychainQueryable {
    public var query: [String: Any] {
        var query: [String: Any] = [:]
        query[String(kSecClass)] = kSecClassGenericPassword
        query[String(kSecAttrService)] = service
        query[String(kSecAttrAccount)] = kSecAttrAccessibleAfterFirstUnlock
        #if !targetEnvironment(simulator)
        if let accessGroup = accessGroup {
            query[String(kSecAttrAccessGroup)] = accessGroup
        }
        #endif
        return query
    }
}

public enum KeychainHelperError: Error {
    case stringToDataConversionError
    case dataToStringConversionError
    case unhandledError(message: String)
    case userInteractionNotAllowed
}

extension KeychainHelperError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .stringToDataConversionError:
            return "String to Data conversion error"
        case .dataToStringConversionError:
            return "Data to String conversion error"
        case .userInteractionNotAllowed:
            return "🤮"
        case .unhandledError(let message):
            return message
        }
    }
}
