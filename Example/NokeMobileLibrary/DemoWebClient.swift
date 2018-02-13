//
//  DemoWebClient.swift
//  coreapi-demo-simple
//
//  Created by Spencer Apsley on 2/6/18.
//  Copyright © 2018 Nokē Inc. All rights reserved.
//

import Foundation
import NokeMobileLibrary

let serverUrl = "https://sampleurlgoeshere"

public protocol DemoWebClientDelegate{
    func didReceiveUnlockResponse(data: Data)
}

public class DemoWebClient: NSObject{
    
    public var delegate: DemoWebClientDelegate?
    static var sharedDemoWebClient: DemoWebClient?
    
    public static func shared()->DemoWebClient{
        if(sharedDemoWebClient == nil){
            sharedDemoWebClient = DemoWebClient.init()
        }
        return sharedDemoWebClient!
    }

    public func requestUnlock(noke: NokeDevice, email: String){
    
        let url = String.init(format:"%@%@", serverUrl, "unlock/")
        var jsonBody = [String: Any]()
        jsonBody["session"] = noke.session
        jsonBody["mac"] = noke.mac
        jsonBody["email"] = email
    
        if(JSONSerialization.isValidJSONObject(jsonBody)){
            guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonBody, options: JSONSerialization.WritingOptions.prettyPrinted) else{return}
            self.doRequest(url: url, jsonData: jsonData)
        }
    }
    
    internal func doRequest(url: String, jsonData: Data){
    
        var request = URLRequest(url: URL.init(string: url)!)
        request.httpMethod = "POST"
        request.httpBody = jsonData
    
        let task = URLSession.shared.dataTask(with: request){data, response, error in
            guard let data = data, error == nil else{
                print("error=\(String(describing: error))")
                return
            }
        
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200{
                print("statusCode should be 200, but is \(httpStatus.statusCode)")
                print("response = \(String(describing: response))")
            }
        
            let responseString = String(data: data, encoding: .utf8)
            print(responseString!)
            if(url.contains("unlock")){
                self.delegate?.didReceiveUnlockResponse(data: data)
            }
        }
        
        task.resume()
    }
    
    public func requestActivity(){
        
        let url = String.init(format:"%@%@", serverUrl, "activity/")
        let jsonBody = [String: Any]()
        
        if(JSONSerialization.isValidJSONObject(jsonBody)){
            guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonBody, options: JSONSerialization.WritingOptions.prettyPrinted) else{return}
            self.doRequest(url: url, jsonData: jsonData)
        }
    }
}
