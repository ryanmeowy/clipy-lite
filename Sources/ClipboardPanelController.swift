import AppKit

enum ClipboardPanelOpenMode {
    case normal
    case quickCopy
}

@MainActor
final class ClipboardPanelController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    var onCopyRequest: ((ClipboardItem, Bool) -> Bool)?
    var onOpenSettings: (() -> Void)?
    var onQuit: (() -> Void)?
    var onDeleteRequest: ((ClipboardItem) -> Void)?
    var onPinToggleRequest: ((ClipboardItem) -> Void)?
    var onClearAllRequest: (() -> Void)?
    var onCloseAfterCopy: ((ClipboardPanelOpenMode) -> Void)?
    var previewImageProvider: ((ClipboardItem) -> NSImage?)?

    private let searchField = NSSearchField()
    private let tableView = NSTableView()
    private let copyButton = NSButton(title: "Copy", target: nil, action: nil)
    private let plainCopyButton = NSButton(title: "Copy Plain Text", target: nil, action: nil)
    private let pinButton = NSButton(title: "Pin", target: nil, action: nil)
    private let deleteButton = NSButton(title: "Delete", target: nil, action: nil)
    private let clearAllButton = NSButton(title: "Clear All", target: nil, action: nil)

    private var allItems: [ClipboardItem] = []
    private var filteredItems: [ClipboardItem] = []
    private var hasPositionedWindow = false
    private var openMode: ClipboardPanelOpenMode = .normal
    private var isCompactMode = false
    private var isApplyingSelectionProgrammatically = false
    private var keyMonitor: Any?

    init() {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Clipy Lite"
        window.titleVisibility = .visible
        window.isFloatingPanel = true
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.minSize = NSSize(width: 680, height: 420)

        super.init(window: window)
        buildUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func refresh(items: [ClipboardItem]) {
        allItems = items
        applyFilter()
    }

    func setCompactMode(_ enabled: Bool) {
        guard isCompactMode != enabled else {
            return
        }

        isCompactMode = enabled
        tableView.rowHeight = rowHeightForCurrentMode()
        tableView.intercellSpacing = NSSize(width: 0, height: intercellSpacingForCurrentMode())
        tableView.reloadData()
        updateButtonStates()
    }

    func toggleVisibility(mode: ClipboardPanelOpenMode) {
        guard let window else {
            return
        }

        if window.isVisible {
            window.orderOut(nil)
            return
        }
        present(mode: mode)
    }

    func present(mode: ClipboardPanelOpenMode) {
        openMode = mode
        showAndFocus()
    }

    func showAndFocus() {
        guard let window else {
            return
        }

        if !hasPositionedWindow {
            window.center()
            hasPositionedWindow = true
        }

        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(searchField)
        installKeyMonitorIfNeeded()
    }

    private func buildUI() {
        guard let window, let contentView = window.contentView else {
            return
        }

        let background = NSVisualEffectView()
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(background)

        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            background.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            background.topAnchor.constraint(equalTo: contentView.topAnchor),
            background.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        let root = NSView(frame: .zero)
        root.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            root.topAnchor.constraint(equalTo: background.topAnchor),
            root.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])

        let titleLabel = NSTextField(labelWithString: "Clipboard History")
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = .labelColor

        let hintLabel = NSTextField(labelWithString: "Use Up/Down to navigate, Enter to copy, Esc to close")
        hintLabel.font = .systemFont(ofSize: 12, weight: .regular)
        hintLabel.textColor = .secondaryLabelColor

        let titleStack = NSStackView(views: [titleLabel, hintLabel])
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 2

        searchField.placeholderString = "Search text or file names..."
        searchField.delegate = self
        searchField.controlSize = .large

        let settingsButton = NSButton(title: "Settings", target: self, action: #selector(openSettings))
        settingsButton.bezelStyle = .rounded
        settingsButton.controlSize = .large

        let quitButton = NSButton(title: "Quit", target: self, action: #selector(quitApp))
        quitButton.bezelStyle = .rounded
        quitButton.controlSize = .large

        let headerRow = NSStackView(views: [titleStack, NSView(), settingsButton, quitButton])
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 8
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(headerRow)

        searchField.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(searchField)

        let scrollView = NSScrollView(frame: .zero)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        root.addSubview(scrollView)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("clipboard-column"))
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = rowHeightForCurrentMode()
        tableView.intercellSpacing = NSSize(width: 0, height: intercellSpacingForCurrentMode())
        tableView.backgroundColor = .clear
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.action = #selector(handleRowSingleClick)
        tableView.doubleAction = #selector(handleRowDoubleClick)
        scrollView.documentView = tableView

        copyButton.target = self
        copyButton.action = #selector(copySelected)
        copyButton.bezelStyle = .rounded

        plainCopyButton.target = self
        plainCopyButton.action = #selector(copySelectedAsPlainText)
        plainCopyButton.bezelStyle = .rounded

        pinButton.target = self
        pinButton.action = #selector(togglePinSelected)
        pinButton.bezelStyle = .rounded

        deleteButton.target = self
        deleteButton.action = #selector(deleteSelected)
        deleteButton.bezelStyle = .rounded

        clearAllButton.target = self
        clearAllButton.action = #selector(clearAll)
        clearAllButton.bezelStyle = .rounded

        let actionsBar = NSStackView(views: [copyButton, plainCopyButton, pinButton, deleteButton, clearAllButton])
        actionsBar.orientation = .horizontal
        actionsBar.alignment = .centerY
        actionsBar.spacing = 8
        actionsBar.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(actionsBar)

        NSLayoutConstraint.activate([
            headerRow.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 18),
            headerRow.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -18),
            headerRow.topAnchor.constraint(equalTo: root.topAnchor, constant: 14),

            searchField.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 18),
            searchField.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -18),
            searchField.topAnchor.constraint(equalTo: headerRow.bottomAnchor, constant: 12),

            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 12),
            scrollView.bottomAnchor.constraint(equalTo: actionsBar.topAnchor, constant: -12),

            actionsBar.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 18),
            actionsBar.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -18),
            actionsBar.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -14),
        ])

        updateButtonStates()
    }

    private func rowHeightForCurrentMode() -> CGFloat {
        isCompactMode ? 46 : 66
    }

    private func intercellSpacingForCurrentMode() -> CGFloat {
        isCompactMode ? 2 : 6
    }

    private func installKeyMonitorIfNeeded() {
        guard keyMonitor == nil else {
            return
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let window = self.window, window.isKeyWindow else {
                return event
            }

            switch event.keyCode {
            case 53: // Esc
                window.orderOut(nil)
                return nil
            case 36, 76: // Enter
                self.confirmDefaultSelection()
                return nil
            case 125: // Down
                self.moveSelection(by: 1)
                return nil
            case 126: // Up
                self.moveSelection(by: -1)
                return nil
            default:
                return event
            }
        }
    }

    private func applyFilter() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            filteredItems = allItems
        } else {
            filteredItems = allItems.filter {
                $0.searchableText.localizedCaseInsensitiveContains(query) ||
                    $0.displayTitle.localizedCaseInsensitiveContains(query)
            }
        }

        tableView.reloadData()
        if !filteredItems.isEmpty {
            isApplyingSelectionProgrammatically = true
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            isApplyingSelectionProgrammatically = false
        }
        updateButtonStates()
    }

    private func selectedItem() -> ClipboardItem? {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < filteredItems.count else {
            return nil
        }
        return filteredItems[selectedRow]
    }

    private func moveSelection(by delta: Int) {
        guard !filteredItems.isEmpty else {
            return
        }

        let current = tableView.selectedRow >= 0 ? tableView.selectedRow : 0
        let next = max(0, min(filteredItems.count - 1, current + delta))
        tableView.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
        tableView.scrollRowToVisible(next)
    }

    private func updateButtonStates() {
        guard let selected = selectedItem() else {
            copyButton.isEnabled = false
            plainCopyButton.isEnabled = false
            pinButton.isEnabled = false
            deleteButton.isEnabled = false
            clearAllButton.isEnabled = !allItems.isEmpty
            pinButton.title = "Pin"
            return
        }

        copyButton.isEnabled = true
        plainCopyButton.isEnabled = selected.kind == .text && selected.plainTextRepresentation != nil
        pinButton.isEnabled = true
        deleteButton.isEnabled = true
        clearAllButton.isEnabled = !allItems.isEmpty
        pinButton.title = selected.isPinned ? "Unpin" : "Pin"
    }

    private func performCopy(plainTextOnly: Bool, shouldCloseAfterCopy: Bool) {
        guard let item = selectedItem(), let onCopyRequest else {
            return
        }

        let copied = onCopyRequest(item, plainTextOnly)
        if copied, shouldCloseAfterCopy {
            window?.orderOut(nil)
            onCloseAfterCopy?(openMode)
        }
    }

    private func confirmDefaultSelection() {
        switch openMode {
        case .normal:
            performCopy(plainTextOnly: false, shouldCloseAfterCopy: false)
        case .quickCopy:
            performCopy(plainTextOnly: false, shouldCloseAfterCopy: true)
        }
    }

    @objc
    private func handleRowSingleClick() {
        guard openMode == .quickCopy else {
            return
        }
        performCopy(plainTextOnly: false, shouldCloseAfterCopy: true)
    }

    @objc
    private func handleRowDoubleClick() {
        performCopy(plainTextOnly: false, shouldCloseAfterCopy: true)
    }

    @objc
    private func copySelected() {
        performCopy(plainTextOnly: false, shouldCloseAfterCopy: false)
    }

    @objc
    private func copySelectedAsPlainText() {
        guard selectedItem()?.kind == .text else {
            return
        }
        performCopy(plainTextOnly: true, shouldCloseAfterCopy: false)
    }

    @objc
    private func togglePinSelected() {
        guard let item = selectedItem() else {
            return
        }
        onPinToggleRequest?(item)
    }

    @objc
    private func deleteSelected() {
        guard let item = selectedItem() else {
            return
        }
        onDeleteRequest?(item)
    }

    @objc
    private func clearAll() {
        onClearAllRequest?()
    }

    @objc
    private func openSettings() {
        onOpenSettings?()
    }

    @objc
    private func quitApp() {
        onQuit?()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        filteredItems.count
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        if isApplyingSelectionProgrammatically {
            return
        }
        updateButtonStates()
    }

    func controlTextDidChange(_ obj: Notification) {
        applyFilter()
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        ClipboardRowView()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = filteredItems[row]
        let identifier = NSUserInterfaceItemIdentifier("clipboard-row")

        let cellView: ClipboardRowCellView
        if let existing = tableView.makeView(withIdentifier: identifier, owner: self) as? ClipboardRowCellView {
            cellView = existing
        } else {
            cellView = ClipboardRowCellView()
            cellView.identifier = identifier
        }

        let preview = previewImageProvider?(item)
        cellView.configure(
            title: item.displayTitle,
            subtitle: item.displaySubtitle,
            kindText: item.kind.rawValue.capitalized,
            isPinned: item.isPinned,
            image: preview,
            compactMode: isCompactMode
        )
        return cellView
    }
}

private final class ClipboardRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        let selectionRect = bounds.insetBy(dx: 2, dy: 2)
        let color = NSColor.controlAccentColor.withAlphaComponent(0.2)
        color.setFill()
        NSBezierPath(roundedRect: selectionRect, xRadius: 10, yRadius: 10).fill()
    }
}

private final class ClipboardRowCellView: NSTableCellView {
    private let iconContainer = NSView()
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let metaLabel = NSTextField(labelWithString: "")
    private let textStack = NSStackView()
    private var iconWidthConstraint: NSLayoutConstraint?
    private var iconHeightConstraint: NSLayoutConstraint?
    private var metaWidthConstraint: NSLayoutConstraint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        build()
    }

    private func build() {
        translatesAutoresizingMaskIntoConstraints = false

        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.wantsLayer = true
        iconContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.9).cgColor
        iconContainer.layer?.cornerRadius = 8

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.wantsLayer = true
        iconView.layer?.cornerRadius = 6
        iconView.layer?.masksToBounds = true
        iconContainer.addSubview(iconView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 3
        textStack.translatesAutoresizingMaskIntoConstraints = false

        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        metaLabel.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        metaLabel.textColor = .tertiaryLabelColor
        metaLabel.alignment = .right

        addSubview(iconContainer)
        addSubview(textStack)
        addSubview(metaLabel)

        iconWidthConstraint = iconContainer.widthAnchor.constraint(equalToConstant: 44)
        iconHeightConstraint = iconContainer.heightAnchor.constraint(equalToConstant: 44)
        metaWidthConstraint = metaLabel.widthAnchor.constraint(equalToConstant: 88)

        let iconWidthConstraint = self.iconWidthConstraint!
        let iconHeightConstraint = self.iconHeightConstraint!
        let metaWidthConstraint = self.metaWidthConstraint!

        NSLayoutConstraint.activate([
            iconContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            iconContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconWidthConstraint,
            iconHeightConstraint,

            iconView.leadingAnchor.constraint(equalTo: iconContainer.leadingAnchor, constant: 4),
            iconView.trailingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: -4),
            iconView.topAnchor.constraint(equalTo: iconContainer.topAnchor, constant: 4),
            iconView.bottomAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: -4),

            textStack.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: metaLabel.leadingAnchor, constant: -8),

            metaLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            metaLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            metaWidthConstraint,
        ])
    }

    func configure(title: String, subtitle: String, kindText: String, isPinned: Bool, image: NSImage?, compactMode: Bool) {
        titleLabel.stringValue = title
        subtitleLabel.stringValue = subtitle
        iconView.image = image

        if compactMode {
            subtitleLabel.isHidden = true
            metaLabel.stringValue = isPinned ? "PIN" : kindText.prefix(1).uppercased()
            metaLabel.font = .monospacedSystemFont(ofSize: 10, weight: .semibold)
            iconWidthConstraint?.constant = 30
            iconHeightConstraint?.constant = 30
            metaWidthConstraint?.constant = 36
        } else {
            subtitleLabel.isHidden = false
            metaLabel.stringValue = isPinned ? "Pinned · \(kindText)" : kindText
            metaLabel.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
            iconWidthConstraint?.constant = 44
            iconHeightConstraint?.constant = 44
            metaWidthConstraint?.constant = 88
        }
    }
}
