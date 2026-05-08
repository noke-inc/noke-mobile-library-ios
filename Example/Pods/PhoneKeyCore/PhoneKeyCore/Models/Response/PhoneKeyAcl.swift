//
//  PhoneKeyAcl.swift
//  StorageSmartEntry
//
//  Created by Joffrey Mann on 12/22/25.
//  Copyright © 2025 Noke Inc. All rights reserved.
//

import Foundation

// MARK: - ISO8601 helpers (kept for general use with utilities/mocks)

/// A resilient ISO‑8601 parser that supports Zulu UTC, offsets, and fractional seconds.
public enum ISO8601 {
    /// Primary: supports fractional seconds and time zone offsets.
    public static let withFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(secondsFromGMT: 0) // Use UTC for absolute instants
        return f
    }()

    /// Fallback: no fractional seconds.
    public static let basic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    /// Parse function used by decoders (tries fractional → basic).
    public static func parse(_ s: String) -> Date? {
        if let d = withFractional.date(from: s) { return d }
        return basic.date(from: s)
    }

    /// Encoder counterpart that always emits RFC 3339/ISO‑8601 with fractional seconds.
    public static func string(from date: Date) -> String {
        withFractional.string(from: date)
    }
}

// MARK: - Envelopes Root

public struct BulkPhoneKeyAclRoot: Codable {
    public var result: String
    public var acls: [BulkPhoneKeyAcl]
    
    public init(result: String, acls: [BulkPhoneKeyAcl]) {
        self.result = result
        self.acls = acls
    }
}

public struct BulkPhoneKeyAcl: Codable {
    public var result: String?               // Optional: only present when returned as single item, not in bulk array
    public var lockMac: String
    public var aclBinary: String
    public var aclSignature: String
    public let issuedAt: Date                // ISO8601 string in payload
    public let expiresAt: Date               // ISO8601 string in payload
    public let storedAt: Int64               // Milliseconds since epoch (like Android's System.currentTimeMillis())
    
    enum CodingKeys: String, CodingKey {
        case result
        case lockMac
        case aclBinary
        case aclSignature
        case issuedAt
        case expiresAt
        case storedAt
    }
    
    public init(result: String? = nil, lockMac: String, aclBinary: String, aclSignature: String, issuedAt: Date, expiresAt: Date, storedAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) {
        self.result = result
        self.lockMac = lockMac
        self.aclBinary = aclBinary
        self.aclSignature = aclSignature
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
        self.storedAt = storedAt
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        self.result = try? c.decode(String.self, forKey: .result)  // Optional
        self.lockMac = try c.decode(String.self, forKey: .lockMac)
        
        self.aclBinary = try c.decode(String.self, forKey: .aclBinary)
        self.aclSignature = try c.decode(String.self, forKey: .aclSignature)

        self.issuedAt = try Self.decodeFlexibleDateValue(container: c, key: .issuedAt)
        self.expiresAt = try Self.decodeFlexibleDateValue(container: c, key: .expiresAt)
        
        // storedAt is optional in the response - if not present, null, or invalid, use current time
        // Check if key exists and is not null before attempting decode
        if c.contains(.storedAt), !(try c.decodeNil(forKey: .storedAt)) {
            self.storedAt = (try? Self.decodeFlexibleInt64Value(container: c, key: .storedAt)) ?? Int64(Date().timeIntervalSince1970 * 1000)
        } else {
            self.storedAt = Int64(Date().timeIntervalSince1970 * 1000)
        }
    }

    // MARK: Encoding

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        
        try c.encode(result, forKey: .result)
        try c.encode(lockMac, forKey: .lockMac)
        try c.encode(aclBinary, forKey: .aclBinary)
        try c.encode(aclSignature, forKey: .aclSignature)

        // Encode dates as ISO8601 UTC strings to match the server JSON
        try c.encode(ISO8601.string(from: issuedAt), forKey: .issuedAt)
        try c.encode(ISO8601.string(from: expiresAt), forKey: .expiresAt)
        // Encode storedAt as Int64 milliseconds
        try c.encode(storedAt, forKey: .storedAt)
    }
    
    // Flexible decoder: epoch seconds (Int/Double/String) or ISO8601
    private static func decodeFlexibleDateValue(
        container c: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) throws -> Date {
        if let secs = try? c.decode(Int.self, forKey: key) {
            return Date(timeIntervalSince1970: TimeInterval(secs))
        }
        if let secsD = try? c.decode(Double.self, forKey: key) {
            return Date(timeIntervalSince1970: secsD)
        }
        if let str = try? c.decode(String.self, forKey: key) {
            if let secs = Int64(str) {
                return Date(timeIntervalSince1970: TimeInterval(secs))
            }
            if let d = ISO8601.parse(str) {
                return d
            }
        }
        throw DecodingError.dataCorrupted(.init(
            codingPath: c.codingPath + [key],
            debugDescription: "Expected epoch seconds (Int/Double/String) or ISO8601 string for \(key)."
        ))
    }
    
    // Flexible decoder for Int64 milliseconds: handles Int64, Double, String, or Date
    private static func decodeFlexibleInt64Value(
        container c: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) throws -> Int64 {
        // Try Int64 (milliseconds)
        if let ms = try? c.decode(Int64.self, forKey: key) {
            return ms
        }
        // Try Int (milliseconds)
        if let ms = try? c.decode(Int.self, forKey: key) {
            return Int64(ms)
        }
        // Try Double (milliseconds or seconds, disambiguate by magnitude)
        if let value = try? c.decode(Double.self, forKey: key) {
            // If value is < 10_000_000_000, assume seconds; otherwise milliseconds
            return value < 10_000_000_000 ? Int64(value * 1000) : Int64(value)
        }
        // Try String
        if let str = try? c.decode(String.self, forKey: key) {
            if let ms = Int64(str) {
                return ms
            }
            // Try parsing as ISO8601 date
            if let d = ISO8601.parse(str) {
                return Int64(d.timeIntervalSince1970 * 1000)
            }
        }
        // Try Date (encoded as ISO8601 or other)
        if let date = try? c.decode(Date.self, forKey: key) {
            return Int64(date.timeIntervalSince1970 * 1000)
        }
        throw DecodingError.dataCorrupted(.init(
            codingPath: c.codingPath + [key],
            debugDescription: "Expected Int64 milliseconds (Int64/Int/Double/String) or Date for \(key)."
        ))
    }
}

// MARK: - Envelope

/// Top‑level wrapper the server returns.
/// Example payload:
/// {
///   "result": "success",
///   "acl": { ... },
///   "aclSignature": "MEQCIG..."
/// }
public struct PhoneKeyAclEnvelope: Codable {
    public let result: String
    public var acl: PhoneKeyAcl
    public var aclSignature: String
    public var aclBinary: String

    enum CodingKeys: String, CodingKey {
        case result
        case acl
        case aclSignature
        case aclBinary
    }

    public init(result: String, acl: PhoneKeyAcl, aclSignature: String, aclBinary: String) {
        self.result = result
        self.acl = acl
        self.aclSignature = aclSignature
        self.aclBinary = aclBinary
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.result = try container.decode(String.self, forKey: .result)
        self.acl = try container.decode(PhoneKeyAcl.self, forKey: .acl)
        self.aclSignature = try container.decode(String.self, forKey: .aclSignature)
        self.aclBinary = try container.decode(String.self, forKey: .aclBinary)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(result, forKey: .result)
        try container.encode(acl, forKey: .acl)
        // Prefer explicit aclSignature; otherwise derive from acl.signature.value if present
        let sigValue = aclSignature.isEmpty ? (aclSignature) : aclSignature
        try container.encode(sigValue, forKey: .aclSignature)
        try container.encode(aclBinary, forKey: .aclBinary)
    }
}

// MARK: - ACL

public struct PhoneKeyAcl: Codable {
    // MARK: Nested Types

    public struct Permissions: Codable {
        public let unlock: Bool
        public let overrideOverlock: Bool

        enum CodingKeys: String, CodingKey {
            case unlock
            case overrideOverlock
        }

        /// Accept either:
        /// - array-of-strings: ["unlock","overrideOverlock"]
        /// - keyed booleans: { "unlock": true, ... }
        public init(from decoder: Decoder) throws {
            // Try array-of-strings first (server sample form)
            if let single = try? decoder.singleValueContainer(),
               let list = try? single.decode([String].self) {
                func on(_ keys: String...) -> Bool {
                    keys.contains { key in list.contains(key) }
                }
                self.unlock = on("unlock")
                self.overrideOverlock = on("overrideOverlock")
                return
            }

            // Fallback to keyed booleans
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.unlock = (try? c.decode(Bool.self, forKey: .unlock)) ?? false
            self.overrideOverlock = (try? c.decode(Bool.self, forKey: .overrideOverlock)) ?? false
        }

        public init(unlock: Bool, overrideOverlock: Bool) {
            self.unlock = unlock
            self.overrideOverlock = overrideOverlock
        }

        /// Encode back as array-of-strings to match server’s payload shape.
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            var list: [String] = []
            if unlock { list.append("unlock") }
            if overrideOverlock { list.append("overrideOverlock") }
            try container.encode(list)
        }
    }

    public struct Signature: Codable {
        public let algorithm: String   // e.g., "Ed25519", "ECDSA_P256"
        public let value: String       // Base64-encoded signature

        enum CodingKeys: String, CodingKey {
            case algorithm
            case value
        }

        public init(algorithm: String = "ECDSA_P256", value: String) {
            self.algorithm = algorithm
            self.value = value
        }
    }

    public struct Schedule: Codable, Equatable {
        public let start: Date
        public let end: Date

        private enum CodingKeys: String, CodingKey {
            case start
            case end
        }

        public init(start: Date, end: Date) {
            self.start = start
            self.end = end
        }

        public init(from decoder: Decoder) throws {
            // Decode values flexibly (Int/Double/String) then normalize to Date
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let s = try Self.decodeFlexibleDateValue(container: c, key: .start)
            let e = try Self.decodeFlexibleDateValue(container: c, key: .end)
            self.init(start: s, end: e)
        }

        /// Encode as ISO 8601 UTC strings to mirror the server JSON you shared.
        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(ISO8601.string(from: start), forKey: .start)
            try c.encode(ISO8601.string(from: end), forKey: .end)
        }

        // Flexible decoder: epoch seconds (Int/Double/String) or ISO8601
        private static func decodeFlexibleDateValue(
            container c: KeyedDecodingContainer<CodingKeys>,
            key: CodingKeys
        ) throws -> Date {
            if let secs = try? c.decode(Int.self, forKey: key) {
                return Date(timeIntervalSince1970: TimeInterval(secs))
            }
            if let secsD = try? c.decode(Double.self, forKey: key) {
                return Date(timeIntervalSince1970: secsD)
            }
            if let str = try? c.decode(String.self, forKey: key) {
                if let secs = Int64(str) {
                    return Date(timeIntervalSince1970: TimeInterval(secs))
                }
                if let d = ISO8601.parse(str) {
                    return d
                }
            }
            throw DecodingError.dataCorrupted(.init(
                codingPath: c.codingPath + [key],
                debugDescription: "Expected epoch seconds (Int/Double/String) or ISO8601 string for \(key)."
            ))
        }
    }

    // MARK: Properties

    /// NOW OPTIONAL; decodes from Int or String; stores as String?
    public let trackingId: String?
    public let lockMac: String
    public let phonePublicKey: String        // JSON key: "phonePubKey"
    public let issuedAt: Date                // ISO8601 string in payload
    public let expiresAt: Date               // ISO8601 string in payload
    /// NOW OPTIONAL
    public let schedule: [Schedule]?
    public let permissions: Permissions

    enum CodingKeys: String, CodingKey {
        case trackingId
        case lockMac
        case phonePublicKey = "phonePubKey"
        case issuedAt
        case expiresAt
        case schedule
        case permissions
    }

    // MARK: Decoding

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        // trackingId: accept Int or String; allow missing -> nil
        if let idInt = try? c.decode(Int.self, forKey: .trackingId) {
            self.trackingId = String(idInt)
        } else if let idString = try? c.decode(String.self, forKey: .trackingId) {
            self.trackingId = idString
        } else {
            self.trackingId = nil
        }

        self.lockMac = try c.decode(String.self, forKey: .lockMac)
        self.phonePublicKey = try c.decode(String.self, forKey: .phonePublicKey)

        // Dates: accept Int/Double seconds or ISO8601 strings
        self.issuedAt = try Self.decodeFlexibleDate(container: c, key: .issuedAt)
        self.expiresAt = try Self.decodeFlexibleDate(container: c, key: .expiresAt)

        // schedule is optional
        self.schedule = try? c.decode([Schedule].self, forKey: .schedule)
        self.permissions = try c.decode(Permissions.self, forKey: .permissions)
    }

    // MARK: Encoding

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)

        // trackingId: encode when non-nil; Int if numeric string, else String
        if let trackingId {
            if let idInt = Int(trackingId) {
                try c.encode(idInt, forKey: .trackingId)
            } else {
                try c.encode(trackingId, forKey: .trackingId)
            }
        }

        try c.encode(lockMac, forKey: .lockMac)
        try c.encode(phonePublicKey, forKey: .phonePublicKey)

        // Encode dates as ISO8601 UTC strings to match the server JSON
        try c.encode(ISO8601.string(from: issuedAt), forKey: .issuedAt)
        try c.encode(ISO8601.string(from: expiresAt), forKey: .expiresAt)

        // schedule: omit when nil
        if let schedule { try c.encode(schedule, forKey: .schedule) }

        try c.encode(permissions, forKey: .permissions)
    }

    // MARK: Inits

    public init(
        trackingId: String?,
        lockMac: String,
        phonePublicKey: String,
        issuedAt: Date,
        expiresAt: Date,
        schedule: [Schedule]?,
        permissions: PhoneKeyAcl.Permissions
    ) {
        self.trackingId = trackingId
        self.lockMac = lockMac
        self.phonePublicKey = phonePublicKey
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
        self.schedule = schedule
        self.permissions = permissions
    }

    // MARK: - Helpers

    private static func decodeFlexibleDate(container c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) throws -> Date {
        if let secs = try? c.decode(Int.self, forKey: key) {
            return Date(timeIntervalSince1970: TimeInterval(secs))
        }
        if let secsD = try? c.decode(Double.self, forKey: key) {
            return Date(timeIntervalSince1970: secsD)
        }
        if let str = try? c.decode(String.self, forKey: key) {
            if let secs = Int64(str) {
                return Date(timeIntervalSince1970: TimeInterval(secs))
            }
            if let d = ISO8601.parse(str) {
                return d
            }
        }
        throw DecodingError.dataCorrupted(.init(
            codingPath: c.codingPath + [key],
            debugDescription: "Expected epoch seconds (Int/Double/String) or ISO8601 string for \(key)."
        ))
    }
}

// MARK: - JSON Encoder/Decoder (ISO 8601 with fractional seconds) – utility

public enum JSONISO8601 {
    public static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        // RFC3339/ISO8601 + fractional seconds
        if #available(iOS 11.0, *) {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            f.timeZone = TimeZone(secondsFromGMT: 0)
            e.dateEncodingStrategy = .custom { date, enc in
                var container = enc.singleValueContainer()
                try container.encode(f.string(from: date))
            }
        } else {
            e.dateEncodingStrategy = .iso8601
        }
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }

    public static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        if #available(iOS 11.0, *) {
            d.dateDecodingStrategy = .custom { dec in
                let s = try dec.singleValueContainer().decode(String.self)
                if let dt = ISO8601.parse(s) {
                    return dt
                }
                throw DecodingError.dataCorrupted(.init(
                    codingPath: dec.codingPath,
                    debugDescription: "Invalid ISO8601 date string: \(s)"
                ))
            }
        } else {
            d.dateDecodingStrategy = .iso8601
        }
        return d
    }
}

// MARK: - BLE helpers (Date → 64‑bit Unix seconds → Data)

public enum EpochBytes {
    /// Seconds since 1970‑01‑01 UTC (Int64)
    public static func secondsSinceEpoch(_ date: Date) -> Int64 {
        Int64(date.timeIntervalSince1970.rounded(.down))
    }

    /// Big‑endian Data for network/binary protocols
    public static func dataBigEndian(_ seconds: Int64) -> Data {
        var be = seconds.bigEndian
        return withUnsafeBytes(of: &be) { Data($0) }
    }

    /// Little‑endian Data (some BLE specs)
    public static func dataLittleEndian(_ seconds: Int64) -> Data {
        var le = seconds.littleEndian
        return withUnsafeBytes(of: &le) { Data($0) }
    }
}

// MARK: - PhoneKeyAcl mocks & conveniences

public extension PhoneKeyAcl {

    /// A simple deterministic byte array (0x00, 0x01, 0x02, …) of given length.
    private static func sequentialBytes(_ count: Int, start: UInt8 = 0) -> Data {
        Data((0..<count).map { UInt8((Int(start) + $0) & 0xFF) })
    }

    /// Permissions with convenient defaults (all enabled)
    private static func defaultPermissions() -> PhoneKeyAcl.Permissions {
        .init(unlock: true, overrideOverlock: true)
    }

    /// Create a mock ACL with **Ed25519** metadata (32‑byte public key, 64‑byte signature).
    static func mockEd25519(
        now: Date = Date(),
        lockMac: String = "AA:BB:CC:DD:EE:FF",
        phoneKeyId: String? = "ed25519-key-0001",
        trackingId: String? = "1",
        includeSignature: Bool = true
    ) -> PhoneKeyAcl {

        let issuedAt = now
        let expiresAt = now.addingTimeInterval(72 * 3600) // +72h
        let schedule: [Schedule]? = [
            Schedule(start: Date(), end: Date().addingTimeInterval(24 * 3600)),
        ]

        // 32-byte Ed25519 public key → Base64
        let pub32 = sequentialBytes(32, start: 0x11).base64EncodedString()

        return PhoneKeyAcl(
            trackingId: trackingId,
            lockMac: lockMac,
            phonePublicKey: pub32,
            issuedAt: issuedAt,
            expiresAt: expiresAt,
            schedule: schedule,
            permissions: defaultPermissions()
        )
    }

    /// Create a mock ACL with **ECDSA P‑256** metadata.
    static func mockP256(
        now: Date = Date(),
        lockMac: String = "AA:BB:CC:DD:EE:FF",
        phoneKeyId: String? = "p256-key-0001",
        trackingId: String? = "2",
        p256PublicKeyLength: Int = 65,
        includeSignature: Bool = true
    ) -> PhoneKeyAcl {

        let issuedAt = now
        let expiresAt = now.addingTimeInterval(48 * 3600) // +48h
        let schedule: [Schedule]? = [
            Schedule(start: Date(), end: Date().addingTimeInterval(24 * 3600)),
        ]

        // Build a plausible public key buffer.
        var pub = Data()
        if p256PublicKeyLength == 65 {
            pub.append(0x04)
            pub.append(sequentialBytes(64, start: 0x21))
        } else {
            pub = sequentialBytes(p256PublicKeyLength, start: 0x31)
        }

        return PhoneKeyAcl(
            trackingId: trackingId,
            lockMac: lockMac,
            phonePublicKey: pub.base64EncodedString(),
            issuedAt: issuedAt,
            expiresAt: expiresAt,
            schedule: schedule,
            permissions: defaultPermissions()
        )
    }

    // MARK: - JSON convenience for mocks (mirror server: ISO strings)

    /// JSON-encoded bytes for a mock Ed25519 ACL (ISO8601 UTC strings).
    static func mockEd25519JSON(now: Date = Date()) throws -> Data {
        let acl = mockEd25519(now: now)
        let enc = JSONISO8601.encoder() // emits ISO8601 strings
        return try enc.encode(acl)
    }

    /// JSON-encoded bytes for a mock P-256 ACL (ISO8601 UTC strings).
    static func mockP256JSON(now: Date = Date(), p256PublicKeyLength: Int = 65) throws -> Data {
        let acl = mockP256(now: now, p256PublicKeyLength: p256PublicKeyLength)
        let enc = JSONISO8601.encoder() // emits ISO8601 strings
        return try enc.encode(acl)
    }

    /// Produce mock ACL raw bytes of any length (replace with real base64-decoded ACL later).
    static func mockAclRawBytes(length: Int, start: UInt8 = 0x00) -> Data {
        sequentialBytes(length, start: start)
    }

    /// Build ACL JSON string (legacy util). Prefer using Codable above for real data.
    /// (Kept for reference/testing; emits epoch seconds—only use if a specific endpoint requires it.)
    static func makeAclJsonString(
        lockMac: String = "AA:BB:CC:DD:EE:FF",
        phoneKeyId: String? = "p256-key-0001",
        trackingId: String? = "2",
        issuedAt: Date = Date(),
        expiresAt: Date = Date().addingTimeInterval(48 * 3600),
        schedule: String? = "697A332A-697AA300,697B75F0-697B84AA"
    ) -> String {
        return "{ \"trackingId\": \(trackingId ?? "null"), " +
        "\"lockMac\": \"\(lockMac)\", " +
        "\"phonePubKey\": \"\(phoneKeyId ?? "null")\", " +
        "\"issuedAt\": \"\(ISO8601.string(from: issuedAt))\", " +
        "\"expiresAt\": \"\(ISO8601.string(from: expiresAt))\", " +
        "\"schedule\": \(schedule != nil ? "\"\(schedule!)\"" : "null"), " +
        "\"permissions\": [\"unlock\",\"overrideOverlock\"] }"
    }

    /// Create the BLE payload: Base64(ACL JSON) + Base64(signature)
    /// Returns (aclJsonBytes, payloadBytes)
    static func makeAclPayloadWithSignature(
        keyManager: PhoneKeyManager
    ) throws -> (aclJson: Data, payload: Data, aclLengthForHeader: Int, signature: Data) {
        let jsonString = makeAclJsonString()
        let jsonData = Data(jsonString.utf8)

        // Sign the JSON bytes
        let signatureBytes = try keyManager.sign(jsonData, userId: "")

        let aclB64 = jsonData.base64EncodedString()          // ASCII
        let sigB64 = signatureBytes.base64EncodedString()    // ASCII

        // Per protocol: append signature at the end, back-to-back (NO delimiter)
        let concatenated = aclB64 + sigB64

        // Payload to send over BLE is the UTF-8 bytes of that ASCII string
        let payload = Data(concatenated.utf8)

        // IMPORTANT: the final-chunk 4 hex digits are the ACL length BYTES (not base64 length)
        let aclLengthForHeader = jsonData.count

        return (aclJson: jsonData, payload: payload, aclLengthForHeader: aclLengthForHeader, signature: signatureBytes)
    }

    /// Build fixed 128-byte ACL frames (for BLE chunking).
    static func buildAclFrames128(
        acl: Data,
        chunkSize: Int = 128,
        lastTag: UInt8 = 0xFF,
        lengthForFinalHeader: Int? = nil
    ) -> [Data] {

        func asciiHexLength(_ len: Int) -> Data {
            Data(String(format: "%04X", len).utf8) // 4 ASCII hex chars, uppercase
        }

        precondition(chunkSize >= 16, "chunkSize too small for headers + payload")

        // Final header = 1 byte lastTag + 4 ASCII hex digits
        let signaledLength = lengthForFinalHeader ?? acl.count
        precondition(signaledLength <= 0xFFFF, "lengthForFinalHeader must fit in 4 hex digits")

        let finalHeader = Data([lastTag]) + asciiHexLength(signaledLength)
        let stdPayloadCap  = chunkSize - 1                 // 1-byte header
        let finalPayloadCap = chunkSize - finalHeader.count // 5 bytes header

        var frames: [Data] = []
        var offset = 0
        var seq: UInt8 = 0x00

        // Emit non-final frames until what's left fits into one final frame
        while (acl.count - offset) > finalPayloadCap {
            if seq == lastTag { seq &+= 1 }
            let take = min(stdPayloadCap, acl.count - offset)
            var frame = Data(capacity: chunkSize)
            frame.append(seq)
            frame.append(acl[offset ..< offset + take])

            if frame.count < chunkSize {
                frame.append(Data(count: chunkSize - frame.count))
            }

            frames.append(frame)
            offset += take
            seq &+= 1
        }

        // Emit FINAL frame: [lastTag] + 4 ASCII hex digits + remaining payload + padding
        var lastFrame = Data(capacity: chunkSize)
        lastFrame.append(finalHeader)
        if offset < acl.count {
            lastFrame.append(acl[offset ..< acl.count])
        }
        if lastFrame.count < chunkSize {
            lastFrame.append(Data(count: chunkSize - lastFrame.count))
        }
        frames.append(lastFrame)

        return frames
    }
}

// MARK: - Example usage (for reference)
/*
let sample = """
{
    "result": "success",
    "acl": {
        "trackingId": 1,
        "lockMac": "D5:E0:8D:0C:99:AF",
        "issuedAt": "2026-03-05T20:44:33Z",
        "expiresAt": "2026-03-06T04:59:59Z",
        "schedule": [
            { "start": "2026-03-05T05:00:00Z", "end": "2026-03-06T04:59:00Z" }
        ],
        "phonePubKey": "…",
        "permissions": ["unlock"]
    },
    "aclSignature": "…"
}
""".data(using: .utf8)!

do {
    let env = try JSONDecoder().decode(PhoneKeyAclEnvelope.self, from: sample)
    print("Decoded issuedAt:", env.acl.issuedAt) // Date matching Zulu UTC
    // Re-encode (will emit ISO8601 strings for dates):
    let out = try JSONISO8601.encoder().encode(env.acl)
    print(String(data: out, encoding: .utf8)!)
} catch {
    print("Decode/encode error:", error)
}
*/
