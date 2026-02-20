//
//  NokeDevice+Signing.swift
//  Pods
//
//  Created by Joffrey Mann on 2/17/26.
//

import CoreBluetooth
import PhoneKeyCore

extension NokeDevice {
    public func unlockForSigning(aclResponse: PhoneKeyAclEnvelope) {
        startUnlock(aclEnvelope: aclResponse)
    }
    
    private func startUnlock(aclEnvelope: PhoneKeyAclEnvelope) {
        currentAclData = Data(base64Encoded: aclEnvelope.aclBinary)
        currentSignatureData = Data(base64Encoded: aclEnvelope.aclSignature)
        
        guard let aclData = currentAclData else {
            handleFailure?(NokeDeviceSigningError.missingAcl)
            return
        }
        
        writeACLCharacteristic(aclData)
    }
    
    private func writeACLCharacteristic(_ data: Data) {
        if let aclCharacteristic = aclCharacteristic {
            peripheral?.writeValue(data, for: aclCharacteristic, type: .withResponse)
        }
        print("Writing ACL data")
    }
    
    private func writeSignatureCharacteristic() {
        guard let signatureCharacteristic = aclSignatureCharacteristic, let currentSignatureData = currentSignatureData else {
            return
        }
        
        peripheral?.writeValue(currentSignatureData, for: signatureCharacteristic, type: .withResponse)
    }
    
    private func writeCommandSignatureCharacteristic() {
        guard let signatureCharacteristic = commandSignatureCharacteristic, let currentCommandSignatureData = currentCommandSignatureData else {
            return
        }
        
        peripheral?.writeValue(currentCommandSignatureData, for: signatureCharacteristic, type: .withResponse)
        if let statusCharacteristic = statusCharacteristic {
            peripheral?.readValue(for: statusCharacteristic)
        }
    }
    
    private func writeCommandCharacteristic(nonce: Data) throws {
        // Sanity: nonce must be exactly 8 bytes
        guard nonce.count == 8 else {
            print("❌ Nonce must be 8 bytes, got \(nonce.count)")
            handleFailure?(NokeDeviceSigningError.missingAcl)
            return
        }
        
        try sendSignedUnlock(phoneKeyManager: phoneKeyManager, commandIdData: nonce)
    }
    
    func readStatusCharacteristic() {
        guard let statusCharacteristic else {
            return
        }
        
        peripheral?.readValue(for: statusCharacteristic)
    }
    
    func handleACLStatus(_ status: String) {
        if status == "ACL_RECEIVED" {
            print("ACL packet received by lock, now writing signature")
            writeSignatureCharacteristic()
            return
        }
        
        if status == "ACLSIG_VERIFIED" {
            print("Signature received by lock, now reading command id")
            readCommandId { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let commandBytes):
                    // Write command
                    do {
                        try writeCommandCharacteristic(nonce: commandBytes)
                        print("Successfully read command id: \(commandBytes)")
                    } catch {
                        print("Error: \(error)")
                    }
                case .failure:
                    break
                }
            }
            return
        }
        
        if status == "CMD_RECEIVED" {
            writeCommandSignatureCharacteristic()
            print("Writing command signature characteristic")
        }
        
        if status == "ACL_ACCEPT" {
            if encryptionType == .signing {
                currentAclWriteStatus = "The ACL has been accepted"
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "didUpdateAclWriteStatus"), object: nil)
            }
            aclIsAccepted = true
            return
        }
        
        if status == "ACL_REJECT" {
            handleFailure?(NokeDeviceSigningError.aclRejected)
        }
    }
    
    func forceSecurityThenRead(_ characteristic: CBCharacteristic) {
        // This read (on a protected char) will trigger pairing if needed.
        pendingSecuredAction = { [weak self] in
            self?.peripheral?.readValue(for: characteristic)
        }
        pendingSecuredAction?()
    }
    
    
    func forceSecurityThenWrite(_ characteristic: CBCharacteristic, data: Data) {
        guard characteristic.properties.contains(.write) else { return }
        // Write WITH response to trigger pairing if needed.
        pendingSecuredAction = { [weak self] in
            self?.peripheral?.writeValue(data, for: characteristic, type: .withoutResponse)
        }
        pendingSecuredAction?()
    }
    
    
    func isSecurityError(_ error: Error) -> Bool {
        if let att = error as? CBATTError {
            return att.code == .insufficientEncryption || att.code == .insufficientAuthentication
        }
        // Some stacks use CBErrorDomain with these underlying ATT codes
        let ns = error as NSError
        return ns.domain == CBATTErrorDomain && (ns.code == CBATTError.insufficientEncryption.rawValue ||
                                                 ns.code == CBATTError.insufficientAuthentication.rawValue)
    }
    
    func retryAfterShortDelay() {
        // Give the system a brief moment to finish the pairing handshake
        let action = pendingSecuredAction
        pendingSecuredAction = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            action?()
        }
    }
    
    func sendSignedUnlock(phoneKeyManager: PhoneKeyManager, type: String = "UNLOCK", commandIdData: Data) throws {
        do {
            // Log hex for verification
            let hex = commandIdData.map { String(format: "%02X", $0) }.joined(separator: " ")
            print("Command bytes (00 + nonce): \(hex)")
            
            guard let chr = commandWriteCharacterstic else {
                handleFailure?(NokeDeviceSigningError.characteristicNotFound)
                return
            }
            
            guard let peripheral else {
                handleFailure?(NokeDeviceSigningError.peripheralNotFound)
                return
            }
            
            let finalCommandData: Data = Data([0x00]) + commandIdData
            currentCommandSignatureData = try phoneKeyManager.sign(finalCommandData)

            peripheral.writeValue(finalCommandData, for: chr, type: .withResponse)
            
            if let statusCharacteristic = statusCharacteristic {
                peripheral.readValue(for: statusCharacteristic)
            }
        } catch {
            print(error.localizedDescription)
            throw error
        }
    }
    
    func readCommandId(completion: @escaping (Result<Data, Error>) -> Void) {
        guard let commandIdCharacteristic = self.commandIdCharacteristic else {
            handleFailure?(NokeDeviceSigningError.missingCommandIdCharacteritic)
            return
        }
        
        readCommandIdCompletion = completion
        self.peripheral?.readValue(for: commandIdCharacteristic)
    }
}
