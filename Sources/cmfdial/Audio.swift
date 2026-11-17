import CoreAudio
import Foundation

enum Audio {
    static func defaultOutput() -> AudioDeviceID {
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id)
        return id
    }

    static func string(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String {
        var addr = AudioObjectPropertyAddress(
            mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var cf: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &cf) == noErr, let cf = cf else { return "" }
        return cf.takeRetainedValue() as String
    }

    static func allDevices() -> [AudioDeviceID] {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(0)
        let sys = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(sys, &addr, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(sys, &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    static func hasOutput(_ id: AudioDeviceID) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioObjectPropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(0)
        return AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr && size > 0
    }

    @discardableResult
    static func setDefaultOutput(_ id: AudioDeviceID) -> Bool {
        var dev = id
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        return AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil,
                                          UInt32(MemoryLayout<AudioDeviceID>.size), &dev) == noErr
    }

    static func name(_ id: AudioObjectID) -> String { string(id, kAudioObjectPropertyName) }
    static func uid(_ id: AudioObjectID) -> String { string(id, kAudioDevicePropertyDeviceUID) }

    private static func volumeAddr(_ element: UInt32) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput, mElement: element)
    }

    /// Elements that expose a settable volume: master (0) if present, else channels 1 and 2.
    static func volumeElements(_ id: AudioObjectID) -> [UInt32] {
        for group: [UInt32] in [[0], [1, 2]] {
            let present = group.filter { el in
                var a = volumeAddr(el)
                return AudioObjectHasProperty(id, &a)
            }
            if present.count == group.count { return group }
        }
        return []
    }

    static func getVolume(_ id: AudioObjectID) -> Float? {
        let els = volumeElements(id)
        guard !els.isEmpty else { return nil }
        var total: Float = 0
        for el in els {
            var a = volumeAddr(el)
            var v = Float32(0)
            var size = UInt32(MemoryLayout<Float32>.size)
            guard AudioObjectGetPropertyData(id, &a, 0, nil, &size, &v) == noErr else { return nil }
            total += v
        }
        return total / Float(els.count)
    }

    static func setVolume(_ id: AudioObjectID, _ value: Float) {
        for el in volumeElements(id) {
            var a = volumeAddr(el)
            var v = Float32(max(0, min(1, value)))
            AudioObjectSetPropertyData(id, &a, 0, nil, UInt32(MemoryLayout<Float32>.size), &v)
        }
    }
}

/// Calls `onChange(deviceID, volume)` whenever the default output device's volume changes,
/// and re-attaches itself when the default output device switches.
final class VolumeWatcher {
    private var attached: [(AudioObjectID, AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    private let onChange: (AudioDeviceID, Float) -> Void
    private var defaultListener: AudioObjectPropertyListenerBlock?

    init(onChange: @escaping (AudioDeviceID, Float) -> Void) {
        self.onChange = onChange
        attach()
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.attach() }
        defaultListener = block
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &addr, .main, block)
    }

    private func attach() {
        for (id, var addr, block) in attached { AudioObjectRemovePropertyListenerBlock(id, &addr, .main, block) }
        attached = []
        let dev = Audio.defaultOutput()
        log("Output device: \(Audio.name(dev)) [\(Audio.uid(dev))] volume=\(Audio.getVolume(dev).map { String(format: "%.3f", $0) } ?? "n/a")")
        for el in Audio.volumeElements(dev) {
            var addr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioObjectPropertyScopeOutput, mElement: el)
            let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                guard let v = Audio.getVolume(dev) else { return }
                self?.onChange(dev, v)
            }
            AudioObjectAddPropertyListenerBlock(dev, &addr, .main, block)
            attached.append((dev, addr, block))
        }
    }
}
