import SwiftUI
import SwiftData
import AVFoundation

struct FlashCardView: View {
    @Query(sort: \Word.addedDate) private var allWords: [Word]
    @State private var filterSession: Int = 0   // 0 = ALL, -1 = NEW
    @State private var shuffled: Bool = false
    @State private var currentIndex: Int = 0
    @State private var isFlipped: Bool = false
    @State private var flipDeg: Double = 0

    private let synthesizer = AVSpeechSynthesizer()

    // Session color palette
    static let colors: [Color] = [
        .clear,
        Color(hex: "#ff6b6b"), Color(hex: "#4ecdc4"), Color(hex: "#a78bfa"),
        Color(hex: "#fb923c"), Color(hex: "#34d399"), Color(hex: "#f472b6"),
        Color(hex: "#60a5fa"), Color(hex: "#facc15"), Color(hex: "#e8c547"),
    ]

    private var maxSession: Int {
        allWords.map(\.session).max() ?? 1
    }

    private var displayList: [Word] {
        var list: [Word]
        switch filterSession {
        case 0:  list = allWords
        case -1: list = allWords.filter { $0.isNew }
        default: list = allWords.filter { $0.session == filterSession }
        }
        return shuffled ? list.shuffled() : list
    }

    private var card: Word? {
        guard !displayList.isEmpty else { return nil }
        return displayList[min(currentIndex, displayList.count - 1)]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0f0e17").ignoresSafeArea()

                VStack(spacing: 0) {
                    // Session filter chips
                    sessionFilterBar
                        .padding(.horizontal)
                        .padding(.top, 8)

                    // Progress
                    if !displayList.isEmpty {
                        HStack {
                            ProgressView(value: Double(currentIndex + 1), total: Double(displayList.count))
                                .tint(Color(hex: "#e8c547"))
                            Text("\(currentIndex + 1)/\(displayList.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                    }

                    Spacer(minLength: 16)

                    // Card
                    if let card {
                        cardView(card)
                            .padding(.horizontal, 20)
                            .gesture(DragGesture(minimumDistance: 40)
                                .onEnded { val in
                                    if val.translation.width < -40 { goNext() }
                                    else if val.translation.width > 40 { goPrev() }
                                })
                    } else {
                        Text("단어가 없습니다")
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 16)

                    // Nav arrows
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

                    // Word chips
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
                        currentIndex = 0
                        isFlipped = false
                        flipDeg = 0
                    } label: {
                        Image(systemName: shuffled ? "shuffle.circle.fill" : "shuffle")
                            .foregroundStyle(Color(hex: "#e8c547"))
                    }
                }
            }
        }
    }

    // MARK: - Session filter bar
    @ViewBuilder
    private var sessionFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                sessionChip(label: "ALL", value: 0)
                ForEach(1...maxSession, id: \.self) { s in
                    sessionChip(label: "S\(s)", value: s)
                }
                let hasNew = allWords.contains { $0.isNew }
                if hasNew {
                    sessionChip(label: "NEW", value: -1)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func sessionChip(label: String, value: Int) -> some View {
        let color = value == -1 ? Color(hex: "#00ffcc")
            : value == 0 ? Color(hex: "#e8c547")
            : Self.colors[value % Self.colors.count]
        let selected = filterSession == value
        Button {
            filterSession = value
            currentIndex = 0
            isFlipped = false
            flipDeg = 0
        } label: {
            Text(label)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(selected ? color : Color.clear)
                .foregroundStyle(selected ? Color(hex: "#0f0e17") : color)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(color, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Flash card
    @ViewBuilder
    private func cardView(_ word: Word) -> some View {
        ZStack {
            // Front
            cardFace(word: word, isFront: true)
                .rotation3DEffect(.degrees(flipDeg), axis: (x: 0, y: 1, z: 0))
                .opacity(flipDeg < 90 ? 1 : 0)

            // Back
            cardFace(word: word, isFront: false)
                .rotation3DEffect(.degrees(flipDeg - 180), axis: (x: 0, y: 1, z: 0))
                .opacity(flipDeg >= 90 ? 1 : 0)
        }
        .frame(height: 260)
        .onTapGesture { flipCard() }
    }

    @ViewBuilder
    private func cardFace(word: Word, isFront: Bool) -> some View {
        let sessionColor = Self.colors[word.session % Self.colors.count]
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(isFront
                    ? LinearGradient(colors: [Color(hex: "#1a1828"), Color(hex: "#221f35")], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [Color(hex: "#1b2a2a"), Color(hex: "#142320")], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(sessionColor.opacity(0.3), lineWidth: 1))

            VStack(spacing: 14) {
                if isFront {
                    Text("Session \(word.session)\(word.isNew ? " ★" : "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(word.word)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(Color(hex: "#e8c547"))
                        .multilineTextAlignment(.center)
                    speakButton(text: word.word, label: "🔊")
                    Text("탭하여 뒤집기")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else {
                    Text(word.meaning)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color(hex: "#4ecdc4"))
                        .multilineTextAlignment(.center)
                    Text(word.exampleEn)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    speakButton(text: word.exampleEn, label: "🔊 예문")
                }
            }
            .padding(24)
        }
    }

    @ViewBuilder
    private func speakButton(text: String, label: String) -> some View {
        Button {
            speak(text)
        } label: {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.4), lineWidth: 1))
        }
        .foregroundStyle(.secondary)
    }

    // MARK: - Word chips
    @ViewBuilder
    private var wordChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(displayList.enumerated()), id: \.offset) { i, w in
                    let color = Self.colors[w.session % Self.colors.count]
                    let selected = i == currentIndex
                    Button {
                        currentIndex = i
                        isFlipped = false
                        flipDeg = 0
                    } label: {
                        Text(w.word)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(selected ? color : Color.clear)
                            .foregroundStyle(selected ? Color(hex: "#0f0e17") : color)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(color, lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Actions
    private func flipCard() {
        withAnimation(.easeInOut(duration: 0.4)) {
            flipDeg = isFlipped ? 0 : 180
        }
        isFlipped.toggle()
    }

    private func goNext() {
        guard !displayList.isEmpty else { return }
        isFlipped = false
        flipDeg = 0
        currentIndex = (currentIndex + 1) % displayList.count
    }

    private func goPrev() {
        guard !displayList.isEmpty else { return }
        isFlipped = false
        flipDeg = 0
        currentIndex = (currentIndex - 1 + displayList.count) % displayList.count
    }

    private func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.45
        synthesizer.speak(utterance)
    }
}
