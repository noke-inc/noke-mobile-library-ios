//
//  PhoneKeyAclRequest.swift
//  PhoneKeyCore
//
//  Created by Joffrey Mann on 2/4/26.
//

import Foundation

/// Request to fetch/build an ACL for a given user/phoneKey against a lock.
/// - Notes:
///   - `userId` and `phoneKeyId` are **Int** in the model.
///   - Decoding accepts **Int** or numeric **String** and normalizes to **Int**.
///   - Encoding emits **Int** for both IDs.
public struct PhoneKeyAclRequest: Codable {
    public let userId: Int
    public let lockMac: String
    public let phoneKeyId: Int
    
    // MARK: - Designated init
    public init(userId: Int, lockMac: String, phoneKeyId: Int) {
        self.userId = userId
        self.lockMac = lockMac
        self.phoneKeyId = phoneKeyId
    }
    
    // MARK: - Codable (resilient to Int/String for IDs)
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // userId: Int or numeric String
        if let i = try? container.decode(Int.self, forKey: .userId) {
            self.userId = i
        } else if let s = try? container.decode(String.self, forKey: .userId),
                  let i = Int(s.trimmingCharacters(in: .whitespacesAndNewlines)) {
            self.userId = i
        } else {
            throw DecodingError.typeMismatch(
                Int.self,
                .init(codingPath: container.codingPath + [CodingKeys.userId],
                      debugDescription: "Expected userId as Int or numeric String.")
            )
        }
        
        // lockMac: String (required)
        self.lockMac = try container.decode(String.self, forKey: .lockMac)
        
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
}
