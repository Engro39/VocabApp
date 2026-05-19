import SwiftUI
import SwiftData

struct AddWordView: View {
    @Environment(\.modelContext) private var context
    @Query private var allWords: [Word]

    @State private var inputWord: String = ""
    @State private var generated: GeneratedWord? = nil
    @State private var isLoading: Bool = false
    @State private var errorMessage: String = ""
    @State private var successMessage: String = ""

    private var hasAPIKey: Bool {
        !(KeychainService.shared.loadAPIKey() ?? "").isEmpty
    }

    private var nextSession: Int {
        (allWords.map(\.session).max() ?? 0) + 1
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0f0e17").ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text("✦ 새 단어 추가")
                                .font(.title2.bold())
                                .foregroundStyle(Color(hex: "#e8c547"))
                            Text("단어를 입력하면 Claude가 한국어 뜻과 예문을 생성합니다.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if !hasAPIKey {
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

                        // Input
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
                                    .submitLabel(.done)
                                    .onSubmit { Task { await generate() } }
                                    .autocorrectionDisabled()

                                Button {
                                    Task { await generate() }
                                } label: {
                                    if isLoading {
                                        ProgressView()
                                            .tint(Color(hex: "#0f0e17"))
                                    } else {
                                        Text("생성")
                                            .font(.subheadline.bold())
                                    }
                                }
                                .frame(width: 60, height: 44)
                                .background(Color(hex: "#e8c547"))
                                .foregroundStyle(Color(hex: "#0f0e17"))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .disabled(isLoading || inputWord.trimmingCharacters(in: .whitespaces).isEmpty || !hasAPIKey)
                            }
                        }

                        // Error
                        if !errorMessage.isEmpty {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                Text(errorMessage)
                            }
                            .font(.subheadline)
                            .foregroundStyle(Color(hex: "#ff6b6b"))
                            .padding()
                            .background(Color(hex: "#ff6b6b").opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Success
                        if !successMessage.isEmpty {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text(successMessage)
                            }
                            .font(.subheadline)
                            .foregroundStyle(Color(hex: "#4ecdc4"))
                            .padding()
                            .background(Color(hex: "#4ecdc4").opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Preview card
                        if let gen = generated {
                            VStack(spacing: 16) {
                                VStack(spacing: 10) {
                                    Text(gen.word)
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundStyle(Color(hex: "#e8c547"))
                                    Text(gen.meaning)
                                        .font(.title3.bold())
                                        .foregroundStyle(Color(hex: "#4ecdc4"))
                                    Text(gen.exampleEn)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(24)
                                .background(
                                    LinearGradient(colors: [Color(hex: "#1b2a2a"), Color(hex: "#142320")],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "#4ecdc4").opacity(0.3)))
                                .clipShape(RoundedRectangle(cornerRadius: 16))

                                Button {
                                    addWord(gen)
                                } label: {
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

    // MARK: - Actions
    @MainActor
    private func generate() async {
        let trimmed = inputWord.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        errorMessage = ""
        successMessage = ""
        generated = nil
        do {
            generated = try await ClaudeService.shared.generateWord(trimmed)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func addWord(_ gen: GeneratedWord) {
        let word = Word(word: gen.word, meaning: gen.meaning, exampleEn: gen.exampleEn,
                        session: nextSession, isNew: true)
        context.insert(word)
        try? context.save()
        successMessage = "'\(gen.word)' 추가 완료! (Session \(nextSession))"
        generated = nil
        inputWord = ""
    }
}
