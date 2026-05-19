import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Export document
struct VocabDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }
    var text: String

    init(text: String) { self.text = text }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let str = String(data: data, encoding: .utf8)
        else { throw CocoaError(.fileReadCorruptFile) }
        text = str
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

// MARK: - Import mode
enum ImportMode {
    case overwrite   // 전체 덮어쓰기: 세트 1번부터 재시작
    case append      // 추가: 기존 최대 세트 번호 + 1부터
}

// MARK: - SetManagerView
struct SetManagerView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Word.addedDate) private var allWords: [Word]

    @State private var expandedSet: Int? = nil
    @State private var editingWord: Word? = nil
    @State private var deleteSetKey: Int? = nil      // nil = 미표시, -1 = 진행중, 1+ = 세트번호

    // Export
    @State private var exportDoc: VocabDocument? = nil
    @State private var showExporter = false
    @State private var exportFilename = "vocab_export.json"

    // Import — 파일 선택 전에 모드 확인
    @State private var showImportModeSheet = false   // 덮어쓰기/추가 선택 시트
    @State private var pendingImportURL: URL? = nil  // 선택된 파일 보관
    @State private var showImporter = false

    // 결과 알림
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    // MARK: Computed
    private var completedSets: [Int] {
        Array(Set(allWords.filter { !$0.isPending }.map(\.set))).sorted()
    }
    private var pendingWords: [Word] {
        allWords.filter { $0.isPending }.sorted { $0.addedDate < $1.addedDate }
    }
    private func words(for set: Int) -> [Word] {
        allWords.filter { $0.set == set }.sorted { $0.addedDate < $1.addedDate }
    }

    // MARK: - Renumber helper
    // 완성 세트를 addedDate 오름차순으로 1, 2, 3... 재부여
    // pending 단어는 항상 max + 1 세트 번호 유지
    private func renumberSets() {
        let sortedSets = completedSets  // 이미 오름차순 정렬됨
        for (newNum, oldNum) in sortedSets.enumerated() {
            let target = newNum + 1
            if oldNum != target {
                for w in words(for: oldNum) { w.set = target }
            }
        }
        // pending 단어 세트 번호 = 완성 세트 최대값 + 1
        let newMax = completedSets.count  // renumber 후 최대값
        if !pendingWords.isEmpty {
            let pendingTarget = newMax + 1
            for w in pendingWords { w.set = pendingTarget }
        }
        try? context.save()
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0f0e17").ignoresSafeArea()

                if allWords.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray").font(.system(size: 40)).foregroundStyle(.secondary)
                        Text("단어가 없습니다").foregroundStyle(.secondary)
                    }
                } else {
                    List {
                        ForEach(completedSets, id: \.self) { setNum in
                            setSection(setNum, isPendingSection: false)
                        }
                        if !pendingWords.isEmpty {
                            setSection(-1, isPendingSection: true)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("세트 관리")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { toolbarContent }

            // ── Sheets & Alerts ──────────────────────────────────
            .sheet(item: $editingWord) { EditWordView(word: $0) }

            // Import 모드 선택 시트
            .confirmationDialog("가져오기 방식", isPresented: $showImportModeSheet, titleVisibility: .visible) {
                Button("덮어쓰기 (기존 단어 전체 삭제 후 세트 1번부터)") {
                    if let url = pendingImportURL { runImport(url: url, mode: .overwrite) }
                }
                Button("추가 (기존 세트 뒤에 이어서)") {
                    if let url = pendingImportURL { runImport(url: url, mode: .append) }
                }
                Button("취소", role: .cancel) { pendingImportURL = nil }
            } message: {
                Text("가져온 단어를 기존 단어장에 어떻게 적용할까요?")
            }

            // 파일 선택기
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json, .commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first,
                          url.startAccessingSecurityScopedResource() else {
                        showError("파일 접근 권한이 없습니다.")
                        return
                    }
                    pendingImportURL = url
                    showImportModeSheet = true
                case .failure(let e):
                    showError(e.localizedDescription)
                }
            }

            // 파일 내보내기
            .fileExporter(
                isPresented: $showExporter,
                document: exportDoc,
                contentType: exportFilename.hasSuffix(".csv") ? .commaSeparatedText : .json,
                defaultFilename: exportFilename
            ) { result in
                if case .failure(let e) = result { showError(e.localizedDescription) }
            }

            // 결과 알림
            .alert(alertTitle, isPresented: $showAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }

            // 세트 삭제 확인
            .alert("세트 삭제", isPresented: Binding(
                get: { deleteSetKey != nil },
                set: { if !$0 { deleteSetKey = nil } }
            )) {
                Button("삭제", role: .destructive) {
                    if let k = deleteSetKey { deleteSet(k) }
                }
                Button("취소", role: .cancel) { deleteSetKey = nil }
            } message: {
                if let k = deleteSetKey {
                    let count = k == -1 ? pendingWords.count : words(for: k).count
                    let label = k == -1 ? "진행중" : "세트 \(k)"
                    Text("\(label)의 단어 \(count)개를 삭제하고 세트 번호를 재정렬합니다.")
                }
            }
        }
    }

    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Button { prepareExport(format: "json") } label: {
                    Label("JSON으로 내보내기", systemImage: "arrow.up.doc")
                }
                Button { prepareExport(format: "csv") } label: {
                    Label("CSV로 내보내기", systemImage: "tablecells")
                }
            } label: {
                Image(systemName: "arrow.up.circle")
                    .foregroundStyle(Color(hex: "#e8c547"))
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { showImporter = true } label: {
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(Color(hex: "#4ecdc4"))
            }
        }
    }

    // MARK: - Set section
    @ViewBuilder
    private func setSection(_ setNum: Int, isPendingSection: Bool) -> some View {
        let setWords = isPendingSection ? pendingWords : words(for: setNum)
        let color: Color = isPendingSection
            ? Color(hex: "#00ffcc")
            : FlashCardView.colors[setNum % FlashCardView.colors.count]
        let key = isPendingSection ? -1 : setNum

        Section {
            if expandedSet == key {
                ForEach(setWords) { word in
                    wordRow(word, color: color)
                }
                .onDelete { offsets in deleteWords(at: offsets, in: setWords) }
            }
        } header: {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedSet = expandedSet == key ? nil : key
                }
            } label: {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color).frame(width: 4, height: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(isPendingSection ? "진행중" : "세트 \(setNum)")
                                .font(.headline).foregroundStyle(.white)
                            if isPendingSection {
                                Text("미완성")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color(hex: "#00ffcc").opacity(0.2))
                                    .foregroundStyle(Color(hex: "#00ffcc"))
                                    .clipShape(Capsule())
                            }
                        }
                        Text("\(setWords.count)개")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: expandedSet == key ? "chevron.up" : "chevron.down")
                        .font(.caption).foregroundStyle(.secondary)

                    Button { deleteSetKey = key } label: {
                        Image(systemName: "trash")
                            .font(.caption).foregroundStyle(Color(hex: "#ff6b6b"))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        .listRowBackground(Color(hex: "#1a1828"))
    }

    @ViewBuilder
    private func wordRow(_ word: Word, color: Color) -> some View {
        HStack(spacing: 12) {
            Circle().fill(color).frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(word.word).font(.subheadline.bold()).foregroundStyle(.white)
                Text(word.meaning).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Button { editingWord = word } label: {
                Image(systemName: "pencil").font(.caption).foregroundStyle(Color(hex: "#e8c547"))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .listRowBackground(Color(hex: "#1a1828"))
    }

    // MARK: - Delete & Renumber
    private func deleteWords(at offsets: IndexSet, in setWords: [Word]) {
        for i in offsets { context.delete(setWords[i]) }
        try? context.save()
        renumberSets()
    }

    private func deleteSet(_ key: Int) {
        let target = key == -1 ? pendingWords : words(for: key)
        for word in target { context.delete(word) }
        try? context.save()
        if expandedSet == key { expandedSet = nil }
        renumberSets()
    }

    // MARK: - Export
    private func prepareExport(format: String) {
        let sorted = allWords.sorted { $0.set == $1.set ? $0.addedDate < $1.addedDate : $0.set < $1.set }
        if format == "json" {
            let items = sorted.map { w -> [String: Any] in
                ["word": w.word, "meaning": w.meaning, "exampleEn": w.exampleEn,
                 "set": w.set, "isPending": w.isPending]
            }
            if let data = try? JSONSerialization.data(withJSONObject: items, options: .prettyPrinted),
               let str = String(data: data, encoding: .utf8) {
                exportDoc = VocabDocument(text: str)
                exportFilename = "vocab_export.json"
                showExporter = true
            }
        } else {
            var csv = "word,meaning,exampleEn,set,isPending\n"
            for w in sorted {
                let fields = [w.word, w.meaning, w.exampleEn, "\(w.set)", w.isPending ? "true" : "false"]
                csv += fields.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }.joined(separator: ",") + "\n"
            }
            exportDoc = VocabDocument(text: csv)
            exportFilename = "vocab_export.csv"
            showExporter = true
        }
    }

    // MARK: - Import
    private func runImport(url: URL, mode: ImportMode) {
        defer {
            url.stopAccessingSecurityScopedResource()
            pendingImportURL = nil
        }

        do {
            let data = try Data(contentsOf: url)
            let ext = url.pathExtension.lowercased()

            // 덮어쓰기: 기존 단어 전체 삭제
            if mode == .overwrite {
                for w in allWords { context.delete(w) }
                try? context.save()
            }

            let count: Int
            if ext == "json" {
                count = try importJSON(data: data, mode: mode)
            } else {
                count = try importCSV(data: data, mode: mode)
            }

            // 가져온 후 세트 번호 재정렬
            renumberSets()

            let modeLabel = mode == .overwrite ? "덮어쓰기" : "추가"
            alertTitle = "가져오기 완료"
            alertMessage = "\(count)개 단어를 \(modeLabel)했습니다."
            showAlert = true

        } catch {
            showError(error.localizedDescription)
        }
    }

    private func importJSON(data: Data, mode: ImportMode) throws -> Int {
        guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw NSError(domain: "VocabImport", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "JSON 형식 오류"])
        }
        // append 모드: 현재 최대 세트 번호 기준으로 offset
        let setOffset = mode == .append ? (allWords.map(\.set).max() ?? 0) : 0
        var count = 0
        for item in arr {
            guard let word = item["word"] as? String,
                  let meaning = item["meaning"] as? String else { continue }
            let example = item["exampleEn"] as? String ?? ""
            let originalSet = item["set"] as? Int ?? 1
            let isPending = item["isPending"] as? Bool ?? false
            context.insert(Word(word: word, meaning: meaning, exampleEn: example,
                                set: originalSet + setOffset, isPending: isPending))
            count += 1
        }
        try? context.save()
        return count
    }

    private func importCSV(data: Data, mode: ImportMode) throws -> Int {
        guard let str = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "VocabImport", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "CSV 인코딩 오류"])
        }
        let setOffset = mode == .append ? (allWords.map(\.set).max() ?? 0) : 0
        var lines = str.components(separatedBy: "\n").filter { !$0.isEmpty }
        if lines.first?.lowercased().contains("word") == true { lines.removeFirst() }
        var count = 0
        for line in lines {
            let fields = parseCSVLine(line)
            guard fields.count >= 2 else { continue }
            let word    = fields[0]
            let meaning = fields[1]
            let example = fields.count > 2 ? fields[2] : ""
            let originalSet = fields.count > 3 ? (Int(fields[3]) ?? 1) : 1
            let isPending = fields.count > 4 ? fields[4] == "true" : false
            context.insert(Word(word: word, meaning: meaning, exampleEn: example,
                                set: originalSet + setOffset, isPending: isPending))
            count += 1
        }
        try? context.save()
        return count
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var i = line.startIndex
        while i < line.endIndex {
            let c = line[i]
            if c == "\"" {
                let next = line.index(after: i)
                if inQuotes && next < line.endIndex && line[next] == "\"" {
                    current.append("\"")
                    i = line.index(after: next)
                    continue
                }
                inQuotes.toggle()
            } else if c == "," && !inQuotes {
                fields.append(current); current = ""
            } else {
                current.append(c)
            }
            i = line.index(after: i)
        }
        fields.append(current)
        return fields
    }

    private func showError(_ msg: String) {
        alertTitle = "오류"
        alertMessage = msg
        showAlert = true
    }
}

// MARK: - EditWordView
struct EditWordView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var word: Word
    @State private var wordText = ""
    @State private var meaningText = ""
    @State private var exampleText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0f0e17").ignoresSafeArea()
                Form {
                    Section("단어") {
                        TextField("단어/표현", text: $wordText)
                            .foregroundStyle(.white)
                            .listRowBackground(Color(hex: "#1a1828"))
                    }
                    Section("한국어 뜻") {
                        TextField("뜻", text: $meaningText)
                            .foregroundStyle(.white)
                            .listRowBackground(Color(hex: "#1a1828"))
                    }
                    Section("예문") {
                        TextField("영어 예문", text: $exampleText, axis: .vertical)
                            .lineLimit(3...5)
                            .foregroundStyle(.white)
                            .listRowBackground(Color(hex: "#1a1828"))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("단어 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }.foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") {
                        word.word    = wordText.trimmingCharacters(in: .whitespaces)
                        word.meaning = meaningText.trimmingCharacters(in: .whitespaces)
                        word.exampleEn = exampleText.trimmingCharacters(in: .whitespaces)
                        try? context.save()
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(Color(hex: "#e8c547"))
                    .disabled(wordText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                wordText    = word.word
                meaningText = word.meaning
                exampleText = word.exampleEn
            }
        }
    }
}
