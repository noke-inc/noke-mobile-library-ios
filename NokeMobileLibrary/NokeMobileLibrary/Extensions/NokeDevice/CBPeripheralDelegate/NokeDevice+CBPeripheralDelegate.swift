//
//  NokeDevice+CBPeripheralDelegate.swift
//  Pods
//
//  Created by Joffrey Mann on 2/17/26.
//

import CoreBluetooth

extension NokeDevice: CBPeripheralDelegate {
    /// MARK: CBPeripheral Delegate Methods
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if(error != nil){
            return
        }
        
        for s: CBService in (peripheral.services!){
            if(s.uuid.isEqual(NokeDevice.nokeServiceUUID())){
                self.nokeService = s
                self.peripheral?.discoverCharacteristics([NokeDevice.txCharacteristicUUID(), NokeDevice.rxCharacteristicUUID(), NokeDevice.sessionCharacteristicUUID()], for: s)
            }
            else if (s.uuid.isEqual(NokeDevice.nokeInfinityServiceUUID())) {
                self.nokeService = s
                // Create Ion2CharacteristicHandler immediately when service is discovered
                if self.ion2CharacteristicHandler == nil {
                    self.ion2CharacteristicHandler = Ion2CharacteristicHandler(peripheral: peripheral)
                    print("[NokeDevice] Created Ion2CharacteristicHandler")
                }
                self.peripheral?.discoverCharacteristics([
                    NokeDevice.timeCharacteristicUUID(),
                    NokeDevice.aclCharacteristicUUID(),
                    NokeDevice.statusCharacteristicUUID(),
                    NokeDevice.aclSignatureCharacteristicUUID(),
                    NokeDevice.commandIdReadCharacteristicUUID(),
                    NokeDevice.commandWriteCharacteristicUUID(),
                    NokeDevice.sessionCharacteristicUUID(),
                    NokeDevice.commandSignatureCharacteristicUUID()], for: s)
            }
            else if (s.uuid.isEqual(NokeDevice.noke2iFirmwareUUID())) {
                self.nokeService = s
                self.peripheral?.discoverCharacteristics([NokeDevice.bootloader2iTxCharacteristicUUID(), NokeDevice.bootloader2iRxCharacteristicUUID()], for: s)
            }
            else if (s.uuid.isEqual(NokeDevice.noke4iFirmwareUUID())) {
                self.nokeService = s
                self.peripheral?.discoverCharacteristics([NokeDevice.bootloader4iRxCharacteristicUUID(), NokeDevice.bootloader4iTxCharacteristicUUID()], for: s)
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if((error) != nil){
            return
        }
        
        for c : CBCharacteristic in service.characteristics!
        {
            print("Current characteristic: \(c.uuid)")
            if(c.uuid.isEqual(NokeDevice.rxCharacteristicUUID())){
                self.rxCharacteristic = c
                self.peripheral!.setNotifyValue(true, for:self.rxCharacteristic!)
            }
            else if(c.uuid.isEqual(NokeDevice.txCharacteristicUUID())){
                self.txCharacteristic = c
            }
            else if(c.uuid.isEqual(NokeDevice.sessionCharacteristicUUID())){
                self.sessionCharacteristic = c
                self.readSessionCharacteristic()
            }
            else if c.uuid.isEqual(NokeDevice.bootloader2iRxCharacteristicUUID()) {
                self.bootloader2iRxCharacteristic = c
            }
            else if (c.uuid.isEqual(NokeDevice.bootloader2iTxCharacteristicUUID())) {
                self.bootloader2iTxCharacteristic = c
                delegate?.nokeReadyForFirmwareUpdate(noke: self)
            }
            else if c.uuid.isEqual(NokeDevice.bootloader4iRxCharacteristicUUID()) {
                self.bootloader4iRxCharacteristic = c
            } else if c.uuid.isEqual(NokeDevice.bootloader4iTxCharacteristicUUID()) {
                self.bootloader4iTxCharacteristic = c
                delegate?.nokeReadyForFirmwareUpdate(noke: self)
            } else if c.uuid.isEqual(NokeDevice.timeCharacteristicUUID()) {
                self.timeCharacteristic = c
                self.ion2CharacteristicHandler?.setCharacteristic(c)
                self.peripheral!.setNotifyValue(true, for: self.timeCharacteristic!)
            } else if c.uuid.isEqual(NokeDevice.aclCharacteristicUUID()) {
                self.aclCharacteristic = c
                self.ion2CharacteristicHandler?.setCharacteristic(c)
                self.peripheral!.setNotifyValue(true, for:self.aclCharacteristic!)
            } else if c.uuid.isEqual(NokeDevice.statusCharacteristicUUID()) {
                self.statusCharacteristic = c
                self.ion2CharacteristicHandler?.setCharacteristic(c)
                self.peripheral!.setNotifyValue(true, for: c)
            } else if c.uuid.isEqual(NokeDevice.aclSignatureCharacteristicUUID()) {
                self.aclSignatureCharacteristic = c
                self.ion2CharacteristicHandler?.setCharacteristic(c)
                self.peripheral!.setNotifyValue(true, for: c)
            } else if c.uuid.isEqual(NokeDevice.commandIdReadCharacteristicUUID()) {
                self.commandIdCharacteristic = c
                self.ion2CharacteristicHandler?.setCharacteristic(c)
                self.peripheral!.setNotifyValue(true, for: c)
            } else if c.uuid.isEqual(NokeDevice.commandWriteCharacteristicUUID()) {
                self.commandWriteCharacterstic = c
                self.ion2CharacteristicHandler?.setCharacteristic(c)
                self.peripheral!.setNotifyValue(true, for: c)
            } else if c.uuid.isEqual(NokeDevice.commandSignatureCharacteristicUUID()) {
                self.commandSignatureCharacteristic = c
                self.ion2CharacteristicHandler?.setCharacteristic(c)
                self.peripheral!.setNotifyValue(true, for: c)
            }
        }
        
        // Check if all Ion2 characteristics are discovered and trigger pending unlock
        if service.uuid.isEqual(NokeDevice.nokeInfinityServiceUUID()) {
            if let handler = ion2CharacteristicHandler, handler.areAllCharacteristicsDiscovered() {
                print("[NokeDevice] All Ion2 characteristics discovered, ready for unlock")
                ion2CharacteristicsReady = true
                NokeDeviceManager.shared().delegate?.nokeIon2ReadyForUnlock(noke: self)
                // Execute pending unlock if one exists
                if let pending = pendingIon2Unlock {
                    print("[NokeDevice] Executing pending Ion2 unlock")
                    pending()
                    pendingIon2Unlock = nil
                }
            } else {
                print("Characteristic discovery incomplete, waiting...")
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if(error != nil){
            return
        }
        
        if characteristic.uuid == rxCharacteristic?.uuid {
            let response = characteristic.value
            _ = self.receivedDataFromLock(response!)
        } else if characteristic.uuid == sessionCharacteristic?.uuid {
            let data = characteristic.value
            self.setSession(data!)
        } else if characteristic.uuid == statusCharacteristic?.uuid {
            guard let data = characteristic.value, let string = String(data: data, encoding: .utf8) else {
                return
            }
            
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            print("Handling acl status after read \(trimmed)")
            if let status = NokeDeviceSigningStatus(rawValue: trimmed) {
                handleACLStatus(status)
            } else {
                print("Unknown ACL status received: \(trimmed)")
            }
        } else if characteristic.uuid == commandIdCharacteristic?.uuid {
            guard let data = characteristic.value else {
                handleCommandIdRead(result: .failure(NokeDeviceSigningError.invalidCommandId))
                return
            }
            
            readCommandIdCompletion?(.success(data))
            readCommandIdCompletion = nil
            handleCommandIdRead(result: .success(data))
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        
        guard let error = error else {
            // Success: clear pending
            pendingSecuredAction = nil
            if characteristic.uuid == timeCharacteristic?.uuid {
                ion2CharacteristicHandler?.readStatus()
                guard let data = characteristic.value, let string = String(data: data, encoding: .utf8) else {
                    return
                }
            } else if characteristic.uuid == aclCharacteristic?.uuid {
                ion2CharacteristicHandler?.readStatus()
                guard let data = characteristic.value, let string = String(data: data, encoding: .utf8) else {
                    return
                }
                
                if let currentAclData = currentAclData, data == currentAclData {
                    print("Acl written matches what's received \(string)")
                }
            } else if characteristic.uuid == aclSignatureCharacteristic?.uuid {
                ion2CharacteristicHandler?.readStatus()
                guard let data = characteristic.value, let string = String(data: data, encoding: .utf8) else {
                    return
                }
                
                print("Signature sent \(string)")
            } else if characteristic.uuid == commandWriteCharacterstic?.uuid {
                ion2CharacteristicHandler?.readStatus()
                guard let data = characteristic.value, let string = String(data: data, encoding: .utf8) else {
                    return
                }
                
                print("Command written \(string)")
            } else if characteristic.uuid == commandSignatureCharacteristic?.uuid {
                ion2CharacteristicHandler?.readStatus()
                guard let data = characteristic.value, let string = String(data: data, encoding: .utf8) else {
                    return
                }
                
                print("Signature written \(string)")
            }
            return
        }
        
        // Security/pairing error handling
        if error != nil {
            ion2CharacteristicHandler?.readStatus()
            ion2SigningCoordinator?.reset()
//            print("Write error for characteristic \(characteristic.uuid): \(error.localizedDescription)")
//            handleFailure?(NokeDeviceSigningError.unknown)
        }

    }
}
