//
//  PhoneKeyCore.swift
//  PhoneKeyCore
//
//  Created by Joffrey Mann on 1/20/26.
//

import Foundation

// MARK: - Capability protocol that consumers (e.g., NML) can use *optionally*

/// Small façade that expresses exactly what other SDKs/app layers need from PKC.
/// Keep this surface stable and minimal.
public protocol PhoneKeyCoreProviding: AnyObject {
    /// Returns cached key info if available (nil if ensureKeys() hasn't been called).
    var currentKeyInfo: PhoneKeyInfo? { get }

    /// Ensure keys exist (create if missing) and return key info.
    @discardableResult
    func ensureKeys() throws -> PhoneKeyInfo

    /// Ed25519 signature over `data` using the current key (creates key if needed).
    func sign(_ data: Data) throws -> Data

    /// Convenience: returns the active public key raw bytes (creates key if needed).
    func currentPublicKey() throws -> Data

    /// Destroys/clears the key material managed by this provider.
    func destroyKeys() throws
}

/// Lightweight global registry so a host app can make a provider discoverable at runtime
/// without forcing a hard compile-time dependency from other SDKs on PhoneKeyCore types.
///
/// Example in the host app:
///     let pkc = PhoneKeyManager(serviceName: ..., provider: SodiumCryptoProvider())
///     PhoneKeyCoreBridge.shared = pkc
public enum PhoneKeyCoreBridge {
    private static var _shared: PhoneKeyCoreProviding?
    public static var shared: PhoneKeyCoreProviding? {
        get { _shared }
        set { _shared = newValue }
    }
}

