import Foundation

/// Shared backend configuration for all app users.
///
/// **Authentication (401) fix:** Keys are **region-specific**. Use the base URL that matches where you created the key:
/// - Key from **platform.moonshot.ai** → `https://api.moonshot.ai/v1`
/// - Key from **platform.moonshot.cn** (Mainland China) → `https://api.moonshot.cn/v1`
/// A mismatch almost always causes “invalid api key” / 401.
///
/// Set `moonshotAPIKey` before shipping. Keys in the app binary can be extracted—use a backend proxy for production.
enum EmbeddedConfig {
    /// Moonshot / Kimi API key (same for every user).
    static let moonshotAPIKey: String = ""

    /// No trailing slash. Must match your key’s region (see comment above).
    static let moonshotBaseURL: String = "https://api.moonshot.ai/v1"
}
