//
//  PhoneKeyInfoResponse.swift
//  PhoneKeyCore
//
//  Created by Joffrey Mann on 2/4/26.
//

import Foundation

public struct PhoneKeyInfoResponse: Codable {
    public let status: String
    public let keyId: Int?
    public let detail: String?
    public let error: String?
    
    enum CodingKeys: String, CodingKey {
        case status
        case keyId = "key_id"
        case detail
        case error
    }
    
    public init(status: String, keyId: Int?, detail: String?, error: String?) {
        self.status = status
        self.keyId = keyId
        self.detail = detail
        self.error = error
    }
}
