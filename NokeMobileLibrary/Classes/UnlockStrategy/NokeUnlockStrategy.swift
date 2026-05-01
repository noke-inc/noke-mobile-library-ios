//
//  NokeUnlockStrategy.swift
//  NokeMobileLibrary
//
//  Created by Noke Inc. on 3/25/26.
//  Copyright © 2026 Noke Inc. All rights reserved.
//

import Foundation
import CoreBluetooth
import PhoneKeyCore

/// Protocol defining the unlock strategy for Noke devices
/// Different lock types (encryption-based vs signing-based) implement different strategies
internal protocol NokeUnlockStrategy {
    
    /// Execute the unlock operation for this strategy
    /// - Parameters:
    ///   - device: The NokeDevice to unlock
    ///   - context: Context containing all necessary unlock parameters
    ///   - onSuccess: Called when unlock succeeds
    ///   - onFailure: Called when unlock fails
    func executeUnlock(
        device: NokeDevice,
        context: UnlockContext,
        onSuccess: @escaping () -> Void,
        onFailure: @escaping (NokeDeviceOperationError) -> Void
    )
}

/// Context object containing all parameters needed for unlock
public struct UnlockContext {
    // Common to all unlock types
    let options: UnlockOptionsRepresentable?
    
    // For encryption-based unlock (legacy locks)
    let offlineKey: String?
    let unlockCommand: String?
    let addTimestamp: Bool
    
    // For signing-based unlock (Ion 2)
    let acl: BulkPhoneKeyAcl?
    let userId: String?
    let deviceID: String?
    
    /// Initialize for encryption-based unlock
    public static func encryption(
        key: String,
        command: String,
        addTimestamp: Bool = true,
        options: UnlockOptionsRepresentable? = nil
    ) -> UnlockContext {
        return UnlockContext(
            options: options,
            offlineKey: key,
            unlockCommand: command,
            addTimestamp: addTimestamp,
            acl: nil,
            userId: nil,
            deviceID: nil
        )
    }
    
    /// Initialize for signing-based unlock (Ion 2)
    public static func signing(
        acl: BulkPhoneKeyAcl,
        userId: String,
        deviceID: String,
        options: UnlockOptionsRepresentable? = nil
    ) -> UnlockContext {
        return UnlockContext(
            options: options,
            offlineKey: nil,
            unlockCommand: nil,
            addTimestamp: false,
            acl: acl,
            userId: userId,
            deviceID: deviceID
        )
    }
}
