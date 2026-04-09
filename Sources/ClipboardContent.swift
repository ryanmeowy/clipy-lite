import Foundation

enum ClipboardPayload {
    case text(String)
    case files([URL])
    case imagePNGData(Data)
}

struct CapturedClipboardContent {
    let signature: String
    let payload: ClipboardPayload
}
