import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Backup file types

private struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let d = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = d
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct BackupPayload: Codable {
    let exportedAt: String
    let version: Int
    let words: [WordBackup]
    let listeningRecords: [RecordBackup]
}

private struct WordBackup: Codable {
    let word: String
    let meaning: String
    let exampleEn: String
    let set: Int
    let isPending: Bool
    let addedDate: String
    let pronunciation: String
    let partOfSpeech: String
    let detailedDefinition: String
    let examples: [String]
    let nuance: String
    let relatedWords: [String]
}

private struct RecordBackup: Codable {
    let sentence: String
    let topic: String
    let difficulty: String
    let practiceDate: String
    let isCorrect: Bool
    let userAnswer: String
    let attemptCount: Int
}

// MARK: - SettingsView

struct SettingsView: View {
    // Anthropic
    @State private var apiKey: String = ""
    @State private var isRevealed: Bool = false
    @State private var saved: Bool = false
    // Google TTS
    @State private var googleAPIKey: String = ""
    @State private var isGoogleRevealed: Bool = false
    @State private var googleSaved: Bool = false
    @State private var googleKeyExists: Bool = false

    @AppStorage("setBatchSize")  private var setBatchSize: Int = 20
    @AppStorage("autoPlayMode")  private var autoPlayMode: String = "timer"
    @AppStorage("autoPlayCount") private var autoPlayCount: Int = 3
    @AppStorage("ttsNormalRate") private var ttsNormalRate: Double = 1.1
    @AppStorage("ttsSlowRate")   private var ttsSlowRate: Double = 0.8

    // Backup
    @Environment(\.modelContext) private var context
    @Query(sort: \Word.addedDate) private var allWords: [Word]
    @Query(sort: \ListeningRecord.practiceDate) private var allRecords: [ListeningRecord]
    @State private var backupDoc: BackupDocument? = nil
    @State private var backupFilename = "VocabApp_backup.json"
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var backupAlertTitle = ""
    @State private var backupAlertMessage = ""
    @State private var showBackupAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0f0e17").ignoresSafeArea()
                Form {
                    // ── 세트 크기 설정 ──────────────────────────
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("세트당 단어 수")
                                    .foregroundStyle(.white)
                                Spacer()
                                Text("\(setBatchSize)개")
                                    .font(.headline.bold())
                                    .foregroundStyle(Color(hex: "#e8c547"))
                            }
                            Slider(value: Binding(
                                get: { Double(setBatchSize) },
                                set: { setBatchSize = Int($0) }
                            ), in: 1...100, step: 1)
                            .tint(Color(hex: "#e8c547"))

                            HStack {
                                Text("1개").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Text("100개").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .listRowBackground(Color(hex: "#1a1828"))
                    } header: {
                        Text("세트 설정").foregroundStyle(Color(hex: "#e8c547"))
                    } footer: {
                        Text("새로 만들어지는 세트에만 적용됩니다. 기존 세트는 변경되지 않습니다.")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    // ── 자동 넘기기 설정 ─────────────────────────
                    Section {
                        Picker("모드", selection: $autoPlayMode) {
                            Text("표시 시간").tag("timer")
                            Text("발음 읽어주기").tag("tts")
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color(hex: "#1a1828"))

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(autoPlayMode == "tts" ? "반복 횟수" : "카드 표시 시간")
                                    .foregroundStyle(.white)
                                Spacer()
                                Text(autoPlayMode == "tts" ? "\(autoPlayCount)회" : "\(autoPlayCount)초")
                                    .font(.headline.bold())
                                    .foregroundStyle(Color(hex: "#e8c547"))
                            }
                            Slider(value: Binding(
                                get: { Double(autoPlayCount) },
                                set: { autoPlayCount = Int($0) }
                            ), in: 1...10, step: 1)
                            .tint(Color(hex: "#e8c547"))
                            HStack {
                                Text(autoPlayMode == "tts" ? "1회" : "1초")
                                    .font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Text(autoPlayMode == "tts" ? "10회" : "10초")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .listRowBackground(Color(hex: "#1a1828"))
                    } header: {
                        Text("자동 넘기기").foregroundStyle(Color(hex: "#e8c547"))
                    } footer: {
                        Text(autoPlayMode == "tts"
                             ? "단어를 설정한 횟수만큼 읽어준 뒤 다음 카드로 넘어갑니다."
                             : "플레이 버튼을 누르면 설정한 시간마다 다음 카드로 자동으로 넘어갑니다.")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    // ── TTS 재생 속도 ──────────────────────────────
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("기본 속도")
                                    .foregroundStyle(.white)
                                Spacer()
                                Text(String(format: "%.1fx", ttsNormalRate))
                                    .font(.headline.bold())
                                    .foregroundStyle(Color(hex: "#e8c547"))
                            }
                            Slider(value: $ttsNormalRate, in: 0.5...1.5, step: 0.1)
                                .tint(Color(hex: "#e8c547"))
                            HStack {
                                Text("0.5x").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Text("1.5x").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .listRowBackground(Color(hex: "#1a1828"))

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("느리게 속도")
                                    .foregroundStyle(.white)
                                Spacer()
                                Text(String(format: "%.1fx", ttsSlowRate))
                                    .font(.headline.bold())
                                    .foregroundStyle(Color(hex: "#4ecdc4"))
                            }
                            Slider(value: $ttsSlowRate, in: 0.5...1.5, step: 0.1)
                                .tint(Color(hex: "#4ecdc4"))
                            HStack {
                                Text("0.5x").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Text("1.5x").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .listRowBackground(Color(hex: "#1a1828"))
                    } header: {
                        Text("재생 속도").foregroundStyle(Color(hex: "#e8c547"))
                    } footer: {
                        Text("1.0 = 보통 속도 기준. 기본 버튼과 느리게 버튼 각각 독립 조절.")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    // ── 데이터 백업 ────────────────────────────────
                    Section {
                        Button {
                            prepareExport()
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("백업 내보내기")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color(hex: "#e8c547"))
                        .foregroundStyle(Color(hex: "#0f0e17"))

                        Button {
                            showImporter = true
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("백업 가져오기")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color(hex: "#4ecdc4"))
                        .foregroundStyle(Color(hex: "#0f0e17"))

                    } header: {
                        Text("데이터 백업").foregroundStyle(Color(hex: "#e8c547"))
                    } footer: {
                        Text("단어와 듣기 기록을 JSON 파일로 내보내거나 가져올 수 있습니다. 가져오기 시 중복되지 않은 항목만 추가됩니다.")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    // ── Anthropic API 키 ─────────────────────────
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Anthropic API Key")
                                .font(.caption.bold()).foregroundStyle(.secondary)
                            HStack {
                                Group {
                                    if isRevealed {
                                        TextField("sk-ant-...", text: $apiKey)
                                            .autocorrectionDisabled()
                                            .textInputAutocapitalization(.never)
                                    } else {
                                        SecureField("sk-ant-...", text: $apiKey)
                                    }
                                }
                                .textFieldStyle(.plain).foregroundStyle(.white)
                                Button { isRevealed.toggle() } label: {
                                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .listRowBackground(Color(hex: "#1a1828"))

                        Button {
                            KeychainService.shared.saveAPIKey(
                                apiKey.trimmingCharacters(in: .whitespaces))
                            saved = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saved = false }
                        } label: {
                            HStack {
                                Image(systemName: "key.fill")
                                Text(saved ? "저장됨 ✓" : "Keychain에 저장")
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 4)
                        }
                        .listRowBackground(Color(hex: "#e8c547"))
                        .foregroundStyle(Color(hex: "#0f0e17"))
                        .fontWeight(.bold)

                        Button(role: .destructive) {
                            KeychainService.shared.deleteAPIKey()
                            apiKey = ""
                            saved = false
                        } label: {
                            Label("API 키 삭제", systemImage: "trash")
                        }
                        .listRowBackground(Color(hex: "#1a1828"))

                    } header: {
                        Text("API 키 설정").foregroundStyle(Color(hex: "#e8c547"))
                    } footer: {
                        Text("키는 iOS Keychain에 안전하게 저장됩니다.\nClaude Haiku 4.5 사용 (단어 1개 ≈ $0.000001)")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    // ── Google TTS API 키 ────────────────────────
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Google Cloud API Key")
                                    .font(.caption.bold()).foregroundStyle(.secondary)
                                Spacer()
                                if googleKeyExists {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("WaveNet 사용 중")
                                            .font(.caption.bold())
                                    }
                                    .foregroundStyle(Color(hex: "#4ecdc4"))
                                }
                            }
                            HStack {
                                Group {
                                    if isGoogleRevealed {
                                        TextField("AIza...", text: $googleAPIKey)
                                            .autocorrectionDisabled()
                                            .textInputAutocapitalization(.never)
                                    } else {
                                        SecureField("AIza...", text: $googleAPIKey)
                                    }
                                }
                                .textFieldStyle(.plain).foregroundStyle(.white)
                                Button { isGoogleRevealed.toggle() } label: {
                                    Image(systemName: isGoogleRevealed ? "eye.slash" : "eye")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .listRowBackground(Color(hex: "#1a1828"))

                        Button {
                            KeychainService.shared.saveGoogleTTSKey(
                                googleAPIKey.trimmingCharacters(in: .whitespaces))
                            googleKeyExists = !googleAPIKey.trimmingCharacters(in: .whitespaces).isEmpty
                            googleSaved = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { googleSaved = false }
                        } label: {
                            HStack {
                                Image(systemName: "key.fill")
                                Text(googleSaved ? "저장됨 ✓" : "Keychain에 저장")
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 4)
                        }
                        .listRowBackground(Color(hex: "#4ecdc4"))
                        .foregroundStyle(Color(hex: "#0f0e17"))
                        .fontWeight(.bold)

                        Button(role: .destructive) {
                            KeychainService.shared.deleteGoogleTTSKey()
                            googleAPIKey = ""
                            googleKeyExists = false
                            googleSaved = false
                        } label: {
                            Label("Google TTS 키 삭제", systemImage: "trash")
                        }
                        .listRowBackground(Color(hex: "#1a1828"))

                    } header: {
                        Text("Google TTS API 키").foregroundStyle(Color(hex: "#e8c547"))
                    } footer: {
                        Text("Google Cloud WaveNet 목소리를 사용합니다 (en-US-Wavenet-D).\n키가 없으면 기기 내장 TTS로 재생됩니다.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                apiKey = KeychainService.shared.loadAPIKey() ?? ""
                googleAPIKey = KeychainService.shared.loadGoogleTTSKey() ?? ""
                googleKeyExists = KeychainService.shared.hasGoogleTTSKey
            }
            .fileExporter(
                isPresented: $showExporter,
                document: backupDoc,
                contentType: .json,
                defaultFilename: backupFilename
            ) { result in
                if case .failure(let e) = result {
                    backupAlertTitle = "내보내기 오류"
                    backupAlertMessage = e.localizedDescription
                    showBackupAlert = true
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first,
                          url.startAccessingSecurityScopedResource() else {
                        backupAlertTitle = "오류"
                        backupAlertMessage = "파일 접근 권한이 없습니다."
                        showBackupAlert = true
                        return
                    }
                    runImport(url: url)
                case .failure(let e):
                    backupAlertTitle = "오류"
                    backupAlertMessage = e.localizedDescription
                    showBackupAlert = true
                }
            }
            .alert(backupAlertTitle, isPresented: $showBackupAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(backupAlertMessage)
            }
        }
    }

    // MARK: - Backup export

    private func prepareExport() {
        let iso = ISO8601DateFormatter()
        let wordBackups = allWords.map { w in
            WordBackup(
                word: w.word,
                meaning: w.meaning,
                exampleEn: w.exampleEn,
                set: w.set,
                isPending: w.isPending,
                addedDate: iso.string(from: w.addedDate),
                pronunciation: w.pronunciation,
                partOfSpeech: w.partOfSpeech,
                detailedDefinition: w.detailedDefinition,
                examples: w.examples,
                nuance: w.nuance,
                relatedWords: w.relatedWords
            )
        }
        let recordBackups = allRecords.map { r in
            RecordBackup(
                sentence: r.sentence,
                topic: r.topic,
                difficulty: r.difficulty,
                practiceDate: iso.string(from: r.practiceDate),
                isCorrect: r.isCorrect,
                userAnswer: r.userAnswer,
                attemptCount: r.attemptCount
            )
        }
        let payload = BackupPayload(
            exportedAt: iso.string(from: Date()),
            version: 1,
            words: wordBackups,
            listeningRecords: recordBackups
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(payload) else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: Date())
        backupDoc = BackupDocument(data: data)
        backupFilename = "VocabApp_backup_\(dateStr).json"
        showExporter = true
    }

    // MARK: - Backup import

    private func runImport(url: URL) {
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let data = try Data(contentsOf: url)
            let payload = try JSONDecoder().decode(BackupPayload.self, from: data)
            let iso = ISO8601DateFormatter()

            let existingWords = Set(allWords.map { $0.word.lowercased() })
            var wordsAdded = 0
            for wb in payload.words {
                guard !existingWords.contains(wb.word.lowercased()) else { continue }
                let w = Word(
                    word: wb.word,
                    meaning: wb.meaning,
                    exampleEn: wb.exampleEn,
                    set: wb.set,
                    isPending: wb.isPending,
                    pronunciation: wb.pronunciation,
                    partOfSpeech: wb.partOfSpeech,
                    detailedDefinition: wb.detailedDefinition,
                    examples: wb.examples,
                    nuance: wb.nuance,
                    relatedWords: wb.relatedWords
                )
                if let date = iso.date(from: wb.addedDate) { w.addedDate = date }
                context.insert(w)
                wordsAdded += 1
            }

            let existingRecordKeys = Set(
                allRecords.map { "\(iso.string(from: $0.practiceDate))|\($0.sentence)" }
            )
            var recordsAdded = 0
            for rb in payload.listeningRecords {
                let key = "\(rb.practiceDate)|\(rb.sentence)"
                guard !existingRecordKeys.contains(key) else { continue }
                let r = ListeningRecord(
                    sentence: rb.sentence,
                    topic: rb.topic,
                    difficulty: rb.difficulty,
                    isCorrect: rb.isCorrect,
                    userAnswer: rb.userAnswer,
                    attemptCount: rb.attemptCount
                )
                if let date = iso.date(from: rb.practiceDate) { r.practiceDate = date }
                context.insert(r)
                recordsAdded += 1
            }

            try? context.save()
            backupAlertTitle = "가져오기 완료"
            backupAlertMessage = "단어 \(wordsAdded)개, 기록 \(recordsAdded)개 추가됨"
            showBackupAlert = true
        } catch {
            backupAlertTitle = "오류"
            backupAlertMessage = error.localizedDescription
            showBackupAlert = true
        }
    }
}
