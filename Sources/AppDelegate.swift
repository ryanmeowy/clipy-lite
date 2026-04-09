import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings.shared

    private lazy var store = ClipboardStore(maxItems: settings.maxHistoryCount)
    private let monitor = ClipboardMonitor()
    private let hotKeyManager = HotKeyManager()
    private let panelController = ClipboardPanelController()
    private lazy var pasteService = PasteService(store: store)

    private var statusItem: NSStatusItem?
    private var settingsWindowController: SettingsWindowController?
    private var previousActiveApp: NSRunningApplication?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        store.load()
        configureStatusItem()
        configurePanel()
        configureMonitor()
        configureHotKey()
        panelController.setCompactMode(settings.compactMode)
        panelController.refresh(items: store.items)
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        hotKeyManager.unregister()
    }

    private func configureStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = statusItem

        if let button = statusItem.button {
            button.image = StatusBarIconFactory.makeClipyLikeImage()
            button.toolTip = "Clipy Lite"
            button.target = self
            button.action = #selector(handleStatusItemClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func configurePanel() {
        panelController.onCopyRequest = { [weak self] item, plainTextOnly in
            guard let self else { return false }

            let ignoredSignature = makeIgnoredSignature(for: item, plainTextOnly: plainTextOnly)
            monitor.ignoreNext(signature: ignoredSignature)

            let copied = pasteService.copy(item: item, plainTextOnly: plainTextOnly)

            guard copied else {
                return false
            }

            store.markCopied(id: item.id)
            panelController.refresh(items: store.items)
            return true
        }

        panelController.onDeleteRequest = { [weak self] item in
            guard let self else { return }
            store.remove(id: item.id)
            panelController.refresh(items: store.items)
        }

        panelController.onPinToggleRequest = { [weak self] item in
            guard let self else { return }
            store.togglePinned(id: item.id)
            panelController.refresh(items: store.items)
        }

        panelController.onClearAllRequest = { [weak self] in
            guard let self else { return }
            store.clear()
            panelController.refresh(items: store.items)
        }

        panelController.onOpenSettings = { [weak self] in
            self?.showSettings()
        }

        panelController.onCloseAfterCopy = { [weak self] mode in
            guard let self else { return }
            let shouldAutoPaste = (mode == .quickCopy) && settings.quickCopyAutoPaste
            self.restoreFocusToPreviousApp(autoPaste: shouldAutoPaste)
        }

        panelController.onQuit = {
            NSApp.terminate(nil)
        }

        panelController.previewImageProvider = { [weak self] item in
            self?.store.previewImage(for: item)
        }
    }

    private func configureMonitor() {
        monitor.onContentChange = { [weak self] content in
            guard let self else { return }
            let inserted = store.add(content: content)
            if inserted {
                panelController.refresh(items: store.items)
            }
        }

        monitor.start()
    }

    private func configureHotKey() {
        hotKeyManager.onHotKeyPressed = { [weak self] in
            self?.capturePreviousActiveApp()
            self?.panelController.present(mode: .quickCopy)
        }
        hotKeyManager.register(shortcut: settings.hotKeyShortcut)
    }

    @objc
    private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            return
        }

        if event.type == .rightMouseUp {
            showStatusMenu(for: sender)
            return
        }
        panelController.toggleVisibility(mode: .normal)
    }

    private func showStatusMenu(for button: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            return
        }

        let menu = NSMenu(title: "Clipy Lite")
        let openItem = NSMenuItem(title: "Open Clipboard", action: #selector(openClipboardFromMenu), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettingsFromMenu), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitFromMenu), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        NSMenu.popUpContextMenu(menu, with: event, for: button)
    }

    private func showSettings() {
        if settingsWindowController == nil {
            let initialLaunchAtLogin = LaunchAtLoginManager.shared.isEnabled()
            let controller = SettingsWindowController(
                currentLaunchAtLogin: initialLaunchAtLogin,
                currentMaxHistory: settings.maxHistoryCount,
                currentHotKey: settings.hotKeyShortcut,
                currentQuickCopyAutoPaste: settings.quickCopyAutoPaste,
                currentCompactMode: settings.compactMode
            )
            controller.onLaunchAtLoginChanged = { [weak self, weak controller] enabled in
                guard let self else { return }
                do {
                    try LaunchAtLoginManager.shared.setEnabled(enabled)
                    settings.launchAtLogin = enabled
                } catch {
                    controller?.updateLaunchAtLoginUI(LaunchAtLoginManager.shared.isEnabled())
                    presentSettingsErrorAlert(message: "Failed to update launch-at-login setting.")
                }
            }
            controller.onMaxHistoryChanged = { [weak self] maxCount in
                guard let self else { return }
                settings.maxHistoryCount = maxCount
                store.setMaxItems(maxCount)
                panelController.refresh(items: store.items)
            }
            controller.onHotKeyChanged = { [weak self] shortcut in
                guard let self else { return }
                settings.hotKeyShortcut = shortcut
                hotKeyManager.register(shortcut: shortcut)
            }
            controller.onQuickCopyAutoPasteChanged = { [weak self] enabled in
                guard let self else { return }
                settings.quickCopyAutoPaste = enabled
            }
            controller.onCompactModeChanged = { [weak self] enabled in
                guard let self else { return }
                settings.compactMode = enabled
                panelController.setCompactMode(enabled)
            }
            settingsWindowController = controller
        }
        settingsWindowController?.showAndFocus()
    }

    private func capturePreviousActiveApp() {
        let candidate = NSWorkspace.shared.frontmostApplication
        guard candidate?.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return
        }
        previousActiveApp = candidate
    }

    private func restoreFocusToPreviousApp(autoPaste: Bool) {
        guard let previousActiveApp else {
            return
        }

        self.previousActiveApp = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
            previousActiveApp.activate(options: [.activateIgnoringOtherApps])
            guard autoPaste else {
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                _ = self?.pasteService.pasteCurrentClipboard()
            }
        }
    }

    private func makeIgnoredSignature(for item: ClipboardItem, plainTextOnly: Bool) -> String {
        guard plainTextOnly, let plainText = item.plainTextRepresentation else {
            return item.signature
        }
        return "text:\(Hashing.sha256Hex(for: plainText))"
    }

    private func presentSettingsErrorAlert(message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Settings"
        alert.informativeText = message
        alert.runModal()
    }

    @objc
    private func openClipboardFromMenu() {
        panelController.present(mode: .normal)
    }

    @objc
    private func openSettingsFromMenu() {
        showSettings()
    }

    @objc
    private func quitFromMenu() {
        NSApp.terminate(nil)
    }
}
