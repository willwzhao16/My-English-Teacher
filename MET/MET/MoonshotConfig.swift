import Foundation

enum MoonshotConfig {
    static func chatCompletionsURL() -> URL {
        let base = EmbeddedConfig.moonshotBaseURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let url = URL(string: base + "/chat/completions")
        return url ?? URL(string: "https://api.moonshot.ai/v1/chat/completions")!
    }
}
