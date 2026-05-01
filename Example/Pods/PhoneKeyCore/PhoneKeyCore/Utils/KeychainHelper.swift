//
//  KeyChainHelper.swift
//  loto-ios
//
//  Created by Sean Calkins on 3/14/19.
//  Updated by <you> on <today>: Per-install namespacing + correct accessibility + non-persistence across reinstall
//

import Foundation
import Security

// MARK: - Public API

public protocol KeychainQueryable {
    var query: [String: Any] { get }
}

/// Generates a stable "installId" for the current installation.
/// Because UserDefaults is cleared on uninstall, the installId changes after reinstall.
/// We use this to namespace the Keychain service so items from a previous install are
/// not visible anymore (functionally non-persistent across reinstall).
public enum InstallNamespace {
    private static let installIdKey = "com.noke.installId"

    /// Returns the current install id, creating one if missing.
    public static func currentInstallId() -> String {
        if let id = UserDefaults.standard.string(forKey: installIdKey), !id.isEmpty {
            return id
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: installIdKey)
        return newId
    }
}

/// Generic password queryable with per-install namespacing and correct accessibility handling.
public struct GenericPasswordQueryable {
    /// Base service name (stable across versions, e.g. "SmartEntryKeychainService")
    let baseService: String
    /// Optional access group (leave nil if you want items to be app-scoped)
    let accessGroup: String?
    /// Which kSecAttrAccessible to use (default: afterFirstUnlockThisDeviceOnly)
    let accessibility: CFString
    /// Per-install ID used to namespace service
    let installId: String

    /// Convenience init; installId defaults to the current install ID.
    public init(
        service: String,
        accessGroup: String? = nil,
        accessibility: CFString = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        installId: String = InstallNamespace.currentInstallId()
    ) {
        self.baseService = service
        self.accessGroup = accessGroup
        self.accessibility = accessibility
        self.installId = installId
    }

    /// Effective service used for Keychain items (baseService + per-install namespace).
    var namespacedService: String {
        return "\(baseService).\(installId)"
    }
}

extension GenericPasswordQueryable: KeychainQueryable {
    public var query: [String: Any] {
        var query: [String: Any] = [:]
        query[String(kSecClass)] = kSecClassGenericPassword
        query[String(kSecAttrService)] = namespacedService
        // Correct place for accessibility:
        query[String(kSecAttrAccessible)] = accessibility
        #if !targetEnvironment(simulator)
        if let accessGroup = accessGroup, !accessGroup.isEmpty {
            query[String(kSecAttrAccessGroup)] = accessGroup
        }
        #endif
        return query
    }
}

// MARK: - Keychain Helper

public struct KeychainHelper {
    public static let legacyNokeKeychainService = "NokeKeychainService"
    public static let nokeKeychainService = "SmartEntryKeychainService"

    let keychainQueryable: KeychainQueryable

    public init(keychainQueryable: KeychainQueryable) {
        self.keychainQueryable = keychainQueryable
    }

    /// Create/Update a secure string value
    public func setValue(_ value: String, forKey: String) throws {
        guard let encoded = value.data(using: .utf8) else {
            throw KeychainHelperError.stringToDataConversionError
        }
        var query = keychainQueryable.query
        query[String(kSecAttrAccount)] = forKey

        // Check if exists
        var status = SecItemCopyMatching(query as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            // Update
            let attributesToUpdate: [String: Any] = [String(kSecValueData): encoded]
            status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
            if status != errSecSuccess { throw error(from: status) }

        case errSecItemNotFound:
            // Add new
            var addQuery = query
            addQuery[String(kSecValueData)] = encoded
            status = SecItemAdd(addQuery as CFDictionary, nil)
            if status != errSecSuccess { throw error(from: status) }

        default:
            throw error(from: status)
        }
    }

    /// Read a secure string value
    public func getValue(forKey: String) throws -> String? {
        var query = keychainQueryable.query
        query[String(kSecMatchLimit)] = kSecMatchLimitOne
        query[String(kSecReturnAttributes)] = kCFBooleanTrue
        query[String(kSecReturnData)] = kCFBooleanTrue
        query[String(kSecAttrAccount)] = forKey

        var result: AnyObject?
        let status = withUnsafeMutablePointer(to: &result) {
            SecItemCopyMatching(query as CFDictionary, $0)
        }

        switch status {
        case errSecSuccess:
            guard
                let item = result as? [String: Any],
                let data = item[String(kSecValueData)] as? Data,
                let string = String(data: data, encoding: .utf8)
            else {
                throw KeychainHelperError.dataToStringConversionError
            }
            return string

        case errSecItemNotFound:
            return nil

        default:
            throw error(from: status)
        }
    }

    /// Delete a specific value
    public func removeValue(for key: String) throws {
        var query = keychainQueryable.query
        query[String(kSecAttrAccount)] = key
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw error(from: status)
        }
    }

    /// Delete ALL values for this queryable (current namespaced service)
    public func removeAllValues() throws {
        let query = keychainQueryable.query
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw error(from: status)
        }
    }

    // MARK: - Error mapping

    func error(from status: OSStatus) -> KeychainHelperError {
        if status == errSecInteractionNotAllowed {
            return .userInteractionNotAllowed
        }
        if #available(iOS 11.3, *) {
            let message = SecCopyErrorMessageString(status, nil) as String? ?? NSLocalizedString("Unhandled Error", comment: "")
            return .unhandledError(message: message)
        } else {
            let message = "Unhandled Error: \(status)"
            return .unhandledError(message: message)
        }
    }
}

// MARK: - Errors

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
            return "User interaction not allowed"
        case .unhandledError(let message):
            return message
        }
    }
}
