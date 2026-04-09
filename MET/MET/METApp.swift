import SwiftUI

@main
struct METApp: App {
    init() {
        _ = SecretsStore.shared
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
    }
}
