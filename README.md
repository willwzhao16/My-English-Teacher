# MET — My English Teacher

MET is an iOS app that helps you practice English in **text chat**. It uses the **Kimi** model (Moonshot AI) over the OpenAI-compatible API: the assistant replies in English, highlights corrections, explains mistakes, and surfaces short “what to improve next” notes. Chats are stored **on device** only.

## Requirements

- **Xcode** 16+ (Swift 5.10)
- **iOS 17+** deployment target
- A **Moonshot / Kimi API key** from [Kimi Open Platform](https://platform.moonshot.cn) (China) or [platform.moonshot.ai](https://platform.moonshot.ai) (international), matching the API base URL you configure

## Quick start

1. Clone the repository:

   ```bash
   git clone https://github.com/willwzhao16/My-English-Teacher.git
   cd My-English-Teacher
   ```

2. Open the Xcode project:

   ```bash
   open MET/MET.xcodeproj
   ```

3. **API credentials** are not in git. Copy the template and edit the copy:

   ```bash
   cp MET/MET/Secrets.example.plist MET/MET/Secrets.plist
   ```

4. Edit **`MET/MET/Secrets.plist`**:

   - **`MoonshotAPIKey`**: your API key (`sk-…`).
   - **`MoonshotBaseURL`**: must match where the key was issued:
     - China: `https://api.moonshot.cn/v1`
     - International: `https://api.moonshot.ai/v1`  
     Do **not** use `api.moonshot.com` for API calls; it often returns Cloudflare HTML instead of JSON.

5. Select the **MET** scheme, pick a simulator or device, then **Run** (⌘R).

On first build, a Run Script phase may create `Secrets.plist` from `Secrets.example.plist` if it is missing.

## How it works

- **Chat**: You write in English; each turn requests a structured JSON payload (reply, corrected text, mistakes, focus tips).
- **Improve**: Aggregates recent mistake tags and focus lines from saved turns.
- **Settings**: App version / about text.
- **Networking**: [MacPaw OpenAI](https://github.com/MacPaw/OpenAI) Swift package talks to Moonshot’s `/v1/chat/completions`. A **raw HTTP fallback** runs if the SDK cannot decode the provider response; **temperature** is fixed to **1** as required for this Kimi integration.

## Project layout

| Path | Role |
|------|------|
| `MET/MET.xcodeproj` | Xcode project and SPM (OpenAI package) |
| `MET/MET/` | Swift sources, assets, `Secrets.example.plist` |
| `MET/MET/Secrets.plist` | **Local only** (gitignored) — your API key |

## Security note

Treat API keys as secrets. `Secrets.plist` is listed in `.gitignore`. For App Store builds, embedding keys in the app bundle still exposes them to extraction; a production setup often uses your own backend to hold the key.

## License

No license file is included in this repository; add one if you intend to open-source the project under specific terms.
