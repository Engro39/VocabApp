import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 1

    var body: some View {
        TabView(selection: $selectedTab) {
            FlashCardView()
                .tabItem { Label("카드", systemImage: "rectangle.on.rectangle") }
                .tag(0)

            AddWordView()
                .tabItem { Label("새 단어", systemImage: "plus.circle") }
                .tag(1)

            SetManagerView()
                .tabItem { Label("세트 관리", systemImage: "tray.2") }
                .tag(2)

            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape") }
                .tag(3)
        }
        .tint(Color(hex: "#e8c547"))
        .preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for: .searchRelatedWord)) { _ in
            selectedTab = 1  // 새 단어 탭으로 전환
        }
    }
}
