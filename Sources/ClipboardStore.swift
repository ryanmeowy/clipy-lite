import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class ClipboardStore {
    private var maxItems: Int
    private let fileManager: FileManager
    let storageURL: URL
    let imageDirectoryURL: URL

    private(set) var items: [ClipboardItem] = []

    init(maxItems: Int, fileManager: FileManager = .default) {
        self.maxItems = max(10, min(1000, maxItems))
        self.fileManager = fileManager

        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")

        let appDirectory = appSupport.appendingPathComponent("ClipyLite", isDirectory: true)
        self.storageURL = appDirectory.appendingPathComponent("history.json")
        self.imageDirectoryURL = appDirectory.appendingPathComponent("images", isDirectory: true)
    }

    func setMaxItems(_ count: Int) {
        maxItems = max(10, min(1000, count))
        reorderPinnedFirst()
        trimOverflow()
        persist()
    }

    func load() {
        ensureDirectories()

        guard fileManager.fileExists(atPath: storageURL.path) else {
            items = []
            return
        }

        do {
            let data = try Data(contentsOf: storageURL)
            let decoded = try JSONDecoder().decode([ClipboardItem].self, from: data)
            items = Array(decoded.prefix(maxItems))
            reorderPinnedFirst()
            cleanupDanglingImages()
        } catch {
            items = []
        }
    }

    @discardableResult
    func add(content: CapturedClipboardContent) -> Bool {
        if let index = items.firstIndex(where: { $0.signature == content.signature }) {
            var existing = items.remove(at: index)
            existing.lastCopiedAt = Date()
            insertAtPriorityPosition(existing)
            persist()
            return true
        }

        let newItem: ClipboardItem
        switch content.payload {
        case let .text(value):
            let sanitized = value.count > 100_000 ? String(value.prefix(100_000)) : value
            newItem = ClipboardItem(kind: .text, signature: content.signature, text: sanitized)
        case let .files(urls):
            let paths = urls.map(\.path)
            guard !paths.isEmpty else {
                return false
            }
            newItem = ClipboardItem(kind: .files, signature: content.signature, filePaths: paths)
        case let .imagePNGData(data):
            guard let imageFileName = saveImage(data: data) else {
                return false
            }
            newItem = ClipboardItem(kind: .image, signature: content.signature, imageFileName: imageFileName)
        }

        insertAtPriorityPosition(newItem)
        trimOverflow()
        persist()
        return true
    }

    func clear() {
        items.forEach(deleteImageFileIfNeeded)
        items.removeAll()
        persist()
    }

    func remove(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return
        }
        let removed = items.remove(at: index)
        deleteImageFileIfNeeded(for: removed)
        persist()
    }

    func togglePinned(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return
        }

        var item = items.remove(at: index)
        item.isPinned.toggle()
        if item.isPinned {
            items.insert(item, at: 0)
        } else {
            let insertion = unpinnedInsertionIndex()
            items.insert(item, at: insertion)
        }
        reorderPinnedFirst()
        persist()
    }

    func item(with id: UUID) -> ClipboardItem? {
        items.first { $0.id == id }
    }

    func markCopied(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return
        }

        var item = items.remove(at: index)
        item.lastCopiedAt = Date()
        insertAtPriorityPosition(item)
        persist()
    }

    func previewImage(for item: ClipboardItem) -> NSImage? {
        switch item.kind {
        case .text:
            return NSImage(systemSymbolName: "text.alignleft", accessibilityDescription: "Text")
        case .files:
            guard let first = item.filePaths?.first else {
                return NSImage(systemSymbolName: "doc", accessibilityDescription: "File")
            }

            // If the copied file itself is an image, show a real thumbnail instead of a generic file icon.
            let fileURL = URL(fileURLWithPath: first)
            if
                let contentType = try? fileURL.resourceValues(forKeys: [.contentTypeKey]).contentType,
                contentType.conforms(to: .image),
                let image = NSImage(contentsOf: fileURL)
            {
                return image
            }

            return NSWorkspace.shared.icon(forFile: first)
        case .image:
            guard let imageURL = imageURL(for: item), let image = NSImage(contentsOf: imageURL) else {
                return NSImage(systemSymbolName: "photo", accessibilityDescription: "Image")
            }
            return image
        }
    }

    func writeToPasteboard(item: ClipboardItem, plainTextOnly: Bool) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if plainTextOnly {
            guard let plainText = item.plainTextRepresentation else {
                return false
            }
            return pasteboard.setString(plainText, forType: .string)
        }

        switch item.kind {
        case .text:
            guard let text = item.text else {
                return false
            }
            return pasteboard.setString(text, forType: .string)
        case .files:
            let urls = (item.filePaths ?? []).map { URL(fileURLWithPath: $0) }
            guard !urls.isEmpty else {
                return false
            }
            return pasteboard.writeObjects(urls as [NSURL])
        case .image:
            guard
                let imageURL = imageURL(for: item),
                let image = NSImage(contentsOf: imageURL)
            else {
                return false
            }
            return pasteboard.writeObjects([image])
        }
    }

    private func saveImage(data: Data) -> String? {
        ensureDirectories()
        let filename = "\(UUID().uuidString).png"
        let fileURL = imageDirectoryURL.appendingPathComponent(filename)

        do {
            try data.write(to: fileURL, options: .atomic)
            return filename
        } catch {
            return nil
        }
    }

    private func trimOverflow() {
        guard items.count > maxItems else {
            return
        }

        let overflow = items.suffix(from: maxItems)
        overflow.forEach(deleteImageFileIfNeeded)
        items = Array(items.prefix(maxItems))
    }

    private func reorderPinnedFirst() {
        let pinned = items.filter(\.isPinned)
        let unpinned = items.filter { !$0.isPinned }
        items = pinned + unpinned
    }

    private func unpinnedInsertionIndex() -> Int {
        items.firstIndex(where: { !$0.isPinned }) ?? items.count
    }

    private func insertAtPriorityPosition(_ item: ClipboardItem) {
        if item.isPinned {
            items.insert(item, at: 0)
            return
        }
        let insertion = unpinnedInsertionIndex()
        items.insert(item, at: insertion)
    }

    private func imageURL(for item: ClipboardItem) -> URL? {
        guard let fileName = item.imageFileName else {
            return nil
        }
        return imageDirectoryURL.appendingPathComponent(fileName)
    }

    private func deleteImageFileIfNeeded(for item: ClipboardItem) {
        guard let imageURL = imageURL(for: item) else {
            return
        }
        try? fileManager.removeItem(at: imageURL)
    }

    private func cleanupDanglingImages() {
        let usedNames = Set(items.compactMap(\.imageFileName))
        guard let files = try? fileManager.contentsOfDirectory(atPath: imageDirectoryURL.path) else {
            return
        }

        for file in files where !usedNames.contains(file) {
            try? fileManager.removeItem(at: imageDirectoryURL.appendingPathComponent(file))
        }
    }

    private func ensureDirectories() {
        let baseDirectory = storageURL.deletingLastPathComponent()
        try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: imageDirectoryURL, withIntermediateDirectories: true)
    }

    private func persist() {
        ensureDirectories()

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(items)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            // Ignore persistence errors to keep the app responsive.
        }
    }
}
