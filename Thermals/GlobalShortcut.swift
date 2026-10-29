import Carbon
import Foundation
import Observation

enum ShortcutKey: String, FlapTabOption {
    case off, t, h
    var title: String { rawValue.uppercased() }
    var keyCode: UInt32? {
        switch self { case .off: nil; case .t: UInt32(kVK_ANSI_T); case .h: UInt32(kVK_ANSI_H) }
    }
}

@MainActor @Observable
final class GlobalShortcut {
    static let storageKey = "globalShortcut"
    private(set) var selected: ShortcutKey = .off
    private(set) var error: String?
    @ObservationIgnored private var registration: EventHotKeyRef?
    @ObservationIgnored private var handler: EventHandlerRef?
    @ObservationIgnored private let action: () -> Void
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard, action: @escaping () -> Void) {
        self.defaults = defaults
        self.action = action
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                    nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier) == noErr,
                  identifier.signature == 0x5448524D else { return OSStatus(eventNotHandledErr) }
            MainActor.assumeIsolated { Unmanaged<GlobalShortcut>.fromOpaque(context).takeUnretainedValue().action() }
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
        if status == noErr {
            set(ShortcutKey(rawValue: defaults.string(forKey: Self.storageKey) ?? "t") ?? .off)
        } else { error = "Global shortcuts are unavailable (\(status))." }
    }

    func set(_ key: ShortcutKey) {
        if let registration { UnregisterEventHotKey(registration) }
        registration = nil
        selected = key
        defaults.set(key.rawValue, forKey: Self.storageKey)
        error = nil
        guard let code = key.keyCode else { return }
        guard handler != nil else { error = "Global shortcuts are unavailable. Restart Thermals to retry."; return }
        let status = RegisterEventHotKey(code, UInt32(controlKey | optionKey), EventHotKeyID(signature: 0x5448524D, id: 1),
                                        GetApplicationEventTarget(), 0, &registration)
        if status != noErr { error = "Control + Option + \(key.title) could not be registered (\(status)). Choose another key or turn it off." }
    }

    func stop() {
        if let registration { UnregisterEventHotKey(registration) }
        if let handler { RemoveEventHandler(handler) }
        registration = nil
        handler = nil
    }
}
