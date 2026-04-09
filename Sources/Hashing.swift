import CryptoKit
import Foundation

enum Hashing {
    static func sha256Hex(for data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func sha256Hex(for text: String) -> String {
        sha256Hex(for: Data(text.utf8))
    }
}
