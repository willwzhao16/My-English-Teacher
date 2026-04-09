import Foundation

/// Loads Moonshot credentials from `Secrets.plist` in the app bundle (see `Secrets.example.plist`).
///
/// Use the **API** host from the Kimi console (`api.moonshot.cn` or `api.moonshot.ai`), not marketing domains like `api.moonshot.com` (those often return Cloudflare HTML instead of JSON).
/// The real `Secrets.plist` is gitignored; the Run Script phase copies the example file if missing.
final class SecretsStore {
    static let shared = SecretsStore()

    private(set) var moonshotAPIKey: String = ""
    private(set) var moonshotBaseURL: String = "https://api.moonshot.cn/v1"

    private init() {
        loadFromBundle()
    }

    /// Call after launch if you need to re-read (e.g. after tests).
    func loadFromBundle() {
        moonshotAPIKey = ""
        moonshotBaseURL = "https://api.moonshot.cn/v1"

        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: Any] else {
            return
        }
        if let k = dict["MoonshotAPIKey"] as? String {
            moonshotAPIKey = k.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let u = dict["MoonshotBaseURL"] as? String {
            let trimmed = u.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                moonshotBaseURL = trimmed
            }
        }
    }
}
