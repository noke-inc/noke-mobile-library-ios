//
//  PhoneKeyInfoRequest.swift
//  PhoneKeyCore
//
//  Created by Joffrey Mann on 2/4/26.
//

import Foundation

public struct PhoneKeyInfoRequest: Encodable {
    public let userId: String
    public let phoneUdid: String
    public let publicKey: String
    
    
    enum CodingKeys: String, CodingKey {
        case userId    = "user_id"
        case phoneUdid = "phone_udid"
        case publicKey = "public_key"
    }
    
    public init(userId: String, phoneUdid: String, publicKey: String) {
        self.userId = userId
        self.phoneUdid = phoneUdid
        self.publicKey = publicKey
    }
}
