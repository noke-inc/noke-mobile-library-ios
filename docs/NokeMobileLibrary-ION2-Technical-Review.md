# NokeMobileLibrary — ION 2 technical overview and quality review

Scope: only the code added for ION 2 (hardware `5E`) on branch `feature/ION2-Unlock-Integration` (`48724bd`), compared against `e183d2d` (v0.9.3, July 2024). About 80 files changed (+11.5k / −1.2k lines; `Example/Pods` is generated). Static review: nothing was compiled or run.

> The local clone `noke-mobile-library-ios` is on `master` (`8a313d4`, 7 commits behind `origin/master`) and does not contain the ION 2 work (reverted in `8a313d4`).

---

# Part 1 — Technical explanation of the changes

## 1.1 The model change
- **Legacy locks:** offline key + offline command, encrypted with an AES session negotiated over BLE.
- **ION 2 (`5E`):** no session, no offline key. The phone owns a P-256 key pair (PhoneKeyCore). The backend issues a **signed ACL** per lock/user. The lock verifies the ACL signature, hands out an 8-byte nonce, and verifies the phone's signature over `0x00 + nonce`.
- The library picks the path per lock: `NokeDevice.encryptionType` is `.signing` if `isNokeIon2()` (hardware string contains `5E`/`E5`), else `.encryption`.

## 1.2 New components
| Area | Files | Responsibility |
|---|---|---|
| Unlock strategy | `Classes/UnlockStrategy/*` | `NokeUnlockStrategy` protocol; `EncryptionUnlockStrategy` (legacy) and `SigningUnlockStrategy` (ION 2, validates ACL expiry/data then calls `unlockForSigning`). `UnlockContext` carries inputs. |
| ION 2 protocol | `Classes/Ion2/Ion2SigningCoordinator.swift` | State machine: idle → writingTime → writingAcl → writingSignature → readingCommandId → writingCommand → writingCommandSignature → completed/failed. |
| BLE | `Classes/Ion2/Ion2CharacteristicHandler.swift` | Holds the 7 GATT characteristics (`time, acl, status, aclSig, cmdId, cmdWrite, cmdSig`) and performs reads/writes. |
| Device adapter | `Extensions/NokeDevice/Signing/NokeDevice+Signing.swift` | `unlockForSigning`, queues the unlock until characteristics are ready (`pendingIon2Unlock`), emergency/override checks, ACL refetch hooks. |
| Device split | `Extensions/NokeDevice/{Encryption,CBPeripheralDelegate}/` | `NokeDevice` split by path; CoreBluetooth delegate moved to an extension. |
| PhoneKey layer | `Classes/PhoneKey/*` | `PhoneKeyAccessService` (network via injected `PhoneKeyCoreClient`), `PhoneKeyFacade` (keychain cache of key info and ACLs), `PhoneKeyPersistence`, `NokeMobileLibraryError`, models. |
| State/protocols | `Classes/Protocols/NokeProtocols.swift` | `NokePhoneKeyState`, `PhoneKeyHandling`, `NokePhoneKeyStateDelegate`, `UnlockOptionsRepresentable`. |
| Manager | `Classes/NokeDeviceManager.swift` | Scans the "Infinity" BLE service, ACL storage (`addAclForNoke`), `unlockSigningDevice`, state restoration, pre-connect, auto-unlock, new delegate callbacks. |

## 1.3 ION 2 unlock sequence
```
connect → discover Infinity service → all 7 characteristics found → delegate.nokeIon2ReadyForUnlock
write time → TIME_SYNCED
write ACL → ACL_RECEIVED / ACL_VALIDATED
write ACL signature → ACLSIG_VERIFIED
read cmdId (8-byte nonce)
sign (0x00 + nonce) with phone key (userId + deviceID)
write command → CMD_RECEIVED
write command signature → UNLOCK_EXECUTED  (or an error status)
```

## 1.4 Lock status → library error
| Lock status | `NokeDeviceSigningError` | Meaning |
|---|---|---|
| `UNLOCK_DENIED` | `unlockDenied` | Everything verified, but the ACL lacks unlock permission |
| `ACL_SCHEDULE_BLOCKED` | `outOfSchedule` | Schedule forbids it now |
| `UNLOCK_OVERLOCKED` | `overlock` | Payment likely required |
| `CMDSIG_VERIFY_FAIL` | `commandSignatureFailed` | Phone signature/command wrong |
| `ACLSIG_VERIFY_FAIL`, `ACL_TIME_EXPIRED` | `invalidAclSignature` / `aclRejected` | Intended to trigger an ACL refetch |
| `TIME_OFFSET_ERR` | `timeOffsetError` | Clock mismatch |
| `LOCK_JAMMED` | `lockJammed` | Mechanical |

## 1.5 Public API surface added
- `NokeDevice`: `offlineUnlock(context:onSuccess:onFailure:)`, `unlockForSigning`, `isNokeIon2/NokeOne/NokeIon/Keypad/Screen/Padlock/Repeater`, `encryptionType`, `phoneKeyHandler`, `signingKeyState`, `hasValidSession`, `invalidateSession`, `canAutoUnlock`, `currentAclWriteStatus`.
- `NokeDeviceManager`: `addAclForNoke`, `getAcl(forMac:)`, `unlockSigningDevice`, `connectToNokeDevice(_:onSuccess:onFailure:)`, `onConnected`, `currentUserId`, `deviceID`, `currentDeviceOperationOptions`, `resetCentralManager`, `autounlockTimeSeconds`, `preConnectNokeOne`.
- Delegate: six new required methods (see the upgrade guide).
- Removed/changed: `.CUSTOM` mode and `customURL`, `nokeLibraryConnectionTimeout`, `NokeDeviceConnectionState.Error`, `@objc` on several enums, `Constants`/`nokeDevices` made non-public, `NokeDeviceLockState` raw values renumbered.
- Non-ION-2 additions bundled in the same release: keypad/thundergun/door-controller hardware, diagnostics packet `0x9B`, out-of-schedule `0x6D` and free-exit `0x6F` results, jammed events, NokeOne pre-connect retries, auto-unlock.

---

# Part 2 — Quality review

**Verdict:** the architecture is good, but client integration is heavier than necessary and there are several real defects.

## 2.1 What is good
- **Strategy per lock type** is a clean split; the decision is made in one place (`encryptionType`).
- **Single entry point** `offlineUnlock(context:)` with `UnlockContext`.
- **Layering:** state machine, BLE handler and a thin `NokeDevice` adapter are well separated. The coordinator is readable and has a 1213-line test file.
- **Typed errors:** `NokeDeviceOperationError` (`shouldRefreshKeys`, `errorType`, UI-ready `description`).
- **Unlock queueing** until BLE characteristics are ready.

## 2.2 Problems / bugs

**High priority**
1. **ACL retry does not work out of the box.**
   - `phoneKeyHandler`, `signingKeyState` and `NokePhoneKeyState.initializeFetchNewAclClosure()` are never assigned inside the library.
   - Unless the client wires them, `refetchAcl()` does nothing (`phoneKeyHandler?` is nil).
   - `fail()` calls `reset(shouldResetHandlers: true)`, so `retryCount` always goes back to 0 and `maxRetries = 3` never limits anything.
   - `refetchAclAndRetry()` just calls `fail(.invalidAclSignature)`; the app has no way of knowing it should refetch.
2. **Sensitive data is printed.** `PhoneKeyFacade.ensureProvisioned` prints `Binaries:` and `Cached acls:` (ACL contents) and a public-key prefix. The library has 87 `print(` and 24 `debugPrint(` calls and no logging switch; an SDK needs a configurable logger, off by default in release.
3. **Triplicated code.** `Extensions/`, `NokeMobileLibrary/Extensions/` and `NokeMobileLibrary/NokeMobileLibrary/Extensions/` hold identical files (same md5 for `NokeDevice+Signing.swift` and `NokePhoneKeyState.swift`). Risk of drift or compiling the wrong copy. 60 `Example/Pods` files are also committed.
4. **Race on `acls`.** `getAcl(forMac:)` reads via `devicesQueue.sync`; `addAclForNoke` writes without it. The manager mixes `NSLock`, queues and main with no clear rule.

**Medium priority**
5. **Coordinator cruft.** Hand-written `==` on `SigningState` (`.failed == .failed` ignores the error); `isReset()` compares 10 fields; `handleUnlockExecuted` calls `reset()` twice and invokes `successHandler` before resetting; failures like `.unknown // "Invalid nonce length"` lose the cause in a comment.
6. **Questionable error mapping.** `unlockDenied`, `outOfSchedule`, `overlock`, `lockJammed` return `shouldRefreshKeys = true`, but refreshing the ACL does not fix them, which can cause pointless retries. `isValid` is `false` for almost everything (only `peripheralNotFound` is `true`); its meaning is unclear.
7. **Huge types.** `NokeDevice` is 876 lines and `NokeDeviceManager` 1113. `isNokeIon2()` has a TODO ("Remove once this is fixed on firmware") and detects the type with `contains("5E")`, which is brittle.
8. **Public API leaks.** `UnlockContext` is public but its properties are internal; `PhoneKeyCommandSigner` is unused; `currentUserId` / `deviceID` / `currentDeviceOperationOptions` are mutable globals mixed with per-unlock context; `unlockSigningDevice` silently does nothing when there is no ACL.

## 2.3 How to make it simpler for clients
Today the demo needs roughly 300 lines of glue (`Ion2AccessProvider`, `PhoneKeyServiceClient`, `NokeLockManager.unlockIon2`) for provisioning, ACL caching, waiting for the ready callback, timeouts and retries. Proposals, highest impact first:

1. **One high-level `unlock`**, e.g. `noke.unlock(credentials:completion:)`, that connects, waits for characteristics, picks the path by `encryptionType`, applies a timeout and retries with a fresh ACL. The client only supplies a provider: `AclProvider.acl(for mac) async throws -> BulkPhoneKeyAcl`.
2. **No mandatory delegate methods.** Six new required methods break every client's build, even those not using ION 2. Give them empty defaults (as already done for `nokeDeviceDidRelock`); make `nokeIon2ReadyForUnlock` internal or a closure.
3. **ACL retry inside the library.** Register the ACL provider once; the library calls it on `ACL_TIME_EXPIRED` / `ACLSIG_VERIFY_FAIL`. Today the client must implement `PhoneKeyHandling` and `NokePhoneKeyStateDelegate` and wire `signingKeyState`.
4. **Provisioning and `deviceId` inside the library.** Generate and keychain-store a stable `deviceId`; expose one `PhoneKey.prepare(userId:)` that provisions and leaves ACLs ready.
5. **Easier `PhoneKeyCoreClient`.** Done: `DefaultPhoneKeyClient` needs only a base URL and a request-authorization closure. An `async` variant is still open.
6. **Backwards compatibility.** Deprecate instead of removing: `setLibraryMode(_:customURL:)`, `.CUSTOM`, `nokeDevices`, `Constants`; keep `@objc` if Objective-C clients exist.
7. **Configurable logger** (`NokeLogger.level = .off`) that never prints sensitive data.
8. **Actionable errors.** A public `NokeUnlockFailure` with a suggested action (`.retry`, `.refreshAcl`, `.contactAdmin`, `.fallbackOnline`) instead of combining `isValid`, `shouldRefreshKeys`, `willUseFallback` and `errorType`.

## 2.4 Suggested order of work
1. Remove sensitive `print`s and the duplicated `Extensions/` copies.
2. Delegate defaults + deprecations.
3. Fix ACL retry and `retryCount`.
4. Align `shouldRefreshKeys` with what each error can actually fix.
5. Add the high-level `unlock` API with an `AclProvider`.
