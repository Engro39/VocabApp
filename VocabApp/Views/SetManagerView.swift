import SwiftUI
import SwiftData

struct SetManagerView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Word.addedDate) private var allWords: [Word]

    @State private var expandedSet: Int? = nil
    @State private var editingWord: Word? = nil
    @State private var showDeleteSetAlert: Int? = nil

    private var sets: [Int] {
        Array(Set(allWords.map(\.set))).sorted()
    }

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
                        ForEach(sets, id: \.self) { setNum in
                            setSection(setNum)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("세트 관리")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(item: $editingWord) { word in
                EditWordView(word: word)
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
                    Text("세트 \(s)의 단어 \(words(for: s).count)개를 모두 삭제합니다.")
                }
            }
        }
    }

    // MARK: - Set section
    @ViewBuilder
    private func setSection(_ setNum: Int) -> some View {
        let setWords = words(for: setNum)
        let isPending = setWords.contains { $0.isPending }
        let color = FlashCardView.colors[setNum % FlashCardView.colors.count]

        Section {
            if expandedSet == setNum {
                ForEach(setWords) { word in
                    wordRow(word, color: color)
                }
                .onDelete { offsets in
                    deleteWords(at: offsets, in: setWords)
                }
            }
        } header: {
            // 세트 헤더 (탭하여 펼치기/접기)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedSet = expandedSet == setNum ? nil : setNum
                }
            } label: {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: 4, height: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("세트 \(setNum)")
                                .font(.headline)
                                .foregroundStyle(.white)
                            if isPending {
                                Text("진행중")
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

                    Image(systemName: expandedSet == setNum ? "chevron.up" : "chevron.down")
                        .font(.caption).foregroundStyle(.secondary)

                    // 세트 삭제 버튼
                    Button {
                        showDeleteSetAlert = setNum
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(Color(hex: "#ff6b6b"))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        .listRowBackground(Color(hex: "#1a1828"))
    }

    // MARK: - Word row
    @ViewBuilder
    private func wordRow(_ word: Word, color: Color) -> some View {
        HStack(spacing: 12) {
            Circle().fill(color).frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(word.word)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(word.meaning)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                editingWord = word
            } label: {
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundStyle(Color(hex: "#e8c547"))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .listRowBackground(Color(hex: "#1a1828"))
    }

    // MARK: - Delete actions
    private func deleteWords(at offsets: IndexSet, in setWords: [Word]) {
        for i in offsets {
            context.delete(setWords[i])
        }
        try? context.save()
    }

    private func deleteSet(_ setNum: Int) {
        for word in words(for: setNum) {
            context.delete(word)
        }
        try? context.save()
        if expandedSet == setNum { expandedSet = nil }
    }
}

// MARK: - Edit word sheet
struct EditWordView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Bindable var word: Word
    @State private var wordText: String = ""
    @State private var meaningText: String = ""
    @State private var exampleText: String = ""

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
                    Button("취소") { dismiss() }
                        .foregroundStyle(.secondary)
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
