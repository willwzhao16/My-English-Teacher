import Foundation

struct OpenAIChatMessage: Encodable {
    let role: String
    let content: String
}

struct OpenAIChatRequest: Encodable {
    let model: String
    let messages: [OpenAIChatMessage]
    let temperature: Double
    let responseFormat: ResponseFormat

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case responseFormat = "response_format"
    }

    struct ResponseFormat: Encodable {
        let type: String
    }
}

struct OpenAIChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

struct OpenAIErrorEnvelope: Decodable {
    struct Detail: Decodable {
        let message: String?
        let type: String?
    }
    let error: Detail?
}

enum AIClientError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case serverMessage(String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "The app is missing a Moonshot API key. Set EmbeddedConfig.moonshotAPIKey in the project."
        case .invalidResponse:
            return "Unexpected response from the API."
        case .serverMessage(let msg):
            return msg
        case .decodingFailed(let msg):
            return "Could not read the model output: \(msg)"
        }
    }
}

final class AIClient {
    private let session: URLSession
    private let model: String

    init(session: URLSession = .shared, model: String = "kimi-k2.5") {
        self.session = session
        self.model = model
    }

    private static let systemPrompt = """
    You are MET (My English Teacher), a friendly AI that helps the user practice English in typed chat.
    For each user message in English, you MUST respond with a single JSON object only (no markdown fences, no extra text) with these exact keys:
    "assistantReply": a natural, encouraging conversational reply in English continuing the chat.
    "correctedUserText": the user's last message rewritten with mistakes fixed; if already perfect, repeat it.
    "mistakes": an array of objects, each with "type" (short label like grammar, vocabulary, word_choice, spelling, punctuation, register), "explanation" (brief, clear), "suggestion" (how to say it better). Use an empty array if there are no issues.
    "improvementFocus": an array of 1 to 3 short bullet-style strings summarizing what the user should work on next based on this turn.

    Keep explanations concise. Do not include any keys other than these four. The entire output must be valid JSON.
    """

    func completeTeachingTurn(userMessages: [(role: String, text: String)]) async throws -> TeachingPayload {
        let apiKey = EmbeddedConfig.moonshotAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            throw AIClientError.missingAPIKey
        }

        var messages: [OpenAIChatMessage] = [
            OpenAIChatMessage(role: "system", content: Self.systemPrompt)
        ]
        for m in userMessages {
            messages.append(OpenAIChatMessage(role: m.role, content: m.text))
        }

        let body = OpenAIChatRequest(
            model: model,
            messages: messages,
            temperature: 1,
            responseFormat: .init(type: "json_object")
        )

        var request = URLRequest(url: MoonshotConfig.chatCompletionsURL())
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        Self.logHTTPRequest(request)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIClientError.invalidResponse
        }

        Self.logHTTPResponse(statusCode: http.statusCode, data: data)

        if http.statusCode >= 400 {
            let detail = Self.extractAPIErrorMessage(data: data) ?? String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            if http.statusCode == 401 {
                let hint = " Check EmbeddedConfig: use api.moonshot.ai if your key is from platform.moonshot.ai, or api.moonshot.cn if your key is from the China console."
                throw AIClientError.serverMessage(detail + hint)
            }
            throw AIClientError.serverMessage(detail)
        }

        let decoded = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw AIClientError.invalidResponse
        }

        return try parseTeachingPayload(from: content)
    }

    private static func logHTTPRequest(_ request: URLRequest) {
        print("[MET] ---------- HTTP Request ----------")
        print("[MET] URL:", request.url?.absoluteString ?? "(nil)")
        print("[MET] Method:", request.httpMethod ?? "(nil)")
        let auth = request.value(forHTTPHeaderField: "Authorization")
        print("[MET] Authorization:", maskedAuthorizationHeader(auth))
        if let ct = request.value(forHTTPHeaderField: "Content-Type") {
            print("[MET] Content-Type:", ct)
        }
        if let body = request.httpBody, let s = String(data: body, encoding: .utf8) {
            print("[MET] Body:\n\(s)")
        } else {
            print("[MET] Body: <empty>")
        }
        print("[MET] ----------------------------------")
    }

    private static func logHTTPResponse(statusCode: Int, data: Data) {
        print("[MET] ---------- HTTP Response ---------")
        print("[MET] Status:", statusCode)
        let text = String(data: data, encoding: .utf8)
            ?? "<non-UTF8 body, \(data.count) bytes>"
        print("[MET] Body:\n\(text)")
        print("[MET] ----------------------------------")
    }

    /// Masks `Bearer …` so console logs are safer to share.
    private static func maskedAuthorizationHeader(_ value: String?) -> String {
        guard let value, value.hasPrefix("Bearer ") else {
            return value ?? "(none)"
        }
        let token = String(value.dropFirst(7))
        guard token.count > 14 else { return "Bearer <redacted>" }
        let prefix = token.prefix(10)
        return "Bearer \(prefix)… (len \(token.count))"
    }

    /// Moonshot uses OpenAI-style errors; fall back to loose JSON parsing.
    private static func extractAPIErrorMessage(data: Data) -> String? {
        if let env = try? JSONDecoder().decode(OpenAIErrorEnvelope.self, from: data),
           let msg = env.error?.message, !msg.isEmpty {
            return msg
        }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let err = obj["error"] as? [String: Any] else { return nil }
        if let msg = err["message"] as? String, !msg.isEmpty { return msg }
        if let msg = err["msg"] as? String, !msg.isEmpty { return msg }
        return nil
    }

    private func parseTeachingPayload(from content: String) throws -> TeachingPayload {
        guard let payloadData = content.data(using: .utf8) else {
            throw AIClientError.decodingFailed("empty content")
        }
        do {
            return try JSONDecoder().decode(TeachingPayload.self, from: payloadData)
        } catch {
            throw AIClientError.decodingFailed(error.localizedDescription)
        }
    }
}
