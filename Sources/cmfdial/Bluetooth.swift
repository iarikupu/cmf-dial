import Foundation
import IOBluetooth

func pairedDevices() -> [IOBluetoothDevice] {
    (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
}

func findDevice(address: String?) -> IOBluetoothDevice? {
    if let a = address, !a.isEmpty { return IOBluetoothDevice(addressString: a) }
    return pairedDevices().first { ($0.name ?? "").localizedCaseInsensitiveContains("CMF") }
}

struct ServiceInfo {
    let name: String
    let channel: UInt8?
}

func listServices(_ dev: IOBluetoothDevice) -> [ServiceInfo] {
    if !dev.isConnected() { log("Device not connected; trying openConnection()..."); _ = dev.openConnection() }
    dev.performSDPQuery(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(4))
    let records = (dev.services as? [IOBluetoothSDPServiceRecord]) ?? []
    return records.map { rec in
        var ch: BluetoothRFCOMMChannelID = 0
        let hasCh = rec.getRFCOMMChannelID(&ch) == kIOReturnSuccess
        let classes = rec.getAttributeDataElement(0x0001).map { String(describing: $0) } ?? ""
        let name = (rec.getServiceName() ?? "(unnamed)") + (classes.isEmpty ? "" : "  \(classes.replacingOccurrences(of: "\n", with: " "))")
        return ServiceInfo(name: name, channel: hasCh ? ch : nil)
    }
}

/// Opens RFCOMM channels one at a time (IOBluetooth mixes up concurrent opens) and
/// forwards every received frame.
final class RFCOMMLink: NSObject, IOBluetoothRFCOMMChannelDelegate {
    let device: IOBluetoothDevice
    private var channels: [UInt8: IOBluetoothRFCOMMChannel] = [:]
    private var ids: [ObjectIdentifier: UInt8] = [:]
    private var queue: [UInt8] = []
    private var current: UInt8?
    var onData: (UInt8, [UInt8]) -> Void
    var onOpen: ((UInt8) -> Void)?

    init(device: IOBluetoothDevice, onData: @escaping (UInt8, [UInt8]) -> Void) {
        self.device = device
        self.onData = onData
    }

    func open(_ id: UInt8) {
        guard channels[id] == nil, current != id, !queue.contains(id) else { return }
        queue.append(id)
        next()
    }

    private func next() {
        guard current == nil, !queue.isEmpty else { return }
        let id = queue.removeFirst()
        var ch: IOBluetoothRFCOMMChannel?
        let r = device.openRFCOMMChannelAsync(&ch, withChannelID: id, delegate: self)
        if r == kIOReturnSuccess, let ch = ch {
            current = id
            ids[ObjectIdentifier(ch)] = id
            channels[id] = ch
            // Don't stall the queue if the open never completes.
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
                guard let self = self, self.current == id else { return }
                log("RFCOMM ch \(id): open timed out")
                self.channels[id]?.close()
                self.channels[id] = nil
                self.current = nil
                self.next()
            }
        } else {
            log("RFCOMM ch \(id): open failed (IOReturn 0x\(String(UInt32(bitPattern: r), radix: 16)))")
            next()
        }
    }

    func send(_ id: UInt8, _ bytes: [UInt8]) {
        guard let ch = channels[id] else { return }
        var b = bytes
        ch.writeSync(&b, length: UInt16(b.count))
    }

    private func id(of c: IOBluetoothRFCOMMChannel) -> UInt8 { ids[ObjectIdentifier(c)] ?? c.getID() }

    func rfcommChannelOpenComplete(_ c: IOBluetoothRFCOMMChannel!, status error: IOReturn) {
        let id = self.id(of: c)
        if error == kIOReturnSuccess {
            log("RFCOMM ch \(id): OPEN")
            onOpen?(id)
        } else {
            log("RFCOMM ch \(id): open error 0x\(String(UInt32(bitPattern: error), radix: 16))")
            channels[id] = nil
        }
        if current == id { current = nil }
        next()
    }

    func rfcommChannelData(_ c: IOBluetoothRFCOMMChannel!, data p: UnsafeMutableRawPointer!, length: Int) {
        let bytes = Array(UnsafeBufferPointer(start: p.assumingMemoryBound(to: UInt8.self), count: length))
        onData(id(of: c), bytes)
    }

    func rfcommChannelClosed(_ c: IOBluetoothRFCOMMChannel!) {
        let id = self.id(of: c)
        log("RFCOMM ch \(id): CLOSED")
        channels[id] = nil
    }
}
