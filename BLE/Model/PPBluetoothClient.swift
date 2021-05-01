//
//  PPBluetoothClient.swift
//  BLE
//
//  Created by Suren Gevorkyan on 3/25/21.
//

import Foundation
import CoreBluetooth

protocol PPBluetoothClientDelegate: class {
    func peripheralsListUpdated()
    
    func peripheralDisconnected()
    func connected(toPeripheral peripheral: CBPeripheral)
    func failedToConnect(toPeripheral peripheral: CBPeripheral, error: Error?)
}

protocol PPPeripheralDelegate: class {
    func peripheralDidDisconnect(_ peripheral: CBPeripheral)
    func peripheral(_ peripheral: CBPeripheral, didFailToSendRequest: PPRequestMessage)
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices services: [CBService])
    func peripheral(_ peripheral: CBPeripheral, didReceiveResponse response: PPResponseMessage)
}

fileprivate let SERVICE_UUID: CBUUID = CBUUID(string: "55835E90-9CEA-82F6-5BED-FFDE77538BD1")
fileprivate let MESSAGE_UUID: CBUUID = CBUUID(string: "8ec67d3c-d993-82fc-8921-f8d253e0af7e")

class PPBluetoothClient: NSObject {
    static let shared = PPBluetoothClient()
    
    weak var delegate: PPBluetoothClientDelegate?
    weak var peripheralDelegate: PPPeripheralDelegate?
    
    private var client: CBCentralManager!
    
    private var retryCount = 0
    private var sequenceNumber = 0
    private let requestQueue = Queue<PPMessage>()
    private var currentlyExecutingRequest: PPMessage?
    
    private(set) var connectedPeripheral: CBPeripheral? {
        didSet {
            if let p = connectedPeripheral {
                delegate?.connected(toPeripheral: p)
            } else {
                if let oldPeripheral = oldValue {
                    delegate?.peripheralDisconnected()
                    Logger.shared.logMessage(.info(message: "Peripheral (\(oldPeripheral.name ?? "unknown peripheral") disconnected."))
                }
            }
        }
    }
    private(set) var connectedPeripheralCharacteristic: CBCharacteristic?
    
    private(set) var foundPeripherals = [CBPeripheral]() {
        didSet {
            delegate?.peripheralsListUpdated()
        }
    }
    
    var isScanning: Bool { client.isScanning }
    
    private override init() {
        super.init()
        
        client = CBCentralManager(delegate: self, queue: DispatchQueue.main)
    }
    
    func startScanning() -> Bool {
        if client.state == .poweredOn {
            foundPeripherals.removeAll()
            client.scanForPeripherals(withServices: nil)//[SERVICE_UUID])
        }
        
        return client.state == .poweredOn
    }
    
    func stopScanning() {
        client.stopScan()
    }
    
    func connectToPeripheral(_ peripheral: CBPeripheral) {
        client.connect(peripheral)
    }
    
    func selectService(_ service: CBService, forPeripheral peripheral: CBPeripheral) -> Bool {
        if service.uuid != SERVICE_UUID { return false }
        
        peripheral.discoverCharacteristics(nil, for: service)
        return true
    }
    
    func disconnectFromPeripheral(_ peripheral: CBPeripheral) {
        client.cancelPeripheralConnection(peripheral)
        Logger.shared.logMessage(.info(message: "Disconnecting from peripheral (\(peripheral.nameOrPlaceholderText)..."))
    }
    
    @discardableResult
    func sendRequest(ofType type: PPPeripheralRequestResponse, accessPoint: AccessPoint? = nil) -> PPMessage {
        let request = PPRequestMessage(sequence: sequenceNumber, request: type, accessPoint: accessPoint)
        sequenceNumber += 1
        requestQueue.push(request)
        scheduleNextRequest()
        
        return request
    }
    
    @discardableResult
    func sendEdit(accessPoint: AccessPoint, input: String) -> PPMessage {
        let accessPoint = AccessPoint(object: accessPoint)
        accessPoint.password = input
        return sendRequest(ofType: .edit, accessPoint: accessPoint)
    }
    
    private func scheduleNextRequest() {
        guard currentlyExecutingRequest == nil else { return }
        
        guard let request = requestQueue.head(),
              let requestStr = request.toJSONString(),
              let requestData = requestStr.data(using: .utf8) else { return }
            
        guard let peripheral = connectedPeripheral,
              let characteristic = connectedPeripheralCharacteristic else { return }
        
        Logger.shared.logMessage(.info(message: "Sending request of type \(request.title)"))
        currentlyExecutingRequest = request
        if requestData.count <= peripheral.maximumWriteValueLength(for: .withResponse) {
            peripheral.writeValue(requestData, for: characteristic, type: .withResponse)
        } else {
            peripheralDelegate?.peripheral(peripheral, didFailToSendRequest: request as! PPRequestMessage)
            Logger.shared.logMessage(.error(message: "The specified data is larger than the maximum allowed limit(\(peripheral.maximumWriteValueLength(for: .withResponse))."))
        }
    }
}

extension PPBluetoothClient: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
          case .unknown:
            print("central.state is .unknown")
          case .resetting:
            print("central.state is .resetting")
          case .unsupported:
            print("central.state is .unsupported")
          case .unauthorized:
            print("central.state is .unauthorized")
          case .poweredOff:
            print("central.state is .poweredOff")
          case .poweredOn:
            print("central.state is .poweredOn")
        @unknown default:
            print("central.state is unknown")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if foundPeripherals.firstIndex(where: { $0.name == peripheral.name }) == nil {
            foundPeripherals.append(peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        retryCount = 0
        connectedPeripheral = peripheral
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        
        Logger.shared.logMessage(.info(message: "Connected to peripheral(\(peripheral))"))
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectedPeripheral = nil
        peripheralDelegate?.peripheralDidDisconnect(peripheral)
        if let error = error {
            Logger.shared.logMessage(.error(message: "Peripheral (\(peripheral.nameOrPlaceholderText)) disconnected with error: \(error)"))
        } else {
            Logger.shared.logMessage(.info(message: "Peripheral (\(peripheral.nameOrPlaceholderText)) disconnected."))
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        delegate?.failedToConnect(toPeripheral: peripheral, error: error)
        
        Logger.shared.logMessage(.error(message: "Failed to connect to peripheral: \(peripheral.nameOrPlaceholderText). Error: \(error?.localizedDescription ?? "unknown error")"))
    }
}

extension PPBluetoothClient: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        peripheralDelegate?.peripheral(peripheral, didDiscoverServices: services)
        Logger.shared.logMessage(.info(message: "Peripheral (\(peripheral.nameOrPlaceholderText)) did discover services: \(services)"))
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Failed to discover characteristics for service: \(service), with error: \(error)")
            Logger.shared.logMessage(.error(message: "Failed to discover characteristics for service: \(service), with error: \(error)"))
        } else if let characteristics = service.characteristics {
            characteristics.forEach { characteristic in
                if characteristic.properties.contains(.indicate), characteristic.uuid == MESSAGE_UUID {
                    connectedPeripheralCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }
        } else {
            print("Something went wrong")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        print("Peripheral: \(peripheral), didModifyServices invalidatedServices: \(invalidatedServices)")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print(error)
            Logger.shared.logMessage(.error(message: "Failed to update characteristic value with error: \(error)"))
        } else {
            if let data = characteristic.value {
                if let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String : Any],
                   let response = PPResponseMessage(withDictionary: dict) {
                    peripheralDelegate?.peripheral(peripheral, didReceiveResponse: response)
                    Logger.shared.logMessage(.info(message: "Peripheral (\(peripheral.nameOrPlaceholderText)) received data: \(dict)"))
                } else {
                    print("Invalid data received")
                    
                    let dataString = String(data: data, encoding: .utf8) ?? ""
                    Logger.shared.logMessage(.warning(message: "Invalid data received(\(dataString))"))
                }
            }
        }
        
        connectedPeripheralCharacteristic = characteristic
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        connectedPeripheralCharacteristic = characteristic
        
        if let error = error {
            Logger.shared.logMessage(.error(message: "Failed to update notification state for peripheral(\(peripheral.nameOrPlaceholderText)) with error: \(error)"))
        } else {
            Logger.shared.logMessage(.info(message: "Updated notification state for peripheral(\(peripheral.nameOrPlaceholderText))"))
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Failed to write data for peripheral with id = \(peripheral.identifier), error: \(error.localizedDescription). Retrying now...")
            
            retryCount += 1
            if retryCount < 3 {
                currentlyExecutingRequest = nil
                scheduleNextRequest()
                Logger.shared.logMessage(.warning(message: "Something went wrong while sending a request to the peripheral. Error: \(error.localizedDescription). Retrying again..."))
            } else if let req = currentlyExecutingRequest as? PPRequestMessage {
                peripheralDelegate?.peripheral(peripheral, didFailToSendRequest: req)
                Logger.shared.logMessage(.error(message: "Failed to send a request to the peripheral. Error: \(error.localizedDescription)"))
            }
        } else {
            Logger.shared.logMessage(.info(message: "Request successfully sent to the peripheral with name \(peripheral.nameOrPlaceholderText)"))
            if currentlyExecutingRequest != nil {
                requestQueue.pop()
                currentlyExecutingRequest = nil
                
                scheduleNextRequest()
            }
        }
        
        connectedPeripheralCharacteristic = characteristic
    }
}

extension CBPeripheral {
    var nameOrPlaceholderText: String { name ?? "unnamed peripheral" }
}
