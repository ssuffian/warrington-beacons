//
//  BluetoothService.swift
//  Lions Pride
//
//  Created by Kevin Grainer on 6/17/20.
//  Copyright © 2020 Chariot Solutions. All rights reserved.
//

import Foundation
import CoreBluetooth

// We don't need a BluetoothService to scan for beacons since beacons are CoreLocation
// However, if Bluetooth is disabled, beacon scanning won't work. We can't determine if
// Bluetooth is on or off from CoreLocation so we use the BluetoothManager
class BluetoothService: NSObject, CBCentralManagerDelegate {
    
    static let shared = BluetoothService()
    var manager: CBCentralManager?
    var bluetoothEnabled = false

    override init() {
        super.init()
     
        // Instantiating the manager will prompt the user to enable Bluetooth
        self.manager = CBCentralManager(delegate: self, queue: nil)        
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            self.bluetoothEnabled = true
        default:
            self.bluetoothEnabled = false
        }
    }
    
    var isBluetoothEnabled: Bool {
        get {
            self.bluetoothEnabled
        }
    }
}
