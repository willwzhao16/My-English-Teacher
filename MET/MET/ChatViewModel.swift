import Combine
import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var turns: [ChatTurn] = []
    @Published var isSending = false
    @Published var lastError: String?

    private let store = LocalStore()
    private let client = AIClient()

    init() {
        reloadFromDisk()
    }

    func reloadFromDisk() {
        do {
            turns = try store.load().turns
        } catch {
            lastError = error.localizedDescription
        }
    }

    func clearConversation() {
        turns = []
        persist()
    }

    func sendUserMessage(_ raw: String) async {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let userTurn = ChatTurn(role: .user, text: trimmed)
        turns.append(userTurn)
        persist()
        isSending = true
        lastError = nil

        do {
            let payload = try await client.completeTeachingTurn(userMessages: openAIMessageHistory())
            if var last = turns.last, last.role == .user, last.id == userTurn.id {
                last.teaching = payload
                turns[turns.count - 1] = last
            }
            turns.append(ChatTurn(role: .assistant, text: payload.assistantReply))
        } catch {
            lastError = error.localizedDescription
            if turns.last?.id == userTurn.id {
                turns.removeLast()
            }
        }

        isSending = false
        persist()
    }

    private func openAIMessageHistory() -> [(role: String, text: String)] {
        turns.map { turn in
            (turn.role == .user ? "user" : "assistant", turn.text)
        }
    }

    private func persist() {
        do {
            try store.save(ConversationArchive(turns: turns))
        } catch {
            lastError = error.localizedDescription
        }
    }
}
