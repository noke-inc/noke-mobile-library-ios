//
//  Ion2CharacteristicHandler.swift
//  NokeMobileLibrary
//
//  Created by Noke Inc. on 3/25/26.
//  Copyright © 2026 Noke Inc. All rights reserved.
//

import Foundation
import CoreBluetooth

/// Handler for Ion 2 BLE characteristic operations.
///
/// **TIDY Principles:**
/// - **Single Responsibility:** ONLY handles Ion 2 characteristic read/write
/// - **Clear Intent:** Each method maps 1:1 to a BLE operation
/// - **Encapsulation:** Hides CBPeripheral details from coordinator
///
/// **NOT in scope:**
/// - State management (coordinator's job)
/// - Business logic (coordinator's job)
/// - Status interpretation (coordinator's job)
internal final class Ion2CharacteristicHandler {
    
    // MARK: - Properties
    
    private weak var peripheral: CBPeripheral?
    
    // Ion 2 Characteristics
    private(set) var timeCharacteristic: CBCharacteristic?
    private(set) var aclCharacteristic: CBCharacteristic?
    private(set) var statusCharacteristic: CBCharacteristic?
    private(set) var aclSignatureCharacteristic: CBCharacteristic?
    private(set) var commandIdCharacteristic: CBCharacteristic?
    private(set) var commandWriteCharacteristic: CBCharacteristic?
    private(set) var commandSignatureCharacteristic: CBCharacteristic?
    
    // MARK: - Initialization
    
    init(peripheral: CBPeripheral?) {
        self.peripheral = peripheral
    }
    
    // MARK: - Characteristic Discovery
    
    func setCharacteristic(_ characteristic: CBCharacteristic) {
        print("[Ion2Handler] Setting characteristic: \(characteristic.uuid)")
        switch characteristic.uuid {
        case NokeDevice.timeCharacteristicUUID():
            timeCharacteristic = characteristic
            print("[Ion2Handler] ✓ Time characteristic set")
        case NokeDevice.aclCharacteristicUUID():
            aclCharacteristic = characteristic
            print("[Ion2Handler] ✓ ACL characteristic set")
        case NokeDevice.statusCharacteristicUUID():
            statusCharacteristic = characteristic
            print("[Ion2Handler] ✓ Status characteristic set")
        case NokeDevice.aclSignatureCharacteristicUUID():
            aclSignatureCharacteristic = characteristic
            print("[Ion2Handler] ✓ ACL Signature characteristic set")
        case NokeDevice.commandIdReadCharacteristicUUID():
            commandIdCharacteristic = characteristic
            print("[Ion2Handler] ✓ Command ID characteristic set")
        case NokeDevice.commandWriteCharacteristicUUID():
            commandWriteCharacteristic = characteristic
            print("[Ion2Handler] ✓ Command Write characteristic set")
        case NokeDevice.commandSignatureCharacteristicUUID():
            commandSignatureCharacteristic = characteristic
            print("[Ion2Handler] ✓ Command Signature characteristic set")
        default:
            print("[Ion2Handler] ⚠️ Unknown characteristic: \(characteristic.uuid)")
            break
        }
        
        // Log current discovery status
        let discovered = [
            timeCharacteristic != nil ? "time" : "",
            aclCharacteristic != nil ? "acl" : "",
            statusCharacteristic != nil ? "status" : "",
            aclSignatureCharacteristic != nil ? "aclSig" : "",
            commandIdCharacteristic != nil ? "cmdId" : "",
            commandWriteCharacteristic != nil ? "cmdWrite" : "",
            commandSignatureCharacteristic != nil ? "cmdSig" : ""
        ].filter { !$0.isEmpty }
        
        print("[Ion2Handler] Discovered (\(discovered.count)/7): \(discovered.joined(separator: ", "))")
        
        if areAllCharacteristicsDiscovered() {
            print("[Ion2Handler] ✅ ALL 7 CHARACTERISTICS DISCOVERED!")
        }
    }
    
    func areAllCharacteristicsDiscovered() -> Bool {
        return timeCharacteristic != nil &&
               aclCharacteristic != nil &&
               statusCharacteristic != nil &&
               aclSignatureCharacteristic != nil &&
               commandIdCharacteristic != nil &&
               commandWriteCharacteristic != nil &&
               commandSignatureCharacteristic != nil
    }
    
    // MARK: - Write Operations
    
    func writeTime(_ data: Data) {
        guard let characteristic = timeCharacteristic else {
            print("[Ion2Handler] Error: timeCharacteristic not found")
            return
        }
        peripheral?.writeValue(data, for: characteristic, type: .withResponse)
        print("[Ion2Handler] Writing time")
    }
    
    func writeAcl(_ data: Data) {
        guard let characteristic = aclCharacteristic else {
            print("[Ion2Handler] Error: aclCharacteristic not found")
            return
        }
        peripheral?.writeValue(data, for: characteristic, type: .withResponse)
        print("[Ion2Handler] Writing ACL (\(data.count) bytes)")
    }
    
    func writeAclSignature(_ data: Data) {
        guard let characteristic = aclSignatureCharacteristic else {
            print("[Ion2Handler] Error: aclSignatureCharacteristic not found")
            return
        }
        peripheral?.writeValue(data, for: characteristic, type: .withResponse)
        print("[Ion2Handler] Writing ACL signature")
    }
    
    func writeCommand(_ data: Data) {
        guard let characteristic = commandWriteCharacteristic else {
            print("[Ion2Handler] Error: commandWriteCharacteristic not found")
            return
        }
        peripheral?.writeValue(data, for: characteristic, type: .withResponse)
        print("[Ion2Handler] Writing command")
    }
    
    func writeCommandSignature(_ data: Data) {
        guard let characteristic = commandSignatureCharacteristic else {
            print("[Ion2Handler] Error: commandSignatureCharacteristic not found")
            return
        }
        peripheral?.writeValue(data, for: characteristic, type: .withResponse)
        print("[Ion2Handler] Writing command signature")
    }
    
    // MARK: - Read Operations
    
    func readStatus() {
        guard let characteristic = statusCharacteristic else {
            print("[Ion2Handler] Error: statusCharacteristic not found")
            return
        }
        peripheral?.readValue(for: characteristic)
        print("[Ion2Handler] Reading status")
    }
    
    func readCommandId() {
        guard let characteristic = commandIdCharacteristic else {
            print("[Ion2Handler] Error: commandIdCharacteristic not found")
            return
        }
        peripheral?.readValue(for: characteristic)
        print("[Ion2Handler] Reading command ID")
    }
    
    // MARK: - Helper Methods
    
    func enableNotifications() {
        // Enable notifications for characteristics that support it
        if let char = timeCharacteristic {
            peripheral?.setNotifyValue(true, for: char)
        }
        if let char = aclCharacteristic {
            peripheral?.setNotifyValue(true, for: char)
        }
        if let char = statusCharacteristic {
            peripheral?.setNotifyValue(true, for: char)
        }
        if let char = aclSignatureCharacteristic {
            peripheral?.setNotifyValue(true, for: char)
        }
        if let char = commandIdCharacteristic {
            peripheral?.setNotifyValue(true, for: char)
        }
        if let char = commandWriteCharacteristic {
            peripheral?.setNotifyValue(true, for: char)
        }
        if let char = commandSignatureCharacteristic {
            peripheral?.setNotifyValue(true, for: char)
        }
    }
}
