import Foundation
import OpenAI

enum AIClientError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case serverMessage(String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Missing Moonshot API key. Set MoonshotAPIKey in MET/MET/Secrets.plist (copy from Secrets.example.plist)."
        case .invalidResponse:
            return "Unexpected response from the API."
        case .serverMessage(let msg):
            return msg
        case .decodingFailed(let msg):
            return msg
        }
    }
}

final class AIClient {
    private let model: String
    private let urlSession: URLSession

    init(model: String = "kimi-k2.5", urlSession: URLSession = .shared) {
        self.model = model
        self.urlSession = urlSession
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

    /// Moonshot / Kimi requires `temperature` to be `1` for this integration.
    private static let chatTemperature: Double = 1.0

    func completeTeachingTurn(userMessages: [(role: String, text: String)]) async throws -> TeachingPayload {
        let apiKey = SecretsStore.shared.moonshotAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            throw AIClientError.missingAPIKey
        }

        let sdkMessages = buildSDKMessages(from: userMessages)
        let query = ChatQuery(
            messages: sdkMessages,
            model: model,
            responseFormat: .jsonObject,
            temperature: Self.chatTemperature
        )

        let openAI = Self.makeOpenAIClient(apiKey: apiKey)
        Self.logSDKRequest(model: model, messageCount: sdkMessages.count)

        let assistantText: String
        do {
            let result = try await openAI.chats(query: query)
            Self.logSDKResponse(result: result)
            guard let content = result.choices.first?.message.content, !content.isEmpty else {
                throw AIClientError.invalidResponse
            }
            assistantText = content
        } catch {
            print("[MET] OpenAI SDK call failed: \(error.localizedDescription). Using raw HTTP fallback.")
            assistantText = try await Self.fetchChatCompletionTextRaw(
                apiKey: apiKey,
                model: model,
                userMessages: userMessages,
                session: urlSession
            )
            Self.logRawContentPreview(assistantText)
        }

        try Self.throwIfAssistantTextLooksLikeHTML(assistantText)
        return try Self.parseTeachingPayload(from: assistantText)
    }

    private func buildSDKMessages(from userMessages: [(role: String, text: String)]) -> [ChatQuery.ChatCompletionMessageParam] {
        var messages: [ChatQuery.ChatCompletionMessageParam] = [
            .system(.init(content: .textContent(Self.systemPrompt)))
        ]
        for m in userMessages {
            switch m.role {
            case "user":
                messages.append(.user(.init(content: .string(m.text))))
            case "assistant":
                messages.append(.assistant(.init(content: .textContent(m.text))))
            default:
                break
            }
        }
        return messages
    }

    private static func makeOpenAIClient(apiKey: String) -> OpenAI {
        let raw = SecretsStore.shared.moonshotBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: raw), let host = url.host else {
            return OpenAI(configuration: OpenAI.Configuration(
                token: apiKey,
                host: "api.moonshot.cn",
                parsingOptions: .relaxed
            ))
        }
        var path = url.path
        if path.isEmpty { path = "/v1" }
        if path.hasSuffix("/"), path.count > 1 {
            path = String(path.dropLast())
        }
        return OpenAI(configuration: OpenAI.Configuration(
            token: apiKey,
            host: host,
            port: url.port ?? 443,
            scheme: url.scheme ?? "https",
            basePath: path,
            parsingOptions: .relaxed
        ))
    }

    // MARK: - Raw HTTP fallback

    private struct RawChatRequest: Encodable {
        let model: String
        let messages: [RawChatMessage]
        let temperature: Double
        let responseFormat: RawResponseFormat

        enum CodingKeys: String, CodingKey {
            case model, messages, temperature
            case responseFormat = "response_format"
        }

        struct RawChatMessage: Encodable {
            let role: String
            let content: String
        }

        struct RawResponseFormat: Encodable {
            let type: String
        }
    }

    private static func fetchChatCompletionTextRaw(
        apiKey: String,
        model: String,
        userMessages: [(role: String, text: String)],
        session: URLSession
    ) async throws -> String {
        var rawMessages: [RawChatRequest.RawChatMessage] = [
            .init(role: "system", content: systemPrompt)
        ]
        for m in userMessages {
            rawMessages.append(.init(role: m.role, content: m.text))
        }

        let body = RawChatRequest(
            model: model,
            messages: rawMessages,
            temperature: Self.chatTemperature,
            responseFormat: .init(type: "json_object")
        )

        let data = try JSONEncoder().encode(body)
        var request = URLRequest(url: MoonshotConfig.chatCompletionsURL())
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (responseData, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIClientError.invalidResponse
        }

        if http.statusCode >= 400 {
            try throwIfHTMLBlockingPage(data: responseData, httpStatus: http.statusCode)
            let detail = extractAPIErrorMessage(from: responseData) ?? String(data: responseData, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            if http.statusCode == 401 {
                let hint = " Check Secrets.plist MoonshotBaseURL matches your key: https://api.moonshot.cn/v1 (China) or https://api.moonshot.ai/v1 (international)."
                throw AIClientError.serverMessage(detail + hint)
            }
            throw AIClientError.serverMessage(detail)
        }

        try throwIfHTMLBlockingPage(data: responseData, httpStatus: http.statusCode)

        guard let obj = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let choices = obj["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any] else {
            throw AIClientError.invalidResponse
        }

        if let text = extractAssistantText(from: message), !text.isEmpty {
            return text
        }
        throw AIClientError.invalidResponse
    }

    /// Kimi may return `content` as a string, null, or an array of parts; some models put text in `reasoning_content`.
    private static func extractAssistantText(from message: [String: Any]) -> String? {
        if let s = message["content"] as? String, !s.isEmpty {
            return s
        }
        if let arr = message["content"] as? [[String: Any]] {
            let parts = arr.compactMap { $0["text"] as? String }
            if !parts.isEmpty { return parts.joined() }
        }
        if let r = message["reasoning_content"] as? String, !r.isEmpty { return r }
        if let r = message["reasoning"] as? String, !r.isEmpty { return r }
        return nil
    }

    /// `api.moonshot.com` and some URLs return a Cloudflare challenge HTML page instead of JSON.
    private static func throwIfHTMLBlockingPage(data: Data, httpStatus: Int) throws {
        let prefix = String(data: data.prefix(800), encoding: .utf8) ?? ""
        let lower = prefix.lowercased()
        guard lower.contains("<!doctype") || lower.contains("<html") || lower.contains("cloudflare") || lower.contains("attention required") else {
            return
        }
        throw AIClientError.serverMessage(
            "The server returned an HTML page (often a Cloudflare browser check), not the Kimi API. In Secrets.plist set MoonshotBaseURL to https://api.moonshot.cn/v1 (China) or https://api.moonshot.ai/v1 (international). Avoid api.moonshot.com for API calls. (HTTP \(httpStatus))"
        )
    }

    private static func throwIfAssistantTextLooksLikeHTML(_ text: String) throws {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = t.lowercased()
        guard lower.hasPrefix("<!doctype") || lower.hasPrefix("<html") || lower.contains("cloudflare") else {
            return
        }
        try throwIfHTMLBlockingPage(data: Data(text.utf8), httpStatus: 200)
    }

    private static func extractAPIErrorMessage(from data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let err = obj["error"] as? [String: Any] else { return nil }
        return err["message"] as? String ?? err["msg"] as? String
    }

    // MARK: - Teaching JSON

    private static func parseTeachingPayload(from content: String) throws -> TeachingPayload {
        let cleaned = stripJSONArtifacts(from: content)
        guard let payloadData = cleaned.data(using: .utf8) else {
            throw AIClientError.decodingFailed("The model reply could not be read as text. Try again.")
        }
        do {
            return try JSONDecoder().decode(TeachingPayload.self, from: payloadData)
        } catch {
            throw AIClientError.decodingFailed(
                "Teaching JSON could not be parsed (\(describeDecodingError(error))). If the model wrapped JSON in markdown, strip it or try again."
            )
        }
    }

    private static func stripJSONArtifacts(from s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            if let firstLineEnd = t.firstIndex(of: "\n") {
                t = String(t[t.index(after: firstLineEnd)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let fence = t.range(of: "```", options: .backwards) {
                t = String(t[..<fence.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        if !t.hasPrefix("{"), let start = t.firstIndex(of: "{"), let end = t.lastIndex(of: "}") {
            t = String(t[start...end])
        }
        return t
    }

    private static func describeDecodingError(_ error: Error) -> String {
        if let decoding = error as? DecodingError {
            switch decoding {
            case .keyNotFound(let key, _):
                return "missing key \(key.stringValue)"
            case .typeMismatch(let type, _):
                return "wrong type for \(type)"
            case .valueNotFound(let type, _):
                return "missing value for \(type)"
            case .dataCorrupted(let context):
                return context.debugDescription
            @unknown default:
                return decoding.localizedDescription
            }
        }
        return error.localizedDescription
    }

    private static func logSDKRequest(model: String, messageCount: Int) {
        print("[MET] ---------- OpenAI SDK (Kimi) ----------")
        print("[MET] Model:", model)
        print("[MET] Messages:", messageCount)
        print("[MET] --------------------------------------")
    }

    private static func logSDKResponse(result: ChatResult) {
        print("[MET] ---------- Chat completion result -----")
        print("[MET] id:", result.id)
        if let first = result.choices.first?.message.content {
            let preview = first.prefix(800)
            print("[MET] content (prefix):\n\(preview)\(first.count > 800 ? "…" : "")")
        } else {
            print("[MET] content: <nil>")
        }
        print("[MET] --------------------------------------")
    }

    private static func logRawContentPreview(_ text: String) {
        let preview = text.prefix(800)
        print("[MET] ---------- Raw fallback content -------")
        print("[MET] \(preview)\(text.count > 800 ? "…" : "")")
        print("[MET] --------------------------------------")
    }
}
