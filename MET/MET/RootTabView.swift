import SwiftUI

struct RootTabView: View {
    @StateObject private var chatViewModel = ChatViewModel()

    var body: some View {
        TabView {
            ChatView(viewModel: chatViewModel)
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right.fill")
                }

            ImprovementSummaryView(viewModel: chatViewModel)
                .tabItem {
                    Label("Improve", systemImage: "chart.line.uptrend.xyaxis")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}

#Preview {
    RootTabView()
}
