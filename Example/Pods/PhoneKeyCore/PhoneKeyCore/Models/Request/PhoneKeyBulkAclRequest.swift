//
//  PhoneKeyBulkAclRequest.swift
//  StorageSmartEntry
//
//  Created by Joffrey Mann on 3/23/26.
//  Copyright © 2026 Noke Inc. All rights reserved.
//

import Foundation

/// Request to fetch all ACLs for a given phoneKey
public struct PhoneKeyBulkAclRequest: Codable {
    public let phoneKeyId: Int
    
    // MARK: - Designated init
    public init(phoneKeyId: Int) {
        self.phoneKeyId = phoneKeyId
    }
    
    // MARK: - Codable (resilient to Int/String for phoneKeyId)
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // phoneKeyId: Int or numeric String
        if let i = try? container.decode(Int.self, forKey: .phoneKeyId) {
            self.phoneKeyId = i
        } else if let s = try? container.decode(String.self, forKey: .phoneKeyId),
                  let i = Int(s.trimmingCharacters(in: .whitespacesAndNewlines)) {
            self.phoneKeyId = i
        } else {
            throw DecodingError.typeMismatch(
                Int.self,
                .init(codingPath: container.codingPath + [CodingKeys.phoneKeyId],
                      debugDescription: "Expected phoneKeyId as Int or numeric String.")
            )
        }
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(phoneKeyId, forKey: .phoneKeyId)
    }
    
    private enum CodingKeys: String, CodingKey {
        case phoneKeyId
    }
}
