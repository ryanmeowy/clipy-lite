import AppKit

enum StatusBarIconFactory {
    static func makeClipyLikeImage() -> NSImage {
        let canvas = NSSize(width: 18, height: 18)
        let result = NSImage(size: canvas)

        let docConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        let clipConfig = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)

        let docSymbol = NSImage(systemSymbolName: "doc", accessibilityDescription: "file")?
            .withSymbolConfiguration(docConfig)
        let clipSymbol = NSImage(systemSymbolName: "paperclip", accessibilityDescription: "paperclip")?
            .withSymbolConfiguration(clipConfig)

        guard let docSymbol, let clipSymbol else {
            // Last fallback still uses official SF Symbol paperclip shape.
            let fallbackConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
            if
                let base = NSImage(systemSymbolName: "paperclip", accessibilityDescription: "paperclip"),
                let fallback = base.withSymbolConfiguration(fallbackConfig)
            {
                fallback.isTemplate = true
                return fallback
            }
            return result
        }

        result.lockFocus()
        defer {
            result.unlockFocus()
            result.isTemplate = true
        }

        let docRect = NSRect(x: 1.1, y: 1.3, width: 13.2, height: 14.6)
        docSymbol.draw(in: docRect)

        // Make paperclip overlap the file more tightly for a unified silhouette.
        let clipRect = NSRect(x: 6.0, y: 6.0, width: 10.5, height: 10.5)
        clipSymbol.draw(in: clipRect)

        return result
    }
}
