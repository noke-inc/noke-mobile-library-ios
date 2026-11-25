# Nokē Mobile Library for iOS #

[![Version](https://img.shields.io/cocoapods/v/NokeMobileLibrary.svg?style=flat)](http://cocoapods.org/pods/NokeMobileLibrary)
[![License](https://img.shields.io/cocoapods/l/NokeMobileLibrary.svg?style=flat)](http://cocoapods.org/pods/NokeMobileLibrary)
[![Platform](https://img.shields.io/cocoapods/p/NokeMobileLibrary.svg?style=flat)](http://cocoapods.org/pods/NokeMobileLibrary)

## **** Recent Changes (v0.5.1) ****
* The library requires that a mode be set before scanning. The mode determines where the device responses are uploaded. Options are:

   * ```SANDBOX```
   * ```PRODUCTION```

The mode determines where responses from the lock are uploaded.  **Setting an upload URL manually is no longer supported**

* New delegate method has been added to the ```NokeDeviceManagerDelegate```: 

```swift
   func nokeDeviceDidShutdown(noke: NokeDevice, isLocked: Bool, didTimeout: Bool)
```

## Summary

The Nokē Mobile Library provides an easy-to-use and stable way to communicate with Nokē Devices via Bluetooth.  It must be used in conjunction with the Nokē Core API for full functionality such as unlocking locks and uploading activity.

![Nokē Core API Overview](https://imgur.com/vY2llC9.png)

## Requirements

This library is compatible with iOS devices that support Bluetooth Low Energy (BLE) and are running iOS 12.0 or higher (watchOS 6.2 or higher when installed with CocoaPods)

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

 * The library requires that a mode be set before scanning. The mode determines where the device responses are uploaded (it should be either SANDBOX or PRODUCTION)'
 ```swift
 NokeDeviceManager.shared().setLibraryMode(NokeLibraryMode.SANDBOX)
 ```

* By default, the `NokeDeviceManager` class only scans for devices that have been added to the device array.

```swift
//Add locks to device manager
let noke = NokeDevice.init(name: "LOCK NAME", mac: "XX:XX:XX:XX:XX:XX")
NokeDeviceManager.shared().addNoke(noke!)
```

* To allow the `NokeDeviceManager` to discover all Noke devices, use the following method:

```swift
NokeDeviceManager.shared().setAllowAllNokeDevices(true)
```

*You can check the lock state (`noke.lockState`) of the Noke object returned in the `nokeDeviceDidUpdateState` method to know if the lock is unlocked, locked, or unshackled.  HD locks running version 3.13+ will update in realtime as they're discovered

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



### Connecting to a Nokē Device ###

* When a Nokē Device is broadcasting and has been detected by the `NokeDeviceManager` the Nokē Device updates state to `Discovered`.  The manager can then connect to the Nokē Device.

```swift
case .nokeDeviceConnectionStateDiscovered:
    debugPrint(String.init(format:"%@ discovered", noke.name))
    NokeDeviceManager.shared().connectToNokeDevice(noke)
    break
```


### Unlocking a Nokē Device ###

* Once the Nokē device has successfully connected, the unlock process can be initialized.  Unlock requires sending a web request to a server that has implemented the [Noke Core API](https://github.com/noke-inc/noke-core-api-documentation).  While some aspects of the request can vary, an unlock request will always contain:
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

**Note:** ION 2 locks (hardware type `5E`) do not use the session-based online unlock described above. They unlock with a phone key and a signed ACL instead (see [Unlocking Offline: ION 2 Locks](#unlocking-offline-ion-2-locks-hardware-type-5e)).

#### Unlocking Offline ####

Offline unlock works without a network connection once the required credentials are cached on the phone. The method depends on the lock hardware:

| Lock type | Hardware | Offline credential |
| --- | --- | --- |
| ION 2 | `5E` / `E5` (`noke.isNokeIon2()` is `true`) | Phone key ACL (see below) |
| All other locks (NOKE 1A, 3K, 4K, 4E, etc.) | everything else | Offline key + unlock command (from the Core API) |

Route on `noke.isNokeIon2()` (or `noke.encryptionType`, which is `.signing` for ION 2).

#### Unlocking Offline: Offline Key (1A, 3K, 4K, 4E, etc.) ####

* This requires an offline key and an unlock command, both of which can be received by the server via the [Noke Core API](https://github.com/noke-inc/noke-core-api-documentation). These two values should be cached on the phone to be used at a later time. Not used for ION 2 locks, which have no offline key.

The offline key and unlock command should be set on the Noke device object before being used:

```swift
noke.setOfflineValues(key:"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", command: "yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy")
```
They can also be set at the time of offline unlocking:
```swift
 noke.offlineUnlock(key:"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", command: "yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy")
```
Once the values are set, the offline unlock function can be called at any time to unlock the Noke device:
```swift
 noke.offlineUnlock()
```

`offlineUnlock` returns the timestamp used, or an empty string if the key or command has the wrong length (key: 32 hex characters, command: 40 hex characters). In that case `nokeErrorDidOccur` is also called with `nokeLibraryErrorInvalidOfflineKey`.

Logs, errors, and callbacks will continue to function the same as when unlocking online.

#### Unlocking Offline: ION 2 Locks (hardware type `5E`) ####

ION 2 locks use a phone key and a signed ACL (access control list) instead of an offline key or server unlock command. The library depends on [PhoneKeyCore](https://github.com/noke-inc/PhoneKeyCore), which provides `BulkPhoneKeyAcl` and the phone key APIs. With Swift Package Manager it is resolved automatically. PhoneKeyCore is not published to the CocoaPods trunk, so with CocoaPods add it to your **Podfile** as well:

```ruby
target 'YourAppTargetName' do
use_frameworks!
pod 'NokeMobileLibrary'
pod 'PhoneKeyCore', :git => 'https://github.com/noke-inc/PhoneKeyCore.git', :tag => 'v1.1.1'
end
```

**Prerequisites**

1. Create a P-256 phone key on the device using `PhoneKeyCore`.
2. Provision the key with your backend (public key, phone UDID and user ID) and store the returned phone key id.
3. While online, fetch the ACL(s) for the user's phone key and cache them (e.g. in the keychain) so they are available offline. Clear the cached ACLs if a different user signs in.

Refer to the PhoneKeyCore documentation for the provisioning and ACL requests.

**Unlocking**

Get a valid (non-expired) ACL for the lock, connect to the lock, then call `offlineUnlock(context:)` with a signing context. The unlock is queued automatically until the lock's ION 2 characteristics have been discovered.

```swift
import PhoneKeyCore // required for BulkPhoneKeyAcl

if noke.isNokeIon2() {
    noke.offlineUnlock(
        context: .signing(acl: acl, userId: userId, deviceID: deviceID),
        onSuccess: {
            //Unlocked
        },
        onFailure: { error in
            debugPrint(error.description)
        }
    )
} else {
    _ = noke.offlineUnlock()
}
```

* `acl` is the cached `BulkPhoneKeyAcl` for the lock's MAC address. `userId` and `deviceID` must match the user ID and device identifier (UUID) used when the phone key was created, otherwise a different key is used and the signature will not match the provisioned public key.
* An optional `options:` argument (`UnlockOptionsRepresentable`) can be passed to `.signing`. If the user's access requires an override or emergency unlock, the ACL-based unlock fails with `NokeDeviceSigningError.requiresOverrideUnlock` or `.requiresEmergencyUnlock`.
* Failures such as a missing, expired or rejected ACL (`NokeDeviceSigningError.missingAcl`, `.aclRejected`, `.aclTimeInvalid`, `.invalidAclSignature`) are reported through `onFailure`. If the ACL is rejected, fetch a fresh ACL while online and try again.


### Uploading Activity Logs ###

The Nokē Mobile Library automatically uploads all responses from the Nokē device to the Nokē Core API for parsing.  Responses that contain activity logs are stored in the database and can be accessed using endpoints from the API.  Please see the Nokē Core API documentation for more details.

*The library requires you to set a mode before scanning. The mode determines where the device responses are uploaded (it should be either SANDBOX or PRODUCTION)'

```swift
NokeDeviceManager.shared().setLibraryMode(NokeLibraryMode.SANDBOX)
```


## License

Nokē Mobile Library is available under the Apache 2.0 license. See the LICENSE file for more info.

Copyright © 2018 Nokē Inc. All rights reserved.

