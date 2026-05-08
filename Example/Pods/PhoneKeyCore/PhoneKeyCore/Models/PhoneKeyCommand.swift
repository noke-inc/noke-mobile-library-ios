//
//  PhoneKeyCommand.swift
//  StorageSmartEntry
//
//  Created by Joffrey Mann on 12/22/25.
//  Copyright © 2025 Noke Inc. All rights reserved.
//

import Foundation

public struct PhoneKeySignedCommand: Codable {
    let commandId: String
    let signature: Data
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.commandId = try container.decode(String.self, forKey: .commandId)
        self.signature = try container.decode(Data.self, forKey: .signature)
    }
    
    public init (commandId: String, signature: Data) {
        self.commandId = commandId
        self.signature = signature
    }
}
