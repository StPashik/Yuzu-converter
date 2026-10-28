import AppKit
import Carbon
import SwiftUI

struct ShelfShortcut: Codable, Equatable {
    let keyCode: UInt16
    let modifiers: UInt
    static let modifierMask: NSEvent.ModifierFlags = [.control, .option, .shift, .command]
    static let `default` = ShelfShortcut(keyCode: UInt16(kVK_ANSI_C), modifiers: [.command, .shift])!
    private static let functionKeys: [UInt16: String] = [
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15",
        106: "F16", 64: "F17", 79: "F18", 80: "F19", 90: "F20"
    ]

    init?(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers.intersection(Self.modifierMask).rawValue
        guard isValid else { return nil }
    }

    var flags: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiers) }
    var isValid: Bool {
        let supportedKey = (keyCode <= 50 && keyCode != 36 && keyCode != 48) || Self.functionKeys[keyCode] != nil
        // Avoid stealing ordinary typing/editing chords, and work with macOS 15's hotkey restrictions.
        return supportedKey && flags.intersection(Self.modifierMask).rawValue == modifiers &&
            modifiers.nonzeroBitCount >= 2 && !flags.intersection([.command, .control]).isEmpty
    }
    var carbonModifiers: UInt32 {
        var result: UInt32 = 0
        for (flag, value) in [(NSEvent.ModifierFlags.command, cmdKey), (.shift, shiftKey),
                              (.option, optionKey), (.control, controlKey)] where flags.contains(flag) {
            result |= UInt32(value)
        }
        return result
    }

    @MainActor var displayName: String {
        let symbols = [(NSEvent.ModifierFlags.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
            .filter { flags.contains($0.0) }.map(\.1).joined()
        if keyCode == kVK_Space { return symbols + L10n.text("Space") }
        if let name = Self.functionKeys[keyCode] { return symbols + name }
        // Translate the physical key in the current layout instead of storing an English-only letter.
        let source = TISCopyCurrentKeyboardLayoutInputSource().takeRetainedValue()
        guard let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return symbols + "?" }
        let data = unsafeBitCast(pointer, to: CFData.self)
        let layout = UnsafeRawPointer(CFDataGetBytePtr(data)).assumingMemoryBound(to: UCKeyboardLayout.self)
        var state: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)
        let status = UCKeyTranslate(layout, keyCode, UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                                    UInt32(kUCKeyTranslateNoDeadKeysMask), &state, characters.count, &length, &characters)
        return symbols + (status == noErr && length > 0 ? String(utf16CodeUnits: characters, count: length).uppercased() : "?")
    }
}

@MainActor
final class ShelfShortcutController: ObservableObject {
    @Published private(set) var shortcut: ShelfShortcut?
    @Published private(set) var errorMessage: String?
    var onInvoke: (() -> Void)?
    private let defaults: UserDefaults
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var enabled = false
    private static var nextID: UInt32 = 0
    private let identifier: EventHotKeyID

    init(defaults: UserDefaults) {
        self.defaults = defaults
        Self.nextID += 1
        identifier = EventHotKeyID(signature: 0x59757A75, id: Self.nextID)
        if let data = defaults.data(forKey: "shelfShortcut") {
            do {
                let saved = try JSONDecoder().decode(ShelfShortcut?.self, from: data)
                shortcut = saved.map { $0.isValid ? $0 : .default }
            } catch { shortcut = .default }
        } else {
            shortcut = .default
        }
    }

    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }

    func setEnabled(_ enabled: Bool) {
        self.enabled = enabled
        if !enabled {
            if let hotKey { UnregisterEventHotKey(hotKey) }
            hotKey = nil
        } else if hotKey == nil, let shortcut {
            let status = register(shortcut, reference: &hotKey)
            errorMessage = status == noErr ? nil : "This shortcut is unavailable. Record another combination."
        }
    }

    @discardableResult func update(_ value: ShelfShortcut?) -> Bool {
        guard value == nil || value?.isValid == true else { rejectInvalidShortcut(); return false }
        guard value != shortcut else { errorMessage = nil; return true }
        var replacement: EventHotKeyRef?
        if let value, register(value, reference: &replacement) != noErr {
            errorMessage = "This shortcut is unavailable. Record another combination."
            return false
        }
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = replacement
        if !enabled { setEnabled(false) }
        shortcut = value
        defaults.set(try? JSONEncoder().encode(value), forKey: "shelfShortcut")
        errorMessage = nil
        return true
    }

    func rejectInvalidShortcut() {
        errorMessage = "Use a letter, number, Space, or F-key with at least two modifiers, including Command or Control."
    }

    private func register(_ value: ShelfShortcut, reference: inout EventHotKeyRef?) -> OSStatus {
        if handler == nil {
            var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
                guard let event, let context else { return OSStatus(eventNotHandledErr) }
                return MainActor.assumeIsolated {
                    let controller = Unmanaged<ShelfShortcutController>.fromOpaque(context).takeUnretainedValue()
                    var received = EventHotKeyID()
                    guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                            nil, MemoryLayout<EventHotKeyID>.size, nil, &received) == noErr,
                          received.signature == controller.identifier.signature,
                          received.id == controller.identifier.id,
                          controller.enabled, controller.hotKey != nil else { return OSStatus(eventNotHandledErr) }
                    controller.onInvoke?()
                    return noErr
                }
            }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
            guard status == noErr else { return status }
        }
        // Exclusive registration reports conflicts instead of letting two apps act on the same chord.
        return RegisterEventHotKey(UInt32(value.keyCode), value.carbonModifiers, identifier,
                                   GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &reference)
    }
}

struct ShelfShortcutRecorder: NSViewRepresentable {
    @ObservedObject var controller: ShelfShortcutController
    func makeNSView(context: Context) -> ShelfShortcutButton { ShelfShortcutButton(controller: controller) }
    func updateNSView(_ button: ShelfShortcutButton, context: Context) { button.refresh() }
}

@MainActor
final class ShelfShortcutButton: NSButton {
    private let controller: ShelfShortcutController
    private var monitor: Any?
    private var resignObserver: NSObjectProtocol?
    private(set) var isRecording = false
    override var acceptsFirstResponder: Bool { true }

    init(controller: ShelfShortcutController) {
        self.controller = controller
        super.init(frame: .zero)
        bezelStyle = .rounded
        target = self
        action = #selector(beginRecording)
        setAccessibilityLabel(L10n.text("Add Finder selection to shelf"))
        refresh()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
    }

    func refresh() {
        title = isRecording ? L10n.text("Press shortcut…") : controller.shortcut?.displayName ?? L10n.text("Record Shortcut…")
        setAccessibilityLabel(L10n.text("Add Finder selection to shelf"))
        toolTip = L10n.text("Click to record. Escape cancels; Delete disables the shortcut.")
        invalidateIntrinsicContentSize()
    }

    @objc private func beginRecording() {
        if isRecording { finishRecording(); return }
        controller.setEnabled(false)
        isRecording = true
        window?.makeFirstResponder(self)
        refresh()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, isRecording, window === NSApp.keyWindow else { return event }
            keyDown(with: event)
            return nil
        }
        resignObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification,
                                                               object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.finishRecording() }
        }
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { super.keyDown(with: event); return }
        if event.keyCode == kVK_Escape { finishRecording(); return }
        if event.keyCode == kVK_Delete || event.keyCode == kVK_ForwardDelete {
            if controller.update(nil) { finishRecording() }
            return
        }
        guard let value = ShelfShortcut(keyCode: event.keyCode, modifiers: event.modifierFlags) else {
            controller.rejectInvalidShortcut()
            return
        }
        if controller.update(value) { finishRecording() }
    }

    override func resignFirstResponder() -> Bool { finishRecording(); return super.resignFirstResponder() }
    override func viewWillMove(toWindow newWindow: NSWindow?) { finishRecording(); super.viewWillMove(toWindow: newWindow) }

    private func finishRecording() {
        isRecording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        monitor = nil
        resignObserver = nil
        refresh()
    }
}
