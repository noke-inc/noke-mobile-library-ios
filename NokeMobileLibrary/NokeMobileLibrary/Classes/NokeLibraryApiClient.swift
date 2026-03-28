//
//  NokeLibraryApiClient.swift
//  NokeMobileLibrary
//
//  Created by Spencer Apsley on 8/31/18.
//

import Foundation


struct API{
    
    //Endpoints
    static let UPLOAD               = "upload/"
    static let RESTORE              = "restore/"
    static let CONFIRM_RESTORE      = "restore/confirm/"
}

class NokeLibraryApiClient{

    /**
     Makes a web request to the Noke Core API
     
     - Parameters:
     - url: The url for the web request
     - data: The JSON data to send
     */
    internal func doRequest(url: String, jsonData: Data, completionHandler: @escaping(Data?)->()){
        
        var request = URLRequest(url: URL.init(string: url)!)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.addValue(String.init(format: "Bearer %@", NokeDeviceManager.shared().getAPIKey()), forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request){data, response, error in
            guard let data = data, error == nil else{
                return
            }
            
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200{
            }
            
            completionHandler(data)
            
        }
        
        task.resume()
    }
}
