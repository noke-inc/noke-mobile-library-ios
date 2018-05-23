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
        let noke = NokeDevice.init(name: "New Lock", mac: "XX:XX:XX:XX:XX:XX")
        NokeDeviceManager.shared().addNoke(noke!)
        
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
            statusLabel.text = String.init(format:"%@ discovered", noke.name)
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
            break
        case .nokeDeviceConnectionStateDisconnected:
            statusLabel.text = String.init(format:"%@ disconnected. Lock state: %d", noke.name, (noke.lockState?.rawValue)!)
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
    
    func nokeErrorDidOccur(error: NokeDeviceManagerError, message: String, noke: NokeDevice?) {
        DispatchQueue.main.sync {
            statusLabel.text = String.init(format: "Error %d: %@", error.rawValue, message)
        }        
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
            let result = dictionary["result"] as! Bool
            if(result){
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
            DemoWebClient.shared().requestUnlock(noke: currentNoke!, email: emailField.text!)
        }
    }
    
    @IBAction func clickActivityButton(_ sender: Any) {
        DemoWebClient.shared().requestActivity()
    }

}

