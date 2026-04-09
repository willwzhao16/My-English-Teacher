import Foundation

final class LocalStore {
    private let fileURL: URL
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init(fileName: String = "conversation.json") {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = dir.appending(path: "MET", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        fileURL = appDir.appending(path: fileName, directoryHint: .notDirectory)
    }

    func load() throws -> ConversationArchive {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return ConversationArchive(turns: [])
        }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(ConversationArchive.self, from: data)
    }

    func save(_ archive: ConversationArchive) throws {
        let data = try encoder.encode(archive)
        try data.write(to: fileURL, options: [.atomic])
    }
}
