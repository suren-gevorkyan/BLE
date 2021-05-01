//
//  PeripheralViewController.swift
//  BLE
//
//  Created by Suren Gevorkyan on 3/29/21.
//

import UIKit
import CoreBluetooth

class PeripheralViewController: UIViewController {
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var contentTableView: UITableView!
    
    @IBOutlet weak var actionButtonsStackView: UIStackView!
    @IBOutlet weak var requestScanButton: UIButton!
    @IBOutlet weak var finishButton: UIButton!
    @IBOutlet weak var readButton: UIButton!
    @IBOutlet weak var infoButton: UIButton!
    @IBOutlet weak var deleteAllButton: UIButton!
    
    var peripheral: CBPeripheral!
    
    private var isConnected = true
    private var messages = [PPMessage]()
    private var services = [CBService]()
    private var actionButtons: [UIButton] { [requestScanButton, finishButton, readButton, infoButton, deleteAllButton] }
    
    private var mode: Mode = .selectService {
        didSet {
            contentTableView.reloadData()
            actionButtonsStackView.isHidden = mode != .connected
            
            statusLabel.text = mode.rawValue
            statusLabel.textColor = mode == .disconnected ? .systemRed : .black
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupViews()
        PPBluetoothClient.shared.peripheralDelegate = self
    }
    
    deinit {
        PPBluetoothClient.shared.disconnectFromPeripheral(peripheral)
    }
    
    @IBAction func read() {
        guard isConnected else { return }
        
        sendRequest(ofType: .read)
    }
    
    @IBAction func info() {
        guard isConnected else { return }
        
        sendRequest(ofType: .info)
    }
    
    @IBAction func deleteAll() {
        guard isConnected else { return }
        
        sendRequest(ofType: .deleteAll)
    }
    
    @IBAction func requestScan() {
        guard isConnected else { return }
        
        sendRequest(ofType: .scan)
    }
    
    @IBAction func finish() {
        guard isConnected else { return }
        
        sendRequest(ofType: .finish)
    }
    
    private func sendRequest(ofType type: PPPeripheralRequestResponse, accessPoint: AccessPoint? = nil) {
        guard mode == .connected else { return }
        
        var ap: AccessPoint? = nil
        if let accessPoint = accessPoint {
            ap = AccessPoint(object: accessPoint)
        }
        
        let message = PPBluetoothClient.shared.sendRequest(ofType: type, accessPoint: ap)
        addMessage(message)
    }
    
    private func addMessage(_ message: PPMessage) {
        messages.append(message)
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        contentTableView.insertRows(at: [indexPath], with: .automatic)
        contentTableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
    }
    
    private func setupViews() {
        mode = .selectService
        title = peripheral.identifier.uuidString
        
        if #available(iOS 13, *) {
            deleteAllButton.setImage(UIImage(systemName: "trash"), for: .normal)
        }
        
        let press = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        press.minimumPressDuration = 0.5
        contentTableView.addGestureRecognizer(press)
        
        contentTableView.tableFooterView = UIView()
        contentTableView.estimatedRowHeight = UITableView.automaticDimension
    }
    
    private func connectToWiFi(_ message: PPResponseMessage, accessPoint: AccessPoint) {
        let alert = UIAlertController(title: "Password for \"\(accessPoint.ssid)\"", message: "Enter the password for this network to connect to it.", preferredStyle: .alert)
        
        alert.addTextField { (textField) in
            textField.isSecureTextEntry = true
            textField.placeholder = "wi-fi password"
        }

        alert.addAction(UIAlertAction(title: "Connect", style: .default) { _ in
            if let input = alert.textFields?.first?.text {
                let message = PPBluetoothClient.shared.sendEdit(accessPoint: accessPoint, input: input)
                self.addMessage(message)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        present(alert, animated: true, completion: nil)
    }
    
    @objc private func handleLongPress(_ press: UILongPressGestureRecognizer) {
        guard isConnected else { return }
        
        let location = press.location(in: contentTableView)
        guard let ip = contentTableView.indexPathForRow(at: location),
              messages[ip.row] is PPResponseMessage,
              let accessPoint = messages[ip.row].accessPoint else { return }
        
        if press.state == .began {
            let alert = UIAlertController(title: "Delete access point", message: "Are you sure you want to delete this access point?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
                self.sendRequest(ofType: .delete, accessPoint: accessPoint)
            })
            present(alert, animated: true)
        }
    }
}

extension PeripheralViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return mode == .selectService ? services.count : messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: "cell") {
            cell.textLabel?.numberOfLines = 0
            if mode == .selectService {
                let service = services[indexPath.row]
                cell.textLabel?.text = service.description
            } else {
                let message = messages[indexPath.row]
                cell.backgroundColor = (message is PPResponseMessage) ? .white : .systemBlue
                cell.textLabel?.textColor = (message is PPResponseMessage) ? .black : .white
                cell.textLabel?.text = message.toJSONString(options: [.prettyPrinted])
            }
            return cell
        }
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if mode == .selectService {
            let service = services[indexPath.row]
            if PPBluetoothClient.shared.selectService(service, forPeripheral: peripheral) {
                Logger.shared.logMessage(.info(message: "Connecting to service: \(service)"))
                mode = .connected
            } else {
                let alert = UIAlertController(title: "Warning", message: "This service is not supported. Select another one to connect.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                present(alert, animated: true)
            }
        } else if isConnected {
            let message = messages[indexPath.row]
            if let msg = message as? PPResponseMessage,
               let accessPoint = msg.accessPoint {
                connectToWiFi(msg, accessPoint: accessPoint)
            }
        }
    }
}

extension PeripheralViewController: PPPeripheralDelegate {
    func peripheralDidDisconnect(_ peripheral: CBPeripheral) {
        isConnected = false
        
        title = nil
        mode = .disconnected
    }
    
    func peripheral(_ peripheral: CBPeripheral, didReceiveResponse response: PPResponseMessage) {
        addMessage(response)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices services: [CBService]) {
        guard self.peripheral == peripheral else { return }
        
        self.services = services
        self.contentTableView.reloadData()
    }
    
    func peripheral(_ peripheral: CBPeripheral, didFailToSendRequest: PPRequestMessage) {
        isConnected = false
        statusLabel.text = "Failed to send request"
    }
}


extension UIViewController {
    class func instantiate() -> Self {
        let id = String(describing: self)
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        return storyboard.instantiateViewController(withIdentifier: id) as! Self
    }
    
    func showAlert(withTitle title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default))
        present(alert, animated: true)
    }
}

fileprivate enum Mode: String {
    case connected = "Connected"
    case disconnected = "Disconnected"
    case selectService = "Select a Service"
}
