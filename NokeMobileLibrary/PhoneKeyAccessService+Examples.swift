//
//  PhoneKeyAccessService+Examples.swift
//  NokeMobileLibrary - Example Usage
//
//  Created by Noke Inc. on 3/25/26.
//  Copyright © 2026 Noke Inc. All rights reserved.
//
//  This file contains example code demonstrating how to use PhoneKeyAccessService.
//  This is for documentation purposes only and should not be included in production builds.
//

import Foundation
import NokeMobileLibrary

// MARK: - Example 1: Initialize and Provision Phone Key

func exampleInitializeAndProvision() async {
    let service = PhoneKeyAccessService.shared
    
    do {
        // Step 1: Initialize the service
        print("Initializing PhoneKey service...")
        let publicKey = try await service.initialize()
        print("✅ Initialized with public key: \(publicKey)")
        
        // Step 2: Get device ID
        guard let deviceId = UIDevice.current.identifierForVendor?.uuidString else {
            print("❌ No device ID available")
            return
        }
        
        // Step 3: Provision phone key
        let request = PhoneKeyProvisionRequest(
            userId: "user123",
            deviceId: deviceId,
            publicKey: publicKey
        )
        
        print("Provisioning phone key...")
        let response = try await service.provisionPhoneKey(request)
        print("✅ Phone key provisioned with ID: \(response.keyId)")
        
        // Store the key ID for future use
        UserDefaults.standard.set(response.keyId, forKey: "phoneKeyId")
        
    } catch let error as NokeMobileLibraryError {
        print("❌ Error: \(error.localizedDescription)")
        print("   Diagnostic code: \(error.diagnosticCode)")
    } catch {
        print("❌ Unexpected error: \(error)")
    }
}

// MARK: - Example 2: Generate Single ACL

func exampleGenerateSingleAcl(phoneKeyId: Int, lockMac: String) async {
    let service = PhoneKeyAccessService.shared
    
    do {
        // Create ACL request
        let request = AclRequest(
            userId: "user123",
            lockMac: lockMac,
            phoneKeyId: phoneKeyId,
            permissions: LockPermissions(unlock: true, overrideOverlock: false),
            timeWindow: nil  // No time restriction
        )
        
        print("Generating ACL for lock \(lockMac)...")
        let acl = try await service.generateAcl(request)
        
        print("✅ ACL generated successfully")
        print("   Lock: \(acl.lockMac)")
        print("   Issued: \(acl.issuedAt)")
        print("   Expires: \(acl.expiresAt)")
        
        // Use the ACL with NokeDeviceManager
        // NokeDeviceManager.shared.addAclForNoke(mac: acl.lockMac, acl: acl)
        
    } catch let error as NokeMobileLibraryError {
        print("❌ ACL generation failed: \(error.localizedDescription)")
        print("   Diagnostic code: \(error.diagnosticCode)")
    } catch {
        print("❌ Unexpected error: \(error)")
    }
}

// MARK: - Example 3: Generate ACL with Time Window

func exampleGenerateTimeBoundAcl(phoneKeyId: Int, lockMac: String) async {
    let service = PhoneKeyAccessService.shared
    
    do {
        // Create time window (valid for 24 hours starting in 1 hour)
        let now = Date()
        let startTime = now.addingTimeInterval(3600)      // 1 hour from now
        let endTime = now.addingTimeInterval(86400)       // 24 hours from now
        let timeWindow = TimeWindow(start: startTime, end: endTime)
        
        // Validate time window
        guard timeWindow.isValid else {
            print("❌ Invalid time window")
            return
        }
        
        // Create ACL request
        let request = AclRequest(
            userId: "user123",
            lockMac: lockMac,
            phoneKeyId: phoneKeyId,
            permissions: LockPermissions(unlock: true),
            timeWindow: timeWindow
        )
        
        print("Generating time-bound ACL...")
        let acl = try await service.generateAcl(request)
        
        print("✅ Time-bound ACL generated")
        print("   Valid from: \(acl.issuedAt)")
        print("   Valid until: \(acl.expiresAt)")
        
    } catch let error as NokeMobileLibraryError {
        print("❌ Error: \(error.localizedDescription)")
    } catch {
        print("❌ Unexpected error: \(error)")
    }
}

// MARK: - Example 4: Generate Bulk ACLs

func exampleGenerateBulkAcls(phoneKeyId: Int, locks: [String]) async {
    let service = PhoneKeyAccessService.shared
    
    do {
        // Create ACL requests for each lock
        let aclRequests = locks.map { lockMac in
            AclRequest(
                userId: "user123",
                lockMac: lockMac,
                phoneKeyId: phoneKeyId,
                permissions: LockPermissions(unlock: true),
                timeWindow: nil
            )
        }
        
        // Create bulk request
        let bulkRequest = BulkAclRequest(
            phoneKeyId: phoneKeyId,
            aclRequests: aclRequests
        )
        
        print("Generating \(locks.count) ACLs...")
        let response = try await service.generateBulkAcls(bulkRequest)
        
        // Handle response based on status
        switch response.status {
        case .fullSuccess:
            print("✅ All \(response.successCount) ACLs generated successfully")
            
            // Process all successful ACLs
            for acl in response.successfulAcls {
                print("   - Lock \(acl.lockMac): ✓")
                // NokeDeviceManager.shared.addAclForNoke(mac: acl.lockMac, acl: acl)
            }
            
        case .partialSuccess(let successCount, let failureCount):
            print("⚠️  Partial success: \(successCount) succeeded, \(failureCount) failed")
            
            // Process successful ACLs
            for acl in response.successfulAcls {
                print("   ✓ Lock \(acl.lockMac)")
                // NokeDeviceManager.shared.addAclForNoke(mac: acl.lockMac, acl: acl)
            }
            
            // Handle failures
            for (lockMac, error) in response.failures {
                print("   ✗ Lock \(lockMac): \(error.localizedDescription)")
            }
            
        case .fullFailure:
            print("❌ All ACL generations failed")
            for (lockMac, error) in response.failures {
                print("   - Lock \(lockMac): \(error.localizedDescription)")
            }
        }
        
    } catch let error as NokeMobileLibraryError {
        print("❌ Bulk ACL request failed: \(error.localizedDescription)")
        print("   Diagnostic code: \(error.diagnosticCode)")
    } catch {
        print("❌ Unexpected error: \(error)")
    }
}

// MARK: - Example 5: Error Handling Patterns

func exampleErrorHandling() async {
    let service = PhoneKeyAccessService.shared
    
    // Pattern 1: Specific error handling
    do {
        let publicKey = try await service.initialize()
        print("Initialized: \(publicKey)")
    } catch NokeMobileLibraryError.notInitialized {
        print("Service not initialized - this shouldn't happen here")
    } catch NokeMobileLibraryError.initializationFailed(let underlying) {
        print("Initialization failed: \(underlying ?? "unknown reason")")
        // Could retry or show user a meaningful message
    } catch {
        print("Unexpected error: \(error)")
    }
    
    // Pattern 2: Generic error handling with diagnostic codes
    do {
        let request = PhoneKeyProvisionRequest(
            userId: "",  // Invalid - will fail validation
            deviceId: "device",
            publicKey: "key"
        )
        _ = try await service.provisionPhoneKey(request)
    } catch let error as NokeMobileLibraryError {
        print("[\(error.diagnosticCode)] \(error.localizedDescription)")
        // Log diagnostic code for support
        logErrorToAnalytics(code: error.diagnosticCode, message: error.localizedDescription)
    } catch {
        print("Unexpected error: \(error)")
    }
    
    // Pattern 3: Exhaustive error handling
    do {
        let request = AclRequest(
            userId: "user123",
            lockMac: "invalid-mac",
            phoneKeyId: 0,  // Invalid
            permissions: LockPermissions(unlock: true)
        )
        _ = try await service.generateAcl(request)
    } catch let error as NokeMobileLibraryError {
        switch error {
        case .invalidInput(let reason):
            print("Invalid input: \(reason)")
            // Show user-friendly message in UI
            
        case .networkError(let underlying):
            print("Network issue: \(underlying ?? "unknown")")
            // Suggest checking internet connection
            
        case .timeout:
            print("Request timed out")
            // Offer to retry
            
        case .unauthorized, .forbidden:
            print("Authentication issue")
            // Redirect to login
            
        case .serverError(let code, let message):
            print("Server error (\(code)): \(message ?? "unknown")")
            // Show generic error message
            
        default:
            print("Error: \(error.localizedDescription)")
            print("Code: \(error.diagnosticCode)")
        }
    } catch {
        print("Unexpected error: \(error)")
    }
}

// MARK: - Example 6: SwiftUI Integration

#if canImport(SwiftUI)
import SwiftUI

@MainActor
class PhoneKeyViewModel: ObservableObject {
    @Published var isInitialized = false
    @Published var phoneKeyId: Int?
    @Published var acls: [Acl] = []
    @Published var errorMessage: String?
    @Published var isLoading = false
    
    private let service = PhoneKeyAccessService.shared
    
    func initialize() async {
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await service.initialize()
            isInitialized = true
        } catch let error as NokeMobileLibraryError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "An unexpected error occurred"
        }
        
        isLoading = false
    }
    
    func provisionPhoneKey(userId: String, deviceId: String, publicKey: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let request = PhoneKeyProvisionRequest(
                userId: userId,
                deviceId: deviceId,
                publicKey: publicKey
            )
            let response = try await service.provisionPhoneKey(request)
            phoneKeyId = response.keyId
        } catch let error as NokeMobileLibraryError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "An unexpected error occurred"
        }
        
        isLoading = false
    }
    
    func generateAcl(userId: String, lockMac: String) async {
        guard let phoneKeyId = phoneKeyId else {
            errorMessage = "No phone key provisioned"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let request = AclRequest(
                userId: userId,
                lockMac: lockMac,
                phoneKeyId: phoneKeyId,
                permissions: LockPermissions(unlock: true)
            )
            let acl = try await service.generateAcl(request)
            acls.append(acl)
        } catch let error as NokeMobileLibraryError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "An unexpected error occurred"
        }
        
        isLoading = false
    }
}

struct PhoneKeyExampleView: View {
    @StateObject private var viewModel = PhoneKeyViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            if viewModel.isLoading {
                ProgressView("Loading...")
            }
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
            
            if !viewModel.isInitialized {
                Button("Initialize") {
                    Task {
                        await viewModel.initialize()
                    }
                }
            } else {
                Text("Phone Key ID: \(viewModel.phoneKeyId ?? 0)")
                
                Button("Generate ACL") {
                    Task {
                        await viewModel.generateAcl(
                            userId: "user123",
                            lockMac: "00:11:22:33:44:55"
                        )
                    }
                }
                
                List(viewModel.acls, id: \.lockMac) { acl in
                    VStack(alignment: .leading) {
                        Text("Lock: \(acl.lockMac)")
                            .font(.headline)
                        Text("Expires: \(acl.expiresAt)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .task {
            await viewModel.initialize()
        }
    }
}
#endif

// MARK: - Helper Functions

private func logErrorToAnalytics(code: String, message: String) {
    // Log to your analytics service
    print("Analytics: [\(code)] \(message)")
}
