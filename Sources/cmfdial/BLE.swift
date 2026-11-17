import CoreBluetooth
import Foundation

/// Connects to a BLE peripheral by name, dumps its GATT table, subscribes to every
/// notifiable characteristic and logs each value.
final class BLESniffer: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private let nameFilter: String
    private let listAll: Bool
    private var seen = Set<UUID>()

    init(nameFilter: String, listAll: Bool) {
        self.nameFilter = nameFilter
        self.listAll = listAll
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func centralManagerDidUpdateState(_ c: CBCentralManager) {
        log("Bluetooth state: \(c.state.rawValue) (5 = powered on)")
        guard c.state == .poweredOn else {
            if c.state == .unauthorized { log("Bluetooth permission denied: allow your terminal app in System Settings → Privacy & Security → Bluetooth, then re-run.") }
            return
        }
        // Peripherals the system already holds a connection to.
        let known = ["1800", "1801", "180A", "180F"].map { CBUUID(string: $0) }
        for p in c.retrieveConnectedPeripherals(withServices: known) {
            log("Already connected: \(p.name ?? "?") \(p.identifier)")
            consider(p, name: p.name)
        }
        log("Scanning for BLE advertisers (open/close the case lid if nothing shows)...")
        c.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    private func consider(_ p: CBPeripheral, name: String?) {
        guard peripheral == nil, (name ?? "").localizedCaseInsensitiveContains(nameFilter) else { return }
        log("Target found: \(name ?? "?") \(p.identifier) — connecting")
        peripheral = p
        p.delegate = self
        central.stopScan()
        central.connect(p, options: nil)
    }

    func centralManager(_ c: CBCentralManager, didDiscover p: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? p.name
        if listAll, seen.insert(p.identifier).inserted { log("adv: \(name ?? "(no name)") \(p.identifier) rssi=\(rssi)") }
        consider(p, name: name)
    }

    func centralManager(_ c: CBCentralManager, didConnect p: CBPeripheral) {
        log("Connected. Discovering services...")
        p.discoverServices(nil)
    }

    func centralManager(_ c: CBCentralManager, didFailToConnect p: CBPeripheral, error: Error?) {
        log("Connect failed: \(error?.localizedDescription ?? "?")")
    }

    func centralManager(_ c: CBCentralManager, didDisconnectPeripheral p: CBPeripheral, error: Error?) {
        log("Disconnected: \(error?.localizedDescription ?? "clean")")
    }

    func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        for s in p.services ?? [] {
            log("SERVICE \(s.uuid)")
            p.discoverCharacteristics(nil, for: s)
        }
    }

    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor s: CBService, error: Error?) {
        for c in s.characteristics ?? [] {
            var props: [String] = []
            if c.properties.contains(.read) { props.append("read") }
            if c.properties.contains(.write) { props.append("write") }
            if c.properties.contains(.writeWithoutResponse) { props.append("writeNoResp") }
            if c.properties.contains(.notify) { props.append("notify") }
            if c.properties.contains(.indicate) { props.append("indicate") }
            log("  CHAR \(c.uuid) [\(props.joined(separator: ","))] (service \(s.uuid))")
            if c.properties.contains(.notify) || c.properties.contains(.indicate) { p.setNotifyValue(true, for: c) }
            if c.properties.contains(.read) { p.readValue(for: c) }
        }
    }

    func peripheral(_ p: CBPeripheral, didUpdateValueFor c: CBCharacteristic, error: Error?) {
        if let e = error { log("  \(c.uuid) error: \(e.localizedDescription)"); return }
        log("BLE \(c.uuid) = \(hex([UInt8](c.value ?? Data())))")
    }
}
