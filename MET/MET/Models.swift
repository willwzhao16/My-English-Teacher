import Foundation

struct Mistake: Codable, Identifiable, Hashable {
    let type: String
    let explanation: String
    let suggestion: String

    var id: String { "\(type)|\(explanation)|\(suggestion)" }
}

struct TeachingPayload: Codable, Equatable {
    let assistantReply: String
    let correctedUserText: String
    let mistakes: [Mistake]
    let improvementFocus: [String]
}

enum ChatRole: String, Codable {
    case user
    case assistant
}

struct ChatTurn: Codable, Identifiable, Equatable {
    let id: UUID
    let role: ChatRole
    let text: String
    let createdAt: Date
    var teaching: TeachingPayload?

    init(id: UUID = UUID(), role: ChatRole, text: String, createdAt: Date = Date(), teaching: TeachingPayload? = nil) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.teaching = teaching
    }
}

struct ConversationArchive: Codable, Equatable {
    var turns: [ChatTurn]
}
