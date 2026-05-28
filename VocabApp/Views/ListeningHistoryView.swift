import SwiftUI
import SwiftData

struct ListeningHistoryView: View {
    @Query(sort: \ListeningRecord.practiceDate, order: .reverse)
    private var allRecords: [ListeningRecord]

    @State private var searchText = ""
    @State private var sortOption: SortOption = .newest
    @State private var filterOption: FilterOption = .all
    @State private var selectedRecord: ListeningRecord? = nil
    @Environment(\.modelContext) private var context

    enum SortOption: String, CaseIterable {
        case newest    = "최신순"
        case oldest    = "오래된순"
        case difficulty = "난이도순"
    }

    enum FilterOption: String, CaseIterable {
        case all       = "전체"
        case correct   = "정답만"
        case incorrect = "오답만"
    }

    private var filteredRecords: [ListeningRecord] {
        var records = allRecords

        switch filterOption {
        case .correct:   records = records.filter { $0.isCorrect }
        case .incorrect: records = records.filter { !$0.isCorrect }
        case .all:       break
        }

        if !searchText.isEmpty {
            let q = searchText.lowercased()
            records = records.filter {
                $0.sentence.lowercased().contains(q) || $0.topic.lowercased().contains(q)
            }
        }

        switch sortOption {
        case .newest:     break  // @Query already sorted newest-first
        case .oldest:     records.sort { $0.practiceDate < $1.practiceDate }
        case .difficulty:
            let order = ["beginner": 0, "intermediate": 1, "advanced": 2]
            records.sort { (order[$0.difficulty] ?? 0) < (order[$1.difficulty] ?? 0) }
        }

        return records
    }

    private var correctCount: Int { allRecords.filter { $0.isCorrect }.count }
    private var correctPct: Int {
        allRecords.isEmpty ? 0 : Int(Double(correctCount) / Double(allRecords.count) * 100)
    }

    // 날짜별 순번(1-based, 목록에 나타나는 순서)을 record와 묶어서 반환
    private var indexedFilteredRecords: [(dayIndex: Int, record: ListeningRecord)] {
        let calendar = Calendar.current
        var dayCounts: [Date: Int] = [:]
        return filteredRecords.map { record in
            let day = calendar.startOfDay(for: record.practiceDate)
            let n = (dayCounts[day] ?? 0) + 1
            dayCounts[day] = n
            return (dayIndex: n, record: record)
        }
    }
    private var isFiltered: Bool { sortOption != .newest || filterOption != .all }

    var body: some View {
        ZStack {
            Color(hex: "#0f0e17").ignoresSafeArea()

            if allRecords.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    statsBar
                    recordsList
                }
            }
        }
        .navigationTitle("연습 기록")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .searchable(text: $searchText, prompt: "주제 또는 문장 검색")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                sortFilterMenu
            }
        }
        .sheet(item: $selectedRecord) { record in
            RecordDetailSheet(record: record)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(Color(hex: "#e8c547").opacity(0.4))
            Text("연습 기록이 없습니다")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("듣기 연습을 완료하면 자동으로 저장됩니다.")
                .font(.caption)
                .foregroundStyle(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: 0) {
            statItem(value: "\(allRecords.count)", label: "총 연습")
            Divider().frame(height: 28).background(Color.secondary.opacity(0.3))
            statItem(value: "\(correctCount)", label: "정답")
            Divider().frame(height: 28).background(Color.secondary.opacity(0.3))
            statItem(value: "\(correctPct)%", label: "정답률", accent: true)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color(hex: "#1a1828"))
    }

    private func statItem(value: String, label: String, accent: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.bold())
                .foregroundStyle(accent ? Color(hex: "#e8c547") : .white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Records List

    private var recordsList: some View {
        Group {
            if filteredRecords.isEmpty {
                VStack(spacing: 10) {
                    Spacer().frame(height: 80)
                    Image(systemName: "magnifyingglass")
                        .font(.title)
                        .foregroundStyle(.secondary.opacity(0.6))
                    Text("검색 결과가 없습니다")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(indexedFilteredRecords, id: \.record.id) { item in
                        RecordRow(record: item.record, dayIndex: item.dayIndex)
                            .onTapGesture { selectedRecord = item.record }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                    .onDelete { indexSet in
                        indexSet.forEach { context.delete(indexedFilteredRecords[$0].record) }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    // MARK: - Sort / Filter Menu

    private var sortFilterMenu: some View {
        Menu {
            Section("정렬") {
                ForEach(SortOption.allCases, id: \.self) { opt in
                    Button { sortOption = opt } label: {
                        if sortOption == opt {
                            Label(opt.rawValue, systemImage: "checkmark")
                        } else {
                            Text(opt.rawValue)
                        }
                    }
                }
            }
            Section("필터") {
                ForEach(FilterOption.allCases, id: \.self) { opt in
                    Button { filterOption = opt } label: {
                        if filterOption == opt {
                            Label(opt.rawValue, systemImage: "checkmark")
                        } else {
                            Text(opt.rawValue)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: isFiltered
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
            .foregroundStyle(Color(hex: "#e8c547"))
        }
    }
}

// MARK: - RecordRow

private struct RecordRow: View {
    let record: ListeningRecord
    let dayIndex: Int

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: record.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title3)
                .foregroundStyle(record.isCorrect ? Color.green : Color(hex: "#ff6b6b"))
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    if !record.topic.isEmpty {
                        Text(record.topic)
                            .font(.caption.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#e8c547").opacity(0.15))
                            .foregroundStyle(Color(hex: "#e8c547"))
                            .cornerRadius(4)
                    }
                    Text(record.difficultyLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatDate(record.practiceDate))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("#\(dayIndex)")
                        .font(.caption2.bold())
                        .foregroundStyle(Color(hex: "#e8c547").opacity(0.7))
                }
                Text(record.sentence)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(12)
        .background(Color(hex: "#1a1828"))
        .cornerRadius(10)
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "오늘" }
        if calendar.isDateInYesterday(date) { return "어제" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = calendar.isDate(date, equalTo: Date(), toGranularity: .year)
            ? "M월 d일" : "yyyy년 M월 d일"
        return f.string(from: date)
    }
}

// MARK: - RecordDetailSheet

private struct RecordDetailSheet: View {
    let record: ListeningRecord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0f0e17").ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        resultBadge
                        sentenceCard
                        if !record.userAnswer.isEmpty { userAnswerCard }
                        playbackButtons
                        metadataCard
                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationTitle("상세 보기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") { dismiss() }
                        .foregroundStyle(Color(hex: "#e8c547"))
                }
            }
        }
    }

    private var resultBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: record.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
            Text(record.isCorrect ? "정답" : "오답")
                .font(.headline.bold())
        }
        .foregroundStyle(record.isCorrect ? Color.green : Color(hex: "#ff6b6b"))
        .padding(.top, 4)
    }

    private var sentenceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("문장")
                .font(.caption.bold())
                .foregroundStyle(Color(hex: "#e8c547"))
            Text(record.sentence)
                .font(.body)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(hex: "#1a1828"))
        .cornerRadius(12)
    }

    private var userAnswerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("내 답변")
                .font(.caption.bold())
                .foregroundStyle(record.isCorrect ? Color.green : Color(hex: "#ff6b6b"))
            diffText
                .font(.body)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(hex: "#1a1828"))
        .cornerRadius(12)
    }

    // Word-by-word diff: green = match, red = mismatch.
    // Uses greedy LCS — for each user word, scans forward in the sentence word list.
    private var diffText: Text {
        let userWords = record.userAnswer
            .components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        if record.isCorrect || userWords.isEmpty {
            var attr = AttributedString(record.userAnswer)
            attr.foregroundColor = .green.opacity(0.9)
            return Text(attr)
        }

        let sentenceNorms = record.sentence.normalizedWords
        var sentenceIdx = 0
        var attributed = AttributedString()

        for (i, word) in userWords.enumerated() {
            let matched: Bool
            if let j = sentenceNorms[sentenceIdx...].firstIndex(where: { $0 == word.normalized }) {
                sentenceIdx = j + 1
                matched = true
            } else {
                matched = false
            }
            if i > 0 { attributed += AttributedString(" ") }
            var piece = AttributedString(word)
            piece.foregroundColor = matched ? .green : Color(hex: "#ff6b6b")
            attributed += piece
        }

        return Text(attributed)
    }

    private var playbackButtons: some View {
        HStack(spacing: 12) {
            playBtn(label: "재생", icon: "play.fill", rate: 0.42,
                    bg: Color(hex: "#e8c547"), fg: Color(hex: "#0f0e17"))
            playBtn(label: "느리게", icon: "tortoise.fill", rate: 0.30,
                    bg: Color(hex: "#1a1828"), fg: .white, bordered: true)
        }
    }

    private func playBtn(label: String, icon: String, rate: Float,
                         bg: Color, fg: Color, bordered: Bool = false) -> some View {
        Button {
            SpeechService.shared.speak(record.sentence, language: "en-US", rate: rate)
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

    private var metadataCard: some View {
        VStack(spacing: 0) {
            metaRow(label: "난이도", value: record.difficultyLabel)
            Divider().background(Color(hex: "#0f0e17"))
            metaRow(label: "주제", value: record.topic.isEmpty ? "—" : record.topic)
            Divider().background(Color(hex: "#0f0e17"))
            metaRow(label: "제출 횟수", value: "\(record.attemptCount)회")
            Divider().background(Color(hex: "#0f0e17"))
            metaRow(label: "날짜",
                    value: record.practiceDate.formatted(
                        date: .abbreviated, time: .shortened))
        }
        .background(Color(hex: "#1a1828"))
        .cornerRadius(12)
    }

    private func metaRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
