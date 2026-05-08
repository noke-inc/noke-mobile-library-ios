//
//  NokeDevice+Encryption.swift
//  Pods
//
//  Created by Joffrey Mann on 2/17/26.
//

import Foundation
import CoreBluetooth

extension NokeDevice {
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
            let byteString = (hexstring as NSString).substring(with: match!.range)
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
    public func offlineUnlock(key: String, command: String, addTimestamp: Bool? = true) -> String{
        self.offlineKey = key
        self.unlockCmd = command
        return self.offlineUnlock(addTimestamp: addTimestamp)
    }
    
    /**
     Unlocks the lock using the offline key and the unlock command.  If the keys and commands have been set, no internet connection is required.
     */
    public func offlineUnlock(addTimestamp: Bool? = true) -> String {
        if(offlineKey.count == Constants.OFFLINE_KEY_LENGTH && unlockCmd.count == Constants.OFFLINE_COMMAND_LENGTH){
            var keydata = Data(capacity: offlineKey.count/2)
            let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
            regex.enumerateMatches(in: offlineKey, options: [], range: NSMakeRange(0, offlineKey.count)) { match, flags, stop in
                let byteString = (offlineKey as NSString).substring(with: match!.range)
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
            let finalCmdD = self.bytesToString(data: finalCmdData, start: 0, length: 20)
            self.addCommandToCommandArray(finalCmdData)
            self.writeCommandArray()
            return String.init(timeStamp)
        }else{
            NokeDeviceManager.shared().delegate?.nokeErrorDidOccur(error: NokeDeviceManagerError.nokeLibraryErrorInvalidOfflineKey, message: "Offline Key/Command is not a valid length", noke: self)
            return ""
        }
    }
    
    /**
     Makes the necessary checks and then requests the unlock commands from the server (or generates the unlock command if offline)
     This method is also responsible for sending the command to the lock after it's received
     Before unlocking, please check:
     - unlock URL is set on the NokeDeviceManager
     - unlock endpoint has been properly implemented on server
     - Noke Device is provided with valid offline key and command (if unlocking offline)
     - A internet connection is present (if unlocking online)
     
     NOTE: This method has been moved to NokeDevice.swift as unlock(context:onSuccess:onFailure:)
     using the Strategy pattern. Use that method instead.
     */
        
    public func hexEncodedString(data: Data) -> String {
        return String(data.reduce(into: "".unicodeScalars, { (result, value) in
            result.append(hexAlphabet[Int(value/16)])
            result.append(hexAlphabet[Int(value%16)])
        }))
    }
    
    /**
     Called when the phone receives data from the Noke device.  There are two main types of data packets:
     - Server packets: Encrypted responses from the locks that are parsed by the server. Can include logs, keys, and quick-click confirmations
     - App packets: Unencrypted responses that indicate whether command succeeded or failed.
     
     - Parameter data: 20 byte response from the lock
     */
    func receivedDataFromLock(_ data: Data?) {
        // Ensure data is non-nil and contains valid content
        guard let data = data, !data.isEmpty else {
            print("NokeDevice -> receivedDataFromLock -> Error: Received empty or nil data.")
            return
        }
        
        let strongSelf = self
        
        data.withUnsafeBytes { rawBufferPointer in
            guard let baseAddress = rawBufferPointer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                print("NokeDevice -> receivedDataFromLock -> Error: Unable to obtain a valid memory buffer.")
                return
            }
            
            guard data.count > 0 else {
                print("NokeDevice -> receivedDataFromLock -> Error: Data size too small for expected structure.")
                return
            }
            
            let destByte = Int(baseAddress[0])
            
            print("NokeDevice -> receivedDataFromLock -> byte0 \(destByte)")
            print("NokeDevice -> receivedDataFromLock -> hexEncodedString(data: data) \(hexEncodedString(data: data))")
            
            guard data.count >= 20 else {
                print("NokeDevice -> receivedDataFromLock -> Error: Data size too small for expected structure.")
                return
            }
            
            guard let localSession = strongSelf.session else {
                print("NokeDevice -> receivedDataFromLock -> Error: No session active.")
                return
            }
            
            switch destByte {
            case Constants.SERVER_Dest:
                NokeDeviceManager.shared().addUploadPacketToQueue(
                    response: self.bytesToString(data: data, start: 0, length: 20),
                    session: localSession,
                    mac: self.mac)
                break
            case Constants.APP_Dest:
                
                let resultByte = Int(data[1])
                switch resultByte{
                case Constants.SUCCESS_ResultType:
                    let dataType = Int(data[4])
                    if(dataType == Constants.DIAGNOSTIC_PacketType) {
                        print("GOT DIAGNOSTIC PACKET!")
                        NokeDeviceManager.shared().delegate?.nokeDeviceDidSendDiagnostics(data: parseDiagnosticPacket(data: data), noke: strongSelf)
                    }else{
                        if(isRestoring) {
                            let commandid = Int(data[2])
                            commandArray.removeAll()
                            NokeDeviceManager.shared().clearUploadQueue()
                            strongSelf.isRestoring = false
                            NokeDeviceManager.shared().confirmRestore(noke: strongSelf, commandid: commandid)
                            NokeDeviceManager.shared().disconnectNokeDevice(strongSelf)
                        } else {
                            NokeDeviceManager.shared().delegate?.successPacketReceived(noke: self)
                            strongSelf.moveToNext()
                            if let commandArray = strongSelf.commandArray, strongSelf.commandArray.count == 0 {
                                if strongSelf.getHardwareVersion() == "4E" {
                                    print("NokeDevice -> receivedDataFromLock -> lockState = \(strongSelf.lockState)");
                                    callJammedDelegate = true;
                                }
                                strongSelf.lockState = NokeDeviceLockState.nokeDeviceLockStateUnlocked
                                strongSelf.connectionState = NokeDeviceConnectionState.Unlocked
                                if let connectionState = strongSelf.connectionState {
                                    NokeDeviceManager.shared().delegate?.nokeDeviceDidUpdateState(to: connectionState, noke: strongSelf)
                                }
                            }
                        }
                    }
                    break
                case Constants.INVALIDKEY_ResultType:
                    NokeDeviceManager.shared().delegate?.nokeErrorDidOccur(error: NokeDeviceManagerError.nokeDeviceErrorInvalidKey, message: "Invalid Key Result", noke: strongSelf)
                    strongSelf.clearCommandArray()
                    //self.moveToNext()
                    //                        if(self.commandArray.count == 0){
                    //                            if(!isRestoring){
                    //                                NokeDeviceManager.shared().restoreDevice(noke: self)
                    //                            }
                    //                        }
                    break
                case Constants.INVALIDCMD_ResultType:
                    NokeDeviceManager.shared().delegate?.nokeErrorDidOccur(error: NokeDeviceManagerError.nokeDeviceErrorInvalidCmd, message: "Invalid Command Result", noke: strongSelf)
                    strongSelf.moveToNext()
                    break
                case Constants.INVALIDPERMISSION_ResultType:
                    NokeDeviceManager.shared().delegate?.nokeErrorDidOccur(error: NokeDeviceManagerError.nokeDeviceErrorInvalidPermission, message: "Invalid Permission (wrong key) Result", noke: self)
                    strongSelf.moveToNext()
                    break
                case Constants.SHUTDOWN_ResultType:
                    self.clearCommandArray()
                    let lockStateByte = Int32(data[2])
                    var isLocked = true
                    switch(lockStateByte) {
                    case -1:
                        strongSelf.lockState = NokeDeviceLockState.nokeDeviceLockStateUnknown
                        debugPrint("receivedDataFromLock -> lockStateByte -> Unknown (locked)")
                        break
                    case 0:
                        strongSelf.lockState = NokeDeviceLockState.nokeDeviceLockStateUnlocked
                        debugPrint("receivedDataFromLock -> lockStateByte -> Unlocked")
                        isLocked = false
                        break
                    case 1:
                        strongSelf.lockState = NokeDeviceLockState.nokeDeviceLockStateUnshackled
                        debugPrint("receivedDataFromLock -> lockStateByte -> Unshackled (unlocked)")
                        isLocked = false
                        break
                    case 2:
                        strongSelf.lockState = NokeDeviceLockState.nokeDeviceLockStateLocked
                        debugPrint("receivedDataFromLock -> lockStateByte -> Locked")
                        break
                    case 3:
                        strongSelf.lockState = NokeDeviceLockState.nokeDeviceLockStateJammedUnlocking
                        debugPrint("receivedDataFromLock -> lockStateByte -> JammedUnlocking (locked)")
                        isLocked = false
                        break
                    case 4:
                        strongSelf.lockState = NokeDeviceLockState.nokeDeviceLockStateJammedLocking
                        debugPrint("receivedDataFromLock -> lockStateByte -> JammedLocking (unlocked)")
                        isLocked = false
                        break
                    default: strongSelf.lockState = NokeDeviceLockState.nokeDeviceLockStateUnknown
                        debugPrint("receivedDataFromLock -> lockStateByte -> default state -> (locked)")
                    }
                    
                    let timeoutStateByte = Int32(data[3])
                    var didTimeout = true
                    if(timeoutStateByte == 1){
                        didTimeout = false
                    }
                    NokeDeviceManager.shared().delegate?.nokeDeviceDidShutdown(noke: strongSelf, isLocked: isLocked, didTimeout: didTimeout)
                    break
                case Constants.INVALIDDATA_ResultType:
                    NokeDeviceManager.shared().delegate?.nokeErrorDidOccur(error: NokeDeviceManagerError.nokeDeviceErrorInvalidData, message: "Invalid Data Result", noke: strongSelf)
                    strongSelf.moveToNext()
                    break
                case Constants.FREEEXIT_ResultType:
                    NokeDeviceManager.shared().delegate?.nokeErrorDidOccur(error: NokeDeviceManagerError.nokeDeviceErrorFreeExit, message: "Free Exit Message", noke: strongSelf)
                    strongSelf.moveToNext()
                    break
                case Constants.FAILEDTOLOCK_ResultType:
                    NokeDeviceManager.shared().delegate?.nokeErrorDidOccur(error: NokeDeviceManagerError.nokeDeviceErrorInvalidData, message: "Failed To Lock", noke: strongSelf)
                    break
                case Constants.FAILEDTOUNLOCK_ResultType:
                    NokeDeviceManager.shared().delegate?.nokeErrorDidOccur(error: NokeDeviceManagerError.nokeDeviceErrorInvalidData, message: "Failed To Unlock", noke: strongSelf)
                    break
                case Constants.FAILEDTOUNSHACKLE_ResultType:
                    NokeDeviceManager.shared().delegate?.nokeErrorDidOccur(error: NokeDeviceManagerError.nokeDeviceErrorInvalidData, message: "Failed To Unshackle", noke: strongSelf)
                    break
                case Constants.INVALID_ResultType:
                    NokeDeviceManager.shared().delegate?.nokeErrorDidOccur(error: NokeDeviceManagerError.nokeDeviceErrorInvalidResult, message: "Invalid Result", noke: strongSelf)
                    strongSelf.moveToNext()
                    break
                case Constants.OUTOFSCHEDULEUNLOCK_ResultType:
                    NokeDeviceManager.shared().delegate?.nokeErrorDidOccur(error: NokeDeviceManagerError.nokeDeviceErrorOutOfScheduleUnlock, message: "Out Of Schedule Unlock", noke: strongSelf)
                    strongSelf.moveToNext()
                    break
                default:
                    NokeDeviceManager.shared().delegate?.nokeErrorDidOccur(error: NokeDeviceManagerError.nokeDeviceErrorUnknown, message: "Unable to recognize result", noke: strongSelf)
                    strongSelf.moveToNext()
                    break
                }
                break
                
            case Constants.INVALID_ResponseType:
                NokeDeviceManager.shared().delegate?.nokeErrorDidOccur(error: NokeDeviceManagerError.nokeDeviceErrorInvalidResult, message: "Invalid packet received", noke: strongSelf)
                break
            default:
                break
            }
        }
    }
    
    // Helper function for success packet processing
    private func processSuccessPacket(_ data: Data) {
        if isRestoring {
            commandArray.removeAll()
            NokeDeviceManager.shared().clearUploadQueue()
            isRestoring = false
        } else {
            NokeDeviceManager.shared().delegate?.successPacketReceived(noke: self)
            moveToNext()
        }
    }
    
    // Helper function for error handling
    private func handleError(_ error: NokeDeviceManagerError, message: String) {
        NokeDeviceManager.shared().delegate?.nokeErrorDidOccur(error: error, message: message, noke: self)
        moveToNext()
    }
    
    
    func parseDiagnosticPacket(data: Data) -> [String:Any]{
        var diagnostics:[String:Any] = [:]
        let lockStateByte = Int(data[5])
        switch lockStateByte {
        case Constants.LockStateLocked:
            diagnostics["lockState"] = "state_locked"
        case Constants.LockStateUnshackled:
            diagnostics["lockState"] = "state_unshackled"
        case Constants.LockStateUnlocked:
            diagnostics["lockState"] = "state_unlocked"
        case Constants.LockStateJammedWhileUnlocking:
            diagnostics["lockState"] = "state_jammed_while_unlocking"
        case Constants.LockStateJammedWhileLocking:
            diagnostics["lockState"] = "state_jammed_while_locking"
        default:
            diagnostics["lockState"] = "state_unknown"
        }
        
        let ledStateByte = Int(data[6])
        switch ledStateByte {
        case Constants.OffLED:
            diagnostics["ledState"] = "off"
        case Constants.RedLED:
            diagnostics["ledState"] = "red"
        case Constants.GreenLED:
            diagnostics["ledState"] = "green"
        default:
            diagnostics["ledState"] = "unknown"
        }
        
        let touchSensorState = Int(data[7])
        switch touchSensorState {
        case Constants.Touched:
            diagnostics["touchSensorState"] = "touched"
        case Constants.NotTouched:
            diagnostics["touchSensorState"] = "notTouched"
        default:
            diagnostics["touchSensorState"] = "unknown"
        }
        
        diagnostics["temperature"] = Int(data[8])
        
        let batteryVoltageArray : [UInt8] = [data[10], data[9]]
        var batteryVoltage : Int = 0
        for byte in batteryVoltageArray {
            batteryVoltage = batteryVoltage << 8
            batteryVoltage = batteryVoltage | Int(byte)
        }
        
        
        diagnostics["batteryVoltage"] = batteryVoltage
        
        let wiredVoltageArray : [UInt8] = [data[12],data[11]]
        var wiredVoltage : Int = 0
        for byte in wiredVoltageArray {
            wiredVoltage = wiredVoltage << 8
            wiredVoltage = wiredVoltage | Int(byte)
        }
        diagnostics["wiredVoltage"] = wiredVoltage
        
        diagnostics["interiorMotion"] = Int(data[13])
        
        diagnostics["exteriorMotion"] = Int(data[14])
        
        diagnostics["batteryChargingControl"] = Int(data[15])
        
        diagnostics["batteryChargingStatus"] = Int(data[16])
        
        
        return diagnostics
        
    }
    
    
    /// Moves to next command in the command array in preperation to sending
    func moveToNext(){
        guard var commands = self.commandArray, !commands.isEmpty else { return }
        
        commands.remove(at: 0)
        self.commandArray = commands
        
        if !commands.isEmpty {
            writeCommandArray()
        }
    }
    
    /**
     Clears command array. This helps to prevent invalid commands from being sent to the lock and causing errors
     */
    internal func clearCommandArray(){
        if(commandArray == nil){
            commandArray = Array<Data>()
        }else{
            commandArray.removeAll()
        }
    }
    
    /**
     Adds encrypted command to array to be sent to Noke device
     
     - Parameter data: 20 byte command to be sent to the lock
     */
    internal func addCommandToCommandArray(_ data: Data){
        if(commandArray == nil){
            commandArray = Array<Data>()
        }
        commandArray.append(data)
    }
    
    /// Sends command from the first position of the command array to the Noke device via bluetooth
    internal func writeCommandArray(){
        if(self.txCharacteristic?.properties != nil){
            let cmdData = commandArray.first
            self.peripheral?.writeValue(cmdData!, for:self.txCharacteristic!, type: CBCharacteristicWriteType.withResponse)
        }else{
            debugPrint("No write property on TX characteristic")
        }
    }
    
    /// Reads the session characteristic
    func readSessionCharacteristic(){
        self.peripheral?.readValue(for: self.sessionCharacteristic!)
    }
    
    public func getUnlockCmd() -> String {
        return unlockCmd
    }
    
    public func getOfflineKey() -> String {
        return offlineKey
    }
}
