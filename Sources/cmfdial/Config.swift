import Foundation

struct DialConfig: Codable {
    var up: Action?
    var down: Action?
    /// Put the volume back after each tick so the dial can keep "scrolling" and the
    /// real volume doesn't drift. Turn off if you want the dial to still change volume.
    var restoreVolume: Bool?
}

struct RFCOMMTrigger: Codable {
    var name: String?
    var channel: Int
    var match: String        // hex bytes, "??" = wildcard, matched anywhere inside a frame
    var action: Action
}

struct Config: Codable {
    var deviceAddress: String?
    var deviceName: String?
    var dial: DialConfig?
    var rfcomm: [RFCOMMTrigger]?
}

func loadConfig(path: String) -> Config? {
    guard let data = FileManager.default.contents(atPath: (path as NSString).expandingTildeInPath) else { return nil }
    let d = JSONDecoder()
    d.keyDecodingStrategy = .convertFromSnakeCase
    do { return try d.decode(Config.self, from: data) } catch {
        print("Config error: \(error)")
        return nil
    }
}
