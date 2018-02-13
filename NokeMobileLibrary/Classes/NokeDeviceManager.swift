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
    case nokeDeviceConnectionStateDisconnected = 0
    case nokeDeviceConnectionStateDiscovered = 1
    case nokeDeviceConnectionStateConnecting = 2
    case nokeDeviceConnectionStateConnected = 3
    case nokeDeviceConnectionStateSyncing = 4
    case nokeDeviceConnectionStateUnlocked = 5
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
public protocol NokeDeviceManagerDelegate
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
    func nokeDeviceDidUpdateState(to state: NokeDeviceConnectionState, noke: NokeDevice)
    
    /**
      Called when the Noke Mobile library encounters an error. Please see error types for possible errors
 
     - Parameters:
        - error: The NokeDeviceManagerError that was thrown
        - message: English description of error
        - noke: Device associated with the error if applicable
     */
    func nokeErrorDidOccur(error: NokeDeviceManagerError, message: String, noke: NokeDevice?)
    
    func bluetoothManagerDidUpdateState(state: NokeManagerBluetoothState)
}

/// Manages bluetooth interactions with Noke Devices
public class NokeDeviceManager: NSObject, CBCentralManagerDelegate, NokeDeviceDelegate
{
    /// Key for saving noke devices to user defaults
    let nokeDevicesDefaultsKey = "noke-mobile-devices"
    
    /// Key for saving upload packets to user defaults
    let globalUploadDefaultsKey = "noke-mobile-upload-queue"
    
    /// URL string for uploading data
    public var uploadUrl = "https://lock-api-dev.appspot.com/upload/"
    
    /// URL string for fetching unlock commands
    public var unlockUrl: String = ""
    
    /// Delegate for NokeDeviceManager, calls protocol methods
    public var delegate: NokeDeviceManagerDelegate?
    
    /// Array of Noke devices managed by the NokeDeviceManager
    var nokeDevices = [NokeDevice]()
    
    /// Queue of responses from lock ready to be uploaded
    fileprivate var globalUploadQueue = [Dictionary<String,Any>]()

    /// API Key used for upload data endpoint
    fileprivate var apiKey: String = ""
    
    /// CBCentralManager
    lazy var cm: CBCentralManager = CBCentralManager(delegate: self, queue:nil)
    
    /// Shared instance of NokeDeviceManager
    static var sharedNokeDeviceManager: NokeDeviceManager?
    
    /**
     Initializes a new NokeDeviceManager
     - Returns: NokeDeviceManager
    */
    override init(){
        super.init()
        cm = CBCentralManager.init(delegate: self, queue: nil)
    }
    
    /**
     Used for getting the shared instance of NokeDeviceManager
     - Returns: Shared instance of NokeDeviceManager
    */
    public static func shared()->NokeDeviceManager{
        if(sharedNokeDeviceManager == nil){
            sharedNokeDeviceManager = NokeDeviceManager.init()
        }
        return sharedNokeDeviceManager!
    }
    
    /// Begins bluetooth scanning for Noke Devices that have been added to the device array
    public func startScanForNokeDevices(){
        let scanOptions : [String:AnyObject] = [CBCentralManagerScanOptionAllowDuplicatesKey: NSNumber.init(value: true as Bool)]
        let serviceArray = [CBUUID]([NokeDevice.nokeServiceUUID()])
        
        //Make sure we start scan from scratch
        cm.stopScan()
        
        cm.scanForPeripherals(withServices: serviceArray, options: scanOptions)
    }
    
    /// Stops bluetooth scanning
    public func stopScan(){
        cm.stopScan()
    }
    
    /**
     Initializes connection to Noke Device
     
     - Parameter noke: The Noke device for the connection
     */
    public func connectToNokeDevice(_ noke:NokeDevice){
        self.insertNokeDevice(noke)
        let connectionOptions : [String: AnyObject] = [CBConnectPeripheralOptionNotifyOnDisconnectionKey: NSNumber.init(value: true as Bool)]
        cm.connect(noke.peripheral!, options: connectionOptions)
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
    
    /// MARK: Central Manager Delegate Methods
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        self.delegate?.bluetoothManagerDidUpdateState(state: NokeManagerBluetoothState.init(rawValue: central.state.rawValue)!)        
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        
        var broadcastName : String? = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        if(broadcastName == nil || broadcastName?.count != 19){
            broadcastName = peripheral.name!
        }
        
        let devicename : String = broadcastName!
        
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
        
        let noke = self.nokeWithMac(mac)
        if(noke != nil){
            
            noke?.delegate = NokeDeviceManager.shared()
            noke?.peripheral = peripheral
            noke?.peripheral?.delegate = noke
            
            let broadcastData = advertisementData[CBAdvertisementDataManufacturerDataKey]
            if(broadcastData != nil){
                let hardwareVersion = peripheral.name
                noke?.version = hardwareVersion!
            }
            noke?.connectionState = .nokeDeviceConnectionStateDiscovered
            self.delegate?.nokeDeviceDidUpdateState(to: (noke?.connectionState)!, noke: noke!)
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let noke = self.nokeWithPeripheral(peripheral)
        if(noke == nil){
            return
        }
        
        noke?.delegate = NokeDeviceManager.shared()
        noke?.peripheral?.delegate = noke
        noke?.peripheral?.discoverServices([NokeDevice.nokeServiceUUID()])
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let noke = self.nokeWithPeripheral(peripheral)
        if(noke == nil){
            return
        }
        noke?.connectionState = .nokeDeviceConnectionStateDisconnected
        delegate?.nokeDeviceDidUpdateState(to: (noke?.connectionState)!, noke: noke!)
        self.uploadData()
    }
    
    /// MARK: Noke Device Delegate Methods    
    internal func didSetSession(_ mac: String) {
        let noke = self.nokeWithMac(mac)
        noke?.connectionState = .nokeDeviceConnectionStateConnected
        self.delegate?.nokeDeviceDidUpdateState(to: (noke?.connectionState)!, noke: noke!)
    }
    
    
    /// MARK: Noke Device Array Methods
    
    /**
     Adds Noke Device to array of managed Noke Devices
 
     Parameter noke: The noke device to be added
     */
    public func addNoke(_ noke: NokeDevice){
        self.insertNokeDevice(noke)
        self.saveNokeDevices()
    }
    
    /**
     Inserts device into array after checking for duplicates
     
     Parameter noke: The noke device to be added
    */
    fileprivate func insertNokeDevice(_ noke:NokeDevice){
        let newnoke = self.nokeWithMac(noke.mac)
        if(newnoke == nil){
            nokeDevices.append(noke)
        }
    }
    
    /**
     Gets noke device from array with matching UUID
    
     - Parameters: UUID of intended Noke device
     
     - Returns: Noke device with requested UUID
     */
    public func nokeWithUUID(_ uuid: String)->NokeDevice?{
        for noke: NokeDevice in self.nokeDevices{
            if(noke.uuid == uuid){
                return noke
            }
        }
        return nil
    }
    
    /**
     Gets noke device from array with matching MAC address
     
     - Parameters: MAC address of intended Noke device
     
     - Returns: Noke device with requested MAC address
     */
    public func nokeWithMac(_ mac: String)->NokeDevice?{
        for noke: NokeDevice in self.nokeDevices{
            if(noke.mac == mac){
                return noke
            }
        }
        return nil
    }
    
    /**
     Gets noke device from array with matching peripheral
     
     - Parameters: Peripheral of intended Noke device
     
     - Returns: Noke device with requested peripheral
     */
    public func nokeWithPeripheral(_ peripheral:CBPeripheral)->NokeDevice?{
        for noke:NokeDevice in self.nokeDevices{
            if(noke.peripheral == peripheral){
                return noke
            }
        }
        return nil
    }
    
    
    /// Saves noke devices to user defaults for offline access
    public func saveNokeDevices(){
        var encodedNokeDevices = [Data]()
        for noke:NokeDevice in self.nokeDevices{
            let encodedNoke = NSKeyedArchiver.archivedData(withRootObject: noke)
            encodedNokeDevices.append(encodedNoke)
        }
        debugPrint(encodedNokeDevices.count)
        UserDefaults.standard.set(encodedNokeDevices, forKey: nokeDevicesDefaultsKey)
    }
    

    /// Loads noke devices from user defaults
    public func loadNokeDevices(){
        let cachedNokeDevices = UserDefaults.standard.object(forKey: nokeDevicesDefaultsKey) as? [Data]
        for encodedNoke:Data in cachedNokeDevices!{
            let noke = NSKeyedUnarchiver.unarchiveObject(with: encodedNoke) as? NokeDevice
            self.insertNokeDevice(noke!)
        }
        debugPrint(self.nokeDevices.count)
    }
    
    /// Sets Mobile API Key for uploading logs to the Core API
    public func setAPIKey(_ apiKey: String){
        self.apiKey = apiKey
    }
    
    /// Sets Upload URL for uploading Noke device responses to the Core API
    public func changeDefaultUploadUrl(_ newUploadURL: String){
        self.uploadUrl = newUploadURL
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
            var jsonBody = [String: Any]()
            jsonBody["logs"] = globalUploadQueue
            
            if(JSONSerialization.isValidJSONObject(jsonBody)){
                guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonBody, options: JSONSerialization.WritingOptions.prettyPrinted) else{return}
                self.doRequest(url: self.uploadUrl, jsonData: jsonData)
            }
        }
    }
    
    /**
     Makes a web request to the Noke Core API
     
     - Parameters:
     - url: The url for the web request
     - data: The JSON data to send
     */
    internal func doRequest(url: String, jsonData: Data){
        
        var request = URLRequest(url: URL.init(string: url)!)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        
        let task = URLSession.shared.dataTask(with: request){data, response, error in
            guard let data = data, error == nil else{
                print("error=\(String(describing: error))")
                return
            }
            
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200{
                print("statusCode should be 200, but is \(httpStatus.statusCode)")
                print("response = \(String(describing: response))")
            }
            
            let responseString = String(data: data, encoding: .utf8)
            print(responseString!)
            self.didReceiveUploadResponse(data: data)
        }
        
        task.resume()
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
            if(errorCode == 0){
                self.clearUploadQueue()
            }
            else{
                let error = NokeDeviceManagerError(rawValue: errorCode)
                let message = dictionary["message"] as! String
                self.delegate?.nokeErrorDidOccur(error: error!, message: message, noke: nil)
            }
        }
    }
}
