# 📱🔐 **PhoneKeyCore + Sample App**
### **Unified Phone‑Key Generation, ACL Handling, Command Signing & Demo UI**

This repository contains:

---

## **PhoneKeyCore** — a standalone framework that handles:

- Phone‑key generation & storage  
- **Ed25519** and **ECDSA P‑256** signing  
- ACL decoding, canonicalization, signing & chunking  
- JSON & ISO‑8601 utilities  
- Lock‑compatible ACL storage in Keychain  

---

## **PhoneKeySample App** — an end‑to‑end demonstration showing:

- How to ensure/load a phone key  
- How to send your public key to your backend  
- How to build, canonicalize & sign unlock commands  
- How to test key lifecycle events (expire, revoke, delete)  
- How to integrate with `PhoneKeyManager` inside SwiftUI  

This README explains both.

---

# 📒 **Table of Contents**

- #overview
- #phonekeycore-features
- #installation
- #key-architecture
- #key-generation
- #phonekeyinfo-api
- #acl-models
- #signing--canonicalization
- #acl-chunk-builder-firmware-ready
- #local-acl-storage
- #phonekeysample-app-overview
- #sample-app-screens
- #crypto-provider-sodium
- #faq

---

# 🧭 **Overview**

PhoneKeyCore provides everything needed for mobile‑generated authentication keys in secure lock systems:

- Automatic private key creation  
- Deterministic public key derivation  
- Command signing  
- ACL validation & chunking  
- Backend contract models  

Designed to be dropped into any iOS app.

---

# 🔐 **PhoneKeyCore Features**

## 🔑 **Key Generation — Supports:**

| Algorithm         | Private Key Storage              | Notes                           |
|------------------|----------------------------------|----------------------------------|
| **ECDSA P‑256** (default) | Secure, persistent `SecKey` | Best for modern iOS (13+) |
| **Ed25519**      | 32‑byte seed in Keychain         | Sodium fallback for iOS 12 |

Both produce deterministic UUID‑style `keyId` (SHA‑256 → 16 bytes → UUID).

---

## 🧾 **ACL Handling**

PhoneKeyCore includes:

- `PhoneKeyAcl`  
- `PhoneKeyAclEnvelope` *(lock‑compatible)*  
- `PhoneKeyAclRequest`  

With flexible decoding for:

- int/string IDs  
- ISO‑8601 or epoch timestamps  
- Permissions array _or_ keyed booleans  

---

## ✍️ **Signing**

- **Ed25519** → 64‑byte signature  
- **P‑256** → raw 64‑byte `(r||s)` signature  
- Converts DER → raw R/S safely  

---

## 📦 **ACL Chunk Builder**

Produces **128‑byte hex‑encoded packets** for BLE.  
Final chunk format:

```
"xx" + <4 hex digits ACL length> + <remaining bytes>
```

---

## 💾 **Keychain ACL Store**

Store, list, update, delete ACLs locally.  
Self‑healing index.

---

# 📦 **Installation**

## CocoaPods

PhoneKeyCore is available through [CocoaPods](https://cocoapods.org). To install it, add the following line to your Podfile:

```ruby
pod 'PhoneKeyCore', :git => 'https://github.com/noke-inc/PhoneKeyCore.git', :tag => '1.0.0'
```

Or, if published to CocoaPods trunk or a private spec repo:

```ruby
pod 'PhoneKeyCore', '~> 1.0'
```

Then run:

```bash
pod install
```

### Using with NokeMobileLibrary

To integrate PhoneKeyCore into your NokeMobileLibrary or other projects:

1. Add to your Podfile:
```ruby
source 'https://github.com/CocoaPods/Specs.git'

target 'YourTarget' do
  use_frameworks!
  
  pod 'PhoneKeyCore', :git => 'https://github.com/noke-inc/PhoneKeyCore.git', :tag => '1.0.0'
end
```

2. Import in your Swift files:
```swift
import PhoneKeyCore
```

3. Use the `PhoneKeyCoreProviding` protocol for integration:
```swift
let manager = PhoneKeyManager(serviceName: "com.yourapp.phonekey", provider: yourCryptoProvider)
PhoneKeyCoreBridge.shared = manager
```

## Manual Installation

Alternatively, drag the **PhoneKeyCore** folder into your Xcode project.

## Optional: Sodium for iOS 12 Ed25519 Support

If you need iOS 12 Ed25519 support, add Sodium:

```ruby
pod 'Sodium'
```

Then provide a `CryptoProvider` implementation (example included in Sample App).

---

# 🧱 **Key Architecture**

```
PhoneKeyCore/
├── PhoneKeyManager.swift          # Key generation, signing, ACL chunking
├── PhoneKeyAcl.swift              # ACL model
├── PhoneKeyAclRequest.swift
├── PhoneKeyInfoRequest.swift
├── PhoneKeyInfoResponse.swift
├── PhoneKeySignedCommand.swift
├── Canonicalization utils         # ISO-8601, JSON sorting
└── Keychain helpers
```

---

# 🔑 **Key Generation**

```swift
let manager = PhoneKeyManager(
    serviceName: "com.example.app.keys",
    accessGroup: nil,
    provider: SodiumCryptoProvider(),   // iOS 12 Ed25519
    preferredAlgorithm: .ecdsaP256      // default
)
```

### Ensure a key exists

```swift
let info = try manager.ensureKeys()
print(info.keyId)
print(info.publicKeyRaw.base64EncodedString())
```

### Destroy

```swift
try manager.destroyKeys()
```

---

# 🪪 **PhoneKeyInfo API**

```swift
public struct PhoneKeyInfo: Codable {
    public let keyId: String
    public let algorithm: SignatureAlgorithm
    public let publicKeyRaw: Data
    public let seed: Data
    public var status: PhoneKeyStatus
    public let keyTag: Data?
}
```

---

# 📬 **ACL Models**

### Request
```swift
let req = PhoneKeyAclRequest(
    userId: "123",
    lockMac: "AA:BB:CC:DD:EE:FF",
    phoneKeyId: "456"
)
```

### Response
```swift
let env = try JSONDecoder().decode(PhoneKeyAclEnvelope.self, from: data)
let acl = env.acl
print(acl.permissions.unlock)
```

---

# ✍️ **Signing & Canonicalization**

```swift
func signCommand(with manager: PhoneKeyManager,
                 base: PhoneKeySignedCommand) throws -> PhoneKeySignedCommand

func canonicalCommandBytes(for command: PhoneKeySignedCommand) throws -> Data
```

Canonicalization ensures:
- ISO‑8601 UTC w/ fractional seconds
- Sorted key ordering
- Signature removed before signing

ACL canonicalization:
```swift
func canonicalize(acl: PhoneKeyAcl) throws -> Data
```

---

# 📦 **ACL Chunk Builder (Firmware‑Ready)**

```swift
let chunks = try manager.buildACLChunks(acl: aclData)
```

Example:
```
[
  "00<128 bytes hex>",
  "01<128 bytes hex>",
  "xx02d0<remaining>"
]
```

---

# 💾 **Local ACL Storage**

```swift
try manager.saveACL(acl)
let stored = try manager.getACL(trackingId: "1")
let list = try manager.listACLs()
try manager.deleteACL(trackingId: "1")
```

---

# 📱 **PhoneKeySample App Overview**

- Ensuring keys
- Validating existing keys
- Showing Key ID & Public Key
- Signing unlock commands
- Soft-expiring / revoking keys
- Clearing Keychain for test
- Copy-to-clipboard actions
- Full SwiftUI UI

---

# 🖥️ **Sample App Screens**

### ✔ Validate Current Key
### 🔑 Generate / Load Key
### 📤 Register Key With Backend (stub)
```json
{
  "userId": "...",
  "phoneUdid": "...",
  "publicKey": "..."
}
```
### 📝 Build & Sign Unlock Command
### 📚 Logs
### 🔥 Key Lifecycle

---

# 🔧 **Crypto Provider (Sodium)**

Implements:
```swift
generateEd25519Seed()
derivePublicKey(fromSeed:)
sign(message:withSeed:)
getHash(of:)
```

---

# ❓ **FAQ**

- Only need Sodium for iOS 12 Ed25519
- Prefer P‑256 for security & hardware‑backed storage
- Lock expects raw 64‑byte (r||s) P‑256 signatures
- Canonicalization is required for verification

