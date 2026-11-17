import Foundation

let logFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss.SSS"
    return f
}()

var logFile: FileHandle?

func log(_ s: String) {
    let line = "[\(logFormatter.string(from: Date()))] \(s)"
    print(line)
    fflush(stdout)
    if let d = (line + "\n").data(using: .utf8) { logFile?.write(d) }
}

func openAppLog() {
    let dir = (NSHomeDirectory() as NSString).appendingPathComponent("Library/Logs")
    let path = (dir as NSString).appendingPathComponent("CMFDial.log")
    if !FileManager.default.fileExists(atPath: path) { FileManager.default.createFile(atPath: path, contents: nil) }
    logFile = FileHandle(forWritingAtPath: path)
    logFile?.seekToEndOfFile()
    log("── app started ──")
}

func openLogFile(prefix: String) {
    try? FileManager.default.createDirectory(atPath: "captures", withIntermediateDirectories: true)
    let f = DateFormatter()
    f.dateFormat = "yyyyMMdd-HHmmss"
    let path = "captures/\(prefix)-\(f.string(from: Date())).log"
    FileManager.default.createFile(atPath: path, contents: nil)
    logFile = FileHandle(forWritingAtPath: path)
    print("Logging to \(path)")
}

func hex(_ bytes: [UInt8]) -> String {
    bytes.map { String(format: "%02x", $0) }.joined(separator: " ")
}

/// Parses "aa 55 ?? 01" into bytes; `nil` entries are wildcards.
func parsePattern(_ s: String) -> [UInt8?] {
    s.split(whereSeparator: { $0 == " " || $0 == ":" }).map { tok in
        tok == "??" || tok == "xx" ? nil : UInt8(tok, radix: 16)
    }
}

func frame(_ bytes: [UInt8], contains pattern: [UInt8?]) -> Bool {
    guard !pattern.isEmpty, bytes.count >= pattern.count else { return false }
    for start in 0...(bytes.count - pattern.count) {
        var ok = true
        for (i, p) in pattern.enumerated() {
            if let p = p, bytes[start + i] != p { ok = false; break }
        }
        if ok { return true }
    }
    return false
}
