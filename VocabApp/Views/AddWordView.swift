import SwiftUI
import SwiftData
import AVFoundation

struct AddWordView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("setBatchSize") private var setBatchSize: Int = 20

    // pending 단어만 실시간 쿼리
    @Query(filter: #Predicate<Word> { $0.isPending == true }, sort: \Word.addedDate)
    private var pendingWords: [Word]

    // 최대 세트 번호 계산용 (완성된 세트만)
    @Query(filter: #Predicate<Word> { $0.isPending == false }, sort: \Word.set, order: .reverse)
    private var completedWords: [Word]

    @State private var inputWord: String = ""
    @State private var detail: WordDetail? = nil
    @State private var isLoading: Bool = false
    @State private var errorMessage: String = ""
    @State private var showSuccess: Bool = false
    @State private var duplicateWords: [Word] = []
    @State private var wordIndexSet: Set<String> = []

    private var pendingCount: Int { pendingWords.count }
    private var progress: Double { min(Double(pendingCount) / Double(setBatchSize), 1.0) }
    private var isBatchComplete: Bool { pendingCount >= setBatchSize }

    // 진행중 세트 번호: pending 단어가 있으면 그 세트, 없으면 완성 세트 최대값 + 1
    private var pendingSetNumber: Int {
        if let first = pendingWords.first { return first.set }
        return (completedWords.first?.set ?? 0) + 1
    }

    private var hasAPIKey: Bool { KeychainService.shared.hasAPIKey }

    var body: some View {
        ZStack {
                Color(hex: "#0f0e17").ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        progressSection
                        if !hasAPIKey { noKeyBanner }
                        inputSection
                        if !duplicateWords.isEmpty { duplicateWarningBanner }
                        if !errorMessage.isEmpty {
                            messageBanner(text: errorMessage, color: Color(hex: "#ff6b6b"))
                        }
                        if showSuccess {
                            messageBanner(text: "추가 완료!", color: Color(hex: "#4ecdc4"), icon: "checkmark.circle.fill")
                        }
                        if let d = detail { detailSection(d) }
                        if !pendingWords.isEmpty { pendingWordsSection }
                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationTitle("새 단어")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onReceive(NotificationCenter.default.publisher(for: .searchRelatedWord)) { notification in
                guard let word = notification.userInfo?["word"] as? String else { return }
                inputWord = word
                Task { await generate() }
            }
            .onAppear { rebuildWordIndex() }
            .onChange(of: pendingWords)   { rebuildWordIndex() }
            .onChange(of: completedWords) { rebuildWordIndex() }
    }

    // MARK: - Progress bar
    @ViewBuilder
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("진행중 세트 \(pendingSetNumber)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(pendingCount) / \(setBatchSize)")
                    .font(.caption.bold())
                    .foregroundStyle(isBatchComplete
                                     ? Color(hex: "#e8c547")
                                     : Color(hex: "#4ecdc4"))
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
                    Text("세트 \(pendingSetNumber) 완성! 다음 단어부터 새 세트 시작")
                        .font(.caption.bold())
                        .foregroundStyle(Color(hex: "#e8c547"))
                }
            } else {
                Text("\(setBatchSize - pendingCount)개 더 추가하면 세트 완성")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(Color(hex: "#1a1828"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Pending Words
    @ViewBuilder
    private var pendingWordsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("진행 중인 단어")
                    .font(.caption.bold())
                    .foregroundStyle(Color(hex: "#4ecdc4"))
                Spacer()
                Text("\(pendingWords.count)개")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 4) {
                ForEach(pendingWords.reversed()) { word in
                    HStack(spacing: 8) {
                        Text(word.word)
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer()
                        Text(word.meaning)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color(hex: "#1a1828"))
                    .cornerRadius(8)
                }
            }
        }
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

            TextField("예: apple, happy, good morning...", text: $inputWord)
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
                .onChange(of: inputWord) { _, newValue in
                    checkDuplicate(newValue)
                }
                .overlay(alignment: .trailing) {
                    if isLoading {
                        ProgressView().padding(.trailing, 12)
                    }
                }
        }
    }

    // MARK: - Detail section
    @ViewBuilder
    private func detailSection(_ d: WordDetail) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 단어 헤더
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    SelectableText(
                        d.word,
                        font: .systemFont(ofSize: 28, weight: .bold),
                        color: UIColor(Color(hex: "#e8c547"))
                    )
                    HStack(spacing: 8) {
                        SelectableText(
                            d.pronunciation,
                            font: .preferredFont(forTextStyle: .subheadline),
                            color: .secondaryLabel
                        )
                        Text(d.partOfSpeech)
                            .font(.caption.bold())
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color(hex: "#a78bfa").opacity(0.2))
                            .foregroundStyle(Color(hex: "#a78bfa"))
                            .clipShape(Capsule())
                    }
                }
                Spacer()
                Button { speak(d.word) } label: {
                    Image(systemName: "speaker.wave.2")
                        .foregroundStyle(.secondary).font(.title3)
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color(hex: "#1a1828"))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            detailCard(title: "한국어 뜻", icon: "textformat.alt") {
                SelectableText(
                    d.meaningKo,
                    font: .systemFont(ofSize: 20, weight: .bold),
                    color: UIColor(Color(hex: "#4ecdc4"))
                )
            }

            detailCard(title: "Definition", icon: "book") {
                SelectableText(
                    d.detailedDefinition,
                    font: .preferredFont(forTextStyle: .subheadline),
                    color: .label,
                    lineSpacing: 4
                )
            }

            detailCard(title: "예문", icon: "quote.bubble") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(d.examples.enumerated()), id: \.offset) { i, ex in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(i + 1)")
                                .font(.caption.bold()).foregroundStyle(.secondary).frame(width: 16)
                            SelectableText(
                                ex,
                                font: .preferredFont(forTextStyle: .subheadline),
                                color: .label,
                                lineSpacing: 3
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
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

            if !d.nuance.isEmpty {
                detailCard(title: "뉘앙스 & 사용 팁", icon: "lightbulb") {
                    SelectableText(
                        d.nuance,
                        font: .preferredFont(forTextStyle: .subheadline),
                        color: .label,
                        lineSpacing: 4
                    )
                }
            }

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

    // MARK: - Duplicate Warning Banner
    @ViewBuilder
    private var duplicateWarningBanner: some View {
        let setLabels: [String] = Array(
            Set(duplicateWords.map { $0.isPending ? "진행중 세트" : "세트 \($0.set)" })
        ).sorted()

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color(hex: "#e8c547"))
                Text("이미 등록된 단어입니다")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color(hex: "#e8c547"))
            }
            Text(setLabels.isEmpty ? "미분류 단어로 등록되어 있습니다" : setLabels.joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#e8c547").opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#e8c547").opacity(0.3), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Actions
    @MainActor
    private func generate() async {
        let trimmed = inputWord.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        errorMessage = ""
        showSuccess = false
        detail = nil
        do {
            detail = try await ClaudeService.shared.generateWordDetail(trimmed)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func addWord(_ d: WordDetail) {
        // 핵심 로직:
        // - 항상 진행중(isPending=true) 세트에만 추가
        // - 추가 후 pendingCount가 setBatchSize에 도달하면:
        //   → 모든 pending을 완성(isPending=false)으로 전환 → 진행바 자동 0 리셋
        // - 새 세트 탭은 생성하지 않음 (탭은 완성 세트 기준으로만 표시)

        let targetSet = pendingSetNumber

        let newWord = Word(
            word: d.word,
            meaning: d.cardMeaning,
            exampleEn: d.cardExample,
            set: targetSet,
            isPending: true,
            pronunciation: d.pronunciation,
            partOfSpeech: d.partOfSpeech,
            detailedDefinition: d.detailedDefinition,
            examples: d.examples,
            nuance: d.nuance,
            relatedWords: d.relatedWords
        )
        context.insert(newWord)

        // 추가 후 개수 체크 (newWord 포함)
        let newCount = pendingCount + 1
        if newCount >= setBatchSize {
            // 모든 pending(기존 + 방금 추가한 것) 완성 처리
            for w in pendingWords { w.isPending = false }
            newWord.isPending = false
            // → pendingWords가 빈 배열이 되어 진행바 자동 0 리셋
        }

        try? context.save()

        detail = nil
        inputWord = ""
        duplicateWords = []
        showSuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showSuccess = false
        }
    }

    private func speak(_ text: String) {
        SpeechService.shared.speak(text, language: "en-US")
    }

    private func rebuildWordIndex() {
        wordIndexSet = Set((pendingWords + completedWords).map { $0.word.lowercased() })
    }

    private func checkDuplicate(_ input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { duplicateWords = []; return }
        if wordIndexSet.contains(trimmed.lowercased()) {
            duplicateWords = (pendingWords + completedWords).filter {
                $0.word.compare(trimmed, options: .caseInsensitive) == .orderedSame
            }
        } else {
            duplicateWords = []
        }
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
