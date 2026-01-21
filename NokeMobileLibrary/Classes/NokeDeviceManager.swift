/**
 NokeDeviceManager.swift
 NokeMobileLibrary
 
 Created by Spencer Apsley on 1/12/18.
 Copyright © 2018 Nokē Inc. All rights reserved.
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Foundation
import CoreBluetooth


/**
 Connection states of Noke Devices
 
 - Disconnected: Noke device is not connected to phone
 - Discovered: Noke device is broadcasting and is discovered by phone
 - Connecting: Phone has initialized a connection and is waiting for response
 - Connected: Noke device is successfully connected to phone
 - Syncing: Phone is sending commands to Noke device
 - Unlocked: Noke device is unlocked
 */
public enum NokeDeviceConnectionState : Int{
    case Disconnected = 0
    case Discovered = 1
    case Connecting = 2
    case Connected = 3
    case Syncing = 4
    case Unlocked = 5
}

public enum NokeManagerBluetoothState : Int{
    case unknown
    case resetting
    case unsupported
    case unauthorized
    case poweredOff
    case poweredOn
}

/// Delegate for interacting with the NokeDeviceManager
public protocol NokeDeviceManagerDelegate: AnyObject
{
    /**
     Called when a Noke device updates its state.  Please see the NokeDeviceConnectionState enum type for all possible states
     
     - Parameters:
     - state: NokeDeviceConnectionState. Possible states include:
     - Disconnected
     - Discovered
     - Connecting
     - Connected
     - Syncing
     - Unlocked
     - noke: The Noke device that was updated
     */
    
    func nokeDevicefailureUpdate(message: String)
    func nokeDeviceDidUpdateState(to state: NokeDeviceConnectionState, noke: NokeDevice)
    
    func nokeDeviceDidSendDiagnostics(data: [String:Any], noke: NokeDevice)
    
    
    /**
     Called after the lock shuts down
     
     - Parameters:
     - noke: The Noke device that shutdown
     - isLocked: Indicates if the lock was locked or unlocked when it shutdown
     - didTimeout: Indicates if the lock timed out or was shutdown manually
     */
    func nokeDeviceDidShutdown(noke: NokeDevice, isLocked: Bool, didTimeout: Bool)
    
    
    /**
     Called when the Noke Mobile library encounters an error. Please see error types for possible errors
     
     - Parameters:
     - error: The NokeDeviceManagerError that was thrown
     - message: English description of error
     - noke: Device associated with the error if applicable
     */
    func nokeErrorDidOccur(error: NokeDeviceManagerError, message: String, noke: NokeDevice?)
    
    /**
     Called after data from the lock is upload to the API
     
     - Parameters:
     - result: Result of the data being uploaded (success or failure)
     - message: Contains details of the upload result
     */
    func didUploadData(result: Int, message: String)
    
    /**
     Called when the bluetooth manager updates its power state
     
     - Parameters:
     - state: The current power state of the bluetooth manager (off, on, etc)
     */
    func bluetoothManagerDidUpdateState(state: NokeManagerBluetoothState)
    
    func nokeReadyForFirmwareUpdate(noke: NokeDevice)
    
    func successPacketReceived(noke: NokeDevice)
    
    func onNokeJammedLocking(noke: NokeDevice)

    func onNokeJammedUnlocking(noke: NokeDevice)
}

public protocol NokeUploadDelegate{
    func didReceiveUploadData(data: [String:Any])
}



/// Manages bluetooth interactions with Noke Devices
public class NokeDeviceManager: NSObject, CBCentralManagerDelegate, NokeDeviceDelegate
{
    /// Key for saving noke devices to user defaults
    let nokeDevicesDefaultsKey = "noke-mobile-devices"
    
    /// Key for saving upload packets to user defaults
    let globalUploadDefaultsKey = "noke-mobile-upload-queue"
    
    /// URL string for uploading data
    public var uploadUrl = ""
    
    /// URL string for fetching unlock commands
    public var unlockUrl: String = ""
    
    /// Delegate for NokeDeviceManager, calls protocol methods
    public weak var delegate: NokeDeviceManagerDelegate? {
        didSet{
            if let state = NokeManagerBluetoothState.init(rawValue: cm.state.rawValue) {
                delegate?.bluetoothManagerDidUpdateState(state: state)
            }
        }
    }
    
    public var rssiThreshold: Int = -127
    public var autounlockTimeSeconds: Int = 300
    
    public var uploadDelegate: NokeUploadDelegate?
    
    /// Array of Noke devices managed by the NokeDeviceManager
    var nokeDevices = [String: NokeDevice]()
    
    /// Queue of responses from lock ready to be uploaded
    fileprivate var globalUploadQueue = [Dictionary<String,Any>]()
    
    /// API Key used for upload data endpoint
    fileprivate var apiKey: String = ""
    
    var centralManagerRestoreKey = "nokeCentralManagerIdentifer"
    
    /// CBCentralManager
    public lazy var cm: CBCentralManager = CBCentralManager(delegate: self, queue:nil)
    
    /// Shared instance of NokeDeviceManager
    static var sharedNokeDeviceManager: NokeDeviceManager?
    
    /// Boolean that allows SDK to discover devices that haven't been added to the array
    var allowAllNokeDevices: Bool = false
    
    /// typealias used for handling bytes from the lock
    public typealias byteArray = UnsafeMutablePointer<UInt8>
    
    /// Boolean that should be set when scanning for devices to update firmware
    public var firmwareScanning = false
    
    private var devicesQueue = DispatchQueue.init(label: "noke")
    
    /// String value for ensuring the app only connects to the target firmware device
    private var bootloaderName: String = ""

    
    enum NokeError: Error {
        case NokeDeviceInvalidLockState
        case NokeDeviceInvalidData
        case NokeDeviceScanAlreadyRunning
    }
    
    var broadcastName: String?
    var deviceName: String = ""
    var targetMac: String = ""
    private var isRetryScheduled = false
    private let centralQueue = DispatchQueue.main
    var timer: Timer!
    var isUnlockInProgress: Bool {
        return devicesQueue.sync {
            guard !nokeDevices.isEmpty else { return false }
            let nokes = Array(nokeDevices.values)
            let filteredUnlocksInProgress = nokes.filter {
                guard let state = $0.connectionState else { return false }
                return state == .Connecting || state == .Connected || state == .Syncing || state == .Unlocked
            }
            return filteredUnlocksInProgress.count > 0
        }
    }
    
    /**
     Initializes a new NokeDeviceManager
     - Returns: NokeDeviceManager
     */
    override init(){
        super.init()
        cm = CBCentralManager.init(delegate: self, queue: nil, options: [CBCentralManagerOptionRestoreIdentifierKey:centralManagerRestoreKey])
    }
    
    /**
     Used for getting the shared instance of NokeDeviceManager
     - Returns: Shared instance of NokeDeviceManager
     */
    public static func shared()->NokeDeviceManager{
        if(sharedNokeDeviceManager == nil) {
            sharedNokeDeviceManager = NokeDeviceManager.init()
        }
        return sharedNokeDeviceManager!
    }
    
    public func resetCentralManager(){
        cm = CBCentralManager.init(delegate: self, queue: nil, options: [CBCentralManagerOptionRestoreIdentifierKey:centralManagerRestoreKey])
    }
    
    
    private func scheduleRetryScanIfNeeded_locked(in delay: TimeInterval) {
        guard !isRetryScheduled else { return }
        isRetryScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            self.isRetryScheduled = false
            self.startScanForNokeDevices()
        }
    }
    
    private func _startScanForNokeDevices_locked() {
        guard !isUnlockInProgress && cm.state == .poweredOn else {
            scheduleRetryScanIfNeeded_locked(in: 2)
            return
        }
        
        
        guard !uploadUrl.isEmpty else {
            debugPrint("No Library Mode has been set. Please set using the setLibraryMode method")
            delegate?.nokeErrorDidOccur(
                error: NokeDeviceManagerError.nokeLibraryErrorNoModeSet,
                message: "No Library Mode has been set. Please set using the setLibraryMode method",
                noke: nil
            )
            return
        }
        
        let scanOptions : [String:AnyObject] = [CBCentralManagerScanOptionAllowDuplicatesKey: NSNumber.init(value: true as Bool)]
        let serviceArray = [CBUUID]([NokeDevice.nokeServiceUUID(), NokeDevice.noke4iFirmwareUUID(), NokeDevice.noke2iFirmwareUUID()])
        
        //Make sure we start scan from scratch
        cm.stopScan()
        cm.scanForPeripherals(withServices: serviceArray, options: scanOptions)
    }
    
    /// Begins bluetooth scanning for Noke Devices that have been added to the device array
    public func startScanForNokeDevices(){
        if Thread.isMainThread {
            _startScanForNokeDevices_locked()
        } else {
            centralQueue.async { [weak self] in
                guard let self = self else { return }
                self._startScanForNokeDevices_locked( )
            }
        }
    }
    
    /// Stops bluetooth scanning
    public func stopScan() {
        cm.stopScan()
    }
    
    /**
     Initializes connection to Noke Device
     
     - Parameter noke: The Noke device for the connection
     */
    public func connectToNokeDevice(_ noke:NokeDevice) {
        self.insertNokeDevice(noke)
        let connectionOptions : [String: AnyObject] = [CBConnectPeripheralOptionNotifyOnDisconnectionKey: NSNumber.init(value: true as Bool)]
        if (noke.peripheral != nil){
            cm.connect(noke.peripheral!, options: connectionOptions)
        }
    }
    
    /**
     Disconnects Noke Device from phone
     
     - Parameter noke: The Noke device from which to disconnect
     */
    public func disconnectNokeDevice(_ noke:NokeDevice){
        if((noke.peripheral) != nil){
            cm.cancelPeripheralConnection(noke.peripheral!)
        }
    }
    
    /// Allows NokeDeviceManager to discover devices that haven't been added to the device array
    public func setAllowAllNokeDevices(_ allow: Bool){
        allowAllNokeDevices = allow
    }
    
    /// MARK: Central Manager Delegate Methods
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        self.delegate?.bluetoothManagerDidUpdateState(state: NokeManagerBluetoothState.init(rawValue: central.state.rawValue)!)
    }
    
    public func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        debugPrint("CENTRAL MANAGER WILL RESTORE STATE")
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
            
            if(RSSI.intValue < rssiThreshold){
                return
            }
            
            devicesQueue.sync { [weak self] in
                guard let self = self else { return }
                var broadcastName : String? = advertisementData[CBAdvertisementDataLocalNameKey] as? String
                
                if self.firmwareScanning && (broadcastName?.contains("_FW") == true || broadcastName == "NOKE_2I") {
                guard let name = broadcastName else { return }
                    guard name == bootloaderName else {
                        print("Bootloader name: \(bootloaderName) did not match target device name: \(name). Ignoring broadcast")
                        return
                    }
                      let mac = "00:00:00:00:00:00"
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.removeNoke(mac: mac)
                        if let noke = NokeDevice(name: name, mac: mac) {
                            self.stopScan()
                            noke.version = "FIRMWAREUPDATE"
                            noke.name = name == "NOKE_2I" ? "N2I_FW" : name
                            noke.delegate = NokeDeviceManager.shared()
                            noke.peripheral = peripheral
                            noke.peripheral?.delegate = noke
                            self.connectToNokeDevice(noke)
                        }
                        return
                    }
                }
                
                if(broadcastName == nil || broadcastName?.count != 19){
                    if(peripheral.name != nil){
                        broadcastName = peripheral.name
                    }else{
                        return
                    }
                }
            
                if let devicename = broadcastName {
                    var mac = ""
                    if((devicename.contains("NOKE")) && devicename.count == 19){
                        let index = devicename.index((devicename.startIndex), offsetBy: 7)
                        mac = String(devicename[index...])
                        let endindex = mac.index(mac.startIndex, offsetBy:12)
                        mac = String(mac[..<endindex])
                        
                        let macWithColons = NSMutableString.init(string: mac)
                        macWithColons.insert(":", at: 2)
                        macWithColons.insert(":", at: 5)
                        macWithColons.insert(":", at: 8)
                        macWithColons.insert(":", at: 11)
                        macWithColons.insert(":", at: 14)
                        mac = macWithColons as String
                    }else{
                        mac = "??:??:??:??:??:??"
                    }
                    
                    var noke = self.nokeWithMac(mac)
                        if(noke == nil && self.allowAllNokeDevices){
                        noke = NokeDevice.init(name: broadcastName!, mac: mac)
                    }
                    
                    noke?.lastSeen = Date().timeIntervalSince1970
                    //noke?.RSSI = RSSI
                    noke?.addRSSIArray(rssi: RSSI)
                    
                    
                    if(noke != nil){
                        
                        noke?.delegate = NokeDeviceManager.shared()
                        noke?.peripheral = peripheral
                        noke?.peripheral?.delegate = noke
                        
                        let broadcastData = advertisementData[CBAdvertisementDataManufacturerDataKey]
                        
                        if(broadcastData != nil){
                            if let broadcastBytes = broadcastData as? Data{
                                var mutableBroadcastBytes = broadcastBytes
                                noke?.setVersion(data: broadcastBytes, deviceName: broadcastName ?? "Invalid Device")
                                
                                if(noke?.getHardwareVersion()?.contains(Constants.NOKE_HW_TYPE_HD_LOCK) ?? false){
                                    mutableBroadcastBytes.withUnsafeMutableBytes{(bytes: UnsafeMutablePointer<UInt8>)->Void in
                                        let lockStateBroadcast = (bytes[2] >> 5) & 0x01
                                        let lockStateBroadcast2 = (bytes[2] >> 6) & 0x01
                                        let lockState = lockStateBroadcast + lockStateBroadcast2
                                        noke?.lockState = NokeDeviceLockState(rawValue: Int(lockState))!
                                    }
                                }else if(self.isDoorController(noke: noke)){
                                    mutableBroadcastBytes.withUnsafeMutableBytes{(bytes: UnsafeMutablePointer<UInt8>)->Void in
                                        if noke != nil {
                                           if noke!.version.contains("4E") {
                                               let tmpLockState = Int((bytes[2] >> 5))
                                               //debugPrint("NokeDeviceManager -> centralManager -> didDiscover -> mac -> \(mac)");
                                               //debugPrint("NokeDeviceManager -> centralManager -> didDiscover -> tmpLockState -> \(tmpLockState)");
                                               if (tmpLockState == NokeDeviceLockState.nokeDeviceLockStateJammedLocking.rawValue) {
                                                   //debugPrint("NokeDeviceManager -> centralManager -> didDiscover -> onNokeJammedLocking");
                                                   noke?.lockState = NokeDeviceLockState.nokeDeviceLockStateUnlocked
                                                   self.delegate?.onNokeJammedLocking(noke: noke!)
                                               } else if (tmpLockState == NokeDeviceLockState.nokeDeviceLockStateJammedUnlocking.rawValue) {
                                                   //debugPrint("NokeDeviceManager -> centralManager -> didDiscover -> onNokeJammedUnlocking");
                                                   noke?.lockState = NokeDeviceLockState.nokeDeviceLockStateUnlocked
                                                   self.delegate?.onNokeJammedUnlocking(noke: noke!)
                                               }
                                           }
                                        }
                                        let lockStateBroadcast = (bytes[2] >> 5) & 0x01
                                        let lockStateBroadcast2 = (bytes[2] >> 6) & 0x01
                                        
                                        if let bData = broadcastData as? Data {
                                            noke?.canAutoUnlock = self.canAutoUnlock(manufacturerData: bData)
                                        } else {
                                            noke?.canAutoUnlock = false
                                        }
                                        
                                        let lockState = lockStateBroadcast + lockStateBroadcast2
                                        //debugPrint("NokeDeviceManager -> centralManager -> didDiscover -> lockStateBroadcast + lockStateBroadcast2 -> \(lockState)");
                                        if(lockState == 0){
                                            noke?.lockState = NokeDeviceLockState.nokeDeviceLockStateUnlocked
                                        }else{
                                            noke?.lockState = NokeDeviceLockState.nokeDeviceLockStateLocked
                                        }
                                    }
                                }
                                else if(noke?.getHardwareVersion()?.contains(Constants.NOKE_HW_TYPE_ULOCK) ?? false){
                                    mutableBroadcastBytes.withUnsafeMutableBytes{(bytes: UnsafeMutablePointer<UInt8>)->Void in
                                        let lockStateBroadcast = (bytes[2] >> 5) & 0x01
                                        let lockStateBroadcast2 = (bytes[2] >> 6) & 0x01
                                        let lockState = lockStateBroadcast + lockStateBroadcast2
                                        if(lockState == 0){
                                            noke?.lockState = NokeDeviceLockState.nokeDeviceLockStateUnlocked
                                        }else{
                                            noke?.lockState = NokeDeviceLockState.nokeDeviceLockStateLocked
                                        }
                                    }
                                }else{
                                    noke?.lockState = NokeDeviceLockState.nokeDeviceLockStateLocked
                                }
                            }
                            
                            noke?.connectionState = .Discovered
                            self.delegate?.nokeDeviceDidUpdateState(to: (noke?.connectionState)!, noke: noke!)
                        }
                    }
              }
           }
        }
    
    private func isDoorController(noke: NokeDevice?) -> Bool{
        return (noke?.getHardwareVersion()?.contains(Constants.NOKE_HW_TYPE_DOOR_CONTROLLER) ?? false || noke?.getHardwareVersion()?.contains(Constants.NOKE_HW_TYPE_THUNDERGUN) ?? false || noke?.getHardwareVersion()?.contains(Constants.NOKE_HW_TYPE_KEYPAD) ?? false)
    }
    
    private func canAutoUnlock(manufacturerData: Data) -> Bool{
        if(manufacturerData.count >= 7){
            let timeByte1 = manufacturerData[5]
            let timeByte2 = manufacturerData[6]
            
            let timeHexString = String(format:"%02X%02X", timeByte1, timeByte2)
            if(timeHexString == "0000"){
                return false
            }
            
            if(timeHexString == "0001"){
                return true
            }
            
            
            guard let lockTime = UInt64(timeHexString, radix: 16) else {return false}
            let currentUnitTime = NSDate().timeIntervalSince1970
            let currentUnitTimeHex = String(Int(currentUnitTime), radix: 16)

            let start = currentUnitTimeHex.index(currentUnitTimeHex.startIndex, offsetBy: 4)
            let end = currentUnitTimeHex.index(currentUnitTimeHex.startIndex, offsetBy: 8)
            let range = start..<end
            let currentTwoBytes = String(currentUnitTimeHex[range])

            guard let currentTime = UInt64(currentTwoBytes, radix: 16) else {return false}
            
            if(currentTime > lockTime){
                let diff = currentTime - lockTime
                if (diff > autounlockTimeSeconds){
                    return true
                }
            }
        }
      return false
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        print("failed to connect \(error)")
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let noke = self.nokeWithPeripheral(peripheral)
            if(noke == nil){
                return
            }
            
            noke?.delegate = NokeDeviceManager.shared()
            noke?.peripheral?.delegate = noke
            if self.firmwareScanning {
                self.firmwareScanning = false
                 noke?.peripheral?.discoverServices([NokeDevice.noke2iFirmwareUUID()])
            } else {
                 noke?.peripheral?.discoverServices([NokeDevice.nokeServiceUUID()])
            }
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let noke = self.nokeWithPeripheral(peripheral) else { return }
            noke.isDisconnectedDuringUnlock = true
            noke.connectionState = .Disconnected
            self.delegate?.nokeDeviceDidUpdateState(to: (noke.connectionState)!, noke: noke)
            self.uploadData()
            print("Did disconnect from \(noke.name)")
        }
    }
    
    /// MARK: Noke Device Delegate Methods
    internal func didSetSession(_ mac: String) {
        devicesQueue.sync { [weak self] in
            guard let self = self else { return }
            let noke = self.nokeWithMac(mac)
            noke?.connectionState = .Connected
            self.delegate?.nokeDeviceDidUpdateState(to: (noke?.connectionState)!, noke: noke!)
        }
    }
    
    internal func nokeReadyForFirmwareUpdate(noke: NokeDevice) {
         self.delegate?.nokeReadyForFirmwareUpdate(noke: noke)
    }
    
    
    /// MARK: Noke Device Dictionary Methods
    
    /**
     Adds Noke Device to dictionary of managed Noke Devices
     
     - Parameter noke: The noke device to be added
     */
    public func addNoke(_ noke: NokeDevice){
        self.insertNokeDevice(noke)
    }
    
    /**
     Inserts device into dictionary after checking for duplicates
     
     - Parameter noke: The noke device to be added
     */
    fileprivate func insertNokeDevice(_ noke:NokeDevice){
        devicesQueue.sync {
            let newnoke = self.nokeWithMac(noke.mac)
            if(newnoke == nil){
                nokeDevices[noke.mac] = noke
            }
        }
    }
    
    /**
     Removes device from nokeDevices dictionary
     
     - Parameter noke: The noke device to be removed
     */
    public func removeNoke(noke: NokeDevice){
        _ = devicesQueue.sync {
            self.nokeDevices.removeValue(forKey: noke.mac)
        }
    }
    
    /**
     Removes device from nokeDevices dictionary
     
     - Parameter mac: The mac address of the noke device to be removed
     */
    public func removeNoke(mac: String){
        print("REMOVING NOKE")
        _ = devicesQueue.sync {
            nokeDevices.removeValue(forKey: mac)
        }
    }
    
    //Removes all devices from nokeDevices dictionary
    public func removeAllNoke(){
        devicesQueue.sync {
            nokeDevices.removeAll()
        }
    }
    
    /**
     Gets a count of all the devices in the nokeDevice array
     
     - Returns: Count of devices as Int
     */
    public func getNokeCount()->Int{
        devicesQueue.sync {
            return nokeDevices.count
        }
        
    }
    
    /**
     Returns an array of all the devices in the nokeDevice array
     
     - Returns: Array of NokeDevice objects
     */
    public func getAllNoke()->Dictionary<String,NokeDevice>{
        devicesQueue.sync {
            return nokeDevices
        }
    }
    
    /**
     Gets noke device from dictionary with matching UUID
     
     - Parameters: UUID of intended Noke device
     
     - Returns: Noke device with requested UUID
     */
    public func nokeWithUUID(_ uuid: String)->NokeDevice?{
        devicesQueue.sync {
            let nokeArray = Array(nokeDevices.values)
            for noke: NokeDevice in nokeArray{
                if(noke.uuid == uuid){
                    return noke
                }
            }
            return nil
        }
        
    }
    
    /**
     Gets noke device from dictionary with matching MAC address
     
     - Parameters: MAC address of intended Noke device
     
     - Returns: Noke device with requested MAC address
     */
    public func nokeWithMac(_ mac: String)->NokeDevice?{
        if(!self.nokeDevices.isEmpty){
            return self.nokeDevices[mac]
        }else{
            return nil
        }
    }
    
    /**
     Gets noke device from array with matching peripheral
     
     - Parameters: Peripheral of intended Noke device
     
     - Returns: Noke device with requested peripheral
     */
    public func nokeWithPeripheral(_ peripheral:CBPeripheral)->NokeDevice?{
        devicesQueue.sync {
            let nokeArray = Array(nokeDevices.values)
            for noke:NokeDevice in nokeArray{
                if(noke.peripheral == peripheral){
                    return noke
                }
            }
            return nil
        }
    }
    
    /// Sets Mobile API Key for uploading logs to the Core API
    public func setAPIKey(_ apiKey: String){
        self.apiKey = apiKey
    }
    
    internal func getAPIKey()->String{
        return self.apiKey
    }
    
    /// Sets Upload URL for uploading Noke device responses to the Core API
    public func setLibraryMode(_ mode: NokeLibraryMode){
        switch mode {
        case NokeLibraryMode.SANDBOX:
            self.uploadUrl = ApiURL.sandboxUploadURL
            break
        case NokeLibraryMode.PRODUCTION:
            self.uploadUrl = ApiURL.productionUploadURL
            break
        case NokeLibraryMode.DEVELOP:
            self.uploadUrl = ApiURL.developUploadURL
        case NokeLibraryMode.OPEN:
            self.uploadUrl = ApiURL.openString
            break
        }
    }
    
    /// Saves upload packets to user defaults to ensure they're cached before uploading
    public func cacheUploadQueue(){
        UserDefaults.standard.set(globalUploadQueue, forKey:globalUploadDefaultsKey)
    }
    
    /// Loads upload packets from user defaults to be uploaded to server
    fileprivate func retrieveUploadQueue(){
        let cachedUploadQueue = UserDefaults.standard.object(forKey: globalUploadDefaultsKey) as? [Dictionary<String, Any>]
        for uploadObj:Dictionary<String,Any> in cachedUploadQueue!{
            self.globalUploadQueue.append(uploadObj)
        }
    }
    
    /**
     Bundles lock responses with the mac, timestamp, and session and then adds the object to the global upload queue
     
     - Parameters:
     - response: 40 char hex string response from Noke device
     - session: 40 char hex string read from the session characteristic of the Noke device when connecting
     - mac: MAC address of the Noke device
     */
    public func addUploadPacketToQueue(response: String, session: String, mac: String){
        let currentDateTime = Date.init()
        var responses = [String]()
        responses.append(response)
        
        for (index, value) in self.globalUploadQueue.enumerated(){
            let objSession = value["session"] as! String
            if(objSession == session){
                globalUploadQueue.remove(at:index)
                responses = value["responses"] as! [String]
                responses.append(response)
            }
        }
        var sessionPacket = [String: Any]()
        sessionPacket["session"] = session
        sessionPacket["responses"] = responses
        sessionPacket["mac"] = mac
        sessionPacket["received_time"] = Int64(currentDateTime.timeIntervalSince1970)
        globalUploadQueue.append(sessionPacket)
    }
    
    /// Clears all Noke device repsonses from the upload queue
    public func clearUploadQueue(){
        globalUploadQueue.removeAll()
    }
    
    /// Formats data and sends it to Noke Core API for parsing and storing
    public func uploadData(){
        if(self.globalUploadQueue.count > 0){
            if(uploadUrl != ApiURL.openString){
                var jsonBody = [String: Any]()
                jsonBody["logs"] = globalUploadQueue
                
                if(JSONSerialization.isValidJSONObject(jsonBody)){
                    guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonBody, options: JSONSerialization.WritingOptions.prettyPrinted) else{return}
                    NokeLibraryApiClient().doRequest(url: self.uploadUrl + API.UPLOAD, jsonData: jsonData) { [weak self] (data) in
                        guard let self = self else { return }
                        self.didReceiveUploadResponse(data: (data)!)
                    }
                }
            }else{
                var jsonBody = [String: Any]()
                jsonBody["data"] = globalUploadQueue
                uploadDelegate?.didReceiveUploadData(data: jsonBody)
            }
        }
    }
    
    
    /**
     Parses the response from the upload data endpoint
     
     - Parameters:
     - data: The JSON data received from the endpoint
     */
    internal func didReceiveUploadResponse(data: Data){
        let json = try? JSONSerialization.jsonObject(with: data, options: [])
        if let dictionary = json as? [String: Any] {
            let errorCode = dictionary["error_code"] as! Int
            let message = dictionary["message"] as! String
            if(errorCode == 0){
                self.clearUploadQueue()
                self.delegate?.didUploadData(result: errorCode, message: message)
            }
            else{
                let error = NokeDeviceManagerError(rawValue: errorCode)
                self.delegate?.nokeErrorDidOccur(error: error!, message: message, noke: nil)
            }
        }
    }
    
    internal func restoreDevice(noke : NokeDevice){
        noke.isRestoring = true;
    }
    
    
    /// Ensures the keys in the lock and keys on the server remain synced
    public func restoreKey(noke : NokeDevice){
        
        var jsonBody = [String: Any]()
        jsonBody["session"] = noke.session
        jsonBody["mac"] = noke.mac
        
        
        if(JSONSerialization.isValidJSONObject(jsonBody)){
            guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonBody, options: JSONSerialization.WritingOptions.prettyPrinted) else{return}
            NokeLibraryApiClient().doRequest(url: self.uploadUrl + API.RESTORE, jsonData: jsonData) { [weak self] (data) in
                guard let self = self else { return }
                self.didReceiveRestoreResponse(data: (data)!, noke: noke)
            }
        }
        
    }
    
    
    /**
     Parses the response from the restore key data endpoint
     
     - Parameters:
     - data: The JSON data received from the endpoint
     - noke: The device that is being restored
     */
    internal func didReceiveRestoreResponse(data: Data, noke: NokeDevice){
        let json = try? JSONSerialization.jsonObject(with: data, options: [])
        if let dictionary = json as? [String: Any] {
            let errorCode = dictionary["error_code"] as! Int
            if(errorCode == 0){
                let dataDict = dictionary["data"] as? [String: Any]
                let commandString = dataDict!["commands"] as! String
                noke.sendCommands(commandString)
            }
            else{
                noke.isRestoring = false
                let error = NokeDeviceManagerError(rawValue: errorCode)
                let message = dictionary["message"] as! String
                self.delegate?.nokeErrorDidOccur(error: error!, message: message, noke: nil)
            }
        }
    }
    
    
    /// Ensures the keys in the lock and keys on the server remain synced
    public func confirmRestore(noke : NokeDevice, commandid : Int){
        
        var jsonBody = [String: Any]()
        jsonBody["command_id"] = noke.session
        jsonBody["mac"] = noke.mac
        
        if(JSONSerialization.isValidJSONObject(jsonBody)){
            guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonBody, options: JSONSerialization.WritingOptions.prettyPrinted) else{return}
            NokeLibraryApiClient().doRequest(url: self.uploadUrl + API.CONFIRM_RESTORE, jsonData: jsonData) { [weak self] (data) in
                guard let self = self else { return }
                self.didReceiveConfirmResponse(data: (data)!, noke: noke)
            }
        }
    }
    
    
    /**
     Parses the response from the confirm restore data endpoint
     
     - Parameters:
     - data: The JSON data received from the endpoint
     */
    internal func didReceiveConfirmResponse(data: Data, noke: NokeDevice){
        let json = try? JSONSerialization.jsonObject(with: data, options: [])
        if let dictionary = json as? [String: Any] {
            let errorCode = dictionary["error_code"] as! Int
            let message = dictionary["message"] as! String
            if(errorCode == 0){
                self.delegate?.didUploadData(result: errorCode, message: "Restore Successful: " + message)
            }
            else{
                noke.isRestoring = false
                let error = NokeDeviceManagerError(rawValue: errorCode)
                self.delegate?.nokeErrorDidOccur(error: error!, message: message, noke: nil)
            }
        }
    }
    
    public func setTargetFirmwareDevice(bootloaderName: String) {
        self.bootloaderName = bootloaderName
    }
    
    
}
