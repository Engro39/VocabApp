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
        let data = Data(text.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - SetManagerView
struct SetManagerView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Word.addedDate) private var allWords: [Word]

    @State private var expandedSet: Int? = nil
    @State private var editingWord: Word? = nil
    @State private var showDeleteSetAlert: Int? = nil

    // Export
    @State private var exportDoc: VocabDocument? = nil
    @State private var showExporter = false
    @State private var exportFilename = "vocab_export.json"

    // Import
    @State private var showImporter = false
    @State private var importError: String = ""
    @State private var showImportError = false
    @State private var importSuccess: String = ""
    @State private var showImportSuccess = false

    private var completedSets: [Int] {
        Array(Set(allWords.filter { !$0.isPending }.map(\.set))).sorted()
    }
    private var pendingWords: [Word] { allWords.filter { $0.isPending } }

    private func words(for set: Int) -> [Word] {
        allWords.filter { $0.set == set }.sorted { $0.addedDate < $1.addedDate }
    }

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
                        // 완성 세트
                        ForEach(completedSets, id: \.self) { setNum in
                            setSection(setNum, isPendingSection: false)
                        }
                        // 진행중 세트
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
            .toolbar {
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
                    Button {
                        showImporter = true
                    } label: {
                        Image(systemName: "arrow.down.circle")
                            .foregroundStyle(Color(hex: "#4ecdc4"))
                    }
                }
            }
            .sheet(item: $editingWord) { word in
                EditWordView(word: word)
            }
            .fileExporter(
                isPresented: $showExporter,
                document: exportDoc,
                contentType: exportFilename.hasSuffix(".csv") ? .commaSeparatedText : .json,
                defaultFilename: exportFilename
            ) { result in
                if case .failure(let e) = result {
                    importError = e.localizedDescription
                    showImportError = true
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json, .commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .alert("가져오기 실패", isPresented: $showImportError) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(importError)
            }
            .alert("가져오기 완료", isPresented: $showImportSuccess) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(importSuccess)
            }
            .alert("세트 삭제", isPresented: Binding(
                get: { showDeleteSetAlert != nil },
                set: { if !$0 { showDeleteSetAlert = nil } }
            )) {
                Button("삭제", role: .destructive) {
                    if let s = showDeleteSetAlert { deleteSet(s) }
                }
                Button("취소", role: .cancel) {}
            } message: {
                if let s = showDeleteSetAlert {
                    let count = s == -1 ? pendingWords.count : words(for: s).count
                    Text("세트 \(s == -1 ? "진행중" : "\(s)")의 단어 \(count)개를 모두 삭제합니다.")
                }
            }
        }
    }

    // MARK: - Set section
    @ViewBuilder
    private func setSection(_ setNum: Int, isPendingSection: Bool) -> some View {
        let setWords = isPendingSection ? pendingWords.sorted { $0.addedDate < $1.addedDate } : words(for: setNum)
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

                    Button {
                        showDeleteSetAlert = key
                    } label: {
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

    // MARK: - Delete
    private func deleteWords(at offsets: IndexSet, in setWords: [Word]) {
        for i in offsets { context.delete(setWords[i]) }
        try? context.save()
    }

    private func deleteSet(_ key: Int) {
        let target = key == -1 ? pendingWords : words(for: key)
        for word in target { context.delete(word) }
        try? context.save()
        if expandedSet == key { expandedSet = nil }
    }

    // MARK: - Export
    private func prepareExport(format: String) {
        if format == "json" {
            let items = allWords.map { w -> [String: Any] in
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
            for w in allWords {
                let fields = [w.word, w.meaning, w.exampleEn, "\(w.set)", w.isPending ? "true" : "false"]
                csv += fields.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }.joined(separator: ",") + "\n"
            }
            exportDoc = VocabDocument(text: csv)
            exportFilename = "vocab_export.csv"
            showExporter = true
        }
    }

    // MARK: - Import
    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let e):
            importError = e.localizedDescription
            showImportError = true
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                importError = "파일 접근 권한 없음"
                showImportError = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                let ext = url.pathExtension.lowercased()
                var imported = 0

                if ext == "json" {
                    imported = try importJSON(data: data)
                } else {
                    imported = try importCSV(data: data)
                }

                importSuccess = "\(imported)개 단어를 가져왔습니다."
                showImportSuccess = true
            } catch {
                importError = error.localizedDescription
                showImportError = true
            }
        }
    }

    private func importJSON(data: Data) throws -> Int {
        guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw NSError(domain: "VocabImport", code: 1, userInfo: [NSLocalizedDescriptionKey: "JSON 형식 오류"])
        }
        let maxSet = allWords.map(\.set).max() ?? 0
        var count = 0
        for item in arr {
            guard let word = item["word"] as? String,
                  let meaning = item["meaning"] as? String else { continue }
            let example = item["exampleEn"] as? String ?? ""
            let set = (item["set"] as? Int ?? 1) + maxSet
            let isPending = item["isPending"] as? Bool ?? false
            context.insert(Word(word: word, meaning: meaning, exampleEn: example,
                                set: set, isPending: isPending))
            count += 1
        }
        try? context.save()
        return count
    }

    private func importCSV(data: Data) throws -> Int {
        guard let str = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "VocabImport", code: 2, userInfo: [NSLocalizedDescriptionKey: "CSV 인코딩 오류"])
        }
        let maxSet = allWords.map(\.set).max() ?? 0
        var lines = str.components(separatedBy: "\n").filter { !$0.isEmpty }
        if lines.first?.lowercased().contains("word") == true { lines.removeFirst() } // 헤더 제거
        var count = 0
        for line in lines {
            let fields = parseCSVLine(line)
            guard fields.count >= 2 else { continue }
            let word = fields[0]
            let meaning = fields[1]
            let example = fields.count > 2 ? fields[2] : ""
            let set = (fields.count > 3 ? Int(fields[3]) ?? 1 : 1) + maxSet
            let isPending = fields.count > 4 ? fields[4] == "true" : false
            context.insert(Word(word: word, meaning: meaning, exampleEn: example,
                                set: set, isPending: isPending))
            count += 1
        }
        try? context.save()
        return count
    }

    // 간단한 CSV 파싱 (따옴표 처리 포함)
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
                fields.append(current)
                current = ""
            } else {
                current.append(c)
            }
            i = line.index(after: i)
        }
        fields.append(current)
        return fields
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
                        word.word = wordText.trimmingCharacters(in: .whitespaces)
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
                wordText = word.word
                meaningText = word.meaning
                exampleText = word.exampleEn
            }
        }
    }
}
