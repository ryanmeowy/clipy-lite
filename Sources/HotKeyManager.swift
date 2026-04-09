import Carbon

@MainActor
final class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let hotKeyID = UInt32(1)
    private var currentShortcut: HotKeyShortcut?

    var onHotKeyPressed: (() -> Void)?

    func register(shortcut: HotKeyShortcut) {
        currentShortcut = shortcut
        register(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers)
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    private func register(keyCode: UInt32, modifiers: UInt32) {
        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData in
                guard
                    let userData,
                    let eventRef
                else {
                    return noErr
                }

                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                return manager.handleHotKeyEvent(eventRef)
            },
            1,
            &eventType,
            selfPointer,
            &eventHandlerRef
        )

        let eventHotKeyID = EventHotKeyID(signature: OSType(0x434C5059), id: hotKeyID) // CLPY
        RegisterEventHotKey(
            keyCode,
            modifiers,
            eventHotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    private func handleHotKeyEvent(_ eventRef: EventRef) -> OSStatus {
        var pressedHotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            eventRef,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &pressedHotKeyID
        )

        guard status == noErr, pressedHotKeyID.id == hotKeyID else {
            return noErr
        }

        onHotKeyPressed?()
        return noErr
    }
}
