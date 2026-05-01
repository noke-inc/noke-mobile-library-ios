//
//  PhoneKeyCommandSigner.swift
//  Pods
//
//  Created by Joffrey Mann on 1/29/26.
//

import Foundation
import PhoneKeyCore

final class PhoneKeyCommandSigner {
    private let phoneKeyManager: PhoneKeyManager
    
    init(phoneKeyManager: PhoneKeyManager) {
        self.phoneKeyManager = phoneKeyManager
    }
    
    func signUnlockCommand(commandBytes: Data, signature: Data) throws -> Data {
        var final = Data(capacity: 1 + commandBytes.count + signature.count)
        final.append(0x00)
        final.append(commandBytes)
        final.append(signature)
        return final
    }
}
