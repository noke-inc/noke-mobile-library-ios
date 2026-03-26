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
    case lockAlreadyUnlocked = "LOCK_ALREADY_UNLOCKED"
    case unlockOverlocked = "UNLOCK_OVERLOCKED"
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
    case missingCommandIdCharacteritic
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
    case lockAlreadyUnlocked
    case unknown
    
    public var description: String {
        switch self {
        case .peripheralNotFound: return "Could not find device locally"
        case .missingCommandIdCharacteritic: return "Empty commands"
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
        case .timeOffsetError:
            return "There was something wrong with your dates. Please try again."
        case .lockAlreadyUnlocked: return "Your lock is already unlocked."
        case .unknown: return "An unknown error occurred"
        }
    }
    
    public var isValid: Bool {
        switch self {
        case .peripheralNotFound: return true
        case .missingCommandIdCharacteritic, .invalidAclSignature, .missingAcl, .invalidCommandId, .commandSignatureFailed, .aclRejected, .characteristicNotFound, .offlineUnlockTimeout, .requiresEmergencyUnlock, .requiresOverrideUnlock, .outOfSchedule, .unlockDenied, .lockIsLocked, .aclTimeInvalid, .overlock, .timeOffsetError, .lockAlreadyUnlocked, .unknown: return false
        }
    }
    
    public var shouldRefreshKeys: Bool {
        switch self {
        case .missingCommandIdCharacteritic, .missingAcl, .invalidCommandId, .peripheralNotFound, .characteristicNotFound, .commandSignatureFailed, .offlineUnlockTimeout, .requiresEmergencyUnlock, .requiresOverrideUnlock, .aclTimeInvalid, .lockIsLocked, .lockAlreadyUnlocked, .timeOffsetError, .unknown: return false
        case .aclRejected, .invalidAclSignature, .outOfSchedule, .overlock, .unlockDenied: return true
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
        case .missingCommandIdCharacteritic, .overlock, .lockIsLocked, .invalidAclSignature, .lockAlreadyUnlocked, .missingAcl, .aclTimeInvalid, .commandSignatureFailed, .timeOffsetError, .invalidCommandId:
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
        
        return payload
    }
}
