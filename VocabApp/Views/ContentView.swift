import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @AppStorage("wordSubTab") private var wordSubTab = 1

    var body: some View {
        TabView(selection: $selectedTab) {
            WordTabView()
                .tabItem { Label("단어", systemImage: "book.closed") }
                .tag(0)

            ListeningPracticeView()
                .tabItem { Label("듣기", systemImage: "headphones") }
                .tag(1)

            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape") }
                .tag(2)
        }
        .tint(Color(hex: "#e8c547"))
        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: .searchRelatedWord)) { _ in
            selectedTab = 0   // 단어 탭으로
            wordSubTab = 1    // 새 단어 서브탭으로
        }
    }
}
