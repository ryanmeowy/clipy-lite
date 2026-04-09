import AppKit

@MainActor
final class PasteService {
    private unowned let store: ClipboardStore

    init(store: ClipboardStore) {
        self.store = store
    }

    @discardableResult
    func copy(item: ClipboardItem, plainTextOnly: Bool) -> Bool {
        store.writeToPasteboard(item: item, plainTextOnly: plainTextOnly)
    }

    @discardableResult
    func pasteCurrentClipboard() -> Bool {
        guard
            let source = CGEventSource(stateID: .hidSystemState),
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}
