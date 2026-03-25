//
//  NokeDevice+Signing.swift
//  Pods
//
//  Created by Joffrey Mann on 2/17/26.
//
//  REFACTORED 3/25/26 following TIDY principles:
//  - Delegates state management to Ion2SigningCoordinator
//  - Delegates BLE operations to Ion2CharacteristicHandler
//  - NokeDevice is now a thin adapter, not a state machine

import CoreBluetooth
import PhoneKeyCore

extension NokeDevice {
    
    // MARK: - Public API (Entry Point)
    
    /// Start Ion 2 signing-based unlock
    /// **TIDY:** Single entry point with clear intent
    public func unlockForSigning(aclResponse: BulkPhoneKeyAcl, userId: String?, deviceID: String?, options: UnlockOptionsRepresentable? = nil) {
        self.signingKeyState?.delegate = self
        self.signingKeyState?.setOptions(options)
        self.userId = userId
        self.deviceID = deviceID
        
        // Validate requirements
        if isEmergencyUnlockRequired() {
            handleFailure?(NokeDeviceSigningError.requiresEmergencyUnlockUnlock)
            return
        }
        
        if isOverrideUnlockRequired() {
            handleFailure?(NokeDeviceSigningError.requiresOverrideUnlock)
            return
        }
        
        // Create coordinator if needed
        if ion2SigningCoordinator == nil {
            ion2SigningCoordinator = Ion2SigningCoordinator(
                characteristicHandler: getOrCreateIon2Handler(),
                phoneKeyManager: phoneKeyManager
            )
        }
        
        // Start unlock via coordinator
        guard let userId = userId, let deviceID = deviceID else {
            handleFailure?(NokeDeviceSigningError.internalError(message: "Missing userId or deviceID"))
            return
        }
        
        ion2SigningCoordinator?.startUnlock(
            acl: aclResponse,
            userId: userId,
            deviceID: deviceID,
            onSuccess: { [weak self] in
                self?.handleSuccess?()
            },
            onFailure: { [weak self] error in
                self?.handleFailure?(error)
            }
        )
    }
    
    // MARK: - Coordinator Callbacks
    
    /// Handle ACL status updates from lock
    /// **TIDY:** Thin adapter - delegates to coordinator
    func handleACLStatus(_ status: NokeDeviceSigningStatus) {
        ion2SigningCoordinator?.handleStatus(status)
    }
    
    /// Handle command ID read completion
    /// **TIDY:** Thin adapter - delegates to coordinator
    func handleCommandIdRead(result: Result<Data, Error>) {
        ion2SigningCoordinator?.handleCommandIdRead(result: result)
    }
    
    // MARK: - Helper Methods (Minimal Logic)
    
    private func getOrCreateIon2Handler() -> Ion2CharacteristicHandler {
        if let existing = ion2CharacteristicHandler {
            return existing
        }
        let handler = Ion2CharacteristicHandler(peripheral: peripheral)
        ion2CharacteristicHandler = handler
        return handler
    }
    
    private func isEmergencyUnlockRequired() -> Bool {
        guard let signingKeyState, let options = signingKeyState.options else {
            return false
        }
        return options.isEmergencyUnlockRequired()
    }
    
    private func isOverrideUnlockRequired() -> Bool {
        guard let signingKeyState, let options = signingKeyState.options else {
            return false
        }
        return options.isOverrideUnlockRequired()
    }
}

// MARK: - NokePhoneKeyStateDelegate

extension NokeDevice: NokePhoneKeyStateDelegate {
    func didRequestAclRefetch() {
        refetchAcl()
    }
    
    func didUpdateAcl() {
        guard let signingKeyState, let acl = signingKeyState.newAcl else {
            return
        }
        unlockForSigning(aclResponse: acl, userId: userId, deviceID: deviceID)
    }
    
    private func refetchAcl() {
        print("Refetching ACL from server for retry")
        guard let signingKeyState, let userIdStr = userId, let userId = Int(userIdStr), let signingKeyId = signingKeyState.signingKeyInfo?.keyId else {
            return
        }
        phoneKeyHandler?.refetchAcl(request: PhoneKeyAclRequest(userId: userId, lockMac: mac, phoneKeyId: signingKeyId))
    }
}

// MARK: - Data Extension (Utility)

extension Data {
    /// Raw bytes → hex string
    var hex: String {
        self.map { String(format: "%02x", $0) }.joined()
    }

    /// Raw bytes → base64 string
    var b64: String {
        self.base64EncodedString()
    }

    /// Raw bytes → base64 → hex of ASCII(base64)
    var base64Hex: String {
        let b64 = self.base64EncodedString()
        return b64.utf8.map { String(format: "%02x", $0) }.joined()
    }
}
