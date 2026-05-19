import SwiftUI
import SwiftData
import AVFoundation

private let SET_BATCH = 20

struct AddWordView: View {
    @Environment(\.modelContext) private var context
    // pending 단어만 쿼리 (isPending == true)
    @Query(filter: #Predicate<Word> { $0.isPending == true },
           sort: \Word.addedDate)
    private var pendingWords: [Word]

    // 전체 단어에서 최대 세트 번호 계산용
    @Query(sort: \Word.set, order: .reverse) private var allWordsBySet: [Word]

    @State private var inputWord: String = ""
    @State private var detail: WordDetail? = nil
    @State private var isLoading: Bool = false
    @State private var errorMessage: String = ""
    @State private var successMessage: String = ""

    private let synthesizer = AVSpeechSynthesizer()

    private var pendingCount: Int { pendingWords.count }
    private var progress: Double { min(Double(pendingCount) / Double(SET_BATCH), 1.0) }
    private var isBatchComplete: Bool { pendingCount >= SET_BATCH }

    // 다음 단어가 들어갈 세트 번호
    // pending이 20개 미만이면 현재 pending 세트 유지, 아니면 새 세트
    private var nextSetNumber: Int {
        let maxSet = allWordsBySet.first?.set ?? 0
        // pending 단어들이 20개 미만이면 같은 세트에 넣기
        if pendingCount < SET_BATCH {
            // pending 단어가 없으면 새 세트 시작
            return pendingWords.first?.set ?? (maxSet + 1)
        } else {
            // 20개 달성 → 새 세트 번호
            return maxSet + 1
        }
    }

    private var hasAPIKey: Bool {
        !(KeychainService.shared.loadAPIKey() ?? "").isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0f0e17").ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        progressSection
                        if !hasAPIKey { noKeyBanner }
                        inputSection
                        if !errorMessage.isEmpty {
                            messageBanner(text: errorMessage, color: Color(hex: "#ff6b6b"))
                        }
                        if !successMessage.isEmpty {
                            messageBanner(text: successMessage, color: Color(hex: "#4ecdc4"), icon: "checkmark.circle.fill")
                        }
                        if let d = detail { detailSection(d) }
                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationTitle("새 단어")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Progress bar
    @ViewBuilder
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("새 단어 진행")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(pendingCount) / \(SET_BATCH)")
                    .font(.caption.bold())
                    .foregroundStyle(isBatchComplete ? Color(hex: "#e8c547") : Color(hex: "#4ecdc4"))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isBatchComplete ? Color(hex: "#e8c547") : Color(hex: "#4ecdc4"))
                        .frame(width: geo.size.width * progress, height: 8)
                        .animation(.easeInOut(duration: 0.4), value: pendingCount)
                }
            }
            .frame(height: 8)

            if isBatchComplete {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill").foregroundStyle(Color(hex: "#e8c547"))
                    Text("20개 달성! 세트 \(pendingWords.first?.set ?? 0) 완성 🎉")
                        .font(.caption.bold())
                        .foregroundStyle(Color(hex: "#e8c547"))
                }
            } else {
                Text("20개가 쌓이면 새 세트로 확정됩니다")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(Color(hex: "#1a1828"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Banners
    @ViewBuilder
    private var noKeyBanner: some View {
        HStack {
            Image(systemName: "key.fill")
            Text("설정 탭에서 API 키를 먼저 입력해주세요.")
        }
        .font(.subheadline)
        .foregroundStyle(Color(hex: "#ff6b6b"))
        .padding()
        .background(Color(hex: "#ff6b6b").opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func messageBanner(text: String, color: Color, icon: String = "exclamationmark.triangle") -> some View {
        HStack {
            Image(systemName: icon)
            Text(text)
        }
        .font(.subheadline)
        .foregroundStyle(color)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Input
    @ViewBuilder
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("단어 / 표현")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                TextField("예: serendipity, break a leg...", text: $inputWord)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color(hex: "#1a1828"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1)))
                    .foregroundStyle(.white)
                    .submitLabel(.search)
                    .autocorrectionDisabled(false)
                    .textInputAutocapitalization(.never)
                    .onSubmit { Task { await generate() } }

                Button {
                    Task { await generate() }
                } label: {
                    if isLoading {
                        ProgressView().tint(Color(hex: "#0f0e17"))
                    } else {
                        Text("생성").font(.subheadline.bold())
                    }
                }
                .frame(width: 60, height: 44)
                .background(Color(hex: "#e8c547"))
                .foregroundStyle(Color(hex: "#0f0e17"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(isLoading || inputWord.trimmingCharacters(in: .whitespaces).isEmpty || !hasAPIKey)
            }
        }
    }

    // MARK: - Detail section
    @ViewBuilder
    private func detailSection(_ d: WordDetail) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 단어 헤더
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(d.word)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color(hex: "#e8c547"))
                    Button { speak(d.word) } label: {
                        Image(systemName: "speaker.wave.2")
                            .foregroundStyle(.secondary).font(.title3)
                    }
                }
                HStack(spacing: 8) {
                    Text(d.pronunciation).font(.subheadline).foregroundStyle(.secondary)
                    Text(d.partOfSpeech)
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

            // 한국어 뜻
            detailCard(title: "한국어 뜻", icon: "textformat.alt") {
                Text(d.meaningKo)
                    .font(.title3.bold())
                    .foregroundStyle(Color(hex: "#4ecdc4"))
            }

            // 영어 정의
            detailCard(title: "Definition", icon: "book") {
                Text(d.detailedDefinition)
                    .font(.subheadline).foregroundStyle(.primary).lineSpacing(4)
            }

            // 예문
            detailCard(title: "예문", icon: "quote.bubble") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(d.examples.enumerated()), id: \.offset) { i, ex in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(i + 1)")
                                .font(.caption.bold()).foregroundStyle(.secondary).frame(width: 16)
                            Text(ex)
                                .font(.subheadline).foregroundStyle(.primary).lineSpacing(3)
                            Spacer()
                            Button { speak(ex) } label: {
                                Image(systemName: "speaker.wave.2")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        if i < d.examples.count - 1 {
                            Divider().background(Color.white.opacity(0.1))
                        }
                    }
                }
            }

            // 뉘앙스
            if !d.nuance.isEmpty {
                detailCard(title: "뉘앙스 & 사용 팁", icon: "lightbulb") {
                    Text(d.nuance)
                        .font(.subheadline).foregroundStyle(.primary).lineSpacing(4)
                }
            }

            // 관련 단어
            if !d.relatedWords.isEmpty {
                detailCard(title: "관련 단어", icon: "link") {
                    FlowLayout(spacing: 6) {
                        ForEach(d.relatedWords, id: \.self) { w in
                            Text(w)
                                .font(.caption.bold())
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color(hex: "#fb923c").opacity(0.15))
                                .foregroundStyle(Color(hex: "#fb923c"))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            // 추가 버튼
            Button { addWord(d) } label: {
                Label("단어장에 추가", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(Color(hex: "#4ecdc4"))
                    .foregroundStyle(Color(hex: "#0f0e17"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
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

    // MARK: - Actions
    @MainActor
    private func generate() async {
        let trimmed = inputWord.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        errorMessage = ""
        successMessage = ""
        detail = nil
        do {
            detail = try await ClaudeService.shared.generateWordDetail(trimmed)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func addWord(_ d: WordDetail) {
        // 현재 pending 개수 기준으로 세트 번호 결정
        // pending < 20 → 현재 세트에 추가
        // pending >= 20 → 새 세트 시작 (기존 pending들을 완성 처리 후 새 세트)
        let currentSetNum = nextSetNumber

        // 20개 달성 시 기존 pending 단어들을 완성(isPending=false)으로 전환
        if isBatchComplete {
            for w in pendingWords {
                w.isPending = false
            }
        }

        let newWord = Word(
            word: d.word,
            meaning: d.cardMeaning,
            exampleEn: d.cardExample,
            set: currentSetNum,
            isPending: true
        )
        context.insert(newWord)
        try? context.save()

        let newCount = pendingCount + 1  // 방금 추가된 것 포함 예상치
        successMessage = "'\(d.word)' 추가! 세트 \(currentSetNum) (\(min(newCount, SET_BATCH))/\(SET_BATCH))"
        detail = nil
        inputWord = ""
    }

    private func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: "en-US")
        u.rate = 0.45
        synthesizer.speak(u)
    }
}

// MARK: - FlowLayout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let rowHeights: [CGFloat] = rows.map { row in
            row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
        }
        let totalHeight = rowHeights.reduce(0, +)
        let spacingTotal = CGFloat(max(rows.count - 1, 0)) * spacing
        return CGSize(width: proposal.width ?? 0, height: totalHeight + spacingTotal)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: ProposedViewSize(width: bounds.width, height: nil), subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let rowH = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            for sv in row {
                let sz = sv.sizeThatFits(.unspecified)
                sv.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
                x += sz.width + spacing
            }
            y += rowH + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = [[]]
        var x: CGFloat = 0
        let maxW = proposal.width ?? .infinity
        for sv in subviews {
            let w = sv.sizeThatFits(.unspecified).width
            if x + w > maxW && !rows[rows.count - 1].isEmpty {
                rows.append([])
                x = 0
            }
            rows[rows.count - 1].append(sv)
            x += w + spacing
        }
        return rows
    }
}
