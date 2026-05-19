import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            FlashCardView()
                .tabItem {
                    Label("카드", systemImage: "rectangle.on.rectangle")
                }
            AddWordView()
                .tabItem {
                    Label("새 단어", systemImage: "plus.circle")
                }
            SettingsView()
                .tabItem {
                    Label("설정", systemImage: "gearshape")
                }
        }
        .tint(Color(hex: "#e8c547"))
        .preferredColorScheme(.dark)
    }
}
