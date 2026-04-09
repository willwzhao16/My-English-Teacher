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
                    Text("MET (My English Teacher) uses the Kimi API with a key embedded in the app for all users.")
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
