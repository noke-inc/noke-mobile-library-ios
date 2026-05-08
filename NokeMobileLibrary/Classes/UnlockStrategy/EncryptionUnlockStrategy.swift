//
//  EncryptionUnlockStrategy.swift
//  NokeMobileLibrary
//
//  Created by Noke Inc. on 3/25/26.
//  Copyright © 2026 Noke Inc. All rights reserved.
//

import Foundation
import CoreBluetooth

/// Unlock strategy for encryption-based locks (legacy: NokeOne, ION, Padlock, etc.)
/// Uses session-based encryption with offline key and command
internal final class EncryptionUnlockStrategy: NokeUnlockStrategy {
    
    func executeUnlock(
        device: NokeDevice,
        context: UnlockContext,
        onSuccess: @escaping () -> Void,
        onFailure: @escaping (NokeDeviceOperationError) -> Void
    ) {
        print("[EncryptionStrategy] Executing encryption-based unlock for \(device.mac)")
        
        // Validate encryption parameters
        guard let offlineKey = context.offlineKey,
              let unlockCommand = context.unlockCommand else {
            let error = createError(.missingOfflineData)
            onFailure(error)
            return
        }
        
        // Validate key and command lengths
        guard offlineKey.count == Constants.OFFLINE_KEY_LENGTH,
              unlockCommand.count == Constants.OFFLINE_COMMAND_LENGTH else {
            let error = createError(.invalidOfflineKeyLength)
            onFailure(error)
            return
        }
        
        // Set success/failure handlers
        device.handleSuccess = onSuccess
        device.handleFailure = onFailure
        
        // Execute offline unlock
        let result = device.offlineUnlock(
            key: offlineKey,
            command: unlockCommand,
            addTimestamp: context.addTimestamp
        )
        
        if result.isEmpty {
            let error = createError(.encryptionFailed)
            onFailure(error)
            device.handleFailure?(error)
        } else {
            onSuccess()
            device.handleSuccess?()
        }
    }
    
    // MARK: - Error Helper
    
    private func createError(_ type: EncryptionUnlockError) -> NokeDeviceOperationError {
        return type
    }
    
    private enum EncryptionUnlockError: NokeDeviceOperationError {
        case missingOfflineData
        case invalidOfflineKeyLength
        case encryptionFailed
        
        var description: String {
            switch self {
            case .missingOfflineData:
                return "Missing offline key or unlock command"
            case .invalidOfflineKeyLength:
                return "Offline key or command has invalid length"
            case .encryptionFailed:
                return "Failed to create encrypted unlock command"
            }
        }
        
        var isValid: Bool { false }
        var shouldRefreshKeys: Bool { true }
        var willUseFallback: Bool { false }
        var errorType: NokeDeviceOperationErrorType { .deviceError }
    }
}
