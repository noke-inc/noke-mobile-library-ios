//
//  SigningUnlockStrategy.swift
//  NokeMobileLibrary
//
//  Created by Noke Inc. on 3/25/26.
//  Copyright © 2026 Noke Inc. All rights reserved.
//

import Foundation
import CoreBluetooth
import PhoneKeyCore

/// Unlock strategy for signing-based locks (Ion 2)
/// Uses ACL + public/private key signing instead of session encryption
internal final class SigningUnlockStrategy: NokeUnlockStrategy {
    
    func executeUnlock(
        device: NokeDevice,
        context: UnlockContext,
        onSuccess: @escaping () -> Void,
        onFailure: @escaping (NokeDeviceOperationError) -> Void
    ) {
        print("[SigningStrategy] Executing signing-based unlock for \(device.mac)")
        
        // Validate signing parameters
        guard let acl = context.acl,
              let userId = context.userId,
              let deviceID = context.deviceID else {
            onFailure(NokeDeviceSigningError.missingAcl)
            return
        }
        
        // Validate ACL is not expired
        guard acl.expiresAt > Date() else {
            print("[SigningStrategy] ACL expired at \(acl.expiresAt)")
            onFailure(NokeDeviceSigningError.aclRejected)
            return
        }
        
        // Validate ACL has data
        guard !acl.aclBinary.isEmpty, !acl.aclSignature.isEmpty else {
            print("[SigningStrategy] ACL binary or signature is empty")
            onFailure(NokeDeviceSigningError.missingAcl)
            return
        }
        
        print("[SigningStrategy] ACL valid, executing unlock for lock \(acl.lockMac)")
        
        // Set success/failure handlers
        device.handleSuccess = onSuccess
        device.handleFailure = onFailure
        
        // Execute signing unlock
        device.unlockForSigning(
            aclResponse: acl,
            userId: userId,
            deviceID: deviceID,
            options: context.options
        )
    }
}
