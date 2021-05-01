//
//  Logger.swift
//  BLE
//
//  Created by Suren Gevorkyan on 4/20/21.
//

import Foundation

class Logger {
    static let shared = Logger()
    
    let filePath: URL
    private var didClearPreviousData = false
    
    private init() {
        filePath = FileManager.default.createTextFile(withName: "logs.txt")!
    }
    
    func logMessage(_ message: LoggerMessage) {
        if !didClearPreviousData {
            FileManager.default.clearContentsOfFile(withPath: filePath)
            didClearPreviousData = true
        }
        
        switch message {
        case .info(let message):
            FileManager.default.writeText("LOGGER INFO - \(Date().stringWithFormat("dd MMM, h:mm:ss a")) - \(message)\n", toFileWithPath: filePath)
        case .error(let message):
            FileManager.default.writeText("LOGGER ERROR - \(Date().stringWithFormat("dd MMM, h:mm:ss a")) - \(message)\n", toFileWithPath: filePath)
        case .warning(let message):
            FileManager.default.writeText("LOGGER WARNING - \(Date().stringWithFormat("dd MMM, h:mm:ss a")) - \(message)\n", toFileWithPath: filePath)
        }
    }
}

enum LoggerMessage {
    case info(message: String)
    case error(message: String)
    case warning(message: String)
}
