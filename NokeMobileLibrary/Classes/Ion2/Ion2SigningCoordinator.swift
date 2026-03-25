//
//  Ion2SigningCoordinator.swift
//  NokeMobileLibrary
//
//  Created by Noke Inc. on 3/25/26.
//  Copyright © 2026 Noke Inc. All rights reserved.
//

import Foundation
import CoreBluetooth
import PhoneKeyCore

/// Coordinator for Ion 2 signing-based unlock flow.
///
/// **TIDY Principles:**
/// - **Single Responsibility:** Manages ONLY the Ion 2 signing state machine
/// - **Clear Intent:** Each state transition is explicit and intentional
/// - **Minimal Layers:** Direct coordination without unnecessary abstraction
///
/// **State Machine Flow:**
/// 1. writeTime → timeSynced
/// 2. writeAcl → aclReceived/aclValidated
/// 3. writeAclSignature → aclSigVerified
/// 4. readCommandId → commandId received
/// 5. writeCommand → cmdReceived
/// 6. writeCommandSignature → unlockExecuted
///
/// **NOT in scope:**
/// - BLE communication (delegated to Ion2CharacteristicHandler)
/// - Business logic validation (caller's responsibility)
/// - PhoneKey management (uses injected PhoneKeyManager)
internal final class Ion2SigningCoordinator {
    
    // MARK: - State
    
    enum SigningState: Equatable {
        case idle
        case writingTime
        case writingAcl
        case writingSignature
        case readingCommandId
        case writingCommand
        case writingCommandSignature
        case completed
        case failed(NokeDeviceSigningError)
        
        static func == (lhs: SigningState, rhs: SigningState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle),
                 (.writingTime, .writingTime),
                 (.writingAcl, .writingAcl),
                 (.writingSignature, .writingSignature),
                 (.readingCommandId, .readingCommandId),
                 (.writingCommand, .writingCommand),
                 (.writingCommandSignature, .writingCommandSignature),
                 (.completed, .completed):
                return true
            case (.failed, .failed):
                return true
            default:
                return false
            }
        }
    }
    
    private var state: SigningState = .idle
    
    // MARK: - Dependencies
    
    private let characteristicHandler: Ion2CharacteristicHandler
    private let phoneKeyManager: PhoneKeyManager
    
    // MARK: - Current Operation Data
    
    private var currentAcl: BulkPhoneKeyAcl?
    private var currentAclData: Data?
    private var currentSignatureData: Data?
    private var currentCommandSignatureData: Data?
    private var userId: String?
    private var deviceID: String?
    private var retryCount: Int = 0
    private let maxRetries: Int = 3
    
    // MARK: - Completion Handlers
    
    private var successHandler: (() -> Void)?
    private var failureHandler: ((NokeDeviceSigningError) -> Void)?
    
    // MARK: - Initialization
    
    init(characteristicHandler: Ion2CharacteristicHandler, phoneKeyManager: PhoneKeyManager) {
        self.characteristicHandler = characteristicHandler
        self.phoneKeyManager = phoneKeyManager
    }
    
    // MARK: - Public API
    
    /// Start the Ion 2 signing unlock flow
    func startUnlock(
        acl: BulkPhoneKeyAcl,
        userId: String,
        deviceID: String,
        onSuccess: @escaping () -> Void,
        onFailure: @escaping (NokeDeviceSigningError) -> Void
    ) {
        // Check if we're in a state where we can start a new unlock
        switch state {
        case .idle, .completed, .failed:
            break // OK to proceed
        default:
            onFailure(.unknown) // "Signing already in progress"
            return
        }
        
        // Validate ACL
        guard !acl.aclBinary.isEmpty else {
            onFailure(.missingAcl)
            return
        }
        
        guard !acl.aclSignature.isEmpty else {
            onFailure(.invalidAclSignature)
            return
        }
        
        guard
            let aclData = Data(base64Encoded: acl.aclBinary, options: .ignoreUnknownCharacters),
            let sigDer = Data(base64Encoded: acl.aclSignature, options: .ignoreUnknownCharacters)
        else {
            onFailure(.invalidAclSignature)
            return
        }
        
        // Store operation data
        self.currentAcl = acl
        self.currentAclData = aclData
        self.currentSignatureData = sigDer
        self.userId = userId
        self.deviceID = deviceID
        self.successHandler = onSuccess
        self.failureHandler = onFailure
        self.retryCount = 0
        
        // Start flow: write time
        writeTime()
    }
    
    /// Handle status update from lock
    func handleStatus(_ status: NokeDeviceSigningStatus) {
        print("[Ion2Coordinator] Status: \(status) in state: \(state)")
        
        switch status {
        case .timeSynced:
            handleTimeSynced()
        case .timeOffsetErr:
            fail(.timeOffsetError)
        case .aclReceived, .aclValidated:
            handleAclReceived()
        case .aclSigVerified:
            handleSignatureVerified()
        case .cmdReceived:
            handleCommandReceived()
        case .unlockExecuted:
            handleUnlockExecuted()
        case .aclRejected, .aclSetupError:
            fail(.aclRejected)
        case .aclTimeExpired:
            handleAclTimeExpired()
        case .aclTimeInvalid:
            fail(.aclTimeInvalid)
        case .aclSigVerifyFailed:
            handleSignatureVerifyFailed()
        case .unlockDenied:
            fail(.unlockDenied)
        case .lockLocked:
            // Lock has relocked - normal end state
            break
        case .aclScheduleBlocked:
            fail(.outOfSchedule)
        case .unlockOverlocked:
            fail(.overlock)
        default:
            // Handle all other status cases (parsing errors, offset errors, etc.)
            print("[Ion2Coordinator] Unhandled status: \(status)")
            // Most unhandled cases are errors
            if status.rawValue.contains("ERR") || status.rawValue.contains("FAIL") || status.rawValue.contains("INVALID") {
                fail(.unknown)
            }
        }
    }
    
    /// Handle command ID read completion
    func handleCommandIdRead(result: Result<Data, Error>) {
        guard case .readingCommandId = state else {
            print("[Ion2Coordinator] Unexpected commandId read in state: \(state)")
            return
        }
        
        switch result {
        case .success(let commandIdData):
            writeCommand(nonce: commandIdData)
        case .failure(let error):
            fail(.unknown) // "Failed to read command ID"
        }
    }
    
    /// Reset coordinator to idle state
    func reset() {
        state = .idle
        currentAcl = nil
        currentAclData = nil
        currentSignatureData = nil
        currentCommandSignatureData = nil
        userId = nil
        deviceID = nil
        successHandler = nil
        failureHandler = nil
        retryCount = 0
    }
    
    // MARK: - State Transitions
    
    private func writeTime() {
        state = .writingTime
        let secondsSinceEpoch: Int64 = Int64(Date().timeIntervalSince1970)
        let data = withUnsafeBytes(of: secondsSinceEpoch) { Data($0) }
        characteristicHandler.writeTime(data)
    }
    
    private func handleTimeSynced() {
        guard case .writingTime = state else { return }
        guard let aclData = currentAclData else {
            fail(.missingAcl)
            return
        }
        
        state = .writingAcl
        characteristicHandler.writeAcl(aclData)
    }
    
    private func handleAclReceived() {
        guard case .writingAcl = state else { return }
        guard let signatureData = currentSignatureData else {
            fail(.invalidAclSignature)
            return
        }
        
        state = .writingSignature
        characteristicHandler.writeAclSignature(signatureData)
    }
    
    private func handleSignatureVerified() {
        guard case .writingSignature = state else { return }
        
        state = .readingCommandId
        characteristicHandler.readCommandId()
    }
    
    private func writeCommand(nonce: Data) {
        guard nonce.count == 8 else {
            fail(.unknown) // "Invalid nonce length"
            return
        }
        
        guard let userId = userId else {
            fail(.unknown) // "Missing userId"
            return
        }
        
        state = .writingCommand
        
        do {
            // Create command data: 0x00 + nonce
            let finalCommandData = Data([0x00]) + nonce
            
            // Sign the command
            var deviceIDData = Data()
            if let deviceID = deviceID {
                deviceIDData = Data(deviceID.utf8)
            }
            
            currentCommandSignatureData = try phoneKeyManager.sign(finalCommandData, userId: userId, deviceID: deviceIDData)
            
            // Write command
            characteristicHandler.writeCommand(finalCommandData)
            
        } catch {
            fail(.unknown) // "Failed to sign command"
        }
    }
    
    private func handleCommandReceived() {
        guard case .writingCommand = state else { return }
        guard let commandSignature = currentCommandSignatureData else {
            fail(.unknown) // "Missing command signature"
            return
        }
        
        state = .writingCommandSignature
        characteristicHandler.writeCommandSignature(commandSignature)
    }
    
    private func handleUnlockExecuted() {
        state = .completed
        successHandler?()
        print("[Ion2Coordinator] Unlock successful!")
    }
    
    // MARK: - Error Handling & Retry
    
    private func handleAclTimeExpired() {
        if canRetry() {
            print("[Ion2Coordinator] ACL expired, retrying... (\(retryCount + 1)/\(maxRetries))")
            retryCount += 1
            refetchAclAndRetry()
        } else {
            fail(.aclRejected)
        }
    }
    
    private func handleSignatureVerifyFailed() {
        if canRetry() {
            print("[Ion2Coordinator] Signature verify failed, retrying... (\(retryCount + 1)/\(maxRetries))")
            retryCount += 1
            refetchAclAndRetry()
        } else {
            fail(.invalidAclSignature)
        }
    }
    
    private func canRetry() -> Bool {
        return retryCount < maxRetries
    }
    
    private func refetchAclAndRetry() {
        // Fail with invalidAclSignature which triggers ACL refetch
        // The caller (NokeDevice+Signing) will handle the refetch via NokePhoneKeyStateDelegate
        fail(.invalidAclSignature)
    }
    
    private func fail(_ error: NokeDeviceSigningError) {
        state = .failed(error)
        failureHandler?(error)
        print("[Ion2Coordinator] Failed with error: \(error)")
    }
}
