//
//  PhoneKeyCommand.swift
//  StorageSmartEntry
//
//  Created by Joffrey Mann on 12/22/25.
//  Copyright © 2025 Noke Inc. All rights reserved.
//

import Foundation

public struct PhoneKeySignedCommand: Codable {
    public struct Signature: Codable {
        let algorithm: String       // "Ed25519"
        let value: String           // Base64
        
        public init(from decoder: any Decoder) throws {
            let container: KeyedDecodingContainer<PhoneKeySignedCommand.Signature.CodingKeys> = try decoder.container(keyedBy: PhoneKeySignedCommand.Signature.CodingKeys.self)
            self.algorithm = try container.decode(String.self, forKey: PhoneKeySignedCommand.Signature.CodingKeys.algorithm)
            self.value = try container.decode(String.self, forKey: PhoneKeySignedCommand.Signature.CodingKeys.value)
        }
        
        public init(algorithm: String, value: String) {
            self.algorithm = algorithm
            self.value = value
        }
    }
    let commandId: String
    let type: String
    let createdAt: String
    let nonce: String       // Base64 16-32 bytes
    let payload: [String: String]
    public var signature: Signature?
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.commandId = try container.decode(String.self, forKey: .commandId)
        self.type = try container.decode(String.self, forKey: .type)
        self.createdAt = try container.decode(String.self, forKey: .createdAt)
        self.nonce = try container.decode(String.self, forKey: .nonce)
        self.payload = try container.decode([String : String].self, forKey: .payload)
        self.signature = try container.decodeIfPresent(PhoneKeySignedCommand.Signature.self, forKey: .signature)
    }
    
    public init (commandId: String,
          type: String,
          createdAt: String,
          nonce: String,
          payload: [String: String],
          signature: Signature) {
        self.commandId = commandId
        self.type = type
        self.createdAt = createdAt
        self.nonce = nonce
        self.payload = payload
        self.signature = signature
    }
}
