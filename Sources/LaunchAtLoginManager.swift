import Foundation
import ServiceManagement

enum LaunchAtLoginError: Error {
    case missingExecutable
}

@MainActor
final class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()

    private let label = "com.clipylite.agent"
    private let fileManager: FileManager

    private init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func setEnabled(_ enabled: Bool) throws {
        if try setWithSMAppServiceIfAvailable(enabled) {
            return
        }
        try setWithLaunchAgent(enabled)
    }

    func isEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            let status = SMAppService.mainApp.status
            if status == .enabled {
                return true
            }
        }
        return fileManager.fileExists(atPath: launchAgentURL.path)
    }

    @available(macOS 13.0, *)
    private func setWithSMAppService(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    private func setWithSMAppServiceIfAvailable(_ enabled: Bool) throws -> Bool {
        guard #available(macOS 13.0, *) else {
            return false
        }

        // SMAppService requires app-bundle context; if this app is not bundled, fallback to LaunchAgent.
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            return false
        }

        do {
            try setWithSMAppService(enabled)
            return true
        } catch {
            return false
        }
    }

    private var launchAgentURL: URL {
        let base = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library")
        return base
            .appendingPathComponent("LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(label).plist")
    }

    private func setWithLaunchAgent(_ enabled: Bool) throws {
        let launchAgentsDir = launchAgentURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)

        if enabled {
            guard let executablePath = Bundle.main.executableURL?.path else {
                throw LaunchAtLoginError.missingExecutable
            }

            let payload: [String: Any] = [
                "Label": label,
                "ProgramArguments": [executablePath],
                "RunAtLoad": true,
                "KeepAlive": false,
                "ProcessType": "Background",
            ]
            let data = try PropertyListSerialization.data(fromPropertyList: payload, format: .xml, options: 0)
            try data.write(to: launchAgentURL, options: .atomic)
        } else if fileManager.fileExists(atPath: launchAgentURL.path) {
            try fileManager.removeItem(at: launchAgentURL)
        }
    }
}
