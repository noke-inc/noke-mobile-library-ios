//
//  DefaultPhoneKeyClient.swift
//  NokeMobileLibrary
//
//  Copyright © 2026 Noke Inc. All rights reserved.
//

import Foundation
import PhoneKeyCore

/// Ready-to-use `PhoneKeyCoreClient` for the Noke phone key backend.
///
/// It manages the P-256 key pair with PhoneKeyCore and performs the provisioning and ACL requests. The app only
/// supplies the base URL and how to authenticate each request:
/// ```swift
/// let client = DefaultPhoneKeyClient(baseURL: apiURL) { request in
///     request.setValue("ApiKey \(apiKey)", forHTTPHeaderField: "Authorization")
/// }
/// client.setIdentity(userId: user.id, deviceId: deviceId)   // after sign-in
/// PhoneKeyAccessService.setSharedClient(client)
/// ```
/// Apps with a different backend can still implement `PhoneKeyCoreClient` themselves.
public final class DefaultPhoneKeyClient: PhoneKeyCoreClient {

    /// Paths appended to `baseURL`.
    public struct Endpoints {
        public var provision: String
        public var acl: String
        public var bulkAcl: String

        public init(provision: String = "nse-provisioning-device/v1/phone-keys",
                    acl: String = "nse-phone-acl/api/v1/acls",
                    bulkAcl: String = "nse-phone-acl/api/v1/acls/me") {
            self.provision = provision
            self.acl = acl
            self.bulkAcl = bulkAcl
        }
    }

    private struct Identity {
        let userId: String
        let deviceId: String
    }

    private let baseURL: URL
    private let endpoints: Endpoints
    private let authorize: (inout URLRequest) -> Void
    private let urlSession: URLSession
    private let keyManager: PhoneKeyManager
    private let lock = NSLock()
    private var identity: Identity?
    private var publicKey: String?

    /// - Parameters:
    ///   - baseURL: Root of the phone key API.
    ///   - endpoints: Override only if your deployment uses different paths.
    ///   - urlSession: Session used for requests.
    ///   - keychainServiceName: Keychain service that stores the key pair.
    ///   - authorize: Adds authentication (headers, tokens) to every request.
    public init(baseURL: URL,
                endpoints: Endpoints = Endpoints(),
                urlSession: URLSession = .shared,
                keychainServiceName: String = "com.noke.noke-sdk-swift",
                authorize: @escaping (inout URLRequest) -> Void) {
        self.baseURL = baseURL
        self.endpoints = endpoints
        self.urlSession = urlSession
        self.authorize = authorize
        self.keyManager = PhoneKeyManager(serviceName: keychainServiceName, provider: nil)
    }

    /// Sets the signed-in user and this device's stable id. Call before `initialize`, and again when the user changes.
    public func setIdentity(userId: String, deviceId: String) {
        lock.lock()
        defer { lock.unlock() }
        // A different user or device owns a different key pair.
        if identity?.userId != userId || identity?.deviceId != deviceId { publicKey = nil }
        identity = Identity(userId: userId, deviceId: deviceId)
    }

    // MARK: PhoneKeyCoreClient

    public var isInitialized: Bool {
        return validateCurrentKey() != nil
    }

    public func validateCurrentKey() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return publicKey
    }

    public func initialize(completion: @escaping (Result<String, Error>) -> Void) {
        lock.lock()
        let current = identity
        lock.unlock()
        guard let current = current else {
            return completion(.failure(NokeMobileLibraryError.invalidInput(reason: "Call setIdentity(userId:deviceId:) first")))
        }
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let info = try self.keyManager.ensureP256Keys(userId: current.userId, deviceID: Data(current.deviceId.utf8))
                let key = info.publicKeyRaw.base64EncodedString()
                self.lock.lock()
                self.publicKey = key
                self.lock.unlock()
                completion(.success(key))
            } catch {
                completion(.failure(NokeMobileLibraryError.initializationFailed(underlyingError: error.localizedDescription)))
            }
        }
    }

    public func provisionPhoneKey(userId: String,
                                  deviceId: String,
                                  publicKey: String,
                                  completion: @escaping (Result<PhoneKeyInfoResponse, Error>) -> Void) {
        let body: [String: Any] = ["phone_udid": deviceId, "public_key": publicKey, "user_id": userId]
        send(endpoints.provision, body: body) { result in
            completion(result.flatMap { json in
                let keyId = (json["key_id"] as? Int) ?? (json["key_id"] as? String).flatMap(Int.init)
                guard let id = keyId, id > 0 else {
                    return .failure(NokeMobileLibraryError.provisioningFailed(reason: "Response is missing key_id"))
                }
                return .success(PhoneKeyInfoResponse(status: "success", keyId: id, detail: nil, error: nil))
            })
        }
    }

    public func generateAcl(userId: Int,
                            lockMac: String,
                            phoneKeyId: Int,
                            completion: @escaping (Result<BulkPhoneKeyAcl, Error>) -> Void) {
        let body: [String: Any] = ["userId": userId, "lockMac": lockMac, "phoneKeyId": phoneKeyId]
        send(endpoints.acl, body: body) { result in
            completion(result.flatMap { Self.singleAcl(from: $0, lockMac: lockMac) })
        }
    }

    public func generateBulkAcls(phoneKeyId: Int,
                                 completion: @escaping (Result<BulkPhoneKeyAclRoot, Error>) -> Void) {
        send(endpoints.bulkAcl, body: ["phoneKeyId": phoneKeyId]) { result in
            completion(result.flatMap { Self.bulkAcls(from: $0) })
        }
    }

    // MARK: Networking

    private func send(_ path: String,
                      body: [String: Any],
                      completion: @escaping (Result<[String: Any], Error>) -> Void) {
        var request = URLRequest(url: baseURL.appendingPathComponent(path), timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return completion(.failure(NokeMobileLibraryError.encodingFailed(underlyingError: error.localizedDescription)))
        }
        authorize(&request)

        urlSession.dataTask(with: request) { data, response, error in
            if let error = error {
                let code = (error as NSError).code
                return completion(.failure(code == NSURLErrorTimedOut
                    ? NokeMobileLibraryError.timeout
                    : NokeMobileLibraryError.networkError(underlyingError: error.localizedDescription)))
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let json = data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]
            guard (200..<300).contains(status) else {
                switch status {
                case 401: return completion(.failure(NokeMobileLibraryError.unauthorized))
                case 403: return completion(.failure(NokeMobileLibraryError.forbidden))
                default:
                    let detail = (json?["message"] ?? json?["detail"] ?? json?["error"]) as? String
                    return completion(.failure(NokeMobileLibraryError.serverError(statusCode: status, message: detail)))
                }
            }
            guard let json = json else {
                return completion(.failure(NokeMobileLibraryError.decodingFailed(underlyingError: "Empty or non-JSON body")))
            }
            completion(.success(json))
        }.resume()
    }

    // MARK: Parsing

    /// `{ result: "success", acls: [ { lockMac, aclBinary, aclSignature, issuedAt, expiresAt } ] }`; malformed entries are skipped.
    private static func bulkAcls(from json: [String: Any]) -> Result<BulkPhoneKeyAclRoot, Error> {
        guard let result = json["result"] as? String, result.lowercased() == "success" else {
            return .failure(NokeMobileLibraryError.aclGenerationFailed(reason: "Unexpected result in response"))
        }
        guard let entries = json["acls"] as? [[String: Any]] else {
            return .failure(NokeMobileLibraryError.decodingFailed(underlyingError: "Missing acls"))
        }
        let decoder = JSONDecoder()
        let acls = entries.compactMap { entry -> BulkPhoneKeyAcl? in
            guard let data = try? JSONSerialization.data(withJSONObject: entry) else { return nil }
            return try? decoder.decode(BulkPhoneKeyAcl.self, from: data)
        }
        if acls.isEmpty, !entries.isEmpty {
            return .failure(NokeMobileLibraryError.decodingFailed(underlyingError: "No valid ACLs"))
        }
        return .success(BulkPhoneKeyAclRoot(result: result, acls: acls))
    }

    /// `{ acl: { lockMac, issuedAt, expiresAt, ... }, aclSignature, aclBinary }`
    private static func singleAcl(from json: [String: Any], lockMac: String) -> Result<BulkPhoneKeyAcl, Error> {
        guard let acl = json["acl"] as? [String: Any],
              let signature = json["aclSignature"] as? String,
              let binary = json["aclBinary"] as? String,
              let issued = (acl["issuedAt"] as? String).flatMap(parseDate),
              let expires = (acl["expiresAt"] as? String).flatMap(parseDate) else {
            return .failure(NokeMobileLibraryError.decodingFailed(underlyingError: "ACL fields missing"))
        }
        return .success(BulkPhoneKeyAcl(result: "success",
                                        lockMac: (acl["lockMac"] as? String) ?? lockMac,
                                        aclBinary: binary,
                                        aclSignature: signature,
                                        issuedAt: issued,
                                        expiresAt: expires))
    }

    private static func parseDate(_ value: String) -> Date? {
        let plain = ISO8601DateFormatter()
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return plain.date(from: value) ?? fractional.date(from: value)
    }
}
