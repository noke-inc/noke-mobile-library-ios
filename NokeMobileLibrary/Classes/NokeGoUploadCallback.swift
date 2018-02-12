//
//  NokeGoUploadCallback.swift
//  NokeMobileLibrary
//
//  Created by Spencer Apsley on 1/29/18.
//  Copyright © 2018 Noke. All rights reserved.
//

import UIKit
import Nokego

//Class for handling upload callback from Noke Go Library
class NokeGoUploadCallback: NSObject, NokegoUploadCallbackProtocol {
    
    //Called when the Noke Go Library throws an error
    func receivedUploadError(_ err: String!) {
        NokeDeviceManager.shared().delegate?.nokeErrorDidOccur(error: NokeDeviceManagerError.nokeGoUploadError, message: err, noke:nil)
    }
    
    //Called when the Noke Go Library sends response
    func receivedUploadResponse(_ json: String!) {
        debugPrint(json)
        let data: Data? = json?.data(using: .utf8)
        let jsonData = try? JSONSerialization.jsonObject(with: data!, options: [])
        if let dictionary = jsonData as? [String: Any] {
            let errorCode = dictionary["error_code"] as! Int
            if(errorCode == 0){
                NokeDeviceManager.shared().clearUploadQueue()
            }
            else{
                let error = NokeDeviceManagerError(rawValue: errorCode)
                let message = dictionary["message"] as! String
                NokeDeviceManager.shared().delegate?.nokeErrorDidOccur(error: error!, message: message, noke: nil)
            }
        }
    }
}
