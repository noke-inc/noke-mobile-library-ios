//
//  PhoneKeyAcl.swift
//  StorageSmartEntry
//
//  Created by Joffrey Mann on 12/22/25.
//  Copyright © 2025 Noke Inc. All rights reserved.
//

import Foundation


/// A resilient ISO‑8601 parser that supports Zulu UTC, offsets, and fractional seconds.
public enum ISO8601 {
    /// Primary: supports fractional seconds and time zone offsets.
    static let withFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(secondsFromGMT: 0) // Dates should be absolute instants; keep in UTC internally
        return f
    }()
    
    /// Fallback: no fractional seconds.
    static let basic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()
    
    /// Parse function used by decoders (tries fractional → basic).
    static func parse(_ s: String) -> Date? {
        if let d = withFractional.date(from: s) { return d }
        return basic.date(from: s)
    }
    
    /// Encoder counterpart that always emits RFC 3339/ISO‑8601 with fractional seconds.
    static func string(from date: Date) -> String {
        withFractional.string(from: date)
    }
}

public struct PhoneKeyAcl: Codable {
    public struct TimeWindow: Codable {
        let start: Date
        let end: Date
        
        private enum CodingKeys: String, CodingKey {
            case start
            case end
        }
        
        public init(start: Date, end: Date) {
            self.start = start
            self.end = end
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let startStr = try container.decode(String.self, forKey: .start)
            let endStr = try container.decode(String.self, forKey: .end)
            
            guard let startDate = ISO8601.parse(startStr) else {
                throw DecodingError.dataCorruptedError(forKey: .start, in: container, debugDescription: "Invalid ISO8601 date string: \(startStr)")
            }
            guard let endDate = ISO8601.parse(endStr) else {
                throw DecodingError.dataCorruptedError(forKey: .end, in: container, debugDescription: "Invalid ISO8601 date string: \(endStr)")
            }
            self.start = startDate
            self.end = endDate
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            let startStr = ISO8601.string(from: start)
            let endStr = ISO8601.string(from: end)
            try container.encode(startStr, forKey: .start)
            try container.encode(endStr, forKey: .end)
        }
    }
    public struct Permissions: Codable {
        let unlock: Bool
        let overrideOverlock: Bool
        let configWrite: Bool
        let fwUpdate: Bool
        
        public init(from decoder: any Decoder) throws {
            let container: KeyedDecodingContainer<PhoneKeyAcl.Permissions.CodingKeys> = try decoder.container(keyedBy: PhoneKeyAcl.Permissions.CodingKeys.self)
            self.unlock = try container.decode(Bool.self, forKey: PhoneKeyAcl.Permissions.CodingKeys.unlock)
            self.overrideOverlock = try container.decode(Bool.self, forKey: PhoneKeyAcl.Permissions.CodingKeys.overrideOverlock)
            self.configWrite = try container.decode(Bool.self, forKey: PhoneKeyAcl.Permissions.CodingKeys.configWrite)
            self.fwUpdate = try container.decode(Bool.self, forKey: PhoneKeyAcl.Permissions.CodingKeys.fwUpdate)
        }
        
        public init(unlock: Bool, overrideOverlock: Bool, configWrite: Bool, fwUpdate: Bool) {
            self.unlock = unlock
            self.overrideOverlock = overrideOverlock
            self.configWrite = configWrite
            self.fwUpdate = fwUpdate
        }
    }
    public struct Meta: Codable {
        let ttlHours: Int
        let timeSource: String
        let hwType: String
        
        public init(from decoder: any Decoder) throws {
            let container: KeyedDecodingContainer<PhoneKeyAcl.Meta.CodingKeys> = try decoder.container(keyedBy: PhoneKeyAcl.Meta.CodingKeys.self)
            self.ttlHours = try container.decode(Int.self, forKey: PhoneKeyAcl.Meta.CodingKeys.ttlHours)
            self.timeSource = try container.decode(String.self, forKey: PhoneKeyAcl.Meta.CodingKeys.timeSource)
            self.hwType = try container.decode(String.self, forKey: PhoneKeyAcl.Meta.CodingKeys.hwType)
        }
        
        public init(ttlHours: Int, timeSource: String, hwType: String) {
            self.ttlHours = ttlHours
            self.timeSource = timeSource
            self.hwType = hwType
        }
    }
    public struct Signature: Codable {
        let algorithm: String   // "Ed25519"
        let value: String       // Base64
        
        public init(from decoder: any Decoder) throws {
            let container: KeyedDecodingContainer<PhoneKeyAcl.Signature.CodingKeys> = try decoder.container(keyedBy: PhoneKeyAcl.Signature.CodingKeys.self)
            self.algorithm = try container.decode(String.self, forKey: PhoneKeyAcl.Signature.CodingKeys.algorithm)
            self.value = try container.decode(String.self, forKey: PhoneKeyAcl.Signature.CodingKeys.value)
        }
        
        public init(algorithm: String, value: String) {
            self.algorithm = algorithm
            self.value = value
        }
    }
    
    let aclId: String
    let lockMac: String
    let phoneKeyId: String
    let phonePublicKey: String  // Base64 32 bytes
    let issuedAt: Date
    let expiresAt: Date
    let schedule: [TimeWindow]
    let permissions: Permissions
    let meta: Meta
    public var signature: Signature?
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.aclId = try container.decode(String.self, forKey: .aclId)
        self.lockMac = try container.decode(String.self, forKey: .lockMac)
        self.phoneKeyId = try container.decode(String.self, forKey: .phoneKeyId)
        self.phonePublicKey = try container.decode(String.self, forKey: .phonePublicKey)
        self.issuedAt = try container.decode(Date.self, forKey: .issuedAt)
        self.expiresAt = try container.decode(Date.self, forKey: .expiresAt)
        self.schedule = try container.decode([PhoneKeyAcl.TimeWindow].self, forKey: .schedule)
        self.permissions = try container.decode(PhoneKeyAcl.Permissions.self, forKey: .permissions)
        self.meta = try container.decode(PhoneKeyAcl.Meta.self, forKey: .meta)
        self.signature = try container.decodeIfPresent(PhoneKeyAcl.Signature.self, forKey: .signature)
    }
    
    public init (
    aclId: String,
    lockMac: String,
    phoneKeyId: String,
    phonePublicKey: String,
    issuedAt: Date,
    expiresAt: Date,
    schedule: [PhoneKeyAcl.TimeWindow],
    permissions: PhoneKeyAcl.Permissions,
    meta: PhoneKeyAcl.Meta,
    signature: PhoneKeyAcl.Signature
    ) {
        self.aclId = aclId
        self.lockMac = lockMac
        self.phoneKeyId = phoneKeyId
        self.phonePublicKey = phonePublicKey
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
        self.schedule = schedule
        self.permissions = permissions
        self.meta = meta
        self.signature = signature
    }
}

extension PhoneKeyAcl {
    func isCurrentlyAuthorized(now: Date = Date()) -> Bool {
        guard expiresAt > now else { return false }
        guard permissions.unlock else { return false }
        
        return schedule.contains { window in
            now >= window.start && now <= window.end
        }
    }
}
