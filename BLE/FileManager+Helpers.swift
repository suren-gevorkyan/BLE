//
//  FileManager+Helpers.swift
//  BLE
//
//  Created by Suren Gevorkyan on 4/20/21.
//

import Foundation

extension FileManager {
    func createTextFile(withName name: String) -> URL? {
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            return dir.appendingPathComponent(name)
        }
        return nil
    }
    
    @discardableResult
    func writeText(_ text: String, toFileWithPath path: URL) -> Bool {
        var textToWrite = text
        do {
            textToWrite = try String(contentsOf: path, encoding: .utf8)
            textToWrite += text
        } catch {}
        
        if let data = textToWrite.data(using: .utf8) {
            do {
                try data.write(to: path)
                return true
            } catch {
                print("Failed to write text \"\(text)\" to the file. Error: \(error)")
            }
        }
        return false
    }
    
    @discardableResult
    func clearContentsOfFile(withPath path: URL) -> Bool {
        do {
            try removeItem(at: path)
            return true
        } catch {
            print(error)
            return false
        }
    }
}

extension Date {
    func stringWithFormat(_ format: String, timeZone: TimeZone? = .current) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = timeZone
        dateFormatter.dateFormat = format
        return dateFormatter.string(from: self)
    }
}
