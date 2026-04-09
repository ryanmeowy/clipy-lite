import AppKit

@MainActor
final class SettingsWindowController: NSWindowController {
    var onLaunchAtLoginChanged: ((Bool) -> Void)?
    var onMaxHistoryChanged: ((Int) -> Void)?
    var onHotKeyChanged: ((HotKeyShortcut) -> Void)?
    var onQuickCopyAutoPasteChanged: ((Bool) -> Void)?
    var onCompactModeChanged: ((Bool) -> Void)?

    private let launchAtLoginButton = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)
    private let quickCopyAutoPasteButton = NSButton(checkboxWithTitle: "Quick-copy selection auto paste", target: nil, action: nil)
    private let compactModeButton = NSButton(checkboxWithTitle: "Compact mode (show more rows)", target: nil, action: nil)
    private let maxHistoryField = NSTextField(string: "")
    private let maxHistoryStepper = NSStepper()
    private let hotKeyPopupButton = NSPopUpButton()
    private let accessibilityStatusLabel = NSTextField(labelWithString: "")
    private let accessibilityActionButton = NSButton(title: "Request Permission", target: nil, action: nil)

    init(
        currentLaunchAtLogin: Bool,
        currentMaxHistory: Int,
        currentHotKey: HotKeyShortcut,
        currentQuickCopyAutoPaste: Bool,
        currentCompactMode: Bool
    ) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 336),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.level = .modalPanel
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        super.init(window: window)
        buildUI()
        applyInitialValues(
            launchAtLogin: currentLaunchAtLogin,
            maxHistory: currentMaxHistory,
            hotKey: currentHotKey,
            quickCopyAutoPaste: currentQuickCopyAutoPaste,
            compactMode: currentCompactMode
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showAndFocus() {
        guard let window else {
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        refreshAccessibilityStatus()
    }

    func updateLaunchAtLoginUI(_ enabled: Bool) {
        launchAtLoginButton.state = enabled ? .on : .off
    }

    private func applyInitialValues(
        launchAtLogin: Bool,
        maxHistory: Int,
        hotKey: HotKeyShortcut,
        quickCopyAutoPaste: Bool,
        compactMode: Bool
    ) {
        launchAtLoginButton.state = launchAtLogin ? .on : .off
        quickCopyAutoPasteButton.state = quickCopyAutoPaste ? .on : .off
        compactModeButton.state = compactMode ? .on : .off
        maxHistoryField.stringValue = "\(maxHistory)"
        maxHistoryStepper.integerValue = maxHistory
        hotKeyPopupButton.selectItem(withTitle: hotKey.displayName)
        refreshAccessibilityStatus()
    }

    private func buildUI() {
        guard let contentView = window?.contentView else {
            return
        }

        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            root.topAnchor.constraint(equalTo: contentView.topAnchor),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        let maxHistoryLabel = NSTextField(labelWithString: "Max clipboard history")
        maxHistoryLabel.font = .systemFont(ofSize: 13, weight: .medium)

        maxHistoryField.alignment = .right
        maxHistoryField.controlSize = .regular
        maxHistoryField.target = self
        maxHistoryField.action = #selector(maxHistoryTextCommitted)

        maxHistoryStepper.minValue = 10
        maxHistoryStepper.maxValue = 1000
        maxHistoryStepper.increment = 10
        maxHistoryStepper.target = self
        maxHistoryStepper.action = #selector(maxHistoryStepperChanged)

        launchAtLoginButton.target = self
        launchAtLoginButton.action = #selector(launchAtLoginToggled)

        quickCopyAutoPasteButton.target = self
        quickCopyAutoPasteButton.action = #selector(quickCopyAutoPasteToggled)

        compactModeButton.target = self
        compactModeButton.action = #selector(compactModeToggled)

        let accessibilityLabel = NSTextField(labelWithString: "Accessibility permission")
        accessibilityLabel.font = .systemFont(ofSize: 13, weight: .medium)

        accessibilityStatusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        accessibilityStatusLabel.textColor = .secondaryLabelColor

        accessibilityActionButton.target = self
        accessibilityActionButton.action = #selector(requestAccessibilityPermission)
        accessibilityActionButton.bezelStyle = .rounded

        let hotKeyLabel = NSTextField(labelWithString: "Global shortcut")
        hotKeyLabel.font = .systemFont(ofSize: 13, weight: .medium)

        hotKeyPopupButton.removeAllItems()
        hotKeyPopupButton.addItems(withTitles: HotKeyShortcut.presets.map(\.displayName))
        hotKeyPopupButton.target = self
        hotKeyPopupButton.action = #selector(hotKeyChanged)

        let hotKeyRow = NSStackView(views: [hotKeyLabel, hotKeyPopupButton])
        hotKeyRow.orientation = .horizontal
        hotKeyRow.alignment = .centerY
        hotKeyRow.spacing = 10

        hotKeyPopupButton.translatesAutoresizingMaskIntoConstraints = false
        hotKeyPopupButton.widthAnchor.constraint(equalToConstant: 220).isActive = true

        let maxCountRow = NSStackView(views: [maxHistoryLabel, maxHistoryField, maxHistoryStepper])
        maxCountRow.orientation = .horizontal
        maxCountRow.alignment = .centerY
        maxCountRow.spacing = 10

        let accessibilityRow = NSStackView(views: [accessibilityLabel, accessibilityStatusLabel, NSView(), accessibilityActionButton])
        accessibilityRow.orientation = .horizontal
        accessibilityRow.alignment = .centerY
        accessibilityRow.spacing = 10

        maxHistoryField.translatesAutoresizingMaskIntoConstraints = false
        maxHistoryField.widthAnchor.constraint(equalToConstant: 80).isActive = true

        let hintLabel = NSTextField(labelWithString: "Changes apply immediately.")
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.font = .systemFont(ofSize: 12)

        let stack = NSStackView(views: [launchAtLoginButton, quickCopyAutoPasteButton, compactModeButton, hotKeyRow, maxCountRow, accessibilityRow, hintLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 20),
        ])
    }

    @objc
    private func launchAtLoginToggled() {
        onLaunchAtLoginChanged?(launchAtLoginButton.state == .on)
    }

    @objc
    private func quickCopyAutoPasteToggled() {
        onQuickCopyAutoPasteChanged?(quickCopyAutoPasteButton.state == .on)
    }

    @objc
    private func compactModeToggled() {
        onCompactModeChanged?(compactModeButton.state == .on)
    }

    @objc
    private func maxHistoryStepperChanged() {
        let value = maxHistoryStepper.integerValue
        maxHistoryField.stringValue = "\(value)"
        onMaxHistoryChanged?(value)
    }

    @objc
    private func maxHistoryTextCommitted() {
        let parsed = Int(maxHistoryField.stringValue) ?? 120
        let clamped = max(10, min(1000, parsed))
        maxHistoryField.stringValue = "\(clamped)"
        maxHistoryStepper.integerValue = clamped
        onMaxHistoryChanged?(clamped)
    }

    @objc
    private func hotKeyChanged() {
        let selected = hotKeyPopupButton.titleOfSelectedItem ?? HotKeyShortcut.default.displayName
        guard let shortcut = HotKeyShortcut.presets.first(where: { $0.displayName == selected }) else {
            return
        }
        onHotKeyChanged?(shortcut)
    }

    @objc
    private func requestAccessibilityPermission() {
        let alreadyGranted = PermissionManager.isAccessibilityGranted()
        if alreadyGranted {
            _ = PermissionManager.openAccessibilitySettings()
        } else {
            let granted = PermissionManager.isAccessibilityGranted(prompt: true)
            if !granted {
                _ = PermissionManager.openAccessibilitySettings()
            }
        }
        refreshAccessibilityStatus()
    }

    private func refreshAccessibilityStatus() {
        let granted = PermissionManager.isAccessibilityGranted()
        if granted {
            accessibilityStatusLabel.stringValue = "Granted"
            accessibilityStatusLabel.textColor = .systemGreen
            accessibilityActionButton.title = "Open Settings"
        } else {
            accessibilityStatusLabel.stringValue = "Not Granted (required for auto paste)"
            accessibilityStatusLabel.textColor = .systemOrange
            accessibilityActionButton.title = "Request Permission"
        }
    }
}
