//
//  Encodable.swift
//  PhoneKeyCore
//
//  Created by Joffrey Mann on 2/6/26.
//

import Foundation

extension Encodable {
    /// JSON string for the request (pretty or compact).
    @inlinable
    public func toJSONString(prettyPrinted: Bool = false) throws -> String {
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting.insert(.prettyPrinted)
        }
        // Ensure stable key order if you want deterministic snapshots/logs (iOS 11+ / Swift 5.5+).
        if #available(iOS 13.0, macOS 10.15, *) {
            encoder.outputFormatting.insert(.sortedKeys)
        }
        let data = try encoder.encode(self)
        guard let json = String(data: data, encoding: .utf8) else {
            throw EncodingError.invalidValue(
                self,
                .init(codingPath: [],
                      debugDescription: "Failed to create UTF-8 string from encoded JSON.")
            )
        }
        return json
    }
}
