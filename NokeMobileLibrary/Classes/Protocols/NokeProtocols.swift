//
//  NokeProtocols.swift
//  NokeMobileLibrary
//
//  Created by Noke Inc. on 3/25/26.
//  Copyright © 2026 Noke Inc. All rights reserved.
//

import Foundation
import PhoneKeyCore

// MARK: - Unlock Options

public protocol UnlockOptionsRepresentable {
    func isEmergencyUnlockRequired() -> Bool
    func isOverrideUnlockRequired() -> Bool
}

// MARK: - PhoneKey Handling

public protocol PhoneKeyHandling: AnyObject {
    func refetchAcl(request: PhoneKeyAclRequest)
}

public protocol NokePhoneKeyStateDelegate: AnyObject {
    func didUpdateAcl()
    func didRequestAclRefetch()
}

// MARK: - PhoneKey State

public final class NokePhoneKeyState {

    // MARK: ACL Fetch State
    weak var delegate: NokePhoneKeyStateDelegate?
    private(set) var newAcl: BulkPhoneKeyAcl?
    private var isFetchClosureInitialized = false

    /// Closure called when a new ACL envelope is fetched.
    public var onFetchNewAcl: ((BulkPhoneKeyAcl) -> Void)?

    /// Initializes the closure used to capture the new ACL envelopes.
    public func initializeFetchNewAclClosure() {
        guard !isFetchClosureInitialized else { return }

        self.onFetchNewAcl = { [weak self] acl in
            self?.newAcl = acl
            self?.delegate?.didUpdateAcl()
        }

        isFetchClosureInitialized = true
    }

    /// Current encryption mode being used.
    public var encryptionType: NokeEncryptionType = .signing

    /// Number of times signing has been retried.
    public private(set) var numOfSigningRetries: Int = 0

    /// Identifier for the signing key currently in use.
    public var signingKeyInfo: PhoneKeyInfoResponse?

    /// Whether signing can still be retried (max 2 attempts).
    public var isEligibleForSigningRetry: Bool {
        encryptionType == .signing && numOfSigningRetries < 2
    }
    
    public private(set) var options: UnlockOptionsRepresentable?
    
    public init(newAcl: BulkPhoneKeyAcl? = nil, isFetchClosureInitialized: Bool = false, onFetchNewAcl: ((BulkPhoneKeyAcl) -> Void)? = nil, encryptionType: NokeEncryptionType = .signing, numOfSigningRetries: Int = 0, signingKeyInfo: PhoneKeyInfoResponse? = nil) {
        self.newAcl = newAcl
        self.isFetchClosureInitialized = isFetchClosureInitialized
        self.onFetchNewAcl = onFetchNewAcl
        self.encryptionType = encryptionType
        self.numOfSigningRetries = numOfSigningRetries
        self.signingKeyInfo = signingKeyInfo
    }

    /// Increments retry counter for signing.
    public func incrementSigningRetry() {
        numOfSigningRetries += 1
    }
    
    public func setOptions(_ options: UnlockOptionsRepresentable?) {
        self.options = options
    }
    
    public func clearOptions() {
        self.options = nil
    }
}
