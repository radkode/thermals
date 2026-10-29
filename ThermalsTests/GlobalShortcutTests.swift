import AppKit
import Carbon
import SwiftUI
import Testing
@testable import Thermals

@MainActor @Suite(.serialized)
struct GlobalShortcutTests {
    @Test func registrationPersistsAndConflictsAreVisible() throws {
        let suite = "Thermals.ShortcutTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("off", forKey: GlobalShortcut.storageKey)
        let shortcut = GlobalShortcut(defaults: defaults, action: {})
        defer { shortcut.stop() }
        shortcut.set(.h)
        #expect(shortcut.error == nil)
        #expect(defaults.string(forKey: GlobalShortcut.storageKey) == "h")
        var duplicate: EventHotKeyRef?
        let conflict = RegisterEventHotKey(UInt32(kVK_ANSI_H), UInt32(controlKey | optionKey),
                                          EventHotKeyID(signature: 0x54455354, id: 2), GetApplicationEventTarget(), 0, &duplicate)
        if let duplicate { UnregisterEventHotKey(duplicate) }
        #expect(conflict != noErr)
        shortcut.set(.off)
        var blocker: EventHotKeyRef?
        #expect(RegisterEventHotKey(UInt32(kVK_ANSI_H), UInt32(controlKey | optionKey),
                                    EventHotKeyID(signature: 0x54455354, id: 2), GetApplicationEventTarget(), 0, &blocker) == noErr)
        defer { if let blocker { UnregisterEventHotKey(blocker) } }
        shortcut.set(.h)
        #expect(shortcut.error != nil)
        shortcut.set(.off)
        #expect(shortcut.error == nil)
    }

    @Test func hotkeyEventOpensAndClosesTheOwnedPopover() async throws {
        let suite = "Thermals.ShortcutTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("h", forKey: GlobalShortcut.storageKey)
        let monitor = PreviewMonitors.recordedHeat()
        let controller = StatusItemController(monitor: monitor, updater: Updater(previewing: "0.4.4"), registersShortcut: false)
        defer { controller.stop() }
        for _ in 0..<100 where controller.item.button?.window == nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        _ = try #require(controller.item.button?.window, "The system must attach the status item before it can anchor a popover")
        // AppKit connects the status-item scene asynchronously, after creating its local NSWindow.
        try await Task.sleep(for: .milliseconds(150))
        var invocations = 0
        let shortcut = GlobalShortcut(defaults: defaults) {
            invocations += 1
            controller.toggle()
        }
        defer { shortcut.stop() }
        #expect(shortcut.error == nil)
        var event: EventRef?
        #expect(CreateEvent(nil, OSType(kEventClassKeyboard), UInt32(kEventHotKeyPressed), 0, 0, &event) == noErr)
        let keyEvent = try #require(event)
        defer { ReleaseEvent(keyEvent) }
        var identifier = EventHotKeyID(signature: 0x5448524D, id: 1)
        #expect(SetEventParameter(keyEvent, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                 MemoryLayout<EventHotKeyID>.size, &identifier) == noErr)
        #expect(SendEventToEventTarget(keyEvent, GetApplicationEventTarget()) == noErr)
        #expect(invocations == 1)
        try await Task.sleep(for: .milliseconds(150))
        #expect(controller.popover.isShown)
        let view = try #require(controller.popover.contentViewController?.view)
        #expect(view.frame.width == 400)
        #expect(view.frame.height > 300 && view.frame.height < 736)
        #expect(controller.item.button?.image?.isTemplate == false)
        #expect(SendEventToEventTarget(keyEvent, GetApplicationEventTarget()) == noErr)
        #expect(!controller.popover.isShown)
        #expect(!monitor.samplesProcesses && !monitor.samplesHeatActivity && !monitor.samplesAppMemory)
        controller.toggle()
        #expect(controller.popover.isShown)
        controller.close()
        #expect(!controller.popover.isShown)
    }

    @Test func shortcutSettingsFitAndExposeTheSelectedKey() throws {
        let suite = "Thermals.ShortcutTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("off", forKey: GlobalShortcut.storageKey)
        let shortcut = GlobalShortcut(defaults: defaults, action: {})
        defer { shortcut.stop() }
        let renderer = ImageRenderer(content: PopoverView(monitor: PreviewMonitors.cool(), shortcut: shortcut,
                                                         pinnedBoard: .heat, pinnedUnit: .celsius, previewSettings: true).environment(\.snapshotRendering, true))
        let image = try #require(renderer.cgImage)
        #expect(image.width == 400)
        #expect(image.height < 520)
        if let directory = PopoverSnapshotTests.directory {
            let png = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: directory).appendingPathComponent("shortcut-settings.png"))
        }
    }
}
