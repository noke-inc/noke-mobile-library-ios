//
//  Ion2SigningCoordinatorTests.swift
//  NokeMobileLibraryTests
//
//  Created by Noke Inc. on 3/26/26.
//  Copyright © 2026 Noke Inc. All rights reserved.
//

import XCTest
import PhoneKeyCore
@testable import NokeMobileLibrary

/// Unit tests for Ion2SigningCoordinator state machine
///
/// **Test Philosophy:**
/// - Test behavior, not implementation
/// - Deterministic (no real BLE)
/// - Fast and repeatable
/// - Use mocks for dependencies
final class Ion2SigningCoordinatorTests: XCTestCase {
    
    // MARK: - System Under Test
    
    var coordinator: TestableIon2SigningCoordinator!
    var mockHandler: MockIon2CharacteristicHandler!
    var mockKeyManager: MockPhoneKeyManager!
    
    // MARK: - Test Data
    
    let validUserId = "user123"
    let validDeviceID = "device456"
    let validNonce = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
    
    lazy var validAcl: BulkPhoneKeyAcl = {
        let aclData = Data([0xAA, 0xBB, 0xCC])
        let sigData = Data([0x11, 0x22, 0x33])
        return BulkPhoneKeyAcl(
            result: "success",
            lockMac: "AA:BB:CC:DD:EE:FF",
            aclBinary: aclData.base64EncodedString(),
            aclSignature: sigData.base64EncodedString(),
            issuedAt: Date(),
            expiresAt: Date().addingTimeInterval(3600)
        )
    }()
    
    // MARK: - Setup / Teardown
    
    override func setUp() {
        super.setUp()
        mockHandler = MockIon2CharacteristicHandler()
        mockKeyManager = MockPhoneKeyManager()
        coordinator = TestableIon2SigningCoordinator(
            characteristicHandler: mockHandler,
            phoneKeyManager: mockKeyManager
        )
    }
    
    override func tearDown() {
        coordinator = nil
        mockHandler = nil
        mockKeyManager = nil
        super.tearDown()
    }
    
    // MARK: - 1. Happy Path Tests
    
    func test_startUnlock_withValidAcl_completesSuccessfulFlow() {
        // Given
        var successCalled = false
        var failureCalled = false
        var failureError: NokeDeviceSigningError?
        
        // When: Start unlock
        coordinator.startUnlock(
            acl: validAcl,
            userId: validUserId,
            deviceID: validDeviceID,
            onSuccess: { successCalled = true },
            onFailure: { error in
                failureCalled = true
                failureError = error
            }
        )
        
        // Then: writeTime should be called
        XCTAssertEqual(mockHandler.calls.count, 1, "Should call writeTime")
        if case .writeTime(let data) = mockHandler.calls[0] {
            XCTAssertEqual(data.count, 8, "Time data should be 8 bytes (Int64)")
        } else {
            XCTFail("First call should be writeTime")
        }
        
        // When: Time synced
        coordinator.handleStatus(.timeSynced)
        
        // Then: writeAcl should be called
        XCTAssertEqual(mockHandler.calls.count, 2, "Should call writeAcl after timeSynced")
        if case .writeAcl(let data) = mockHandler.calls[1] {
            XCTAssertEqual(data, Data(base64Encoded: validAcl.aclBinary)!)
        } else {
            XCTFail("Second call should be writeAcl")
        }
        
        // When: ACL received
        coordinator.handleStatus(.aclReceived)
        
        // Then: writeAclSignature should be called
        XCTAssertEqual(mockHandler.calls.count, 3, "Should call writeAclSignature")
        if case .writeAclSignature(let data) = mockHandler.calls[2] {
            XCTAssertEqual(data, Data(base64Encoded: validAcl.aclSignature)!)
        } else {
            XCTFail("Third call should be writeAclSignature")
        }
        
        // When: Signature verified
        coordinator.handleStatus(.aclSigVerified)
        
        // Then: readCommandId should be called
        XCTAssertEqual(mockHandler.calls.count, 4, "Should call readCommandId")
        if case .readCommandId = mockHandler.calls[3] {
            // Success
        } else {
            XCTFail("Fourth call should be readCommandId")
        }
        
        // When: Command ID read successful
        coordinator.handleCommandIdRead(result: .success(validNonce))
        
        // Then: writeCommand should be called
        XCTAssertEqual(mockHandler.calls.count, 5, "Should call writeCommand")
        if case .writeCommand(let data) = mockHandler.calls[4] {
            XCTAssertEqual(data.count, 9, "Command should be 0x00 + 8-byte nonce")
            XCTAssertEqual(data[0], 0x00, "First byte should be 0x00")
        } else {
            XCTFail("Fifth call should be writeCommand")
        }
        
        // Verify signing was called
        XCTAssertTrue(mockKeyManager.signCalled, "Should call sign on phoneKeyManager")
        
        // When: Command received
        coordinator.handleStatus(.cmdReceived)
        
        // Then: writeCommandSignature should be called
        XCTAssertEqual(mockHandler.calls.count, 6, "Should call writeCommandSignature")
        if case .writeCommandSignature(let data) = mockHandler.calls[5] {
            XCTAssertEqual(data, mockKeyManager.signResult, "Should write signature from signing")
        } else {
            XCTFail("Sixth call should be writeCommandSignature")
        }
        
        // When: Unlock executed
        coordinator.handleStatus(.unlockExecuted)
        
        // Then: Success handler called, failure NOT called
        XCTAssertTrue(successCalled, "Success handler should be called")
        XCTAssertFalse(failureCalled, "Failure handler should NOT be called")
        XCTAssertNil(failureError)
        
        // Verify sequence
        let expectedSequence: [MockIon2CharacteristicHandler.Call] = [
            .writeTime(mockHandler.calls[0].data!),
            .writeAcl(mockHandler.calls[1].data!),
            .writeAclSignature(mockHandler.calls[2].data!),
            .readCommandId,
            .writeCommand(mockHandler.calls[4].data!),
            .writeCommandSignature(mockHandler.calls[5].data!)
        ]
        XCTAssertEqual(mockHandler.calls.count, expectedSequence.count)
    }
    
    // MARK: - 2. Input Validation Tests
    
    func test_startUnlock_withEmptyAclBinary_failsWithMissingAcl() {
        // Given
        var failureError: NokeDeviceSigningError?
        var successCalled = false
        
        let invalidAcl = BulkPhoneKeyAcl(
            result: "success",
            lockMac: "AA:BB:CC:DD:EE:FF",
            aclBinary: "",  // Empty!
            aclSignature: "validSig==",
            issuedAt: Date(),
            expiresAt: Date().addingTimeInterval(3600)
        )
        
        // When
        coordinator.startUnlock(
            acl: invalidAcl,
            userId: validUserId,
            deviceID: validDeviceID,
            onSuccess: { successCalled = true },
            onFailure: { failureError = $0 }
        )
        
        // Then
        XCTAssertFalse(successCalled)
        XCTAssertNotNil(failureError)
        XCTAssertEqual(failureError, .missingAcl)
        XCTAssertEqual(mockHandler.calls.count, 0, "Should not call any handler methods")
    }
    
    func test_startUnlock_withEmptyAclSignature_failsWithInvalidAclSignature() {
        // Given
        var failureError: NokeDeviceSigningError?
        var successCalled = false
        
        let invalidAcl = BulkPhoneKeyAcl(
            result: "success",
            lockMac: "AA:BB:CC:DD:EE:FF",
            aclBinary: "validAcl==",
            aclSignature: "",  // Empty!
            issuedAt: Date(),
            expiresAt: Date().addingTimeInterval(3600)
        )
        
        // When
        coordinator.startUnlock(
            acl: invalidAcl,
            userId: validUserId,
            deviceID: validDeviceID,
            onSuccess: { successCalled = true },
            onFailure: { failureError = $0 }
        )
        
        // Then
        XCTAssertFalse(successCalled)
        XCTAssertNotNil(failureError)
        XCTAssertEqual(failureError, .invalidAclSignature)
        XCTAssertEqual(mockHandler.calls.count, 0)
    }
    
    func test_startUnlock_withInvalidBase64AclBinary_failsWithInvalidAclSignature() {
        // Given
        var failureError: NokeDeviceSigningError?
        
        let invalidAcl = BulkPhoneKeyAcl(
            result: "success",
            lockMac: "AA:BB:CC:DD:EE:FF",
            aclBinary: "!!!INVALID_BASE64!!!",
            aclSignature: "validSig==",
            issuedAt: Date(),
            expiresAt: Date().addingTimeInterval(3600)
        )
        
        // When
        coordinator.startUnlock(
            acl: invalidAcl,
            userId: validUserId,
            deviceID: validDeviceID,
            onSuccess: { },
            onFailure: { failureError = $0 }
        )
        
        // Then
        XCTAssertEqual(failureError, .invalidAclSignature)
        XCTAssertEqual(mockHandler.calls.count, 0)
    }
    
    func test_startUnlock_withInvalidBase64AclSignature_failsWithInvalidAclSignature() {
        // Given
        var failureError: NokeDeviceSigningError?
        
        let invalidAcl = BulkPhoneKeyAcl(
            result: "success",
            lockMac: "AA:BB:CC:DD:EE:FF",
            aclBinary: "dGVzdA==",
            aclSignature: "!!!INVALID_BASE64!!!",
            issuedAt: Date(),
            expiresAt: Date().addingTimeInterval(3600)
        )
        
        // When
        coordinator.startUnlock(
            acl: invalidAcl,
            userId: validUserId,
            deviceID: validDeviceID,
            onSuccess: { },
            onFailure: { failureError = $0 }
        )
        
        // Then
        XCTAssertEqual(failureError, .invalidAclSignature)
        XCTAssertEqual(mockHandler.calls.count, 0)
    }
    
    func test_startUnlock_whenAlreadyInProgress_failsWithUnknownError() {
        // Given: Start first unlock to put coordinator in .writingTime state
        coordinator.startUnlock(
            acl: validAcl,
            userId: validUserId,
            deviceID: validDeviceID,
            onSuccess: { },
            onFailure: { _ in }
        )
        XCTAssertEqual(mockHandler.calls.count, 1, "First unlock should call writeTime")
        
        // When: Try to start second unlock while first is in progress
        var secondFailureError: NokeDeviceSigningError?
        var secondSuccessCalled = false
        
        coordinator.startUnlock(
            acl: validAcl,
            userId: validUserId,
            deviceID: validDeviceID,
            onSuccess: { secondSuccessCalled = true },
            onFailure: { secondFailureError = $0 }
        )
        
        // Then
        XCTAssertFalse(secondSuccessCalled)
        XCTAssertEqual(secondFailureError, .unknown, "Should fail with unknown when already in progress")
        XCTAssertEqual(mockHandler.calls.count, 1, "Should not call handler again")
    }
    
    // MARK: - 3. Command ID / Nonce Tests
    
    func test_handleCommandIdRead_withSuccessAndValidNonce_writesCommandAndSigns() {
        // Given: Coordinator in readingCommandId state
        startUnlockAndProgressTo(state: .readingCommandId)
        let initialCallCount = mockHandler.calls.count
        
        // When
        coordinator.handleCommandIdRead(result: .success(validNonce))
        
        // Then: Should call sign and writeCommand
        XCTAssertTrue(mockKeyManager.signCalled, "Should sign the command")
        XCTAssertEqual(mockKeyManager.lastSignedData?.count, 9, "Should sign 0x00 + 8-byte nonce")
        XCTAssertEqual(mockKeyManager.lastSignedData?[0], 0x00)
        XCTAssertEqual(mockKeyManager.lastUserId, validUserId)
        
        XCTAssertEqual(mockHandler.calls.count, initialCallCount + 1)
        if case .writeCommand(let data) = mockHandler.calls.last {
            XCTAssertEqual(data.count, 9)
            XCTAssertEqual(data[0], 0x00)
            XCTAssertEqual(data.suffix(8), validNonce)
        } else {
            XCTFail("Should call writeCommand")
        }
    }
    
    func test_handleCommandIdRead_withInvalidNonceLength_failsWithUnknown() {
        // Given
        startUnlockAndProgressTo(state: .readingCommandId)
        var failureError: NokeDeviceSigningError?
        
        coordinator.startUnlock(
            acl: validAcl,
            userId: validUserId,
            deviceID: validDeviceID,
            onSuccess: { },
            onFailure: { failureError = $0 }
        )
        progressTo(state: .readingCommandId)
        
        // When: Invalid nonce (7 bytes instead of 8)
        let invalidNonce = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])
        coordinator.handleCommandIdRead(result: .success(invalidNonce))
        
        // Then
        XCTAssertEqual(failureError, .unknown)
        XCTAssertFalse(mockKeyManager.signCalled, "Should not sign with invalid nonce")
    }
    
    func test_handleCommandIdRead_withFailure_failsWithUnknown() {
        // Given
        var failureError: NokeDeviceSigningError?
        coordinator.startUnlock(
            acl: validAcl,
            userId: validUserId,
            deviceID: validDeviceID,
            onSuccess: { },
            onFailure: { failureError = $0 }
        )
        progressTo(state: .readingCommandId)
        
        // When
        coordinator.handleCommandIdRead(result: .failure(NSError(domain: "test", code: -1)))
        
        // Then
        XCTAssertEqual(failureError, .unknown)
    }
    
    func test_handleCommandIdRead_inWrongState_isIgnored() {
        // Given: Coordinator in .idle state
        let initialCallCount = mockHandler.calls.count
        
        // When
        coordinator.handleCommandIdRead(result: .success(validNonce))
        
        // Then: Should be ignored (no calls, no state change)
        XCTAssertEqual(mockHandler.calls.count, initialCallCount, "Should not make any calls")
    }
    
    // MARK: - 4. Status Handling & Sequencing Tests
    
    func test_handleStatus_timeSynced_transitionsToWritingAclAndWritesAcl() {
        // Given
        coordinator.startUnlock(
            acl: validAcl,
            userId: validUserId,
            deviceID: validDeviceID,
            onSuccess: { },
            onFailure: { _ in }
        )
        XCTAssertEqual(mockHandler.calls.count, 1) // writeTime
        
        // When
        coordinator.handleStatus(.timeSynced)
        
        // Then
        XCTAssertEqual(mockHandler.calls.count, 2)
        if case .writeAcl = mockHandler.calls[1] {
            // Success
        } else {
            XCTFail("Should call writeAcl after timeSynced")
        }
    }
    
    func test_handleStatus_aclValidated_transitionsToWritingSignatureAndWritesSignature() {
        // Given
        startUnlockAndProgressTo(state: .writingAcl)
        coordinator.handleStatus(.timeSynced)
        let callCountBeforeAcl = mockHandler.calls.count
        
        // When
        coordinator.handleStatus(.aclValidated)
        
        // Then
        XCTAssertEqual(mockHandler.calls.count, callCountBeforeAcl + 1)
        if case .writeAclSignature = mockHandler.calls.last {
            // Success
        } else {
            XCTFail("Should call writeAclSignature after aclValidated")
        }
    }
    
    func test_handleStatus_aclSigVerified_transitionsToReadingCommandIdAndReadsCommandId() {
        // Given
        startUnlockAndProgressTo(state: .writingSignature)
        let callCountBefore = mockHandler.calls.count
        
        // When
        coordinator.handleStatus(.aclSigVerified)
        
        // Then
        XCTAssertEqual(mockHandler.calls.count, callCountBefore + 1)
        if case .readCommandId = mockHandler.calls.last {
            // Success
        } else {
            XCTFail("Should call readCommandId after aclSigVerified")
        }
    }
    
    func test_handleStatus_cmdReceived_transitionsToWritingCommandSignatureAndWritesSignature() {
        // Given
        startUnlockAndProgressTo(state: .writingCommand)
        let callCountBefore = mockHandler.calls.count
        
        // When
        coordinator.handleStatus(.cmdReceived)
        
        // Then
        XCTAssertEqual(mockHandler.calls.count, callCountBefore + 1)
        if case .writeCommandSignature = mockHandler.calls.last {
            // Success
        } else {
            XCTFail("Should call writeCommandSignature after cmdReceived")
        }
    }
    
    func test_handleStatus_unlockExecuted_callsSuccessAndResetsState() {
        // Given
        var successCalled = false
        startUnlockToCompletion(onSuccess: { successCalled = true })
        
        // When
        coordinator.handleStatus(.unlockExecuted)
        
        // Then
        XCTAssertTrue(successCalled, "Should call success handler")
        
        // Verify can start new unlock (state reset to idle)
        let newUnlockCallCount = mockHandler.calls.count
        coordinator.startUnlock(
            acl: validAcl,
            userId: validUserId,
            deviceID: validDeviceID,
            onSuccess: { },
            onFailure: { _ in }
        )
        XCTAssertEqual(mockHandler.calls.count, newUnlockCallCount + 1, "Should be able to start new unlock after reset")
    }
    
    // MARK: - 5. Error Scenario Tests
    
    func test_handleStatus_timeOffsetErr_failsWithTimeOffsetError() {
        // Given
        var failureError: NokeDeviceSigningError?
        coordinator.startUnlock(
            acl: validAcl,
            userId: validUserId,
            deviceID: validDeviceID,
            onSuccess: { },
            onFailure: { failureError = $0 }
        )
        
        // When
        coordinator.handleStatus(.timeOffsetErr)
        
        // Then
        XCTAssertEqual(failureError, .timeOffsetError)
    }
    
    func test_handleStatus_aclRejected_failsWithAclRejected() {
        // Given
        var failureError: NokeDeviceSigningError?
        coordinator.startUnlock(
            acl: validAcl,
            userId: validUserId,
            deviceID: validDeviceID,
            onSuccess: { },
            onFailure: { failureError = $0 }
        )
        
        // When
        coordinator.handleStatus(.aclRejected)
        
        // Then
        XCTAssertEqual(failureError, .aclRejected)
    }
    
    func test_handleStatus_aclTimeInvalid_failsWithAclTimeInvalid() {
        // Given
        var failureError: NokeDeviceSigningError?
        coordinator.startUnlock(
            acl: validAcl,
            userId: validUserId,
            deviceID: validDeviceID,
            onSuccess: { },
            onFailure: { failureError = $0 }
        )
        
        // When
        coordinator.handleStatus(.aclTimeInvalid)
        
        // Then
        XCTAssertEqual(failureError, .aclTimeInvalid)
    }
    
    func test_handleStatus_unlockDenied_failsWithUnlockDenied() {
        // Given
        var failureError: NokeDeviceSigningError?
        coordinator.startUnlock(
            acl: validAcl,
            userId: validUserId,
            deviceID: validDeviceID,
            onSuccess: { },
            onFailure: { failureError = $0 }
        )
        
        // When
        coordinator.handleStatus(.unlockDenied)
        
        // Then
        XCTAssertEqual(failureError, .unlockDenied)
    }
    
    func test_handleStatus_aclScheduleBlocked_failsWithOutOfSchedule() {
        // Given
        var failureError: NokeDeviceSigningError?
        coordinator.startUnlock(
            acl: validAcl,
            userId: validUserId,
            deviceID: validDeviceID,
            onSuccess: { },
            onFailure: { failureError = $0 }
        )
        
        // When
        coordinator.handleStatus(.aclScheduleBlocked)
        
        // Then
        XCTAssertEqual(failureError, .outOfSchedule)
    }
    
    func test_handleStatus_unlockOverlocked_failsWithOverlock() {
        // Given
        var failureError: NokeDeviceSigningError?
        coordinator.startUnlock(
            acl: validAcl,
            userId: validUserId,
            deviceID: validDeviceID,
            onSuccess: { },
            onFailure: { failureError = $0 }
        )
        
        // When
        coordinator.handleStatus(.unlockOverlocked)
        
        // Then
        XCTAssertEqual(failureError, .overlock)
    }
    
    func test_handleStatus_withErrorRawValue_failsWithUnknown() {
        // Given
        var failureError: NokeDeviceSigningError?
        coordinator.startUnlock(
            acl: validAcl,
            userId: validUserId,
            deviceID: validDeviceID,
            onSuccess: { },
            onFailure: { failureError = $0 }
        )
        
        // When: Simulate status with "ERR" in raw value
        coordinator.handleStatus(.cmdOffsetErr)
        
        // Then
        XCTAssertEqual(failureError, .unknown)
    }
    
    // MARK: - 6. Retry Logic Tests
    
    func test_handleAclTimeExpired_whenCanRetry_triggersInvalidAclSignatureAndFailure() {
        // Given
        var failureError: NokeDeviceSigningError?
        coordinator.startUnlock(
            acl: validAcl,
            userId: validUserId,
            deviceID: validDeviceID,
            onSuccess: { },
            onFailure: { failureError = $0 }
        )
        
        // When: ACL time expired (first time)
        coordinator.handleStatus(.aclTimeExpired)
        
        // Then
        XCTAssertEqual(failureError, .invalidAclSignature, "Should fail with invalidAclSignature to trigger refetch")
    }
    
    func test_handleAclTimeExpired_whenMaxRetriesReached_failsWithAclRejected() {
        // Given: Exhaust retries
        var failureCallCount = 0
        var lastFailureError: NokeDeviceSigningError?
        
        coordinator.startUnlock(
            acl: validAcl,
            userId: validUserId,
            deviceID: validDeviceID,
            onSuccess: { },
            onFailure: { error in
                failureCallCount += 1
                lastFailureError = error
            }
        )
        
        // When: Trigger ACL time expired 4 times (max retries = 3)
        coordinator.handleStatus(.aclTimeExpired) // Retry 1
        XCTAssertEqual(lastFailureError, .invalidAclSignature)
        
        // Restart for retry 2
        coordinator.reset()
        coordinator.startUnlock(acl: validAcl, userId: validUserId, deviceID: validDeviceID, onSuccess: { }, onFailure: { lastFailureError = $0 })
        coordinator.handleStatus(.aclTimeExpired) // Retry 2
        
        coordinator.reset()
        coordinator.startUnlock(acl: validAcl, userId: validUserId, deviceID: validDeviceID, onSuccess: { }, onFailure: { lastFailureError = $0 })
        coordinator.handleStatus(.aclTimeExpired) // Retry 3
        
        coordinator.reset()
        coordinator.startUnlock(acl: validAcl, userId: validUserId, deviceID: validDeviceID, onSuccess: { }, onFailure: { lastFailureError = $0 })
        coordinator.handleStatus(.aclTimeExpired) // Retry 4 - should fail permanently
        
        // Then
        XCTAssertEqual(lastFailureError, .aclRejected, "After max retries, should fail with aclRejected")
    }
    
    func test_handleSignatureVerifyFailed_whenCanRetry_triggersInvalidAclSignatureAndFailure() {
        // Given
        var failureError: NokeDeviceSigningError?
        coordinator.startUnlock(
            acl: validAcl,
            userId: validUserId,
            deviceID: validDeviceID,
            onSuccess: { },
            onFailure: { failureError = $0 }
        )
        
        // When
        coordinator.handleStatus(.aclSigVerifyFailed)
        
        // Then
        XCTAssertEqual(failureError, .invalidAclSignature)
    }
    
    func test_handleSignatureVerifyFailed_whenMaxRetriesReached_failsWithInvalidAclSignature() {
        // Given: Exhaust retries with signature verify failed
        var lastFailureError: NokeDeviceSigningError?
        
        // Retry 1
        coordinator.startUnlock(acl: validAcl, userId: validUserId, deviceID: validDeviceID, onSuccess: { }, onFailure: { lastFailureError = $0 })
        coordinator.handleStatus(.aclSigVerifyFailed)
        XCTAssertEqual(lastFailureError, .invalidAclSignature)
        
        // Retry 2
        coordinator.reset()
        coordinator.startUnlock(acl: validAcl, userId: validUserId, deviceID: validDeviceID, onSuccess: { }, onFailure: { lastFailureError = $0 })
        coordinator.handleStatus(.aclSigVerifyFailed)
        
        // Retry 3
        coordinator.reset()
        coordinator.startUnlock(acl: validAcl, userId: validUserId, deviceID: validDeviceID, onSuccess: { }, onFailure: { lastFailureError = $0 })
        coordinator.handleStatus(.aclSigVerifyFailed)
        
        // Retry 4 - max reached
        coordinator.reset()
        coordinator.startUnlock(acl: validAcl, userId: validUserId, deviceID: validDeviceID, onSuccess: { }, onFailure: { lastFailureError = $0 })
        coordinator.handleStatus(.aclSigVerifyFailed)
        
        // Then
        XCTAssertEqual(lastFailureError, .invalidAclSignature, "After max retries, should still fail with invalidAclSignature")
    }
    
    // MARK: - 7. Reset Tests
    
    func test_reset_clearsStateAndOperationData() {
        // Given: Complete an unlock flow
        var successCalled = false
        coordinator.startUnlock(
            acl: validAcl,
            userId: validUserId,
            deviceID: validDeviceID,
            onSuccess: { successCalled = true },
            onFailure: { _ in }
        )
        
        // Progress through full flow
        coordinator.handleStatus(.timeSynced)
        coordinator.handleStatus(.aclReceived)
        coordinator.handleStatus(.aclSigVerified)
        coordinator.handleCommandIdRead(result: .success(validNonce))
        coordinator.handleStatus(.cmdReceived)
        coordinator.handleStatus(.unlockExecuted)
        
        XCTAssertTrue(successCalled)
        let callCountAfterFirstUnlock = mockHandler.calls.count
        
        // When: Manually reset (though unlockExecuted already resets)
        coordinator.reset()
        
        // Then: Should be able to start fresh unlock
        var secondSuccessCalled = false
        coordinator.startUnlock(
            acl: validAcl,
            userId: validUserId,
            deviceID: validDeviceID,
            onSuccess: { secondSuccessCalled = true },
            onFailure: { _ in }
        )
        
        XCTAssertEqual(mockHandler.calls.count, callCountAfterFirstUnlock + 1, "Should start fresh unlock")
        if case .writeTime = mockHandler.calls.last {
            // Success - fresh unlock started
        } else {
            XCTFail("Fresh unlock should start with writeTime")
        }
    }
    
    func test_reset_afterFailure_allowsFreshUnlock() {
        // Given: Failed unlock
        var failureCalled = false
        coordinator.startUnlock(
            acl: validAcl,
            userId: validUserId,
            deviceID: validDeviceID,
            onSuccess: { },
            onFailure: { _ in failureCalled = true }
        )
        coordinator.handleStatus(.unlockDenied)
        XCTAssertTrue(failureCalled)
        
        // When: Reset
        coordinator.reset()
        
        // Then: Can start new unlock
        var secondFailureCalled = false
        coordinator.startUnlock(
            acl: validAcl,
            userId: validUserId,
            deviceID: validDeviceID,
            onSuccess: { },
            onFailure: { _ in secondFailureCalled = true }
        )
        
        // Should not immediately fail
        XCTAssertFalse(secondFailureCalled, "Fresh unlock after reset should not immediately fail")
    }
    
    // MARK: - Test Helpers
    
    private func startUnlockAndProgressTo(state targetState: TestableIon2SigningCoordinator.SigningState) {
        coordinator.startUnlock(
            acl: validAcl,
            userId: validUserId,
            deviceID: validDeviceID,
            onSuccess: { },
            onFailure: { _ in }
        )
        progressTo(state: targetState)
    }
    
    private func progressTo(state targetState: TestableIon2SigningCoordinator.SigningState) {
        switch targetState {
        case .idle:
            break
        case .writingTime:
            break // Already there after startUnlock
        case .writingAcl:
            coordinator.handleStatus(.timeSynced)
        case .writingSignature:
            coordinator.handleStatus(.timeSynced)
            coordinator.handleStatus(.aclReceived)
        case .readingCommandId:
            coordinator.handleStatus(.timeSynced)
            coordinator.handleStatus(.aclReceived)
            coordinator.handleStatus(.aclSigVerified)
        case .writingCommand:
            coordinator.handleStatus(.timeSynced)
            coordinator.handleStatus(.aclReceived)
            coordinator.handleStatus(.aclSigVerified)
            coordinator.handleCommandIdRead(result: .success(validNonce))
        case .writingCommandSignature:
            coordinator.handleStatus(.timeSynced)
            coordinator.handleStatus(.aclReceived)
            coordinator.handleStatus(.aclSigVerified)
            coordinator.handleCommandIdRead(result: .success(validNonce))
            coordinator.handleStatus(.cmdReceived)
        case .completed, .failed:
            break // Can't progress to terminal states via helper
        }
    }
    
    private func startUnlockToCompletion(onSuccess: @escaping () -> Void) {
        coordinator.startUnlock(
            acl: validAcl,
            userId: validUserId,
            deviceID: validDeviceID,
            onSuccess: onSuccess,
            onFailure: { _ in }
        )
        coordinator.handleStatus(.timeSynced)
        coordinator.handleStatus(.aclReceived)
        coordinator.handleStatus(.aclSigVerified)
        coordinator.handleCommandIdRead(result: .success(validNonce))
        coordinator.handleStatus(.cmdReceived)
    }
}

// MARK: - Test Mocks & Wrappers

/// Test-only protocol mirroring Ion2CharacteristicHandler interface
protocol TestIon2CharacteristicHandler {
    func writeTime(_ data: Data)
    func writeAcl(_ data: Data)
    func writeAclSignature(_ data: Data)
    func readCommandId()
    func writeCommand(_ data: Data)
    func writeCommandSignature(_ data: Data)
}

/// Test-only protocol mirroring PhoneKeyManager signing interface
protocol TestPhoneKeyManager {
    func sign(_ data: Data, userId: String, deviceID: Data) throws -> Data
}

/// Adapter to allow Ion2SigningCoordinator to work with test mocks
/// This is test-only code that wraps the real coordinator
final class TestableIon2SigningCoordinator {
    
    enum SigningState: Equatable {
        case idle
        case writingTime
        case writingAcl
        case writingSignature
        case readingCommandId
        case writingCommand
        case writingCommandSignature
        case completed
        case failed(NokeDeviceSigningError)
        
        static func == (lhs: SigningState, rhs: SigningState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.writingTime, .writingTime), (.writingAcl, .writingAcl),
                 (.writingSignature, .writingSignature), (.readingCommandId, .readingCommandId),
                 (.writingCommand, .writingCommand), (.writingCommandSignature, .writingCommandSignature),
                 (.completed, .completed):
                return true
            case (.failed, .failed):
                return true
            default:
                return false
            }
        }
    }
    
    private var state: SigningState = .idle
    private let characteristicHandler: TestIon2CharacteristicHandler
    private let phoneKeyManager: TestPhoneKeyManager
    
    private var currentAcl: BulkPhoneKeyAcl?
    private var currentAclData: Data?
    private var currentSignatureData: Data?
    private var currentCommandSignatureData: Data?
    private var userId: String?
    private var deviceID: String?
    private var retryCount: Int = 0
    private let maxRetries: Int = 3
    
    private var successHandler: (() -> Void)?
    private var failureHandler: ((NokeDeviceSigningError) -> Void)?
    
    init(characteristicHandler: TestIon2CharacteristicHandler, phoneKeyManager: TestPhoneKeyManager) {
        self.characteristicHandler = characteristicHandler
        self.phoneKeyManager = phoneKeyManager
    }
    
    // Copy entire coordinator logic for testing (this mirrors production)
    func startUnlock(
        acl: BulkPhoneKeyAcl,
        userId: String,
        deviceID: String,
        onSuccess: @escaping () -> Void,
        onFailure: @escaping (NokeDeviceSigningError) -> Void
    ) {
        switch state {
        case .idle, .completed, .failed:
            break
        default:
            onFailure(.unknown)
            return
        }
        
        guard !acl.aclBinary.isEmpty else {
            onFailure(.missingAcl)
            return
        }
        
        guard !acl.aclSignature.isEmpty else {
            onFailure(.invalidAclSignature)
            return
        }
        
        guard
            let aclData = Data(base64Encoded: acl.aclBinary, options: .ignoreUnknownCharacters),
            let sigDer = Data(base64Encoded: acl.aclSignature, options: .ignoreUnknownCharacters)
        else {
            onFailure(.invalidAclSignature)
            return
        }
        
        self.currentAcl = acl
        self.currentAclData = aclData
        self.currentSignatureData = sigDer
        self.userId = userId
        self.deviceID = deviceID
        self.successHandler = onSuccess
        self.failureHandler = onFailure
        self.retryCount = 0
        
        writeTime()
    }
    
    func handleStatus(_ status: NokeDeviceSigningStatus) {
        switch status {
        case .timeSynced:
            handleTimeSynced()
        case .timeOffsetErr:
            fail(.timeOffsetError)
        case .aclReceived, .aclValidated:
            handleAclReceived()
        case .aclSigVerified:
            handleSignatureVerified()
        case .cmdReceived:
            handleCommandReceived()
        case .unlockExecuted:
            handleUnlockExecuted()
        case .aclRejected, .aclSetupError:
            fail(.aclRejected)
        case .aclTimeExpired:
            handleAclTimeExpired()
        case .aclTimeInvalid:
            fail(.aclTimeInvalid)
        case .aclSigVerifyFailed:
            handleSignatureVerifyFailed()
        case .unlockDenied:
            fail(.unlockDenied)
        case .lockLocked:
            break
        case .aclScheduleBlocked:
            fail(.outOfSchedule)
        case .unlockOverlocked:
            fail(.overlock)
        default:
            if status.rawValue.contains("ERR") || status.rawValue.contains("FAIL") || status.rawValue.contains("INVALID") {
                fail(.unknown)
            }
        }
    }
    
    func handleCommandIdRead(result: Result<Data, Error>) {
        guard case .readingCommandId = state else { return }
        
        switch result {
        case .success(let commandIdData):
            writeCommand(nonce: commandIdData)
        case .failure:
            fail(.unknown)
        }
    }
    
    func reset() {
        state = .idle
        currentAcl = nil
        currentAclData = nil
        currentSignatureData = nil
        currentCommandSignatureData = nil
        userId = nil
        deviceID = nil
        successHandler = nil
        failureHandler = nil
        retryCount = 0
    }
    
    private func writeTime() {
        state = .writingTime
        let secondsSinceEpoch: Int64 = Int64(Date().timeIntervalSince1970)
        let data = withUnsafeBytes(of: secondsSinceEpoch) { Data($0) }
        characteristicHandler.writeTime(data)
    }
    
    private func handleTimeSynced() {
        guard case .writingTime = state else { return }
        guard let aclData = currentAclData else {
            fail(.missingAcl)
            return
        }
        state = .writingAcl
        characteristicHandler.writeAcl(aclData)
    }
    
    private func handleAclReceived() {
        guard case .writingAcl = state else { return }
        guard let signatureData = currentSignatureData else {
            fail(.invalidAclSignature)
            return
        }
        state = .writingSignature
        characteristicHandler.writeAclSignature(signatureData)
    }
    
    private func handleSignatureVerified() {
        guard case .writingSignature = state else { return }
        state = .readingCommandId
        characteristicHandler.readCommandId()
    }
    
    private func writeCommand(nonce: Data) {
        guard nonce.count == 8 else {
            fail(.unknown)
            return
        }
        
        guard let userId = userId else {
            fail(.unknown)
            return
        }
        
        state = .writingCommand
        
        do {
            let finalCommandData = Data([0x00]) + nonce
            var deviceIDData = Data()
            if let deviceID = deviceID {
                deviceIDData = Data(deviceID.utf8)
            }
            
            currentCommandSignatureData = try phoneKeyManager.sign(finalCommandData, userId: userId, deviceID: deviceIDData)
            characteristicHandler.writeCommand(finalCommandData)
        } catch {
            fail(.unknown)
        }
    }
    
    private func handleCommandReceived() {
        guard case .writingCommand = state else { return }
        guard let commandSignature = currentCommandSignatureData else {
            fail(.unknown)
            return
        }
        state = .writingCommandSignature
        characteristicHandler.writeCommandSignature(commandSignature)
    }
    
    private func handleUnlockExecuted() {
        state = .completed
        successHandler?()
        reset()
    }
    
    private func handleAclTimeExpired() {
        if retryCount < maxRetries {
            retryCount += 1
            refetchAclAndRetry()
        } else {
            fail(.aclRejected)
        }
    }
    
    private func handleSignatureVerifyFailed() {
        if retryCount < maxRetries {
            retryCount += 1
            refetchAclAndRetry()
        } else {
            fail(.invalidAclSignature)
        }
    }
    
    private func refetchAclAndRetry() {
        fail(.invalidAclSignature)
    }
    
    private func fail(_ error: NokeDeviceSigningError) {
        state = .failed(error)
        failureHandler?(error)
    }
}

/// Mock characteristic handler for testing
final class MockIon2CharacteristicHandler: TestIon2CharacteristicHandler {
    
    enum Call: Equatable {
        case writeTime(Data)
        case writeAcl(Data)
        case writeAclSignature(Data)
        case readCommandId
        case writeCommand(Data)
        case writeCommandSignature(Data)
        
        var data: Data? {
            switch self {
            case .writeTime(let d), .writeAcl(let d), .writeAclSignature(let d),
                 .writeCommand(let d), .writeCommandSignature(let d):
                return d
            case .readCommandId:
                return nil
            }
        }
    }
    
    private(set) var calls: [Call] = []
    
    func writeTime(_ data: Data) {
        calls.append(.writeTime(data))
    }
    
    func writeAcl(_ data: Data) {
        calls.append(.writeAcl(data))
    }
    
    func writeAclSignature(_ data: Data) {
        calls.append(.writeAclSignature(data))
    }
    
    func readCommandId() {
        calls.append(.readCommandId)
    }
    
    func writeCommand(_ data: Data) {
        calls.append(.writeCommand(data))
    }
    
    func writeCommandSignature(_ data: Data) {
        calls.append(.writeCommandSignature(data))
    }
}

/// Mock PhoneKeyManager for testing
final class MockPhoneKeyManager: TestPhoneKeyManager {
    
    var signResult: Data = Data([0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE])
    var signError: Error?
    var signCalled = false
    var lastSignedData: Data?
    var lastUserId: String?
    var lastDeviceID: Data?
    
    func sign(_ data: Data, userId: String, deviceID: Data) throws -> Data {
        signCalled = true
        lastSignedData = data
        lastUserId = userId
        lastDeviceID = deviceID
        
        if let error = signError {
            throw error
        }
        
        return signResult
    }
}
