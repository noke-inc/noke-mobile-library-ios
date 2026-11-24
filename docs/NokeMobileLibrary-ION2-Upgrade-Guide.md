# NokeMobileLibrary 0.10.0 — ION 2 (5E) upgrade guide

This guide is for apps upgrading `NokeMobileLibrary` and adding support for **ION 2 locks (hardware type `5E`)**. It covers only what is new for ION 2. Locks that are not ION 2 keep working through the existing offline-key flow.

## 1. How ION 2 differs
Legacy locks unlock with an **offline key + command**. ION 2 locks have **no offline key**. Instead:
- the phone has its own key pair (created by PhoneKeyCore);
- your backend issues a signed **ACL** (access control list) for each user and lock;
- the library sends the ACL and a signed command to the lock over BLE.

The library chooses the path automatically: `noke.encryptionType` is `.signing` for ION 2 locks and `.encryption` for the rest.

## 2. Upgrade steps

### 2.1 Requirements
- **iOS 12 or later.**
- New dependency: **PhoneKeyCore** (resolved automatically by Swift Package Manager; the podspec declares `~> 1.1.1`).
- Swift Package: `https://github.com/noke-inc/noke-mobile-library-ios` (use the release that contains ION 2).

### 2.2 Update your `NokeDeviceManagerDelegate`
The delegate is now class-bound and the manager holds it **weakly**, so make sure your delegate object is retained elsewhere. These methods are **new and required**:

```swift
func nokeDevicefailureUpdate(message: String) { }
func nokeDeviceDidSendDiagnostics(data: [String: Any], noke: NokeDevice) { }
func successPacketReceived(noke: NokeDevice) { }
func onNokeJammedLocking(noke: NokeDevice) { }
func onNokeJammedUnlocking(noke: NokeDevice) { }
func nokeIon2ReadyForUnlock(noke: NokeDevice) { }   // ION 2 only
```
`nokeDeviceDidRelock(noke:)` is optional.

### 2.3 Fix removed/changed API (compile errors you may see)
| Removed / changed | What to do |
|---|---|
| `setLibraryMode(_:customURL:)` and `NokeLibraryMode.CUSTOM` | Use `setLibraryMode(_:)` with `.SANDBOX`, `.PRODUCTION`, `.DEVELOP` or `.OPEN` |
| `NokeDeviceManagerError.nokeLibraryConnectionTimeout` | Remove; handle timeouts in your own flow |
| `NokeDeviceConnectionState.Error` | Remove the case from your `switch` |
| `NokeDeviceManager.nokeDevices` (now internal) | Use `getAllNoke()` or `nokeWithMac(_:)` |
| `NokeDeviceLockState` raw values changed (now `Unknown=-1, Unlocked=0, Unshackled=1, Locked=2, JammedUnlocking=3, JammedLocking=4`) | Compare by case, never by raw value |
| `@objc` removed from connection/bluetooth/lock-state enums | Objective-C code can no longer use them |

## 3. Adding ION 2 support

### 3.1 Implement `PhoneKeyCoreClient` (your backend calls)
The library does not talk to the backend itself; you provide a client that calls your API, then register it once at startup:

```swift
final class MyPhoneKeyClient: PhoneKeyCoreClient {
    var isInitialized: Bool { /* true after initialize succeeds */ }
    func initialize(completion: @escaping (Result<String, Error>) -> Void) { /* ensure key pair, return public key */ }
    func provisionPhoneKey(userId: String, deviceId: String, publicKey: String,
                           completion: @escaping (Result<PhoneKeyInfoResponse, Error>) -> Void) { /* POST to your API */ }
    func generateAcl(userId: Int, lockMac: String, phoneKeyId: Int,
                     completion: @escaping (Result<BulkPhoneKeyAcl, Error>) -> Void) { /* ACL for one lock */ }
    func generateBulkAcls(phoneKeyId: Int,
                          completion: @escaping (Result<BulkPhoneKeyAclRoot, Error>) -> Void) { /* ACLs for all the user's locks */ }
    func validateCurrentKey() -> String? { /* public key if a valid key exists */ }
}

PhoneKeyAccessService.setSharedClient(MyPhoneKeyClient())   // e.g. in AppDelegate / App init
```
See `PhoneKeyServiceClient.swift` in this demo for a complete implementation.

### 3.2 Choose a stable `deviceId`
Pick one identifier for the device (for example a UUID stored in the keychain) and use **the same value** for provisioning and for every unlock. It is part of what the phone signs; if it changes, the existing key stops working. See `Ion2AccessProvider.stableDeviceId` in the demo.

### 3.3 Provision the phone key (once per user/device)
```swift
let publicKey = try await PhoneKeyAccessService.shared.initializeAsync()
let request = PhoneKeyInfoRequest(userId: userId, phoneUdid: deviceId, publicKey: publicKey)
let info = try await PhoneKeyAccessService.shared.provisionPhoneKeyAsync(request)
try PhoneKeyFacade.shared.savePhoneKeyInfo(userId: userId, info: info)   // cache it; reuse info.keyId later
```

### 3.4 Get and cache ACLs
```swift
// All of the user's locks (e.g. on login / pull-to-refresh)
let bulk = try await PhoneKeyAccessService.shared.generateBulkAclsAsync(PhoneKeyBulkAclRequest(phoneKeyId: keyId))
for acl in bulk.successfulAcls { try PhoneKeyFacade.shared.saveACL(userId: userId, lockMac: acl.lockMac, acl: acl) }

// One lock (fallback when no valid cached ACL exists)
let acl = try await PhoneKeyAccessService.shared.generateAclAsync(
    PhoneKeyAclRequest(userId: numericUserId, lockMac: mac, phoneKeyId: keyId))

// Read from cache
let cached = PhoneKeyFacade.shared.getACL(userId: userId, lockMac: mac)
```
Check `acl.expiresAt > Date()` before using a cached ACL. When the signed-in user changes, call `PhoneKeyFacade.shared.clearAll(userId: previousUserId)`.

### 3.5 Unlock an ION 2 lock
1. Scan as usual (`setLibraryMode`, `setAPIKey`, `startScanForNokeDevices`).
2. Detect ION 2 with `noke.isNokeIon2()`.
3. Connect with `NokeDeviceManager.shared().connectToNokeDevice(noke)`.
4. When `nokeIon2ReadyForUnlock(noke:)` fires (all BLE characteristics discovered), unlock:

```swift
noke.offlineUnlock(
    context: .signing(acl: acl, userId: userId, deviceID: deviceId),
    onSuccess: { /* unlocked */ },
    onFailure: { error in /* NokeDeviceOperationError */ }
)
```
If the lock is already connected, calling it earlier is safe: the library queues the unlock until the characteristics are ready.

Legacy locks use the same call with `.encryption(key:command:)`, or the previous `offlineUnlock(key:command:)` methods, which still work.

Add your own timeout (the demo uses 30 s): the library reports `onSuccess` or `onFailure`, but a lost BLE connection can leave the request waiting.

## 4. Handling errors
`onFailure` delivers a `NokeDeviceOperationError`. For ION 2 it is a `NokeDeviceSigningError`:

| Error | Typical cause | Suggested client action |
|---|---|---|
| `unlockDenied` | The ACL does not grant unlock permission for this user/lock | Show `error.description`; verify the user's permissions on the backend; do not retry blindly |
| `aclRejected`, `invalidAclSignature`, `aclTimeInvalid` | ACL expired, invalid or rejected | Discard the cached ACL, fetch a new one, retry once |
| `outOfSchedule` | Schedule forbids access now | Show the message (`errorType == .access`) |
| `overlock` | Unit in overlock, payment required | Show the message |
| `commandSignatureFailed` | Phone signature rejected (often a `deviceId` or key mismatch) | Re-provision the key; check the `deviceId` |
| `timeOffsetError` | Clock mismatch | Ask the user to check date/time settings |
| `lockJammed` | Mechanical jam | Show the message |
| `requiresEmergencyUnlock` / `requiresOverrideUnlock` | Unlock options require a fallback | Use your fallback flow (`errorType == .noOperation`) |
| `characteristicNotFound`, `peripheralNotFound` | BLE problem | Retry the connection |

Useful properties on every error: `description` (user-facing text), `shouldRefreshKeys`, `errorType`, `willUseFallback`. Library-level (PhoneKey) errors are `NokeMobileLibraryError`; log `diagnosticCode`, because it is not a `LocalizedError`.

Unlock options (emergency/override) can be passed with `UnlockContext.signing(..., options:)` by conforming to `UnlockOptionsRepresentable`.

## 5. Checklist
- [ ] Deployment target is iOS 12 or later; PhoneKeyCore resolves.
- [ ] Delegate implements the new required methods and is retained by your app.
- [ ] Removed uses of `.CUSTOM`, `customURL`, `.Error`, `nokeLibraryConnectionTimeout`, `nokeDevices`.
- [ ] `PhoneKeyCoreClient` implemented and registered with `PhoneKeyAccessService.setSharedClient`.
- [ ] Stable `deviceId` stored and used for provisioning and every unlock.
- [ ] Phone key provisioned and its `keyId` cached per user.
- [ ] ACLs fetched, cached, checked for expiry; cache cleared on user change.
- [ ] ION 2 locks unlocked with `offlineUnlock(context: .signing(...))`, after `nokeIon2ReadyForUnlock` (or queued).
- [ ] Errors mapped to user messages and ACL refresh logic.
- [ ] A timeout wraps each unlock attempt.
