import AppKit
import CoreGraphics

/// Watches system media keys (play/pause, next, previous). Bluetooth earbud buttons — including the
/// case dial's presses once the buds are set to Play/Pause, Next, Previous — arrive as these events.
/// The handler decides whether to swallow the event.
final class MediaKeyTap {
    /// Events posted by this app carry this value so the tap leaves them alone.
    static let marker: Int64 = 0xC0FFEE

    /// (keyCode, isKeyDown, sourcePID) -> swallow?
    var handler: ((Int, Bool, Int64) -> Bool)?
    private var tap: CFMachPort?

    var isRunning: Bool { tap != nil }

    @discardableResult
    func start() -> Bool {
        if tap != nil { return true }
        let mask = CGEventMask(1 << 14)       // NX_SYSDEFINED
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
            let me = Unmanaged<MediaKeyTap>.fromOpaque(refcon).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let t = me.tap { CGEvent.tapEnable(tap: t, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            guard type.rawValue == 14, let ns = NSEvent(cgEvent: event), ns.subtype.rawValue == 8 else {
                return Unmanaged.passUnretained(event)
            }
            if event.getIntegerValueField(.eventSourceUserData) == MediaKeyTap.marker { return Unmanaged.passUnretained(event) }
            let data1 = ns.data1
            let key = (data1 & 0xFFFF0000) >> 16
            let down = ((data1 & 0xFF00) >> 8) == 0xA
            let pid = event.getIntegerValueField(.eventSourceUnixProcessID)
            let swallow = me.handler?(key, down, pid) ?? false
            return swallow ? nil : Unmanaged.passUnretained(event)
        }
        guard let t = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                        eventsOfInterest: mask, callback: callback,
                                        userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        tap = t
        let src = CFMachPortCreateRunLoopSource(nil, t, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        return true
    }
}
