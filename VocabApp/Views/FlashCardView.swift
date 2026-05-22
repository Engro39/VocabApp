import SwiftUI
import SwiftData
import AVFoundation

struct FlashCardView: View {
    @Query(sort: \Word.addedDate) private var allWords: [Word]

    @State private var filterSet: Int = 0      // 0 = ALL, -1 = 진행중
    @State private var shuffled: Bool = false
    @State private var displayList: [Word] = []  // 셔플 상태 고정 리스트
    @State private var currentIndex: Int = 0
    @State private var isFlipped: Bool = false
    @State private var flipDeg: Double = 0
    @State private var showingDetail: Word? = nil
    @State private var hasInitialized: Bool = false

    // 10개 고정 색상, set % 10 으로 순환 (세트 1 = 세트 11, 세트 2 = 세트 12, ...)
    static let colors: [Color] = [
        Color(hex: "#e8c547"),  // 0, 10, 20…
        Color(hex: "#ff6b6b"),  // 1, 11, 21…
        Color(hex: "#4ecdc4"),  // 2, 12, 22…
        Color(hex: "#a78bfa"),  // 3, 13, 23…
        Color(hex: "#fb923c"),  // 4, 14, 24…
        Color(hex: "#34d399"),  // 5, 15, 25…
        Color(hex: "#f472b6"),  // 6, 16, 26…
        Color(hex: "#60a5fa"),  // 7, 17, 27…
        Color(hex: "#facc15"),  // 8, 18, 28…
        Color(hex: "#c084fc"),  // 9, 19, 29…
    ]

    // 완성된 세트 번호 목록
    private var completedSets: [Int] {
        Array(Set(allWords.filter { !$0.isPending }.map(\.set))).sorted()
    }

    // MARK: - Position persistence (UserDefaults)
    private func indexKey(_ set: Int) -> String { "fc_idx_\(set)" }
    private let kLastFilterSet = "fc_lastFilterSet"

    private func savePosition() {
        guard !shuffled else { return }
        UserDefaults.standard.set(currentIndex, forKey: indexKey(filterSet))
        UserDefaults.standard.set(filterSet, forKey: kLastFilterSet)
    }

    private var hasPending: Bool {
        allWords.contains { $0.isPending }
    }

    private var card: Word? {
        guard !displayList.isEmpty,
              currentIndex < displayList.count else { return nil }
        return displayList[currentIndex]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0f0e17").ignoresSafeArea()
                VStack(spacing: 0) {
                    setFilterBar
                        .padding(.horizontal)
                        .padding(.top, 8)

                    if !displayList.isEmpty {
                        HStack {
                            ProgressView(value: Double(currentIndex + 1),
                                         total: Double(displayList.count))
                                .tint(Color(hex: "#e8c547"))
                            Text("\(currentIndex + 1)/\(displayList.count)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                    }

                    Spacer(minLength: 16)

                    if let card {
                        cardView(card)
                            .padding(.horizontal, 20)
                            .gesture(DragGesture(minimumDistance: 40).onEnded { val in
                                if val.translation.width < -40 { goNext() }
                                else if val.translation.width > 40 { goPrev() }
                            })
                    } else {
                        Text("단어가 없습니다").foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 16)

                    HStack(spacing: 48) {
                        Button(action: goPrev) {
                            Image(systemName: "chevron.left.circle")
                                .font(.system(size: 40))
                                .foregroundStyle(Color(hex: "#e8c547").opacity(0.7))
                        }
                        Button(action: goNext) {
                            Image(systemName: "chevron.right.circle")
                                .font(.system(size: 40))
                                .foregroundStyle(Color(hex: "#e8c547").opacity(0.7))
                        }
                    }
                    .padding(.bottom, 12)

                    wordChips
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
            }
            .navigationTitle("VOCAB")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        shuffled.toggle()
                        rebuildList()
                    } label: {
                        Image(systemName: shuffled ? "shuffle.circle.fill" : "shuffle")
                            .foregroundStyle(Color(hex: "#e8c547"))
                    }
                }
            }
            .onChange(of: allWords) { rebuildList(preservePosition: true) }
            .onChange(of: filterSet) { rebuildList() }
            .onAppear {
                guard !hasInitialized else { return }
                hasInitialized = true

                // 마지막으로 보던 세트 복원
                let savedSet = UserDefaults.standard.integer(forKey: kLastFilterSet)
                let valid = Set([0, -1] + completedSets)
                let targetSet = valid.contains(savedSet) ? savedSet : 0

                if targetSet != filterSet {
                    // filterSet 변경 → onChange → rebuildList (UD에서 인덱스 복원)
                    filterSet = targetSet
                } else {
                    rebuildList()   // filterSet 동일 → onChange 미발생, 직접 호출
                }
            }
            .sheet(item: $showingDetail) { word in
                WordDetailSheet(word: word)
            }
        }
    }

    // MARK: - Rebuild display list
    private func rebuildList(preservePosition: Bool = false) {
        let previousID = preservePosition && !displayList.isEmpty
            ? displayList[min(currentIndex, displayList.count - 1)].persistentModelID
            : nil

        var list: [Word]
        switch filterSet {
        case 0:  list = allWords
        case -1: list = allWords.filter { $0.isPending }
        default: list = allWords.filter { $0.set == filterSet }
        }
        displayList = shuffled ? list.shuffled() : list

        if let pid = previousID,
           let idx = displayList.firstIndex(where: { $0.persistentModelID == pid }) {
            currentIndex = idx
        } else if !preservePosition && !shuffled && !displayList.isEmpty {
            // 비셔플·필터 전환 또는 초기 진입 시 UserDefaults에서 인덱스 복원
            let saved = UserDefaults.standard.integer(forKey: indexKey(filterSet))
            currentIndex = min(saved, displayList.count - 1)
            isFlipped = false
            flipDeg = 0
        } else {
            currentIndex = 0
            isFlipped = false
            flipDeg = 0
        }
    }

    // MARK: - Set filter bar
    @ViewBuilder
    private var setFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if hasPending {
                    setChip(label: "진행중", value: -1)
                }
                setChip(label: "ALL", value: 0)
                ForEach(completedSets.reversed(), id: \.self) { s in
                    setChip(label: "세트 \(s)", value: s)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func setChip(label: String, value: Int) -> some View {
        let color: Color = value == -1 ? Color(hex: "#00ffcc")
            : value == 0  ? Color(hex: "#e8c547")
            : Self.colors[value % Self.colors.count]
        let selected = filterSet == value
        Button {
            if filterSet != value {
                // 나가는 세트의 현재 인덱스 저장
                if !shuffled {
                    UserDefaults.standard.set(currentIndex, forKey: indexKey(filterSet))
                }
                filterSet = value
                UserDefaults.standard.set(value, forKey: kLastFilterSet)
            }
        } label: {
            Text(label)
                .font(.caption.bold())
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(selected ? color : Color.clear)
                .foregroundStyle(selected ? Color(hex: "#0f0e17") : color)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(color, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Card
    @ViewBuilder
    private func cardView(_ word: Word) -> some View {
        ZStack {
            cardFace(word: word, isFront: true)
                .rotation3DEffect(.degrees(flipDeg), axis: (x: 0, y: 1, z: 0))
                .opacity(flipDeg < 90 ? 1 : 0)
            cardFace(word: word, isFront: false)
                .rotation3DEffect(.degrees(flipDeg - 180), axis: (x: 0, y: 1, z: 0))
                .opacity(flipDeg >= 90 ? 1 : 0)
        }
        .frame(height: 280)
        .onTapGesture(count: 2) {
            if word.hasDetail { showingDetail = word }
        }
        .onTapGesture(count: 1) { flipCard() }
    }

    @ViewBuilder
    private func cardFace(word: Word, isFront: Bool) -> some View {
        let setColor = Self.colors[word.set % Self.colors.count]
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(isFront
                      ? LinearGradient(colors: [Color(hex: "#1a1828"), Color(hex: "#221f35")],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                      : LinearGradient(colors: [Color(hex: "#1b2a2a"), Color(hex: "#142320")],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(setColor.opacity(0.3), lineWidth: 1))

            if isFront {
                VStack(spacing: 12) {
                    Text(word.word)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Color(hex: "#e8c547"))
                        .multilineTextAlignment(.center)

                    // 단어 + 예문 TTS 버튼 둘 다 전면에 표시
                    HStack(spacing: 16) {
                        Button {
                            speak(word.word)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "speaker.wave.2")
                                Text("단어")
                                    .font(.caption)
                            }
                            .font(.caption)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.4), lineWidth: 1))
                            .foregroundStyle(.secondary)
                        }

                        Button {
                            speak(word.exampleEn)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "speaker.wave.2")
                                Text("예문")
                                    .font(.caption)
                            }
                            .font(.caption)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.4), lineWidth: 1))
                            .foregroundStyle(.secondary)
                        }
                    }

                    if word.hasDetail {
                        Text("더블탭으로 상세보기").font(.caption2).foregroundStyle(Color(hex: "#a78bfa").opacity(0.7))
                    } else {
                        Text("탭하여 뒤집기").font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                .padding(24)
            } else {
                VStack(spacing: 14) {
                    Text(word.meaning)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color(hex: "#4ecdc4"))
                        .multilineTextAlignment(.center)
                    Text(word.exampleEn)
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal)
                    Button { speak(word.exampleEn) } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "speaker.wave.2")
                            Text("예문")
                        }
                        .font(.caption)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.4), lineWidth: 1))
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(24)
            }
        }
    }

    // MARK: - Word chips
    @ViewBuilder
    private var wordChips: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(displayList.enumerated()), id: \.offset) { i, w in
                        let color = Self.colors[w.set % Self.colors.count]
                        let selected = i == currentIndex
                        Button {
                            currentIndex = i
                            isFlipped = false
                            flipDeg = 0
                            savePosition()
                        } label: {
                            Text(w.word)
                                .font(.caption)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(selected ? color : Color.clear)
                                .foregroundStyle(selected ? Color(hex: "#0f0e17") : color)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(color, lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .id(i)
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: currentIndex) { newIndex in
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }

    // MARK: - Actions
    private func flipCard() {
        withAnimation(.easeInOut(duration: 0.4)) { flipDeg = isFlipped ? 0 : 180 }
        isFlipped.toggle()
    }

    private func goNext() {
        guard !displayList.isEmpty else { return }
        isFlipped = false; flipDeg = 0
        currentIndex = (currentIndex + 1) % displayList.count
        savePosition()
    }

    private func goPrev() {
        guard !displayList.isEmpty else { return }
        isFlipped = false; flipDeg = 0
        currentIndex = (currentIndex - 1 + displayList.count) % displayList.count
        savePosition()
    }

    private func speak(_ text: String) {
        SpeechService.shared.speak(text)
    }
}

// MARK: - Word Detail Sheet
struct WordDetailSheet: View {
    let word: Word
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0f0e17").ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // 헤더
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(word.word)
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(Color(hex: "#e8c547"))
                                Button { SpeechService.shared.speak(word.word) } label: {
                                    Image(systemName: "speaker.wave.2")
                                        .foregroundStyle(.secondary).font(.title3)
                                }
                            }
                            HStack(spacing: 8) {
                                Text(word.pronunciation).font(.subheadline).foregroundStyle(.secondary)
                                Text(word.partOfSpeech)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color(hex: "#a78bfa").opacity(0.2))
                                    .foregroundStyle(Color(hex: "#a78bfa"))
                                    .clipShape(Capsule())
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .background(Color(hex: "#1a1828"))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        detailCard(title: "한국어 뜻", icon: "textformat.alt") {
                            Text(word.meaning)
                                .font(.title3.bold())
                                .foregroundStyle(Color(hex: "#4ecdc4"))
                        }

                        if !word.detailedDefinition.isEmpty {
                            detailCard(title: "Definition", icon: "book") {
                                Text(word.detailedDefinition)
                                    .font(.subheadline).foregroundStyle(.primary).lineSpacing(4)
                            }
                        }

                        if !word.examples.isEmpty {
                            detailCard(title: "예문", icon: "quote.bubble") {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(Array(word.examples.enumerated()), id: \.offset) { i, ex in
                                        HStack(alignment: .top, spacing: 10) {
                                            Text("\(i + 1)")
                                                .font(.caption.bold()).foregroundStyle(.secondary).frame(width: 16)
                                            Text(ex)
                                                .font(.subheadline).foregroundStyle(.primary).lineSpacing(3)
                                            Spacer()
                                            Button { SpeechService.shared.speak(ex) } label: {
                                                Image(systemName: "speaker.wave.2")
                                                    .font(.caption).foregroundStyle(.secondary)
                                            }
                                        }
                                        if i < word.examples.count - 1 {
                                            Divider().background(Color.white.opacity(0.1))
                                        }
                                    }
                                }
                            }
                        }

                        if !word.nuance.isEmpty {
                            detailCard(title: "뉘앙스 & 사용 팁", icon: "lightbulb") {
                                Text(word.nuance)
                                    .font(.subheadline).foregroundStyle(.primary).lineSpacing(4)
                            }
                        }

                        if !word.relatedWords.isEmpty {
                            detailCard(title: "관련 단어", icon: "link") {
                                FlexWrap(items: word.relatedWords) { w in
                                    Text(w)
                                        .font(.caption.bold())
                                        .padding(.horizontal, 10).padding(.vertical, 5)
                                        .background(Color(hex: "#fb923c").opacity(0.15))
                                        .foregroundStyle(Color(hex: "#fb923c"))
                                        .clipShape(Capsule())
                                }
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationTitle("상세 정보")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                        .foregroundStyle(Color(hex: "#e8c547"))
                }
            }
        }
    }

    @ViewBuilder
    private func detailCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.caption.bold()).foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(hex: "#1a1828"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// 관련단어 태그 래핑 레이아웃
private struct FlexWrap<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    init(items: [Item], @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.content = content
    }

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(items, id: \.self) { item in
                content(item)
            }
        }
    }
}
