//
//  ViewController.swift
//  NokeMobileLibrary
//
//  Created by Spencer Apsley on 02/09/2018.
//  Copyright © 2018 Nokē Inc. All rights reserved.
//

import UIKit
import NokeMobileLibrary

class ViewController: UIViewController, NokeDeviceManagerDelegate, DemoWebClientDelegate {    
    
    var currentNoke : NokeDevice?
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Setup device manager
        NokeDeviceManager.shared().delegate = self
        
        //Add locks to device manager
        let macs = [ "C6:71:A0:1B:F5:CC",
                     "F1:F3:74:C2:9D:CB",
                     "E5:1C:A0:4D:F5:10",
                     "CF:B9:4C:98:3C:D9",
                     "C9:09:07:9D:57:0D",
                     "E7:33:D3:0F:EC:DB",
                     "C2:B5:0E:A9:F4:4F",
                     "CE:3F:33:7D:5C:1E",
                     "EC:66:FA:4B:AE:9F",
                     "D0:E4:09:17:AF:EE",
                     "E6:7A:81:0B:46:BC",
                     "FD:64:95:88:F8:45",
                     "E6:EC:EB:43:B4:AE",
                     "CD:4B:CB:5C:3C:EE",
                     "D4:F0:58:53:CB:E7",
                     "F9:1D:DC:ED:6F:D5",
                     "D7:60:D1:C8:A2:F3",
                     "FC:6B:8B:FA:B9:30",
                     "C7:F3:0B:CC:2B:2D",
                     "DD:15:C8:2E:86:87",
                     "D5:0B:A2:29:6C:84",
                     "C1:8E:47:9C:37:C0",
                     "EB:D9:E9:E8:4E:13",
                     "CA:99:01:DD:DB:0D",
                     "C7:6D:B1:F3:0A:3E",
                     "C1:C2:5D:97:27:35",
                     "FA:A6:D7:40:E3:42",
                     "C3:B7:38:49:D1:CB",
                     "D4:9C:69:A6:B9:F0",
                     "E8:B7:B2:20:72:1D",
                     "D6:9B:48:CC:AC:D3",
                     "CB:EB:51:F7:EF:83",
                     "C1:B7:84:C5:2E:DF",
                     "C8:A9:F9:CC:A7:D3",
                     "F3:87:02:AA:70:C8",
                     "F8:B2:8B:01:DC:F6",
                     "CA:A9:49:D9:7E:D4",
                     "F1:A3:94:92:2C:5F",
                     "EB:67:99:9B:08:C1",
                     "F6:39:E3:A6:DE:74",
                     "C5:16:16:D0:6A:45",
                     "CA:22:A5:F7:AB:08",
                     "C4:BD:0F:96:16:B7",
                     "E9:76:95:59:31:9F",
                     "E0:20:75:54:3C:B9",
                     "EB:07:29:54:8A:47",
                     "FC:74:B7:92:E1:68",
                     "D1:B2:D6:FB:AF:62",
                     "C2:CD:B5:24:04:83",
                     "D3:69:AE:D0:5F:1E",
                     "D0:6D:DC:01:A0:6E",
                     "C8:45:79:4C:6A:D3",
                     "D8:6D:77:CA:AB:86",
                     "C2:EB:DB:92:09:20",
                     "CC:83:C0:E0:7B:3F",
                     "F8:87:9D:59:65:6A",
                     "C0:80:93:78:06:54",
                     "E6:18:CC:0B:30:DA",
                     "CB:F2:C7:09:79:14",
                     "F4:5E:80:F7:F0:07",
                     "FA:0E:92:6A:29:5F",
                     "E3:39:63:1D:A7:A1",
                     "F4:CD:A8:55:3E:36",
                     "C0:58:FD:0C:4E:0E",
                     "D1:9C:0A:C3:68:4A",
                     "CC:6F:03:1A:8F:F0",
                     "C7:9D:FD:52:1B:20",
                     "D1:0B:DF:DC:EC:54",
                     "F3:C4:0D:54:33:B3",
                     "D2:58:6F:B8:B6:E1",
                     "C3:F6:AA:56:7A:30",
                     "C9:66:B0:76:24:C6",
                     "E4:61:B7:EF:EF:E3",
                     "F3:0B:B3:9D:0C:52",
                     "CD:4E:44:05:11:68",
                     "CB:66:7F:18:C3:6D",
                     "C5:8A:83:9D:8B:47",
                     "CD:69:20:D4:D1:84",
                     "C7:E4:65:EA:4E:B0",
                     "C0:0B:69:80:9E:A9",
                     "E5:B8:98:E8:3D:3C",
                     "C0:AB:A4:AA:54:AC",
                     "CF:B0:EB:80:3A:B2",
                     "DE:D2:05:5C:E1:4C",
                     "D9:D8:D7:FD:EB:E0",
                     "DC:88:0B:79:0C:2A",
                     "DF:B1:3E:01:CA:C3",
                     "EE:F2:B2:C9:0A:53",
                     "EC:7C:25:99:E1:3C",
                     "F8:EE:59:CF:37:BA",
                     "FE:FD:A6:F7:67:4D",
                     "D7:04:8F:41:B8:4C",
                     "C7:A6:1C:75:B6:D3",
                     "F5:4E:68:29:C3:95",
                     "EE:59:83:45:C6:CC",
                     "CF:53:80:10:74:44",
                     "EF:59:2A:C5:40:77",
                     "C3:10:0F:73:8B:2C",
                     "DD:DC:FD:04:71:C6",
                     "D0:B3:08:81:33:B6",
                     "D5:0A:88:1A:38:1E",
                     "FA:B5:04:B8:68:38",
                     "D4:25:DC:E0:D4:5B",
                     "E4:70:96:06:48:A7",
                     "C2:96:3B:FD:9B:8B",
                     "C8:44:49:8D:75:B8",
                     "F7:FE:C8:E3:BA:C5",
                     "F4:6C:48:75:04:8F",
                     "EA:55:23:4C:92:36",
                     "D6:E1:E6:4A:0C:62",
                     "CE:87:9E:B9:38:12",
                     "C7:35:3C:1D:D4:34",
                     "E0:1B:AF:B8:65:E1",
                     "D5:CD:FB:6B:C5:EA",
                     "F4:C6:6A:68:C2:78",
                     "DE:9F:A5:27:2A:5E",
                     "FB:F5:FD:7A:5A:50",
                     "EA:82:9F:35:6C:02",
                     "D1:B1:78:3F:05:B4",
                     "C5:D1:3A:BE:7E:1F",
                     "C3:F7:11:EE:84:08",
                     "D1:27:04:5C:CE:F3",
                     "F0:FA:11:F4:6E:07",
                     "E2:DF:05:F9:C7:9E",
                     "D7:DF:FE:41:69:8E",
                     "F0:B3:B1:9E:33:12",
                     "CC:0E:27:17:10:C2",
                     "F8:74:35:BC:DE:EF",
                     "F0:B2:BC:FC:CB:3C",
                     "C8:B0:3C:CB:D6:14",
                     "E1:63:82:10:E1:E9",
                     "ED:9B:B4:5A:11:10",
                     "D1:20:2D:E8:D7:56",
                     "CA:65:50:3F:47:25",
                     "EC:D8:7B:03:F5:78",
                     "C0:0F:22:34:F4:DD",
                     "D1:B5:C9:89:CF:DE",
                     "D3:7E:3E:48:E5:EC",
                     "C7:67:AC:21:19:45",
                     "D7:F5:A2:33:20:81",
                     "DD:79:1E:6C:1A:1A",
                     "D2:AE:8B:22:9B:D1",
                     "EF:90:29:66:16:8F",
                     "CD:3B:B9:5B:F5:4F",
                     "F4:4F:BA:59:50:BD",
                     "E4:8D:81:29:58:8D",
                     "C0:5C:D5:D0:0C:2B",
                     "D0:AA:E7:EB:82:34",
                     "D3:0F:0D:7B:EB:B7",
                     "F0:6D:40:95:2E:28",
                     "E4:89:11:2E:C0:E5",
                     "FC:54:33:2B:8A:E0",
                     "F1:2A:23:3C:7B:3E",
                     "F3:72:C6:2E:EC:51",
                     "D5:AC:D8:B3:F6:65",
                     "EC:95:6F:CA:D9:C4",
                     "FF:2F:31:BC:59:15",
                     "C3:A2:21:5D:3C:64",
                     "FC:B8:2D:DF:90:22",
                     "F9:AA:02:80:CC:CB",
                     "CB:8D:80:D7:35:E9",
                     "AX:BX:CX:DX:EX:FX",
                     "C1:7C:AF:6A:DA:A5",
                     "F1:5E:3B:2C:6E:17",
                     "F4:A2:1F:61:1E:0B",
                     "CB:DC:81:9D:13:DD",
                     "CE:21:99:A3:C0:06",
                     "EB:31:D6:55:CF:DD",
                     "C2:36:35:3B:9F:A0",
                     "DC:E1:64:CE:35:8A",
                     "EB:0E:56:8F:84:94",
                     "E3:F1:42:F2:98:2C",
                     "D6:57:9F:21:AA:64",
                     "E7:B8:4C:88:FB:A1",
                     "ED:A4:6D:31:7D:0F",
                     "CD:32:4B:CF:26:99",
                     "F9:F6:48:22:EB:C0",
                     "D1:1C:28:F0:2D:52",
                     "F2:20:E8:80:EC:75",
                     "FA:F0:84:46:25:8D",
                     "C5:14:AF:D4:8C:9B",
                     "D0:18:59:A8:4E:F1",
                     "EE:D5:BE:CE:FC:37",
                     "C4:50:2E:20:81:72",
                     "FF:A2:5B:28:12:87",
                     "F8:D8:8E:9E:14:35",
                     "D5:F1:DB:A6:85:BB",
                     "DB:E9:12:7A:29:FB",
                     "F9:B1:F7:03:2E:6B",
                     "E4:0E:ED:CC:4F:16",
                     "F6:1F:54:D1:C0:F1",
                     "C9:BA:F9:49:C1:DA",
                     "F4:4A:5F:71:38:F0",
                     "F3:73:FD:F4:81:14",
                     "E9:83:E8:1D:20:5E",
                     "C9:8A:54:D4:E5:E1",
                     "F9:45:B3:55:33:CE",
                     "DE:EB:93:0B:F2:69",
                     "DD:8C:20:AC:91:27",
                     "C4:D7:60:E2:58:25",
                     "DA:57:4E:AF:FD:8B",
                     "F9:EA:DD:29:16:13",
                     "E0:A0:EA:06:C6:71",
                     "C7:15:9F:BA:09:DD",
                     "F8:57:13:A5:F2:72",
                     "C1:19:20:0E:0A:3C",
                     "E6:33:7D:BD:A9:A0",
                     "EA:9A:53:69:6C:3E",
                     "DF:47:83:E6:6B:67",
                     "F9:26:7A:8F:B2:5E",
                     "C3:BE:AE:62:8A:81",
                     "ED:AD:79:58:6F:2D",
                     "C4:5D:6D:EE:6E:C7",
                     "E3:47:E4:6B:12:3D",
                     "CB:BD:E7:0D:BF:1C",
                     "E1:9F:A4:B9:33:73",
                     "D2:DC:3A:21:15:93",
                     "C1:5D:CF:02:35:13",
                     "D9:AE:E8:B9:99:2F",
                     "CA:F7:7C:BD:94:7F",
                     "ED:8D:10:01:70:24",
                     "D8:AC:8E:11:5B:49",
                     "EA:BF:B8:32:D9:BC",
                     "E3:1A:B9:75:E5:B8",
                     "D8:AD:F1:A3:BD:B3",
                     "C0:CE:4C:2E:CD:8A",
                     "EB:DB:33:7E:70:98",
                     "C7:65:30:AB:75:B3",
                     "EC:9F:24:1D:66:68",
                     "DE:3A:4A:D1:3A:B3",
                     "DA:37:26:9F:4C:FC",
                     "D8:73:15:02:10:67",
                     "FC:C0:CA:C9:18:7B",
                     "FA:8B:56:D9:0A:71",
                     "E5:EB:7F:F8:F7:E5",
                     "D3:9E:B3:C2:EA:24",
                     "F0:18:3A:4F:9B:C8",
                     "CC:11:C9:41:64:A9",
                     "C4:DB:08:6B:A9:B3",
                     "C9:2E:88:94:B4:79",
                     "D0:71:31:BF:85:F0",
                     "F1:F0:22:9B:6A:94",
                     "C1:13:FB:F7:BE:B5",
                     "EE:13:58:55:D3:84",
                     "F4:F7:D9:7B:67:06",
                     "C8:53:CC:2F:EA:1D",
                     "FC:5A:CB:25:3A:3A",
                     "E0:7A:94:21:37:76",
                     "CC:A9:22:C9:1F:BF",
                     "D7:88:3D:23:AF:C2",
                     "EA:15:D3:66:1E:0B",
                     "FC:45:4C:04:3E:D6",
                     "EF:F7:56:C3:2C:B6",
                     "E3:3E:D6:87:D4:CE",
                     "FD:AD:16:4E:6F:69",
                     "CC:A7:64:E5:87:8F",
                     "CA:E2:5E:9D:7A:5E",
                     "EB:19:9E:48:6F:0C",
                     "C2:10:92:37:77:2C",
                     "FC:5E:A6:D0:81:9C",
                     "F5:E9:3D:70:29:D9",
                     "C4:9A:A6:01:03:EA",
                     "D0:D3:A4:2D:23:08",
                     "DD:52:DD:62:45:CF",
                     "E1:D3:05:B7:57:B5",
                     "D3:D1:C3:31:24:C4",
                     "DD:5A:42:51:A8:04",
                     "C3:8A:48:1C:0D:84",
                     "C7:09:F2:0B:4C:93"]
        
            for mac in macs {
                let noke = NokeDevice.init(name: mac, mac: mac)
                NokeDeviceManager.shared().addNoke(noke!)
            }
        
        
        
        
        //noke?.setOfflineValues(key: <#T##String#>, command: <#T##String#>)
        //noke?.offlineUnlock()
        emailField.text = "NO EMAIL REQUIRED"
        
        //Setup UI
        backgroundButton.addTarget(self, action: #selector(clickLockButton(_:)), for: .touchUpInside)
        view.addSubview(backgroundButton)
        activityButton.addTarget(self, action: #selector(clickActivityButton(_:)), for: .touchUpInside)
        view.addSubview(activityButton)
        lockNameLabel.text = "No Lock Connected"
        view.addSubview(lockNameLabel)
        view.addSubview(lockImageView)
        view.addSubview(statusLabel)
        view.bringSubview(toFront: lockImageView)
        view.addSubview(emailField)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func nokeDeviceDidUpdateState(to state: NokeDeviceConnectionState, noke: NokeDevice) {
        switch state {
        case .nokeDeviceConnectionStateDiscovered:
            var lockState = ""
            switch(noke.lockState){
            case .nokeDeviceLockStateLocked:
                lockState = "Locked"
                break
            case .nokeDeviceLockStateUnlocked:
                lockState = "Unlocked"
                break
            case .nokeDeviceLockStateUnshackled:
                lockState = "Unshackled"
                break
            default:
                lockState = "Unknown"
                break
            }
            
            statusLabel.text = String.init(format:"%@ discovered (%@)", noke.name, lockState)
            NokeDeviceManager.shared().stopScan()
            NokeDeviceManager.shared().connectToNokeDevice(noke)
            break
        case .nokeDeviceConnectionStateConnected:
            statusLabel.text = String.init(format:"%@ connected", noke.name)
            print(noke.session!)
            self.lockNameLabel.text = noke.name
            currentNoke = noke
            makeButtonColor(UIColor(red:0.00, green:0.44, blue:0.81, alpha:1.0))
            break
        case .nokeDeviceConnectionStateSyncing:
            statusLabel.text = String.init(format: "%@ syncing", noke.name)
        case .nokeDeviceConnectionStateUnlocked:
            statusLabel.text = String.init(format:"%@ unlocked. Battery %d", noke.name, noke.battery)
            makeButtonColor(UIColor(red:0.05, green:0.62, blue:0.10, alpha:1.0))
            NokeDeviceManager.shared().removeNoke(mac: (currentNoke?.mac)!)
            NokeDeviceManager.shared().disconnectNokeDevice(currentNoke!)
            NokeDeviceManager.shared().startScanForNokeDevices()
            break
        case .nokeDeviceConnectionStateDisconnected:
            statusLabel.text = String.init(format:"%@ disconnected. Lock state: %d", noke.name, noke.lockState.rawValue)
            NokeDeviceManager.shared().cacheUploadQueue()
            makeButtonColor(UIColor.darkGray)
            lockNameLabel.text = "No Lock Connected"
            NokeDeviceManager.shared().startScanForNokeDevices()
            currentNoke = nil
            break
        default:
            statusLabel.text = String.init(format:"%@ unrecognized state", noke.name)
            break
        }
    }
    
    func nokeDeviceDidShutdown(noke: NokeDevice, isLocked: Bool, didTimeout: Bool) {
        statusLabel.text = "Noke did shutdown"
    }
    
    func nokeErrorDidOccur(error: NokeDeviceManagerError, message: String, noke: NokeDevice?) {
        debugPrint(message)
    }
    
    func didUploadData(result: Int, message: String) {
        debugPrint("DID UPLOAD DATA")
    }
    
    func bluetoothManagerDidUpdateState(state: NokeManagerBluetoothState) {
        switch (state) {
        case NokeManagerBluetoothState.poweredOn:
            debugPrint("NOKE MANAGER ON")
            NokeDeviceManager.shared().startScanForNokeDevices()
            statusLabel.text = "Scanning for Noke Devices"
            break
        case NokeManagerBluetoothState.poweredOff:
            debugPrint("NOKE MANAGER OFF")
            break
        default:
            debugPrint("NOKE MANAGER UNSUPPORTED")
            break
        }
    }
    
    func didReceiveUnlockResponse(data: Data) {
        let json = try? JSONSerialization.jsonObject(with: data, options: [])
        if let dictionary = json as? [String: Any]{
            let result = dictionary["result"] as! String
            if(result == "success"){
                print("REQUEST WORKED")
                let dataobj = dictionary["data"] as! [String:Any]
                let commandString = dataobj["commands"] as! String
                currentNoke?.sendCommands(commandString)
                
            }else{
                DispatchQueue.main.sync {
                    print("REQUEST FAILED")
                    statusLabel.text = "Access Denied"
                    makeButtonColor(UIColor(red:0.81, green:0.00, blue:0.00, alpha:1.0))
                }
            }
        }
    }
    
    /// MARK: UI Components
    lazy var backgroundButton: UIButton! = {
        let view = UIButton()
        view.frame.size.width = self.view.frame.size.width
        view.frame.size.height = self.view.frame.size.height/3 - 20
        view.backgroundColor = UIColor.darkGray
        return view
    }()
    
    lazy var lockNameLabel: UILabel! = {
        let view = UILabel()
        view.frame.size.width = self.view.frame.size.width - 20
        view.frame.size.height = 40
        view.frame.origin.x = 20
        view.frame.origin.y = 20
        view.font = UIFont.init(name: "HelveticaNeue-Thin", size: 18)
        view.textColor = UIColor.white
        return view
    }()
    
    lazy var lockImageView: UIImageView! = {
        let view = UIImageView()
        view.frame.size.width = self.view.frame.size.width/3
        view.frame.size.height = self.view.frame.size.height/3 - 60
        view.frame.origin.x = self.view.frame.size.width/3
        view.frame.origin.y = 30
        view.image = UIImage.init(named: "LockIcon")
        view.contentMode = UIViewContentMode.scaleAspectFit
        return view
    }()
    
    lazy var statusLabel: UILabel! = {
        let view = UILabel()
        view.frame.size.width = self.view.frame.size.width
        view.frame.size.height = 60
        view.frame.origin.y = self.view.frame.size.height/3 - 20
        view.backgroundColor = UIColor.darkGray
        view.textColor = UIColor.white
        view.font = UIFont.init(name: "HelveticaNeue-Thin", size: 18)
        view.textAlignment = NSTextAlignment.center
        return view
    }()
    
    lazy var emailField: UITextField = {
        let view = UITextField()
        view.frame.size.width = self.view.frame.size.width
        view.frame.size.height = 60
        view.frame.origin.y = self.view.frame.size.height/3 + 40
        view.backgroundColor = UIColor(red:0.96, green:0.96, blue:0.96, alpha:1.0)
        view.placeholder = "Email"
        view.font = UIFont.init(name: "HelveticaNeue-Thin", size: 18)
        
        view.leftViewMode = UITextFieldViewMode.always
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 40, height: 60))
        imageView.contentMode = .scaleAspectFit
        var image = UIImage(named: "AccountIcon")
        imageView.image = image
        view.leftView = imageView
        
        view.keyboardType = UIKeyboardType.emailAddress
        view.autocapitalizationType = UITextAutocapitalizationType.none
        return view
    }()
    
    lazy var activityButton: UIButton = {
        let view = UIButton()
        view.frame.size.width = self.view.frame.size.width
        view.frame.size.height = 60
        view.frame.origin.y = self.view.frame.size.height/3 + 40 + 60
        view.backgroundColor = UIColor.darkGray
        view.setTitle("Get Activity", for: UIControlState.normal)
        return view
    }()
    
    func makeButtonColor(_ color: UIColor){
        UIView.animate(withDuration: 0.25, animations: {
            self.backgroundButton.layer.backgroundColor = color.cgColor
        })
    }
    
    @IBAction func clickLockButton(_ sender: Any) {
    
        
        if(currentNoke == nil){
            statusLabel.text = "Noke Not Connected"
        }
        if(emailField.text?.count == 0){
            statusLabel.text = "Email Address Required"
        }
        else{
            statusLabel.text = "Requesting Unlock Command..."
            DemoWebClient.shared().delegate = self
            DemoWebClient.shared().requestUnshackle(noke: currentNoke!, email: emailField.text!)
        }
    }
    
    @IBAction func clickActivityButton(_ sender: Any) {
        DemoWebClient.shared().requestActivity()
    }

}

