# Zero-Config Integration Guide - NokeMobileLibrary

**Date:** March 26, 2026  
**For Third-Party Developers**

## 🎉 Zero Setup Required!

NokeMobileLibrary now works **out of the box** with zero configuration. Just add the pod and start unlocking!

## Quick Start (3 Lines of Code)

```swift
// 1. Import the library
import NokeMobileLibrary

// 2. That's it! Use PhoneKeyAccessService immediately:
PhoneKeyAccessService.shared.initialize { result in
    // Ready to unlock Ion 2 locks!
}

// 3. Or use PhoneKeyProvisioningService (if you're using our patterns):
PhoneKeyProvisioningService.shared.ensurePhoneKeyProvisioned()
```

**No AppDelegate setup required!**  
**No protocol implementations required!**  
**No dependency injection required!**

## What Works Automatically

✅ **Phone key generation** - DefaultPhoneKeyCoreClient.default  
✅ **Phone key storage** - DefaultPhoneKeyPersistence.default (keychain)  
✅ **ACL storage** - DefaultPhoneKeyPersistence.default (keychain)  
✅ **Phone key access** - PhoneKeyAccessService.shared  
✅ **RxSwift bridge** - PhoneKeyAccessServiceRx.shared (iOS 12+)  

## Default Implementations

### 1. DefaultPhoneKeyPersistence

**Singleton:** `DefaultPhoneKeyPersistence.default`

**What it does:**
- Stores phone key info in keychain
- Stores ACLs in keychain
- Uses PhoneKeyCore's PhoneKeyManager under the hood

**Usage:**
```swift
// Automatic (used by PhoneKeyProvisioningService)
PhoneKeyProvisioningService.shared.ensurePhoneKeyProvisioned()

// Manual (if needed)
let persistence = DefaultPhoneKeyPersistence.default
let acl = try? persistence.getACL(userId: "user123", lockMac: "AA:BB:CC:DD:EE:FF")
```

### 2. DefaultPhoneKeyCoreClient

**Singleton:** `DefaultPhoneKeyCoreClient.default`

**What it does:**
- Manages PhoneKeyCore initialization
- Handles key generation
- Thread-safe (serial queue)

**Usage:**
```swift
// Automatic (used by PhoneKeyAccessService)
PhoneKeyAccessService.shared  // Uses DefaultPhoneKeyCoreClient.default

// Manual (rarely needed)
let client = DefaultPhoneKeyCoreClient.default
client.initialize { result in ... }
```

### 3. PhoneKeyAccessService

**Singleton:** `PhoneKeyAccessService.shared`

**What it does:**
- Automatically uses DefaultPhoneKeyCoreClient.default
- No setup required in AppDelegate!

**Usage:**
```swift
// Zero-config usage (just works!)
PhoneKeyAccessService.shared.initialize { result in
    print("Ready!")
}
```

## Advanced: Custom Implementations (Optional)

If you need custom behavior, you can still provide your own implementations:

### Custom Persistence

```swift
class MyCustomPersistence: PhoneKeyPersistence {
    // Store in SQLite, Realm, etc.
    func getPhoneKeyInfo(userId: String) throws -> PhoneKeyInfoResponse? {
        // Your implementation
    }
    // ... implement other methods
}

// Inject into your services
let service = PhoneKeyProvisioningService(
    persistence: MyCustomPersistence()
)
```

### Custom Client

```swift
class MyCustomClient: PhoneKeyCoreClient {
    // Custom API integration
    func provisionPhoneKey(..., completion: ...) {
        // Call your backend API
    }
    // ... implement other methods
}

// Set globally
PhoneKeyAccessService.setSharedClient(MyCustomClient())
```

## Comparison: Before vs After

### Before (Required Setup)

```swift
// AppDelegate.swift
func application(..., didFinishLaunchingWithOptions ...) -> Bool {
    // 1. Create client implementation (required!)
    let phoneKeyCoreClient = PhoneKeyCoreClientImpl()
    
    // 2. Set it globally (required!)
    PhoneKeyAccessService.setSharedClient(phoneKeyCoreClient)
    
    // 3. Now you can use it
    PhoneKeyAccessService.shared.initialize { ... }
}
```

**Problems:**
- ❌ Third parties must implement PhoneKeyCoreClient
- ❌ Must call setSharedClient() in AppDelegate
- ❌ Crashes if they forget
- ❌ Extra boilerplate

### After (Zero Config)

```swift
// AppDelegate.swift
func application(..., didFinishLaunchingWithOptions ...) -> Bool {
    // Just use it! Defaults are automatic
    PhoneKeyProvisioningService.shared.ensurePhoneKeyProvisioned()
}

// Or anywhere in your app
PhoneKeyAccessService.shared.initialize { result in
    // Works immediately!
}
```

**Benefits:**
- ✅ No setup required
- ✅ Works out of the box
- ✅ Can't forget to initialize
- ✅ Clean, simple API

## Architecture

```
Third-Party App
    ↓
Uses: PhoneKeyAccessService.shared (zero config!)
    ↓
Automatically uses:
    ├─ DefaultPhoneKeyCoreClient.default
    └─ DefaultPhoneKeyPersistence.default
    ↓
PhoneKeyCore (handles cryptography)
```

## For StorageSmartEntry

**Before this refactor:**
- Had to create PhoneKeyCoreClientImpl in AppDelegate
- Had to call PhoneKeyAccessService.setSharedClient()
- Had to use PhoneKeyHandler as intermediary

**After this refactor:**
- ✅ No AppDelegate setup (removed 2 lines)
- ✅ No PhoneKeyHandler (deleted 251 lines)
- ✅ Uses defaults automatically
- ✅ PhoneKeyProvisioningService just works

## Migration from PhoneKeyHandler

If you were using PhoneKeyHandler, here's the migration:

**Old:**
```swift
// AppDelegate setup
let client = PhoneKeyCoreClientImpl()
PhoneKeyAccessService.setSharedClient(client)

// Get ACL
let acl = PhoneKeyHandler.shared.getBulkAclForLock(mac: "AA:BB...")
```

**New:**
```swift
// No AppDelegate setup needed!

// Get ACL
let persistence = DefaultPhoneKeyPersistence.default
let acl = try? persistence.getACL(userId: "user", lockMac: "AA:BB...")

// Or use the service (recommended)
PhoneKeyProvisioningService.shared.ensurePhoneKeyProvisioned()
```

## Benefits for Third Parties

1. **Zero Configuration**
   - Add pod → import → use
   - No setup code required
   
2. **Still Customizable**
   - Can override with custom implementations
   - Protocol-based design allows flexibility
   
3. **Fail-Safe**
   - Can't forget initialization
   - Defaults always work
   
4. **Clean API**
   - One singleton per service
   - Clear method names
   - Completion handlers (iOS 12+) or async/await (iOS 13+)

5. **Production Ready**
   - Thread-safe
   - Error handling included
   - Battle-tested defaults

## Summary

**For 99% of third parties:**
- ✅ Use the defaults (zero config)
- ✅ Call PhoneKeyAccessService.shared or PhoneKeyProvisioningService.shared
- ✅ Everything just works

**For the 1% who need customization:**
- ✅ Implement PhoneKeyPersistence for custom storage
- ✅ Implement PhoneKeyCoreClient for custom API integration
- ✅ Inject via initializers or setSharedClient()

**The library is now as simple to use as possible while remaining fully extensible!**
