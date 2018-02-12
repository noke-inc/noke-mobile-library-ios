# Nokē Mobile Library for iOS #

[![CI Status](http://img.shields.io/travis/sapsley/NokeMobileLibrary.svg?style=flat)](https://travis-ci.org/sapsley/NokeMobileLibrary)
[![Version](https://img.shields.io/cocoapods/v/NokeMobileLibrary.svg?style=flat)](http://cocoapods.org/pods/NokeMobileLibrary)
[![License](https://img.shields.io/cocoapods/l/NokeMobileLibrary.svg?style=flat)](http://cocoapods.org/pods/NokeMobileLibrary)
[![Platform](https://img.shields.io/cocoapods/p/NokeMobileLibrary.svg?style=flat)](http://cocoapods.org/pods/NokeMobileLibrary)

The Nokē Mobile Library provides an easy-to-use and stable way to communicate with Nokē Devices via Bluetooth.  It must be used in conjunction with the Nokē Core API for full functionality such as unlocking locks and uploading activity.

![Nokē Core API Overview](https://imgur.com/vY2llC9.png)

## Requirements

This library is compatible with iOS devices that support Bluetooth Low Energy (BLE) and are running iOS 8 or higher

## Installation
- Create/Update your **Podfile** with the following contents

```ruby
target 'YourAppTargetName' do
use_frameworks!
pod 'NokeMobileLibrary'
end
```
- Install dependencies
```ruby
pod install
```
- Open the newly created `.xcworkspace`

- Import the library to any of your classes by using `import NokeMobileLibrary` and begin working on your project

- **Important!** The NokeMobileLibrary uses an embedded framework written in Go.  Gomobile does not currently support Bitcode which means **you must disable Bitcode for the project to work:**.

In the **Project navigator**, select the topmost project item, and select the **Build Settings** tab. Type `bitcode` in the search bar and change the **Enable Bitcode** setting to **No**

- Once you've add the CocoaPod to your project, add the Mobile API Key by setting it in the AppDelegate
NokeDeviceManager.shared().setAPIKey("YOUR_KEY_HERE")

## Usage ##

### Setup ###
* The `NokeDeviceManager.swift` class handles scanning for Nokē Devices, connecting, sending commands, and receiving responses. All interaction is done through a singleton shared instance of the class:
```swift
//Setup device manager
NokeDeviceManager.shared().delegate = self
```

* Use the `NokeDeviceManagerDelegate` protocol to receive callbacks from the `NokeDeviceManager`:

```swift
func nokeDeviceDidUpdateState(to state: NokeDeviceConnectionState, noke: NokeDevice) {

    switch state {
        case .nokeDeviceConnectionStateDiscovered:
            //Nokē Discovered
            break
        case .nokeDeviceConnectionStateConnected:
            //Nokē Connected
            break
        case .nokeDeviceConnectionStateSyncing:
            //Nokē Syncing
            break
        case .nokeDeviceConnectionStateUnlocked:
            //Nokē Unlocked
            break
        case .nokeDeviceConnectionStateDisconnected:
            //Nokē Disconnected
            break
        default:
            //Unrecognized State
            break
        }
    }

func nokeErrorDidOccur(error: NokeDeviceManagerError, message: String, noke: NokeDevice?) {

}
```

### Scanning for Nokē Devices ###

* The `NokeDeviceManager` class only scans for devices that have been added to the device array.

```swift
//Add locks to device manager
let noke = NokeDevice.init(name: "LOCK NAME", mac: "XX:XX:XX:XX:XX:XX")
NokeDeviceManager.shared().addNoke(noke!)
```
**Note:** Make sure that the Bluetooth Manager is in the Powered On State before beginning scanning or you will encounter an error. The `bluetoothManagerDidUpdateState` protocol method can be used to receive updates on the state

```swift
func bluetoothManagerDidUpdateState(state: NokeManagerBluetoothState) {
    switch (state) {
        case NokeManagerBluetoothState.poweredOn:
            debugPrint("NOKE MANAGER ON")
            NokeDeviceManager.shared().startScanForNokeDevices()
            break
        case NokeManagerBluetoothState.poweredOff:
            debugPrint("NOKE MANAGER OFF")
            break
        default:
            debugPrint("NOKE MANAGER UNSUPPORTED")
            break
        }
    }
```

### Connecting to Nokē Device ###

* When a Nokē Device is broadcasting and has been detected by the `NokeDeviceManager` the Noke Device updates state to `Discovered`.  The manager can then connect to the Nokē Device.

```swift
case .nokeDeviceConnectionStateDiscovered:
    debugPrint(String.init(format:"%@ discovered", noke.name))
    NokeDeviceManager.shared().connectToNokeDevice(noke)
    break
```


### Unlocking a Nokē Device ###

* Once the Nokē device has successfully connected, the unlock process can be initialized.  Unlock requires sending a web request to a server that has implemented the Noke Core API (insert link here).  While some aspects of the request can vary, an unlock request will always contain:
    - **Mac Address** (`noke.mac`) - The bluetooth MAC Address of the Nokē device
    - **Session** (`noke.session`) - A unique session string used to encrypt commands to the lock
* Both of these values can be read from the `noke` object *after* a successful connection

- Example:
```swift
public func requestUnlock(noke: NokeDevice, email: String){

    let url = String.init(format:"%@%@", serverUrl, "unlock/")
    var jsonBody = [String: Any]()
    jsonBody["session"] = noke.session
    jsonBody["mac"] = noke.mac
    jsonBody["email"] = email

    if(JSONSerialization.isValidJSONObject(jsonBody)){
        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonBody, options: JSONSerialization.WritingOptions.prettyPrinted) else{return}
        self.doRequest(url: url, jsonData: jsonData)
        }
    }
```

* A successful unlock request will return a string of commands to be sent to the Nokē device.  These can be sent to the device by passing them to the `NokeDevice` object:
```swift
currentNoke.sendCommands(commandString)
```

* Once the Nokē device receives the command, it will verify that the keys are correct and unlock.


## License

NokeMobileLibrary is available under the Apache 2.0 license. See the LICENSE file for more info.

Copyright © 2018 Nokē Inc. All rights reserved.

