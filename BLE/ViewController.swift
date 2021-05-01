//
//  ViewController.swift
//  BLE
//
//  Created by Suren Gevorkyan on 3/16/21.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var startStopScanButon: UIButton!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    
    @IBOutlet weak var loadingView: UIView!
    @IBOutlet weak var loadingMessageLabel: UILabel!
    @IBOutlet weak var loadingIndicatorView: UIActivityIndicatorView!
    
    @IBOutlet weak var shareItem: UIBarButtonItem!
    
    private var timer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        PPBluetoothClient.shared.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let text = try? String(contentsOf: Logger.shared.filePath) {
            shareItem.isEnabled = !text.isEmpty
        } else {
            shareItem.isEnabled = false
        }
    }
    
    @IBAction func startStopScanAction() {
        PPBluetoothClient.shared.isScanning ? stopScanning() : startScanning()
    }
    
    @IBAction func shareLogsAction() {
        let activityVC = UIActivityViewController(activityItems: [Logger.shared.filePath], applicationActivities: nil)
        present(activityVC, animated: true)
    }
    
    private func startScanning() {
        guard !PPBluetoothClient.shared.isScanning else { return }
        
        if PPBluetoothClient.shared.startScanning() {
            loadingIndicator.startAnimating()
            startStopScanButon.setTitle("STOP", for: .normal)
        } else {
            showAlert(withTitle: "Warning", message: "Failed to start scanning for peripherals. Please check your Bluetooth connectivity and try again.")
        }
    }
    
    private func stopScanning() {
        loadingIndicator.stopAnimating()
        startStopScanButon.setTitle("SCAN", for: .normal)
        PPBluetoothClient.shared.stopScanning()
    }
    
    private func setLoadingViewHidden(_ hidden: Bool, message: String? = nil) {
        loadingView.isHidden = hidden
        loadingMessageLabel.text = message
        hidden ? loadingIndicatorView.stopAnimating() : loadingIndicatorView.startAnimating()
    }
}

extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return PPBluetoothClient.shared.foundPeripherals.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: "cell") {
            let p = PPBluetoothClient.shared.foundPeripherals[indexPath.row]
            cell.textLabel?.attributedText = NSAttributedString(string: p.name ?? "unknown", attributes: [.font : UIFont.boldSystemFont(ofSize: 16)])
            cell.detailTextLabel?.text = p.identifier.uuidString
            return cell
        }
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        stopScanning()
        connectToPeripheral(PPBluetoothClient.shared.foundPeripherals[indexPath.row])
    }
    
    private func connectToPeripheral(_ peripheral: CBPeripheral) {
        setLoadingViewHidden(false, message: "Connecting...")
        PPBluetoothClient.shared.connectToPeripheral(peripheral)
        
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { _ in
            self.setLoadingViewHidden(true)
            self.showAlert(withTitle: "Error", message: "Failed to connect to \"\(peripheral.name ?? "unknown")\". Please try again later or select a different peripheral.")
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

extension ViewController: PPBluetoothClientDelegate {
    func peripheralsListUpdated() {
        tableView.reloadData()
    }
    
    func connected(toPeripheral peripheral: CBPeripheral) {
        stopTimer()
        setLoadingViewHidden(true)
        
        let vc = PeripheralViewController.instantiate()
        vc.peripheral = peripheral
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func peripheralDisconnected() {
        setLoadingViewHidden(true)
    }
    
    func failedToConnect(toPeripheral peripheral: CBPeripheral, error: Error?) {
        stopTimer()
        setLoadingViewHidden(true)
        
        let alert = UIAlertController(title: "Error", message: "Failed to connect to peripheral with id \"\(peripheral.identifier.uuidString)\". Error: \(error?.localizedDescription ?? "unknown error")", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        alert.addAction(UIAlertAction(title: "Retry", style: .default) { _ in
            self.connectToPeripheral(peripheral)
        })
        
        present(alert, animated: true)
    }
}
