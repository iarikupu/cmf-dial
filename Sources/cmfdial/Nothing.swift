import Foundation

// Nothing/CMF control protocol on RFCOMM "NTAPP" (channel 16).
// Frame: 55 | 60 01 | cmd(LE16) | len | 00 | opId | payload | CRC16-MODBUS(LE)
// Responses/notifications start 55 20 01. Command IDs and payloads come from the
// community ear-web project (radiance-project/ear-web), cross-checked against captures from real buds.

enum NT {
    static let channel: UInt8 = 16
    static let getGesture: UInt16 = 0xC018
    static let setGesture: UInt16 = 0xF003
    static let dialDevice: UInt8 = 4

    static func crc16(_ bytes: [UInt8]) -> UInt16 {
        var crc: UInt16 = 0xFFFF
        for b in bytes {
            crc ^= UInt16(b)
            for _ in 0..<8 { crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xA001 : crc >> 1 }
        }
        return crc
    }

    static func frame(cmd: UInt16, payload: [UInt8] = [], op: UInt8 = 1) -> [UInt8] {
        var f: [UInt8] = [0x55, 0x60, 0x01, UInt8(cmd & 0xFF), UInt8(cmd >> 8), UInt8(payload.count), 0x00, op] + payload
        let c = crc16(f)
        f += [UInt8(c & 0xFF), UInt8(c >> 8)]
        return f
    }

    /// payload layout (from ear-web): [dev, common, type, action] per entry after a count byte.
    static func decodeGestures(_ f: [UInt8]) -> [(dev: UInt8, common: UInt8, type: UInt8, action: UInt8)] {
        guard f.count > 9 else { return [] }
        let payload = Array(f[8..<(f.count - 2)])
        guard let n = payload.first else { return [] }
        var out: [(UInt8, UInt8, UInt8, UInt8)] = []
        for i in 0..<Int(n) where 1 + i * 4 + 3 < payload.count {
            let o = 1 + i * 4
            out.append((payload[o], payload[o + 1], payload[o + 2], payload[o + 3]))
        }
        return out
    }

    static let typeNames: [UInt8: String] = [1: "single press", 2: "double press", 3: "triple press", 7: "press & hold", 10: "ROTATE"]
    static let actionNames: [UInt8: String] = [1: "no action", 2: "play/pause", 9: "next", 8: "previous", 11: "voice assistant", 17: "low-lag toggle", 23: "VOLUME CONTROL", 3: "answer call", 25: "answer/mute mic", 26: "hang up"]

    /// Splits a received buffer into individual protocol frames.
    static func splitFrames(_ b: [UInt8]) -> [[UInt8]] {
        var out: [[UInt8]] = []
        var i = 0
        while i + 10 <= b.count {
            guard b[i] == 0x55 else { i += 1; continue }
            let total = 8 + Int(b[i + 5]) + 2
            guard i + total <= b.count else { break }
            out.append(Array(b[i..<(i + total)]))
            i += total
        }
        return out
    }

    static func command(_ f: [UInt8]) -> UInt16 { UInt16(f[3]) | UInt16(f[4]) << 8 }
    static let getBattery: UInt16 = 0xC007
    static let batteryNotify: UInt16 = 0xE001
    static let batteryReply: UInt16 = 0x4007
    static let gestureReply: UInt16 = 0x4018

    /// [count, (id, level|0x80 if charging)...] — ids: 2 left, 3 right, 4 case.
    static func decodeBattery(_ f: [UInt8]) -> [UInt8: (level: Int, charging: Bool)] {
        guard f.count > 10 else { return [:] }
        let p = Array(f[8..<(f.count - 2)])
        guard let n = p.first else { return [:] }
        var out: [UInt8: (Int, Bool)] = [:]
        for i in 0..<Int(n) where 2 + i * 2 <= p.count - 1 {
            out[p[1 + i * 2]] = (Int(p[2 + i * 2] & 0x7F), p[2 + i * 2] & 0x80 != 0)
        }
        return out
    }
}
