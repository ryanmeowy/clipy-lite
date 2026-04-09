import Carbon
import Foundation

struct HotKeyShortcut: Equatable {
    let id: String
    let displayName: String
    let keyCode: UInt32
    let modifiers: UInt32

    static let presets: [HotKeyShortcut] = [
        .init(
            id: "cmd_shift_v",
            displayName: "Cmd + Shift + V",
            keyCode: UInt32(kVK_ANSI_V),
            modifiers: UInt32(cmdKey | shiftKey)
        ),
        .init(
            id: "cmd_shift_c",
            displayName: "Cmd + Shift + C",
            keyCode: UInt32(kVK_ANSI_C),
            modifiers: UInt32(cmdKey | shiftKey)
        ),
        .init(
            id: "cmd_option_v",
            displayName: "Cmd + Option + V",
            keyCode: UInt32(kVK_ANSI_V),
            modifiers: UInt32(cmdKey | optionKey)
        ),
        .init(
            id: "control_option_space",
            displayName: "Control + Option + Space",
            keyCode: UInt32(kVK_Space),
            modifiers: UInt32(controlKey | optionKey)
        ),
    ]

    static var `default`: HotKeyShortcut {
        presets[0]
    }

    static func from(id: String) -> HotKeyShortcut {
        presets.first(where: { $0.id == id }) ?? .default
    }
}
