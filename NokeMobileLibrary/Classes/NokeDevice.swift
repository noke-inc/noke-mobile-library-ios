//
//  NokeDevice.swift
//  NokeMobileLibrary
//
//  Created by Spencer Apsley on 1/12/18.
//  Copyright © 2018 Noke. All rights reserved.
//

import Foundation
import CoreBluetooth
import PhoneKeyCore

//Here are all of the possible status messages you can get back
//
//ACL Characteristic
//ACL_LONG - The ACL being sent is larger than the available buffer
//ACL_OFFSET - An error occured within the BLE driver resulting in an offset error
//NO_DEVICE_MAC - The MAC couldn't be validated due to an internal error on the lock
//ACL_PARSE_ERROR - Something went wrong with parsing the ACL. Was a field in the wrong spot or invalid?
//ACL_MAC_MISMATCH - The MAC in the ACL does not match the lock
//ACL_TIME_INVALID - The timestamps included for the ACL creation/expiration are invalid/malformed
//ACL_VALIDATED - Set when the ACL has been written and parsed. THIS DOES NOT MEAN IT HAS BEEN VERIFIED WITH THE SIGNATURE YET! This just means that the lock understands the ACL
//
//Command ID Characteristic
//CID_READ - The command ID was read as the last operation
//
//Command Characteristic
//CMD_OFFSET_ERR - The BLE driver has tried to use a chunking mode that is not supported
//CMD_TOO_LONG - The command being sent is larger than the buffer in the lock
//NO_ACL_VALIDATED - You have tried to send a command without sending a valid ACL and ACL signature
//CMD_LEN - Not enough bytes were sent(9)
//CID_MISMATCH - The Command ID/Nonce was incorrect
//CMD_RECEIVED - The CMD was received and stored successfully
//
//ACL Signature Characteristic
//ACLSIG_OFFSET - The BLE driver has tried to use a chunking mode that is not supported
//ACLSIG_TOO_LARGE - The signature sent does not fit in the lock's signature buffer
//ACLSIG_INVALID - No data was received for some reason
//NO_ACL_DATA - No ACL has been written to attempt to validate yet!
//ACLSIG_DER_ERROR - Stripping of DER encoding could not be completed. Format problem!
//ACLSIG_BAD_LEN - The length of the signature is incorrect. We are expecting 64 bytes!
//ACL_SETUP_ERR - The cryptocore has rejected the ACL or signature, this means one of them is of the wrong format or has flipped bits(almost always the signature)
//ACLSIG_VERIFIED - Signature matches the ACL. GOOD!
//ACLSIG_VERIFY_FAIL - Everything worked fine, your signature or ACL is wrong though
//
//Time Characteristic
//TIME_OFFSET_ERR - The BLE driver has tried to use a chunking mode that is not supported
//TIME_BAD_LEN - length must be 8 bytes
//TIME_SYNCED - time has been stored and is accepted
//
//Command Signature Characteristic
//CMDSIG_OFFSET - The BLE driver has tried to use a chunking mode that is not supported
//CMDSIG_TOO_LARGE - signature sent will not fit in the lock's buffer
//CMDSIG_INVALID - No data was sent for some reason
//NO_CMD_TO_VERIFY - There is no command in the command characteristic yet...
//CMDSIG_DER_ERROR - Failed to strip the DER encoding. Usually a format error
//CMDSIG_BAD_LEN - Signature expected to be 64 bytes
//NO_PHONE_PUBKEY - The phone's public key could not be pulled from the ACL or the ACL is not set yet
//CMDSIG_SETUP_ERR - The cryptocore has rejected the command or signature, this means one of them is of the wrong format or has flipped bits(almost always the signature)
//CMDSIG_VERIFY_FAIL - Everything worked fine, your signature or command is wrong though
//CMDSIG_VERIFIED - Status set as soon as the signature is verified and command is authentic. This will be the status message until the command is executed, or fails to execute
//NO_VALID_ACL - The ACL can not be found or was cleared
//ACL_TIME_EXPIRED - We are past the expiration of the ACL so it's invalid
//ACL_SCHEDULE_BLOCKED - The schedule forbids executing commands now
//UNLOCK_OVERLOCKED - The lock is in overlock, likely due to too many failed unlock attempts. Payment is likely required to clear this status.
//
//
//
//Command-Specific Statuses!!!!!!
//Unlock
//UNLOCK_DENIED - Insufficient user permissions
//UNLOCK_EXECUTED - The unlock command was executed
//
//Lock
//LOCK_EXECUTED - The lock command was executed
//
//Anything else
//CMD_UNKNOWN - Unknown command was sent to the lock

/// Protocol for interacting with the Noke device (in virtually all cases this is the NokeDeviceManager)
protocol NokeDeviceDelegate: AnyObject
{
    /// Called after Noke device reads the session and stores it
    func didSetSession(_ mac:String)
    /// Called after connecting to a Noke device that is in bootloader mode, ready for a firmware update
    func nokeReadyForFirmwareUpdate(noke: NokeDevice)
}

protocol NokeDeviceSigningFailure: AnyObject {
    
}

enum NokeDeviceSigningStatus: String {
    case aclMacMismatch = "ACL_MAC_MISMATCH"
    case aclLong = "ACL_LONG"
    case aclOffset = "ACL_OFFSET"
    case aclParseError = "ACL_PARSE_ERROR"
    case aclValidated = "ACL_VALIDATED"
    case aclReceived = "ACL_RECEIVED"
    case aclRejected = "ACL_REJECTED"
    case aclSigVerified = "ACLSIG_VERIFIED"
    case aclSigVerifyFailed = "ACLSIG_VERIFY_FAIL"
    case aclSigBadLen = "ACLSIG_BAD_LEN"
    case aclSigDerError = "ACLSIG_DER_ERROR"
    case aclSigTooLarge = "ACLSIG_TOO_LARGE"
    case aclSigInvalid = "ACLSIG_INVALID"
    case aclSigOffset = "ACLSIG_OFFSET"
    case aclSetupError = "ACL_SETUP_ERR"
    case aclScheduleBlocked = "ACL_SCHEDULE_BLOCKED"
    case aclTimeExpired = "ACL_TIME_EXPIRED"
    case aclTimeInvalid = "ACL_TIME_INVALID"
    case noValidAcl = "NO_VALID_ACL"
    case noAclValidated = "NO_ACL_VALIDATED"
    case cidRead = "CID_READ"
    case cidMisMatch = "CID_MISMATCH"
    case cmdLen = "CMD_LEN"
    case cmdReceived = "CMD_RECEIVED"
    case cmdSigVerified = "CMDSIG_VERIFIED"
    case cmdSigVerifyFailed = "CMDSIG_VERIFY_FAIL"
    case cmdSigSetupErr = "CMDSIG_SETUP_ERR"
    case cmdSigBadLen = "CMDSIG_BAD_LEN"
    case cmdSigDerError = "CMDSIG_DER_ERROR"
    case cmdSigTooLarge = "CMDSIG_TOO_LARGE"
    case cmdSigInvalid = "CMDSIG_INVALID"
    case cmdSigOffset = "CMDSIG_OFFSET"
    case cmdTooLong = "CMD_TOO_LONG"
    case cmdOffsetErr = "CMD_OFFSET_ERR"
    case noCmdToVerify = "NO_CMD_TO_VERIFY"
    case noDeviceMac = "NO_DEVICE_MAC"
    case unlockExecuted = "UNLOCK_EXECUTED"
    case unlockDenied = "UNLOCK_DENIED"
    case lockExecuted = "LOCK_EXECUTED"
    case noPhonePubKey = "NO_PHONE_PUBKEY"
    case timeSynced = "TIME_SYNCED"
    case timeBadLen = "TIME_BAD_LEN"
    case timeOffsetErr = "TIME_OFFSET_ERR"
    case cmdUnknown = "CMD_UNKNOWN"
    case lockLocked = "LOCK_LOCKED"
    case lockUnlocked = "LOCK_UNLOCKED"
    case lockAlreadyUnlocked = "LOCK_ALREADY_UNLOCKED"
    case unlockOverlocked = "UNLOCK_OVERLOCKED"
    case lockJammed = "LOCK_JAMMED"
}

class DummyCryptoProvider: CryptoProvider {
    func generateEd25519Seed() throws -> Data {
        return Data()
    }
    
    func derivePublicKey(fromSeed seed: Data) throws -> Data {
        return Data()
    }
    
    func sign(message: Data, withSeed seed: Data) throws -> Data {
        return Data()
    }
    
    func getHash(of data: Data) throws -> Data {
        return Data()
    }
    
    
}

public enum NokeDeviceSigningError: NokeDeviceOperationError {
    case missingCommandIdCharacteristic
    case invalidCommandId
    case invalidAclSignature
    case missingAcl
    case aclRejected
    case aclTimeInvalid
    case timeOffsetError
    case peripheralNotFound
    case characteristicNotFound
    case offlineUnlockTimeout
    case outOfSchedule
    case overlock
    case unlockDenied
    case commandSignatureFailed
    case requiresEmergencyUnlock
    case requiresOverrideUnlock
    case lockIsLocked
    case lockJammed
    case unknown
    
    public var description: String {
        switch self {
        case .peripheralNotFound: return "Could not find device locally"
        case .missingCommandIdCharacteristic: return "Empty commands"
        case .invalidCommandId:
            return "Your command is invalid. Please try again."
        case .invalidAclSignature:
            return "Error fetching commands from the server"
        case .offlineUnlockTimeout: return "Offline unlock commands were sent, but did not receive a response"
        case .missingAcl: return "Sorry, you don't have access to unlock this device."
        case .aclRejected: return "Sorry, your access to this device has either expired or is invalid."
        case .aclTimeInvalid: return "Sorry, your access to this device is invalid."
        case .outOfSchedule: return "You do not have access at this time. Please check the facility hours and try again later."
        case .overlock: return "Your unit is currently in overlock. Please make a payment to gain access."
        case .characteristicNotFound: return "We weren't able to find your device. It's possible it's not broadcasting on Bluetooth."
        case .unlockDenied: return "You don't have access to unlock this device."
        case .commandSignatureFailed: return "Command signature failed"
        case .requiresEmergencyUnlock: return "This operation requires an emergency unlock."
        case .requiresOverrideUnlock: return "This operation requires an override unlock."
        case .lockIsLocked: return "Your lock has no key. Please contact your administrator to get access."
        case .lockJammed:
            return "We have detected that your lock may have jammed during operation.﻿\n\nPlease try the following steps:\n\n1. Ensure the lock hasp is clear of debris.\n2. Try stepping on the door handle and sliding the hasp into the unlocked position.\n3. If the issue persists, contact facility management to assist."
        case .timeOffsetError:
            return "There was something wrong with your dates. Please try again."
        case .unknown: return "An unknown error occurred"
        }
    }
    
    public var isValid: Bool {
        switch self {
        case .peripheralNotFound: return true
        case .missingCommandIdCharacteristic, .invalidAclSignature, .missingAcl, .invalidCommandId, .commandSignatureFailed, .aclRejected, .characteristicNotFound, .offlineUnlockTimeout, .requiresEmergencyUnlock, .requiresOverrideUnlock, .outOfSchedule, .unlockDenied, .lockIsLocked, .aclTimeInvalid, .overlock, .lockJammed, .timeOffsetError, .unknown: return false
        }
    }
    
    public var shouldRefreshKeys: Bool {
        switch self {
        case .missingCommandIdCharacteristic, .missingAcl, .invalidCommandId, .peripheralNotFound, .characteristicNotFound, .commandSignatureFailed, .offlineUnlockTimeout, .requiresEmergencyUnlock, .requiresOverrideUnlock, .aclTimeInvalid, .lockIsLocked, .timeOffsetError, .unknown: return false
        case .aclRejected, .invalidAclSignature, .lockJammed, .outOfSchedule, .overlock, .unlockDenied: return true
        }
    }
    
    public var willUseFallback: Bool {
        switch self {
        case .offlineUnlockTimeout, .requiresEmergencyUnlock, .requiresOverrideUnlock: return true
        default: return false
        }
    }
    
    public var errorType: NokeDeviceOperationErrorType {
        switch self {
        case .missingCommandIdCharacteristic, .overlock, .lockIsLocked, .invalidAclSignature, .missingAcl, .aclTimeInvalid, .lockJammed, .commandSignatureFailed, .timeOffsetError, .invalidCommandId:
            return .deviceError
        case .aclRejected, .unlockDenied, .requiresEmergencyUnlock, .requiresOverrideUnlock, .unknown:
            return .noOperation
        case .peripheralNotFound:
            return .connection
        case .characteristicNotFound, .offlineUnlockTimeout:
            return .connection
        case .outOfSchedule:
            return .access
        }
    }
}

/// Enum that is able to classify different types of NokeDeviceOperationErrors
public enum NokeDeviceOperationErrorType: String {
    /// This case describes connection-related errors such as (.invalidSessionOnRetry, .restartScanning, nokeDeviceSleeping, and .failedToConnect)
    case connection
    /// This case describes no operation errors such as (.nothingDoneAfterConnected)
    case noOperation
    /// This case describes device errors such as (.invalidKey, InvalidCommand)
    case deviceError
    /// This case describes network errors in which the user has no internet.
    case network
    /// This case describes access errors such as .outOfSchedule
    case access = "Gate hours"
    /// This case describes overlock errors where payment is required
    case overlock = "Overlock"
    
    public var value: String {
        if self == .access {
            return "Gate hours"
        }
        if self == .overlock {
            return "Overlock"
        }
        
        return rawValue
    }
}

/// Protocol for errors that occur during Noke device operations.
/// These errors expose metadata for  session recovery, and key refresh logic.
public protocol NokeDeviceOperationError: Error {
    var description: String { get }
    var isValid: Bool { get }
    var shouldRefreshKeys: Bool { get }
    var errorType: NokeDeviceOperationErrorType { get }
    var willUseFallback: Bool { get }
}

public enum NokeEncryptionType: Int {
    case encryption
    case signing
}

/**
 Lock states of Noke Devices
 - Unlocked: Noke device unlocked OR Device has been locked but phone never received updated status
 - Locked: Noke device locked
 */
public enum NokeDeviceLockState : Int{
    case nokeDeviceLockStateUnknown = -1
    case nokeDeviceLockStateUnlocked = 0
    case nokeDeviceLockStateUnshackled = 1
    case nokeDeviceLockStateLocked = 2
    case nokeDeviceLockStateJammedUnlocking = 3
    case nokeDeviceLockStateJammedLocking = 4
}

/// Class stores information about the Noke device and contains methods for interacting with the Noke device
public class NokeDevice: NSObject, NSCoding {
    
    /// Time Interval representing the most recent time the device was discovered
    public var lastSeen: Double = 0.0
    
    /// typealias used for handling bytes from the lock
    public typealias byteArray = UnsafeMutablePointer<UInt8>
    
    /// Name of the Noke device (strictly cosmetic)
    public var name: String = ""
    
    /// MAC address of Noke device. This can be found in the peripheral name
    public var mac: String = ""
    
    /// Serial number of Noke device. Laser engraved onto the device during manufacturing
    public var serial: String = ""
    
    /// UUID of the lock.  Unique identifier assigned by iOS upon connection
    public var uuid: String = ""
    
    /// Firmware and hardware version of the lock. Follows format: '3P-2.10' where '3P' is the hardware version and '2.10' is the firmware version
    public var version: String = ""
    
    /// Tracking key used to track Noke device usage and activity
    public var trackingKey: String = ""
    
    /// CBPeripheral of the Noke device used by CoreBluetooth
    public var peripheral: CBPeripheral?
    
    /// Delegate of the Noke device. In virtually all cases this is the NokeDeviceManager
    weak var delegate: NokeDeviceDelegate?
    
    public var phoneKeyHandler: PhoneKeyHandling?
    
    public var signingKeyState: NokePhoneKeyState?
    
    /// Byte array read from the session characteristic upon connecting to the Noke device
    public var session: String?
    public var sessionTimestamp: Date?
    
    /// Battery level of the Noke device in millivolts
    public var battery: UInt64 = 0
    
    /// RSSI level of the Noke device
    public var RSSI: NSNumber = -127
    
    /// Current RSSI of the Noke device
    public var currentRSSI: Int {
        rssiArray.last ?? RSSI.intValue
    }
    
    ///RSSI array
    public var rssiArray: [Int] = []
    
    /// Connection state of the Noke device
    public var connectionState: NokeDeviceConnectionState?
    
    public var isDisconnectedDuringUnlock: Bool = false
    public var unlockTime: Date?
    public var postUnlockShackleEventCount: Int = 0
    
    public var isUnlockInProgress: Bool {
        return connectionState == .Connecting || connectionState == .Connected || connectionState == .Syncing || connectionState == .Unlocked || isDisconnectedDuringUnlock
    }
    
    /// Lock state of the Noke device
    public var lockState: NokeDeviceLockState = NokeDeviceLockState.nokeDeviceLockStateLocked
    
    public var encryptionType: NokeEncryptionType {
        return isNokeIon2() ? .signing : .encryption
    }
    
    /// Bluetooth Gatt Service of Noke device
    var nokeService: CBService?
    
    /// Read characteristic of Noke device
    var rxCharacteristic: CBCharacteristic?
    
    /// Write characteristic of Noke device
    var txCharacteristic: CBCharacteristic?
    
    /// Read/Write characteristic of Noke device
    var trxCharacteristic: CBCharacteristic?
    
    /// Session characteristic of Noke device. This is read upon connecting and used for encryption
    var sessionCharacteristic: CBCharacteristic?
    
    /// Read characteristic of Noke 4i bootloader
    var bootloader4iRxCharacteristic: CBCharacteristic?
    
    /// Write characteristic of Noke 4i bootloader
    var bootloader4iTxCharacteristic: CBCharacteristic?
    
    /// Read characteristic of Noke 2i bootloader
    var bootloader2iRxCharacteristic: CBCharacteristic?
    
    /// Write characteristic of Noke 2i bootloader
    var bootloader2iTxCharacteristic: CBCharacteristic?
    
    var timeCharacteristic: CBCharacteristic?
    
    var aclCharacteristic: CBCharacteristic?
    
    var statusCharacteristic: CBCharacteristic?
    
    var aclSignatureCharacteristic: CBCharacteristic?
    
    var commandIdCharacteristic: CBCharacteristic?
    
    var commandWriteCharacterstic: CBCharacteristic?
    
    var commandSignatureCharacteristic: CBCharacteristic?
    
    // MARK: - Pending Ion2 Unlock
    
    /// Pending unlock request that will execute once all Ion2 characteristics are discovered
    var pendingIon2Unlock: (() -> Void)?
    
    /// Tracks whether Ion2 service and characteristics have been fully discovered
    var ion2CharacteristicsReady: Bool = false
    
    /// Array of commands to be sent to the Noke device
    var commandArray: Array<Data>!
    
    /// Array of responses from the Noke device that need to be uploaded
    var responseArray: Array<String>!
    
    /// Unlock command used for offline unlocking
    var unlockCmd: String = ""
    
    /// Unique key used for encrypting the unlock command for offline unlocking
    var offlineKey: String = ""
    
    /// Indicates if the lock keys need to be restored
    var isRestoring: Bool = false
    
    /// Indicates if the lock is able to be Auto Unlocked
    public var canAutoUnlock: Bool = false
    
    public var currentAclWriteStatus: String = ""
    
    var callJammedDelegate: Bool = true
    
    var aclIsAccepted: Bool = false
    
    var readCommandIdCompletion: ((Result<Data, Error>) -> Void)?
        
    var handleSuccess: (() -> Void)?
    
    var handleFailure: ((NokeDeviceOperationError) -> Void)?
    
    var currentAclData: Data?
    
    var currentSignatureData: Data?
    
    var currentCommandSignatureData: Data?
    
    internal var currentAclEnvelope: PhoneKeyAclEnvelope?
    
    var userId: String?
    
    var deviceID: String?
    
    var pendingSecuredAction: (() -> Void)?
    
    // MARK: - Ion 2 Components (TIDY Refactor)
    
    /// Ion 2 signing coordinator - manages state machine
    var ion2SigningCoordinator: Ion2SigningCoordinator?
    
    /// Ion 2 characteristic handler - manages BLE operations
    var ion2CharacteristicHandler: Ion2CharacteristicHandler?
    
    let phoneKeyManager = PhoneKeyManager(serviceName: "com.noke.noke-sdk-swift", provider: DummyCryptoProvider())
    
    let hexAlphabet = "0123456789abcdef".unicodeScalars.map { $0 }
    
    /// UUID of the Noke service
    internal static func nokeServiceUUID() -> (CBUUID){
        return CBUUID.init(string: "1bc50001-0200-d29e-e511-446c609db825")
    }
    
    /// UUID of the Noke infinity service
    internal static func nokeInfinityServiceUUID() -> (CBUUID){
        return CBUUID.init(string: "AE82FFB0-6AC4-4F9D-A917-308D52492513")
    }
    
    /// UUID of the Noke write characteristic
    internal static func txCharacteristicUUID() -> (CBUUID){
        return CBUUID.init(string: "1bc50002-0200-d29e-e511-446c609db825")
    }
    
    /// UUID of the Noke read characteristic
    internal static func rxCharacteristicUUID() -> (CBUUID){
        return CBUUID.init(string: "1bc50003-0200-d29e-e511-446c609db825")
    }
    
    /// UUID of the Noke session characteristic
    internal static func sessionCharacteristicUUID() -> (CBUUID){
        return CBUUID.init(string: "1bc50004-0200-d29e-e511-446c609db825")
    }
    
    /// UUID of the time characteristic for Noke Ion 2
    internal static func timeCharacteristicUUID() -> (CBUUID){
        return CBUUID.init(string: "AE82FFB6-6AC4-4F9D-A917-308D52492513")
    }
    
    /// UUID of acl characteristic for Noke Ion 2
    internal static func aclCharacteristicUUID() -> (CBUUID){
        return CBUUID.init(string: "AE82FFB1-6AC4-4F9D-A917-308D52492513")
    }
    
    /// UUID of command  id read characteristic for Noke Ion 2
    internal static func commandIdReadCharacteristicUUID() -> (CBUUID){
        return CBUUID.init(string: "AE82FFB2-6AC4-4F9D-A917-308D52492513")
    }
    
    /// UUID of command write characteristic for Noke Ion 2
    internal static func commandWriteCharacteristicUUID() -> (CBUUID){
        return CBUUID.init(string: "AE82FFB3-6AC4-4F9D-A917-308D52492513")
    }
    
//    #define BT_UUID_NOKE_CMD_SIGNATURE_CHAR_VAL \
//        BT_UUID_128_ENCODE(0xae82ffb7, 0x6ac4, 0x4f9d, 0xa917, 0x308d52492513)
    /// UUID of command signature characteristic for Noke Ion 2
    internal static func commandSignatureCharacteristicUUID() -> (CBUUID){
        return CBUUID.init(string: "AE82FFB7-6AC4-4F9D-A917-308D52492513")
    }
    
    /// UUID of acl status characteristic for Noke Ion 2
    internal static func statusCharacteristicUUID() -> (CBUUID){
        return CBUUID.init(string: "AE82FFB4-6AC4-4F9D-A917-308D52492513")
    }
    
    /// UUID of acl signature characteristic for Noke Ion 2
    internal static func aclSignatureCharacteristicUUID() -> (CBUUID){
        return CBUUID.init(string: "AE82FFB5-6AC4-4F9D-A917-308D52492513")
    }
    
    /// UUID of firmware update mode for Noke 2i
    internal static func noke2iFirmwareUUID() -> (CBUUID) {
        return CBUUID.init(string: "0000fe59-0000-1000-8000-00805f9b34fb")
    }
    
    /// UUID of firmware update mode for Noke 4i
    internal static func noke4iFirmwareUUID() -> (CBUUID) {
        return CBUUID.init(string: "0000fe59-0000-1000-8000-00805f9b34fb")
    }
    
    /// UUID of Noke 4i bootloader write characteristic
    internal static func bootloader4iTxCharacteristicUUID() -> CBUUID {
        return CBUUID(string: "8ec90001-f315-4f60-9fb8-838830daea50")
    }
    
    /// UUID of Noke 4i bootloader read characteristic
    internal static func bootloader4iRxCharacteristicUUID() -> CBUUID {
        return CBUUID(string: "8ec90002-f315-4f60-9fb8-838830daea50")
    }
    
    /// UUID of Noke 2i bootloader write characteristic
    internal static func bootloader2iTxCharacteristicUUID() -> CBUUID {
        return CBUUID(string: "8ec90001-f315-4f60-9fb8-838830daea50")
    }
    
    /// UUID of Noke 2i bootloader read characteristic
    internal static func bootloader2iRxCharacteristicUUID() -> CBUUID {
        return CBUUID(string: "8ec90002-f315-4f60-9fb8-838830daea50")
    }
    
    public func isNokeOne() -> Bool {
        return getHardwareVersion()?.contains("1A") ?? false
    }
    
    public func isNokeIon() -> Bool {
        return getHardwareVersion()?.contains("4E") ?? false
    }
    
    public func isNokeIon2() -> Bool {
        // TODO: Remove once this is fixed on firmware.
        if let hardwareVersion = getHardwareVersion() {
            return hardwareVersion.contains("5E") || hardwareVersion.contains("E5")
        }
        return false
    }
    
    public func isKeypad() -> Bool {
        return getHardwareVersion()?.contains("3K") ?? false
    }
    
    public func isScreen() -> Bool {
        return getHardwareVersion()?.contains("4K") ?? false
    }
    
    public func isPadlock() -> Bool {
        return getHardwareVersion()?.contains("4I") ?? false
    }
    
    public func isWakeupNeeded() -> Bool {
        return isNokeOne() || isPadlock()
    }
    
    public func isRepeater() -> Bool {
        return getHardwareVersion()?.contains("1R") ?? false
    }
    
    public func hasValidSession() -> Bool {
        guard let session = session, !session.isEmpty else { return false }
        if session.range(of: "^[0]+$", options: .regularExpression) != nil { return false }
        guard let timestamp = sessionTimestamp else { return false }
        let elapsed = Date().timeIntervalSince(timestamp)
        let validityWindow: TimeInterval = isWakeupNeeded() ? 15.0 : 60.0
        return elapsed < validityWindow
    }
    
    public func invalidateSession() {
        session = nil
        sessionTimestamp = nil
        unlockTime = nil
        postUnlockShackleEventCount = 0
    }
    
    // MARK: - Unified Unlock (Strategy Pattern)
    
    /// Unified unlock method that routes to the appropriate strategy based on device type
    /// - Parameters:
    ///   - context: UnlockContext containing all necessary unlock parameters
    ///   - onSuccess: Called when unlock succeeds
    ///   - onFailure: Called when unlock fails with error
    ///
    /// **Usage:**
    /// ```swift
    /// // Encryption-based (legacy locks)
    /// device.unlock(
    ///     context: .encryption(key: "...", command: "..."),
    ///     onSuccess: { print("Unlocked!") },
    ///     onFailure: { error in print("Failed: \(error)") }
    /// )
    ///
    /// // Signing-based (Ion 2)
    /// device.unlock(
    ///     context: .signing(acl: acl, userId: "...", deviceID: "..."),
    ///     onSuccess: { print("Unlocked!") },
    ///     onFailure: { error in print("Failed: \(error)") }
    /// )
    /// ```
    public func offlineUnlock(
        context: UnlockContext,
        onSuccess: @escaping () -> Void,
        onFailure: @escaping (NokeDeviceOperationError) -> Void
    ) {
        let strategy = getUnlockStrategy()
        strategy.executeUnlock(
            device: self,
            context: context,
            onSuccess: onSuccess,
            onFailure: onFailure
        )
    }
    
    /// Returns the appropriate unlock strategy based on device encryption type
    /// - Returns: NokeUnlockStrategy (EncryptionUnlockStrategy or SigningUnlockStrategy)
    private func getUnlockStrategy() -> NokeUnlockStrategy {
        switch encryptionType {
        case .encryption:
            return EncryptionUnlockStrategy()
        case .signing:
            return SigningUnlockStrategy()
        }
    }
    
    /**
     Initializes a new Noke device with provided properties
     
     - Parameters:
     - name: Name of the noke device (strictly for UI purposes)
     - mac: MAC address of noke device.  NokeDeviceManager will scan for this mac address
     
     -Returns: A beautiful, ready-to-use, Noke device just for you
     */
    public init?(name: String, mac: String){
        self.name = name
        self.mac = mac
        
        self.unlockCmd = ""
        self.offlineKey = ""
        self.lockState = NokeDeviceLockState.nokeDeviceLockStateLocked
        super.init()
    }
    
    /**
     Initializes a new Noke device with provided properties. This is mostly used when loading cached locks from user defaults, but can also be used to initialize a Noke device when more properties are known
     
     - Parameters:
     - name: Name of the noke device (strictly for UI purposes)
     - mac: MAC address of noke device.  NokeDeviceManager will scan for this mac address
     - serial: Serial address of the Noke device, laser-engraved on the device during manufacturing
     - uuid: Unique identifier of the Noke device, assigned by iOS
     - version: Hardware and firmware version of the Noke device
     - trackingKey: Tracking key of the Noke device used to track activity
     - battery: Battery level of the lock in millivolts
     - unlockCmd: Unlock command used for offline unlocking
     - offlineKey: Key used to encrypt the offline unlock command
     
     -Returns: A beautiful, ready-to-use, Noke device just for you
     */
    public init(name: String, mac: String, serial: String, uuid: String, version: String, trackingKey: String, battery: UInt64, unlockCmd: String, offlineKey: String){
        self.name = name
        self.mac = mac
        self.serial = serial
        self.uuid = uuid
        self.version = version
        self.trackingKey = trackingKey
        self.battery = battery
        self.unlockCmd = unlockCmd
        self.offlineKey = offlineKey
    }
    
    /// Method used to encode class to be stored in User Defaults
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(self.name, forKey: "name")
        aCoder.encode(self.mac, forKey: "mac")
        aCoder.encode(self.serial, forKey:"serial")
        aCoder.encode(self.uuid, forKey:"uuid")
        aCoder.encode(self.version, forKey:"version")
        aCoder.encode(self.trackingKey, forKey:"trackingkey")
        aCoder.encode(self.battery, forKey:"battery")
        aCoder.encode(self.unlockCmd, forKey:"unlockcmd")
        aCoder.encode(self.offlineKey, forKey:"offlinekey")
    }
    
    /// Method used to decode class to reload from User Defaults
    public required convenience init?(coder aDecoder: NSCoder) {
        guard   let name = aDecoder.decodeObject(forKey: "name") as? String,
                let mac = aDecoder.decodeObject(forKey: "mac") as? String,
                let serial = aDecoder.decodeObject(forKey: "serial") as? String,
                let uuid = aDecoder.decodeObject(forKey: "uuid") as? String,
                let version = aDecoder.decodeObject(forKey: "version") as? String,
                let trackingKey = aDecoder.decodeObject(forKey: "trackingkey") as? String,
                let battery = aDecoder.decodeObject(forKey: "battery") as? UInt64,
                let unlockCmd = aDecoder.decodeObject(forKey: "unlockcmd") as? String,
                let offlineKey = aDecoder.decodeObject(forKey: "offlinekey") as? String
        else{return nil}
        
        self.init(
            name: name,
            mac: mac,
            serial: serial,
            uuid: uuid,
            version: version,
            trackingKey: trackingKey,
            battery: battery,
            unlockCmd: unlockCmd,
            offlineKey: offlineKey)
    }
    
    /// Called when initial bluetooth connection has been established
    fileprivate func didConnect(){
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.clearCommandArray()
            self.peripheral?.delegate = self
            self.peripheral!.discoverServices([NokeDevice.nokeServiceUUID()])
        }
    }
    
    /// Stores the session after reading the session characteristic upon connecting
    func setSession(_ data: Data){
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.session = self.bytesToString(data: data, start: 0, length: 20)
            self.sessionTimestamp = Date()
            self.getBatteryFromSession(data: data)
            self.delegate?.didSetSession(self.mac)
        }
    }
    
    /// Extracts the battery level from the session and stores it in the battery variable
    fileprivate func getBatteryFromSession(data: Data){
        var session = data
        session.withUnsafeMutableBytes{(bytes: UnsafeMutablePointer<UInt8>)->Void in
            let batteryArray = byteArray.allocate(capacity: 2)
            batteryArray[0] = bytes[3]
            batteryArray[1] = bytes[2]
            
            let batteryString = String.init(format: "%02x%02x", batteryArray[0],batteryArray[1])
            let batteryResult = UInt64(batteryString, radix:16)
            battery = batteryResult!
        }
    }
    
    func addRSSIArray(rssi: NSNumber){
        if(rssiArray.count < 20){
            rssiArray.insert(rssi.intValue, at: 0)
        }else{
            rssiArray.remove(at: 19)
            rssiArray.insert(rssi.intValue, at: 0)
        }
        //debugPrint("\(name) RSSI ARRAY: \(rssiArray)")
    }
    
    public func getRSSIMode() -> NSNumber{
        if(rssiArray.count > 0){
            return NSNumber.init(value: mostFrequent(array: rssiArray))
        }
        return NSNumber.init(value: -127)
    }
    
    func mostFrequent(array: [Int]) -> Int {
        var counts: [Int: Int] = [:]
        
        array.forEach { counts[$0] = (counts[$0] ?? 0) + 1 }
        if let count = counts.max(by: {$0.value < $1.value})?.value {
            return (counts.filter{$0.value == count}.map{$0.key}.first ?? array.first ?? 0)
        }
        return array.first ?? 0
    }
    
    /**
     Parses through the broadcast data and pulls out the version
     
     Parameters
     data: broadcast data from the lock
     
     
     */
    public func setVersion(data: Data, deviceName: String){
        var byteData = data
        if(deviceName.contains(Constants.NOKE_DEVICE_IDENTIFIER_STRING)){
            byteData.withUnsafeMutableBytes{(bytes: UnsafeMutablePointer<UInt8>)->Void in
                let majorVersion = bytes[3]
                let minorVersion = bytes[4]
                
                let startIndex = deviceName.index(deviceName.startIndex, offsetBy: 4)
                let endIndex = deviceName.index(startIndex, offsetBy:2)
                let hardwareVersion = String(deviceName[startIndex..<endIndex])
                self.version = String(format: "%@-%d.%d", hardwareVersion,majorVersion,minorVersion)
            }
        }
    }
    
    public func getHardwareVersion()-> String? {
        if(version.count > 2) {
            let endIndex = version.index(version.startIndex, offsetBy:2)
            return String(version[version.startIndex..<endIndex])
        }
        
        let peripheralName = peripheral?.name ?? ""
        return String(peripheralName.dropFirst(4).prefix(2))
    }
    
    public func getSoftwareVersion()->String{
        let startIndex = version.index(version.startIndex, offsetBy: 3)
        return String(version[startIndex..<version.endIndex])
    }
    
    
    func makeUnlockPayload(offlineKeyHex: String, unlockCmdHex: String, includeTimestamp: Bool, commandId: String) -> [String: String] {
        var payload: [String: String] = [
            "offlineKey": offlineKeyHex,
            "unlockCmd": unlockCmdHex
        ]
        if includeTimestamp {
            let timestamp = UInt64(Date().timeIntervalSince1970)
            payload["timestamp"] = String(timestamp)
        }

        for s: CBService in (peripheral.services!){
            if(s.uuid.isEqual(NokeDevice.nokeServiceUUID())){
                self.nokeService = s
                self.peripheral?.discoverCharacteristics([NokeDevice.txCharacteristicUUID(), NokeDevice.rxCharacteristicUUID(), NokeDevice.sessionCharacteristicUUID()], for: s)
            }
            if (s.uuid.isEqual(NokeDevice.noke2iFirmwareUUID())) {
                self.nokeService = s
                self.peripheral?.discoverCharacteristics([NokeDevice.bootloader2iTxCharacteristicUUID(), NokeDevice.bootloader2iRxCharacteristicUUID()], for: s)
            }
            if (s.uuid.isEqual(NokeDevice.noke4iFirmwareUUID())) {
                self.nokeService = s
                self.peripheral?.discoverCharacteristics([NokeDevice.bootloader4iRxCharacteristicUUID(), NokeDevice.bootloader4iTxCharacteristicUUID()], for: s)
            }
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if((error) != nil){
            print(error as Any)
            return
        }

        for c : CBCharacteristic in service.characteristics!
        {
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
            }
            else if c.uuid.isEqual(NokeDevice.bootloader2iTxCharacteristicUUID()) {
                 self.bootloader4iTxCharacteristic = c
                 delegate?.nokeReadyForFirmwareUpdate(noke: self)
            }
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if(error != nil){
            return
        }
        if(characteristic == self.rxCharacteristic){
            let response = characteristic.value
            _ = self.receivedDataFromLock(response!)
        }
        else if(characteristic == self.sessionCharacteristic){
            let data = characteristic.value
            self.setSession(data!)
        }
    }

    /**
     Called when the phone receives data from the Noke device.  There are two main types of data packets:
     - Server packets: Encrypted responses from the locks that are parsed by the server. Can include logs, keys, and quick-click confirmations
     - App packets: Unencrypted responses that indicate whether command succeeded or failed.

     - Parameter data: 20 byte response from the lock
     */
    fileprivate func receivedDataFromLock(_ data: Data){
        var newData = data
        newData.withUnsafeMutableBytes{(bytes: UnsafeMutablePointer<UInt8>)->Void in
            let dataBytes = bytes
            let destByte = Int(dataBytes[0])
            switch destByte{
            case Constants.SERVER_Dest:
                if(self.session != nil){
                    NokeDeviceManager.shared().addUploadPacketToQueue(
                        response: self.bytesToString(data: data, start: 0, length: 20),
                        session: self.session!,
                        mac: self.mac)
                }
                break
            case Constants.APP_Dest:

                let resultByte = Int(data[1])
                switch resultByte{
                case Constants.SUCCESS_ResultType:
                    if(isRestoring){
                        let commandid = Int(data[2])
                        commandArray.removeAll()
                        NokeDeviceManager.shared().clearUploadQueue()
                        self.isRestoring = false
                        NokeDeviceManager.shared().confirmRestore(noke: self, commandid: commandid)
                        NokeDeviceManager.shared().disconnectNokeDevice(self)
                    }else{
                        self.moveToNext()
                        if(self.commandArray.count == 0){
                            self.lockState = NokeDeviceLockState.Unlocked
                            self.connectionState = NokeDeviceConnectionState.Unlocked
                            NokeDeviceManager.shared().delegate?.nokeDeviceDidUpdateState(to: self.connectionState!, noke: self)
                            NokeDeviceManager.shared().uploadData()
                        }
                    }
                    break
                case Constants.INVALIDKEY_ResultType:
                    NokeDeviceManager.shared().delegate?.nokeErrorDidOccur(error: NokeDeviceManagerError.nokeDeviceErrorInvalidKey, message: "Invalid Key Result", noke: self)
                    self.clearCommandArray()
                    //self.moveToNext()
                    //                        if(self.commandArray.count == 0){
                    //                            if(!isRestoring){
                    //                                NokeDeviceManager.shared().restoreDevice(noke: self)
                    //                            }
                    //                        }
                    break
                case Constants.INVALIDCMD_ResultType:
                    NokeDeviceManager.shared().delegate?.nokeErrorDidOccur(error: NokeDeviceManagerError.nokeDeviceErrorInvalidCmd, message: "Invalid Command Result", noke: self)
                    self.moveToNext()
                    break
                case Constants.INVALIDPERMISSION_ResultType:
                    NokeDeviceManager.shared().delegate?.nokeErrorDidOccur(error: NokeDeviceManagerError.nokeDeviceErrorInvalidPermission, message: "Invalid Permission (wrong key) Result", noke: self)
                    self.moveToNext()
                    break
                case Constants.SHUTDOWN_ResultType:
                    print("shutDown Called")
                    self.clearCommandArray()
                    let lockStateByte = Int32(data[2])
                    var isLocked = true
                    if(lockStateByte == 0){
                        self.lockState = NokeDeviceLockState.Unlocked
                        isLocked = false
                    }
                    else if(lockStateByte == 1){
                        self.lockState = NokeDeviceLockState.Locked
                    }

                    let timeoutStateByte = Int32(data[3])
                    var didTimeout = true
                    if(timeoutStateByte == 1){
                        didTimeout = false
                    }
                    NokeDeviceManager.shared().delegate?.nokeDeviceDidShutdown(noke: self, isLocked: isLocked, didTimeout: didTimeout)
                    break
                case Constants.INVALIDDATA_ResultType:
                    NokeDeviceManager.shared().delegate?.nokeErrorDidOccur(error: NokeDeviceManagerError.nokeDeviceErrorInvalidData, message: "Invalid Data Result", noke: self)
                    self.moveToNext()
                    break
                case Constants.FAILEDTOLOCK_ResultType:
                    NokeDeviceManager.shared().delegate?.nokeErrorDidOccur(error: NokeDeviceManagerError.nokeDeviceErrorInvalidData, message: "Failed To Lock", noke: self)
                    break
                case Constants.FAILEDTOUNLOCK_ResultType:
                    NokeDeviceManager.shared().delegate?.nokeErrorDidOccur(error: NokeDeviceManagerError.nokeDeviceErrorInvalidData, message: "Failed To Unlock", noke: self)
                    break
                case Constants.FAILEDTOUNSHACKLE_ResultType:
                    NokeDeviceManager.shared().delegate?.nokeErrorDidOccur(error: NokeDeviceManagerError.nokeDeviceErrorInvalidData, message: "Failed To Unshackle", noke: self)
                    break
                case Constants.INVALID_ResultType:
                    NokeDeviceManager.shared().delegate?.nokeErrorDidOccur(error: NokeDeviceManagerError.nokeDeviceErrorInvalidResult, message: "Invalid Result", noke: self)
                    self.moveToNext()
                    break
                default:
                    NokeDeviceManager.shared().delegate?.nokeErrorDidOccur(error: NokeDeviceManagerError.nokeDeviceErrorUnknown, message: "Unable to recognize result", noke: self)
                    self.moveToNext()
                    break
                }
                break

            case Constants.INVALID_ResponseType:
                NokeDeviceManager.shared().delegate?.nokeErrorDidOccur(error: NokeDeviceManagerError.nokeDeviceErrorInvalidResult, message: "Invalid packet received", noke: self)
                break
            default:
                break
            }
        }
    }

    /// Moves to next command in the command array in preperation to sending
    func moveToNext(){
        if(commandArray != nil){
            if(commandArray.count >= 1){
                commandArray.remove(at: 0)
                if(commandArray.count >= 1){
                    writeCommandArray()
                }
            }
        }
    }

   

    /**
     Sends a command string from the Noke Core API to the Noke device

     - Parameter commands: A command string from the Core API. Commands are delimited by '+'
     */
    public func sendCommands(_ commands: String){
        let commandsArr = commands.components(separatedBy: "+")
        clearCommandArray()
        for command: String in commandsArr{
            self.addCommandToCommandArray(self.stringToBytes(hexstring: command)!)
        }
        self.writeCommandArray()
    }

    /**
    Sends a command string from the Noke Core API to the Noke device

    - Parameter commands: A n array of commands
    */
    public func sendCommands(_ commands: Array<String>){
        for command: String in commands{
            self.addCommandToCommandArray(self.stringToBytes(hexstring: command)!)
        }
        self.writeCommandArray()
    }

    /**
     Sets offline key and command used for unlocking offline

     - Parameters:
     -key: String used to encrypt the command to the lock. Received from the Core API
     -command: String sent to the lock to unlock offline. Received from the Core API
     */
    public func setOfflineValues(key: String, command: String){
        self.offlineKey = key
        self.unlockCmd = command
    }

    /**
     Sets offline values before offline unlocking

     - Parameters:
     -key: String used to encrypt the command to the lock. Received from the Core API
     -command: String sent to the lock to unlock offline. Received from the Core API
     */
    public func offlineUnlock(key: String, command: String, addTimestamp: Bool? = true) ->String{
        self.offlineKey = key
        self.unlockCmd = command
        return self.offlineUnlock(addTimestamp: addTimestamp)
    }

    /**
     Unlocks the lock using the offline key and the unlock command.  If the keys and commands have been set, no internet connection is required.
     */
    public func offlineUnlock(addTimestamp: Bool? = true)->String{
        if(offlineKey.count == Constants.OFFLINE_KEY_LENGTH && unlockCmd.count == Constants.OFFLINE_COMMAND_LENGTH){
            var keydata = Data(capacity: offlineKey.count/2)
            let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
            regex.enumerateMatches(in: offlineKey, options: [], range: NSMakeRange(0, offlineKey.count)) { match, flags, stop in
                guard let range = Range(match!.range, in: offlineKey) else {
                    return
                }
                let byteString = String(offlineKey[range])
                var num = UInt8(byteString, radix: 16)!
                keydata.append(&num, count: 1)
            }

            guard keydata.count > 0 else {
                return ""
            }

            var cmddata = Data(capacity:unlockCmd.count/2)
            regex.enumerateMatches(in: unlockCmd, options: [], range: NSMakeRange(0, unlockCmd.count)) { match, flags, stop in
                let byteCmdString = (unlockCmd as NSString).substring(with: match!.range)
                var cmdnum = UInt8(byteCmdString, radix: 16)!
                cmddata.append(&cmdnum, count: 1)
            }

            guard cmddata.count > 0 else {
                return ""
            }

            let currentDateTime = Date()
            let timeStamp = UInt64(currentDateTime.timeIntervalSince1970)
            let timedata = Data.init([UInt8((timeStamp >> 24) & 0xFF), UInt8((timeStamp >> 16) & 0xFF), UInt8((timeStamp >> 8) & 0xFF), UInt8((timeStamp & 0xFF))])

            let finalCmdData = createOfflineUnlock(preSessionKey: keydata, unlockCmd: cmddata, timestamp: timedata)
            print("KEY DATA: \(keydata) COMMAND DATA: \(cmddata)")
            print("FINAL COMMAND DATA: \(finalCmdData)")
            let finalCmdD = self.bytesToString(data: finalCmdData, start: 0, length: 20)
            print("finalCmdD: \(finalCmdD)")
            print("KEY DATA: \(keydata) COMMAND DATA: \(cmddata)")
            print("FINAL COMMAND DATA: \(finalCmdData)")
            self.addCommandToCommandArray(finalCmdData)
            self.writeCommandArray()
            return String.init(timeStamp)
        }else{
            NokeDeviceManager.shared().delegate?.nokeErrorDidOccur(error: NokeDeviceManagerError.nokeLibraryErrorInvalidOfflineKey, message: "Offline Key/Command is not a valid length", noke: self)
            return ""
        }
    }

    /**
     Creates the offline unlock command, adds the current timestamp, and encrypts using the keys.

     - Parameters:
     - preSessionKey: key used to encrypt commands
     - unlockCmd: command to be encrypted
     - timestamp: Current time to be embedded into the command
     */
    fileprivate func createOfflineUnlock(preSessionKey: Data, unlockCmd: Data, timestamp: Data, addTimestamp: Bool? = false) -> Data
    {
        let newCommandPacket = byteArray.allocate(capacity: 20)
        var key = self.createOfflineCombinedKey(baseKey:preSessionKey)
        let combinek = self.bytesToString(data: key, start: 0, length: 16)
        debugPrint("CombibeKey: \(combinek)")
        var unlockCmdBytes = [UInt8](unlockCmd)

        var x = 0
        while x<4 {
            newCommandPacket[x] = unlockCmdBytes[x]
            x += 1
        }

        let cmddata = byteArray.allocate(capacity: 16)

        var i = 0
        while i<16 {
            cmddata[i] = unlockCmd[i+4]
            i += 1
        }


        if(addTimestamp ?? true){
            var timeStampBytes = [UInt8](timestamp)
            cmddata[2] = timeStampBytes[3]
            cmddata[3] = timeStampBytes[2]
            cmddata[4] = timeStampBytes[1]
            cmddata[5] = timeStampBytes[0]

            var checksum:Int = 0
            var n = 0
            while n<15 {
                checksum += Int(cmddata[n])
                n += 1
            }
            cmddata[15] = UInt8.init(truncatingIfNeeded: checksum)
        }

        key.withUnsafeMutableBytes {(bytes: UnsafeMutablePointer<UInt8>)->Void in
            let keyBytes = bytes
            self.copyArray(newCommandPacket, outStart: 4, dataIn: self.encryptPacket(keyBytes, data: cmddata), inStart: 0, size: 16)
        }

        return Data.init([newCommandPacket[0], newCommandPacket[1], newCommandPacket[2], newCommandPacket[3], newCommandPacket[4], newCommandPacket[5], newCommandPacket[6], newCommandPacket[7], newCommandPacket[8], newCommandPacket[9], newCommandPacket[10], newCommandPacket[11], newCommandPacket[12], newCommandPacket[13], newCommandPacket[14], newCommandPacket[15], newCommandPacket[16], newCommandPacket[17], newCommandPacket[18], newCommandPacket[19]])
    }

    //Creates offline key by combining the offline key with the session
    fileprivate func createOfflineCombinedKey(baseKey: Data) -> Data{

        let session = stringToBytes(hexstring: self.session!)!
        var sessionBytes = [UInt8](session)
        var baseKeyBytes = [UInt8](baseKey)

        var total:Int
        var x = 0
        while x<16 {

            total = Int(baseKeyBytes[x]) + Int(sessionBytes[x])
            baseKeyBytes[x] = UInt8.init(truncatingIfNeeded: total)
            x += 1
        }
        return Data.init(baseKeyBytes)
    }


    /// Converts hex string to byte array (data)
    internal func stringToBytes(hexstring: String) -> Data? {
        var data = Data(capacity: hexstring.count / 2)
        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        regex.enumerateMatches(in: hexstring, range: NSMakeRange(0, hexstring.utf16.count)) { match, flags, stop in
            guard let range = Range(match!.range, in: offlineKey) else {
                return
            }
            let byteString = String(offlineKey[range])
            var num = UInt8(byteString, radix: 16)!
            data.append(&num, count: 1)
        }
        guard data.count > 0 else { return nil }
        return data
    }

    /// Converts byte array (data) to hex string
    internal func bytesToString(data:Data, start:Int, length:Int) -> String
    {
        var bytes = [UInt8](data)
        let hex = NSMutableString(string: "")
        var x = 0
        while x < length {
            hex.appendFormat("%02x", bytes[x + start])
            x += 1
        }
        let immutableHex = String.init(hex)
        return immutableHex
    }

    fileprivate func copyArray(_ dataOut: byteArray, outStart: Int, dataIn: byteArray, inStart: Int, size: Int){

        var x = 0
        while x < size {
            dataOut[x+outStart] = dataIn[x+inStart]
            x += 1
        }

    }

    fileprivate func copyArray(_ dataOut: byteArray, dataIn: byteArray, size: Int)
    {
        var x = 0
        while x < size {

            dataOut[x] = dataIn[x]
            x += 1
        }
    }

    fileprivate func copyArray(_ dataOut: Data, dataIn: Data, size: Int) -> Data
    {
        var bytesDataOut = [UInt8](dataOut)
        var bytesDataIn = [UInt8](dataIn)

        var x = 0
        while x < size {

            bytesDataOut[x] = bytesDataIn[x]
            x += 1
        }

        return Data.init(bytesDataOut)
    }

    fileprivate func encryptPacket(_ combinedKey: byteArray, data: byteArray) -> byteArray
    {
        let tempKey = byteArray.allocate(capacity: 16)
        let buffer = byteArray.allocate(capacity: 16)
        self.copyArray(tempKey, dataIn: combinedKey, size: 16)
        aes_enc_dec(data, tempKey, 1)
        self.copyArray(buffer, dataIn: data, size: 16)

        return buffer
    }
}
