import SwiftUI
import SwiftData

struct ListeningPracticeView: View {
    enum Difficulty: String, CaseIterable {
        case beginner    = "초급"
        case intermediate = "중급"
        case advanced    = "상급"

        var englishName: String {
            switch self {
            case .beginner:     return "beginner"
            case .intermediate: return "intermediate"
            case .advanced:     return "advanced"
            }
        }
    }

    enum EvaluationResult { case correct, incorrect }
    enum FocusField { case topic, answer }

    @Environment(\.modelContext) private var context
    @FocusState private var focusedField: FocusField?

    @State private var difficulty: Difficulty = .beginner
    @State private var topic: String = ""
    @State private var sentence: String = ""
    @State private var userAnswer: String = ""
    @State private var isGenerating = false
    @State private var evaluation: EvaluationResult? = nil
    @State private var showCorrectAnswer = false
    @State private var errorMessage: String? = nil
    @State private var savedRecord: ListeningRecord? = nil
    @State private var attemptCount: Int = 0
    @State private var showPeekedWarning = false
    @State private var sessionHistory: [String] = []
    @State private var sessionContextKey: String = ""
    @AppStorage("recentTopics")        private var recentTopicsRaw: String = ""
    @AppStorage("dailyListeningGoal")  private var dailyListeningGoal: Int = 10

    @Query(sort: \ListeningRecord.practiceDate, order: .reverse)
    private var allRecords: [ListeningRecord]

    private var recentTopics: [String] {
        recentTopicsRaw.split(separator: ",").map(String.init).filter { !$0.isEmpty }
    }

    private func addRecentTopic(_ t: String) {
        guard !t.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        var list = recentTopics.filter { $0.lowercased() != t.lowercased() }
        list.insert(t, at: 0)
        recentTopicsRaw = list.prefix(8).joined(separator: ",")
    }

    private var hasAPIKey: Bool { KeychainService.shared.hasAPIKey }

    private var todayCount: Int {
        let start = Calendar.current.startOfDay(for: Date())
        return allRecords.filter { $0.practiceDate >= start }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0f0e17").ignoresSafeArea()
                    .onTapGesture { hideKeyboard() }

                ScrollView {
                    VStack(spacing: 16) {
                        if !hasAPIKey { noKeyBanner }
                        difficultySection
                        topicSection
                        generateButton

                        if !sentence.isEmpty {
                            playbackSection
                            if evaluation != .correct { answerSection }
                            if evaluation != .correct { submitButton }
                            if let result = evaluation { resultSection(result) }
                        }

                        if let err = errorMessage {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(Color(hex: "#ff6b6b"))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding()
                    .contentShape(Rectangle())
                    .onTapGesture { hideKeyboard() }
                }
            }
            .navigationTitle("듣기 연습")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    dailyProgressView
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        ListeningHistoryView()
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(Color(hex: "#e8c547"))
                    }
                }
            }
        }
    }

    // MARK: - Daily progress

    private var dailyProgressView: some View {
        let count    = todayCount
        let goal     = dailyListeningGoal
        let progress = min(Double(count) / Double(goal), 1.0)
        let done     = count >= goal

        return ZStack {
            Circle()
                .stroke(Color(hex: "#e8c547").opacity(0.2), lineWidth: 2.5)
            if done {
                Circle()
                    .stroke(Color(hex: "#e8c547"), lineWidth: 2.5)
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color(hex: "#e8c547"))
            } else {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color(hex: "#e8c547"),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.4), value: progress)
                Text("\(count)/\(goal)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color(hex: "#e8c547"))
            }
        }
        .padding(2)
        .frame(width: 34, height: 34)
    }

    // MARK: - Sections

    private var noKeyBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "key.slash")
            Text("API 키를 설정탭에서 입력해주세요.")
                .font(.caption)
        }
        .foregroundStyle(Color(hex: "#0f0e17"))
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color(hex: "#e8c547"))
        .cornerRadius(10)
    }

    private var difficultySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("난이도")
                .font(.caption.bold())
                .foregroundStyle(Color(hex: "#e8c547"))
            Picker("난이도", selection: $difficulty) {
                ForEach(Difficulty.allCases, id: \.self) { d in
                    Text(d.rawValue).tag(d)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(Color(hex: "#1a1828"))
        .cornerRadius(12)
    }

    private var topicSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("주제 (선택)")
                .font(.caption.bold())
                .foregroundStyle(Color(hex: "#e8c547"))
            TextField("예: food, travel, sports...", text: $topic)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .padding(10)
                .background(Color(hex: "#0f0e17"))
                .cornerRadius(8)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
                .focused($focusedField, equals: .topic)
                .onSubmit { hideKeyboard() }

            if !recentTopics.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(recentTopics, id: \.self) { t in
                            Button {
                                topic = t
                                hideKeyboard()
                            } label: {
                                Text(t)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(topic == t
                                                ? Color(hex: "#e8c547")
                                                : Color(hex: "#e8c547").opacity(0.15))
                                    .foregroundStyle(topic == t
                                                     ? Color(hex: "#0f0e17")
                                                     : Color(hex: "#e8c547"))
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
        .padding()
        .background(Color(hex: "#1a1828"))
        .cornerRadius(12)
    }

    private var generateButton: some View {
        Button {
            hideKeyboard()
            Task { await generateSentence() }
        } label: {
            HStack(spacing: 8) {
                if isGenerating {
                    ProgressView().tint(Color(hex: "#0f0e17")).scaleEffect(0.85)
                } else {
                    Image(systemName: "sparkles")
                }
                Text(sentence.isEmpty ? "문장 생성" : "다음 문장")
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .background(isGenerating || !hasAPIKey
                    ? Color(hex: "#e8c547").opacity(0.4)
                    : Color(hex: "#e8c547"))
        .foregroundStyle(Color(hex: "#0f0e17"))
        .cornerRadius(12)
        .disabled(isGenerating || !hasAPIKey)
    }

    private var playbackSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "waveform")
                    .foregroundStyle(Color(hex: "#e8c547"))
                Text("문장이 준비되었습니다. 잘 듣고 입력하세요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                playButton(label: "재생", icon: "play.fill", slow: false,
                           bg: Color(hex: "#e8c547"), fg: Color(hex: "#0f0e17"))
                playButton(label: "느리게", icon: "tortoise.fill", slow: true,
                           bg: Color(hex: "#1a1828"), fg: .white, bordered: true)
            }
        }
        .padding()
        .background(Color(hex: "#1a1828"))
        .cornerRadius(12)
    }

    private func playButton(label: String, icon: String, slow: Bool,
                            bg: Color, fg: Color, bordered: Bool = false) -> some View {
        Button {
            SpeechService.shared.speak(sentence, language: "en-US", slow: slow)
        } label: {
            Label(label, systemImage: icon)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .background(bg)
        .foregroundStyle(fg)
        .cornerRadius(10)
        .overlay(bordered
                 ? RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(hex: "#e8c547").opacity(0.4), lineWidth: 1)
                 : nil)
    }

    private var answerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("들은 내용 입력")
                .font(.caption.bold())
                .foregroundStyle(Color(hex: "#e8c547"))
            ZStack(alignment: .topLeading) {
                if userAnswer.isEmpty {
                    Text("여기에 입력하세요...")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                }
                TextEditor(text: $userAnswer)
                    .frame(minHeight: 90)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.never)
                    .focused($focusedField, equals: .answer)
            }
            .padding(10)
            .background(Color(hex: "#0f0e17"))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(hex: "#1a1828"))
        .cornerRadius(12)
    }

    private var submitButton: some View {
        let disabled = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return VStack(spacing: 6) {
            Button {
                hideKeyboard()
                if showCorrectAnswer {
                    showPeekedWarning = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        showPeekedWarning = false
                    }
                } else {
                    evaluate()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                    Text(attemptCount == 0 ? "제출" : "제출 (\(attemptCount)회)")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .background(disabled ? Color.gray.opacity(0.35) : Color(hex: "#e8c547"))
            .foregroundStyle(disabled ? Color.secondary : Color(hex: "#0f0e17"))
            .cornerRadius(12)
            .disabled(disabled)

            if showPeekedWarning {
                HStack(spacing: 6) {
                    Image(systemName: "eye.slash")
                    Text("정답을 확인했으므로 재제출할 수 없습니다.")
                        .font(.caption)
                }
                .foregroundStyle(Color(hex: "#e8c547"))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showPeekedWarning)
    }

    private func resultSection(_ result: EvaluationResult) -> some View {
        VStack(spacing: 14) {
            // 정답 / 오답 뱃지
            HStack(spacing: 8) {
                Image(systemName: result == .correct
                      ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title2)
                Text(result == .correct ? "정답 ✓" : "오답 ✗")
                    .font(.headline.bold())
            }
            .foregroundStyle(result == .correct ? Color.green : Color(hex: "#ff6b6b"))

            // 정답 문장 공개 영역
            if showCorrectAnswer {
                VStack(alignment: .leading, spacing: 6) {
                    Text("정답 문장")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    SelectableText(sentence)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .background(Color(hex: "#0f0e17"))
                .cornerRadius(8)
            } else {
                Button {
                    withAnimation(.easeIn(duration: 0.2)) {
                        showCorrectAnswer = true
                    }
                    let record = ListeningRecord(
                        sentence: sentence,
                        topic: topic.trimmingCharacters(in: .whitespaces),
                        difficulty: difficulty.englishName,
                        isCorrect: evaluation == .correct,
                        userAnswer: userAnswer,
                        attemptCount: attemptCount
                    )
                    context.insert(record)
                    savedRecord = record
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "eye")
                        Text("정답 보기")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .background(Color(hex: "#0f0e17"))
                .foregroundStyle(.secondary)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .padding()
        .background(Color(hex: "#1a1828"))
        .cornerRadius(12)
    }

    // MARK: - Persistent recent sentences

    private func sentencesKey(for topic: String) -> String {
        let t = topic.trimmingCharacters(in: .whitespaces)
        return "recentSentences_\(t.isEmpty ? "general" : t.lowercased())"
    }

    private func loadStoredSentences(for topic: String) -> [String] {
        let key = sentencesKey(for: topic)
        guard let data = UserDefaults.standard.data(forKey: key),
              let arr = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return arr
    }

    private func saveStoredSentences(_ sentences: [String], for topic: String) {
        let key = sentencesKey(for: topic)
        if let data = try? JSONEncoder().encode(Array(sentences.prefix(5))) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // MARK: - Logic

    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
        focusedField = nil
    }

    private func generateSentence() async {
        isGenerating = true
        evaluation = nil
        showCorrectAnswer = false
        showPeekedWarning = false
        userAnswer = ""
        errorMessage = nil
        sentence = ""
        savedRecord = nil
        attemptCount = 0

        let trimmedTopic = topic.trimmingCharacters(in: .whitespaces)

        // topic 또는 difficulty가 바뀌면 세션 히스토리 초기화
        let contextKey = "\(trimmedTopic)|\(difficulty.englishName)"
        if contextKey != sessionContextKey {
            sessionHistory = []
            sessionContextKey = contextKey
        }

        let stored = loadStoredSentences(for: trimmedTopic)  // newest-first, max 5

        // stored(oldest-first) + sessionHistory 합산 후 중복 제거, 최대 5개
        var combined: [String] = []
        for s in stored.reversed() where !combined.contains(s) { combined.append(s) }
        for s in sessionHistory  where !combined.contains(s) { combined.append(s) }
        let history = Array(combined.suffix(5))

        do {
            let result = try await ClaudeService.shared.generateListeningSentence(
                difficulty: difficulty.englishName,
                topic: trimmedTopic,
                conversationHistory: history
            )
            sentence = result
            sessionHistory.append(result)
            saveStoredSentences([result] + stored, for: trimmedTopic)
            addRecentTopic(trimmedTopic)
            SpeechService.shared.speak(sentence, language: "en-US")
        } catch {
            errorMessage = error.localizedDescription
        }
        isGenerating = false
    }

    private func evaluate() {
        let isCorrect = userAnswer.normalized == sentence.normalized
        evaluation = isCorrect ? .correct : .incorrect
        attemptCount += 1
    }
}
