import Foundation

extension Notification.Name {
    static let clipySettingsDidChange = Notification.Name("ClipySettingsDidChange")
}

@MainActor
final class AppSettings {
    static let shared = AppSettings()

    private enum Keys {
        static let maxHistoryCount = "maxHistoryCount"
        static let launchAtLogin = "launchAtLogin"
        static let hotKeyShortcutID = "hotKeyShortcutID"
        static let quickCopyAutoPaste = "quickCopyAutoPaste"
        static let compactMode = "compactMode"
    }

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if defaults.object(forKey: Keys.maxHistoryCount) == nil {
            defaults.set(120, forKey: Keys.maxHistoryCount)
        }
        if defaults.object(forKey: Keys.launchAtLogin) == nil {
            defaults.set(false, forKey: Keys.launchAtLogin)
        }
        if defaults.object(forKey: Keys.hotKeyShortcutID) == nil {
            defaults.set(HotKeyShortcut.default.id, forKey: Keys.hotKeyShortcutID)
        }
        if defaults.object(forKey: Keys.quickCopyAutoPaste) == nil {
            defaults.set(true, forKey: Keys.quickCopyAutoPaste)
        }
        if defaults.object(forKey: Keys.compactMode) == nil {
            defaults.set(false, forKey: Keys.compactMode)
        }
    }

    var maxHistoryCount: Int {
        get {
            let value = defaults.integer(forKey: Keys.maxHistoryCount)
            return max(10, min(1000, value))
        }
        set {
            let clamped = max(10, min(1000, newValue))
            defaults.set(clamped, forKey: Keys.maxHistoryCount)
            NotificationCenter.default.post(name: .clipySettingsDidChange, object: nil)
        }
    }

    var launchAtLogin: Bool {
        get {
            defaults.bool(forKey: Keys.launchAtLogin)
        }
        set {
            defaults.set(newValue, forKey: Keys.launchAtLogin)
            NotificationCenter.default.post(name: .clipySettingsDidChange, object: nil)
        }
    }

    var hotKeyShortcut: HotKeyShortcut {
        get {
            let id = defaults.string(forKey: Keys.hotKeyShortcutID) ?? HotKeyShortcut.default.id
            return HotKeyShortcut.from(id: id)
        }
        set {
            defaults.set(newValue.id, forKey: Keys.hotKeyShortcutID)
            NotificationCenter.default.post(name: .clipySettingsDidChange, object: nil)
        }
    }

    var quickCopyAutoPaste: Bool {
        get {
            defaults.bool(forKey: Keys.quickCopyAutoPaste)
        }
        set {
            defaults.set(newValue, forKey: Keys.quickCopyAutoPaste)
            NotificationCenter.default.post(name: .clipySettingsDidChange, object: nil)
        }
    }

    var compactMode: Bool {
        get {
            defaults.bool(forKey: Keys.compactMode)
        }
        set {
            defaults.set(newValue, forKey: Keys.compactMode)
            NotificationCenter.default.post(name: .clipySettingsDidChange, object: nil)
        }
    }
}
