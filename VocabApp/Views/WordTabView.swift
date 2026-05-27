import SwiftUI

struct WordTabView: View {
    @AppStorage("wordSubTab") private var selectedTab = 1

    var body: some View {
        NavigationStack {
            ZStack {
                if selectedTab == 0 {
                    FlashCardView()
                } else if selectedTab == 1 {
                    AddWordView()
                } else {
                    SetManagerView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("", selection: $selectedTab) {
                        Text("카드").tag(0)
                        Image(systemName: "plus.circle.fill").tag(1)
                        Text("세트").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 230)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
