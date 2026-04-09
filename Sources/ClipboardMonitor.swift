import AppKit

@MainActor
final class ClipboardMonitor {
    private let pasteboard: NSPasteboard
    private var timer: Timer?
    private var lastChangeCount: Int
    private var ignoredSignature: String?

    var onContentChange: ((CapturedClipboardContent) -> Void)?

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
        self.lastChangeCount = pasteboard.changeCount
    }

    func start(pollInterval: TimeInterval = 0.4) {
        stop()

        let timer = Timer(timeInterval: pollInterval, target: self, selector: #selector(handleTimerTick), userInfo: nil, repeats: true)
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func ignoreNext(signature: String) {
        ignoredSignature = signature
    }

    @objc
    private func handleTimerTick() {
        poll()
    }

    private func poll() {
        guard pasteboard.changeCount != lastChangeCount else {
            return
        }

        lastChangeCount = pasteboard.changeCount

        guard let captured = readContent() else {
            return
        }

        if let ignoredSignature, ignoredSignature == captured.signature {
            self.ignoredSignature = nil
            return
        }

        ignoredSignature = nil
        onContentChange?(captured)
    }

    private func readContent() -> CapturedClipboardContent? {
        if let urls = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL], !urls.isEmpty {
            let standardized = urls
                .map(\.path)
                .map { URL(fileURLWithPath: $0).standardizedFileURL.path }
                .sorted()
            let signature = "files:\(Hashing.sha256Hex(for: standardized.joined(separator: "\n")))"
            return CapturedClipboardContent(signature: signature, payload: .files(urls))
        }

        if
            let tiffData = pasteboard.data(forType: .tiff),
            let image = NSImage(data: tiffData),
            let imageData = image.pngData()
        {
            let signature = "image:\(Hashing.sha256Hex(for: imageData))"
            return CapturedClipboardContent(signature: signature, payload: .imagePNGData(imageData))
        }

        if let text = pasteboard.string(forType: .string) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return nil
            }

            let signature = "text:\(Hashing.sha256Hex(for: text))"
            return CapturedClipboardContent(signature: signature, payload: .text(text))
        }

        return nil
    }
}

private extension NSImage {
    func pngData() -> Data? {
        guard
            let tiffData = tiffRepresentation,
            let bitmapRep = NSBitmapImageRep(data: tiffData)
        else {
            return nil
        }

        return bitmapRep.representation(using: .png, properties: [:])
    }
}
