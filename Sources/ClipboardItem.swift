import Foundation

enum ClipboardItemKind: String, Codable {
    case text
    case files
    case image
}

struct ClipboardItem: Codable, Identifiable, Equatable {
    let id: UUID
    let kind: ClipboardItemKind
    let signature: String
    let text: String?
    let filePaths: [String]?
    let imageFileName: String?
    var isPinned: Bool
    let createdAt: Date
    var lastCopiedAt: Date

    init(
        id: UUID = UUID(),
        kind: ClipboardItemKind,
        signature: String,
        text: String? = nil,
        filePaths: [String]? = nil,
        imageFileName: String? = nil,
        isPinned: Bool = false,
        createdAt: Date = Date(),
        lastCopiedAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.signature = signature
        self.text = text
        self.filePaths = filePaths
        self.imageFileName = imageFileName
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.lastCopiedAt = lastCopiedAt
    }

    var displayTitle: String {
        switch kind {
        case .text:
            return Self.makeSingleLineTitle(from: text ?? "", fallback: "(Empty text)")
        case .files:
            let names = fileNames
            if names.isEmpty {
                return "(Files)"
            }
            if names.count == 1 {
                return names[0]
            }
            return "\(names[0]) +\(names.count - 1) files"
        case .image:
            return "Image"
        }
    }

    var displaySubtitle: String {
        switch kind {
        case .text:
            return "Text"
        case .files:
            let names = fileNames
            if names.isEmpty {
                return "Files"
            }
            return names.prefix(3).joined(separator: ", ")
        case .image:
            return "Image preview"
        }
    }

    var searchableText: String {
        switch kind {
        case .text:
            return text ?? ""
        case .files:
            return fileNames.joined(separator: " ")
        case .image:
            return "image"
        }
    }

    var plainTextRepresentation: String? {
        switch kind {
        case .text:
            return text
        case .files:
            guard !fileNames.isEmpty else {
                return nil
            }
            return fileNames.joined(separator: "\n")
        case .image:
            return nil
        }
    }

    var fileNames: [String] {
        (filePaths ?? []).map { URL(fileURLWithPath: $0).lastPathComponent }
    }

    private static func makeSingleLineTitle(from source: String, fallback: String) -> String {
        let singleLine = source
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !singleLine.isEmpty else {
            return fallback
        }

        let maxLength = 90
        guard singleLine.count > maxLength else {
            return singleLine
        }

        return "\(singleLine.prefix(maxLength))…"
    }
}

extension ClipboardItem {
    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case signature
        case text
        case filePaths
        case imageFileName
        case isPinned
        case createdAt
        case lastCopiedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(ClipboardItemKind.self, forKey: .kind)
        signature = try container.decode(String.self, forKey: .signature)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        filePaths = try container.decodeIfPresent([String].self, forKey: .filePaths)
        imageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastCopiedAt = try container.decode(Date.self, forKey: .lastCopiedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(signature, forKey: .signature)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(filePaths, forKey: .filePaths)
        try container.encodeIfPresent(imageFileName, forKey: .imageFileName)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(lastCopiedAt, forKey: .lastCopiedAt)
    }
}
