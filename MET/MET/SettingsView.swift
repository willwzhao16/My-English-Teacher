import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Version", value: versionString)
                } header: {
                    Text("About")
                } footer: {
                    Text("MET uses the Kimi API. The Moonshot API key is read from Secrets.plist at launch (kept out of git; see Secrets.example.plist).")
                }
            }
            .navigationTitle("Settings")
        }
    }

    private var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return b.isEmpty ? v : "\(v) (\(b))"
    }
}

#Preview {
    SettingsView()
}
