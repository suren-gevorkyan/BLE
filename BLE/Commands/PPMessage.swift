//
//  PPMessage.swift
//  BLE
//
//  Created by Suren Gevorkyan on 3/29/21.
//

import Foundation

class PPMessage: NSObject {
    let sequence: Int
    var collarId: String? = "a1b2-c3d4"
    var accessPoint: AccessPoint? = nil
    
    var title: String { "" }
    var requiresResponse: Bool { false }
    
    init(sequence: Int, accessPoint: AccessPoint?) {
        self.sequence = sequence
        self.accessPoint = accessPoint
    }
    
    init?(withDictionary dictionary: [String : Any]) {
        if let sequence = dictionary["SEQU"] as? Int {
            self.sequence = sequence
            
            self.collarId = dictionary["COID"] as? String
            
            if let acpo = dictionary["ACPO"] as? [String : Any] {
                self.accessPoint = AccessPoint(withDictionary: acpo)
            }
        } else {
            return nil
        }
    }
    
    func toJSONString(options: JSONSerialization.WritingOptions = []) -> String? {
        var result = [String : Any]()
        result["SEQU"] = sequence
        result["COID"] = collarId
        result["ACPO"] = accessPoint?.toJSONString()
        return result.toString(options: options)
    }
}

class PPRequestMessage: PPMessage {
    let request: PPPeripheralRequestResponse
    
    override var title: String { request.rawValue }
    override var requiresResponse: Bool { request == .scan }
    
    init(sequence: Int, request: PPPeripheralRequestResponse, accessPoint: AccessPoint?) {
        self.request = request
        super.init(sequence: sequence, accessPoint: accessPoint)
    }
    
    override func toJSONString(options: JSONSerialization.WritingOptions = []) -> String? {
        var result = [String : Any]()
        result["SEQU"] = sequence
        result["COID"] = collarId
        result["REQU"] = request.rawValue
        result["ACPO"] = accessPoint?.toJSONString(options: options)
        return result.toString(options: options)
    }
}

class PPResponseMessage: PPMessage {
    let result: Int
    let response: PPPeripheralRequestResponse
    
    override var title: String { response.rawValue }
    
//    init(sequence: Int, response: PPPeripheralRequestResponse, accessPoint: AccessPoint?) {
//        self.response = response
//        super.init(sequence: sequence, accessPoint: accessPoint)
//    }
    
    override init?(withDictionary dictionary: [String : Any]) {
        if let result = dictionary["RSLT"] as? Int,
            let responseStr = dictionary["RESP"] as? String,
            let response = PPPeripheralRequestResponse(rawValue: responseStr) {
            self.result = result
            self.response = response
            super.init(withDictionary: dictionary)
        } else {
            return nil
        }
    }
    
    override func toJSONString(options: JSONSerialization.WritingOptions = []) -> String? {
        var result = [String : Any]()
        result["SEQU"] = sequence
        result["COID"] = collarId
        result["RSLT"] = self.result
        result["RESP"] = response.rawValue
        result["ACPO"] = accessPoint?.toJSONString(options: options)
        return result.toString(options: options)
    }
}

class AccessPoint: Codable {
    let rcpi: Int
    let index: Int
    let count: Int
    let channel: Int
    let ssid: String
    
    var password: String?
    
    init(object: AccessPoint) {
        self.ssid = object.ssid
        self.rcpi = object.rcpi
        self.index = object.index
        self.count = object.count
        self.channel = object.channel
        self.password = object.password
    }
    
    init?(withDictionary dictionary: [String : Any]) {
        if let rcpi = dictionary["RCPI"] as? Int,
           let index = dictionary["INDE"] as?Int,
           let count = dictionary["COUN"] as? Int,
           let channel = dictionary["CHAN"] as? Int,
           let ssid = dictionary["SSID"] as? String {
            self.ssid = ssid
            self.rcpi = rcpi
            self.index = index
            self.count = count
            self.channel = channel
            
            self.password = dictionary["PASS"] as? String
        } else {
            return nil
        }
    }
    
    func toJSONString(options: JSONSerialization.WritingOptions = []) -> String? {
        var result = [String : Any]()
        result["SSID"] = ssid
        result["RCPI"] = rcpi
        result["INDE"] = index
        result["COUN"] = count
        result["CHAN"] = channel
        result["PASS"] = password
        return result.toString(options: options)
    }
}

enum PPPeripheralRequestResponse: String {
    case scan = "SCAN"
    case read = "READ"
    case info = "INFO"
    case edit = "EDIT"
    case finish = "FINISH"
    case delete = "DELETE"
    case deleteAll = "DELETE_ALL"
}
