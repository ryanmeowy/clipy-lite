import AppKit

enum StatusBarIconFactory {
    static func makeClipyLikeImage() -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let image = NSImage(systemSymbolName: "paperclip", accessibilityDescription: "paperclip")?
            .withSymbolConfiguration(config) ?? NSImage(size: NSSize(width: 18, height: 18))
        image.isTemplate = true
        return image
    }
}
