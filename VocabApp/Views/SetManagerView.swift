import SwiftUI
import SwiftData

// MARK: - SetManagerView
struct SetManagerView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Word.addedDate) private var allWords: [Word]

    @State private var expandedSet: Int? = nil
    @State private var editingWord: Word? = nil
    @State private var deleteSetKey: Int? = nil
    @State private var sortDescending: Bool = true

    // MARK: Computed
    private var completedSets: [Int] {
        Array(Set(allWords.filter { !$0.isPending }.map(\.set))).sorted()
    }
    private var displayedSets: [Int] {
        sortDescending ? completedSets.reversed() : completedSets
    }
    private var pendingWords: [Word] {
        allWords.filter { $0.isPending }.sorted { $0.addedDate < $1.addedDate }
    }
    private func words(for set: Int) -> [Word] {
        allWords.filter { $0.set == set }.sorted { $0.addedDate < $1.addedDate }
    }

    // MARK: - Renumber helper
    private func renumberSets() {
        let sortedSets = completedSets
        for (newNum, oldNum) in sortedSets.enumerated() {
            let target = newNum + 1
            if oldNum != target {
                for w in words(for: oldNum) { w.set = target }
            }
        }
        let newMax = completedSets.count
        if !pendingWords.isEmpty {
            let pendingTarget = newMax + 1
            for w in pendingWords { w.set = pendingTarget }
        }
        try? context.save()
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            Color(hex: "#0f0e17").ignoresSafeArea()

            if allWords.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray").font(.system(size: 40)).foregroundStyle(.secondary)
                    Text("단어가 없습니다").foregroundStyle(.secondary)
                }
            } else {
                List {
                    if !pendingWords.isEmpty {
                        setSection(-1, isPendingSection: true)
                    }
                    ForEach(displayedSets, id: \.self) { setNum in
                        setSection(setNum, isPendingSection: false)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("세트 관리")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(item: $editingWord) { EditWordView(word: $0) }
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

    // MARK: - Set section
    @ViewBuilder
    private func setSection(_ setNum: Int, isPendingSection: Bool) -> some View {
        let setWords = isPendingSection ? pendingWords : words(for: setNum)
        let color: Color = isPendingSection
            ? Color(hex: "#00ffcc")
            : Color.setColor(for: setNum)
        let key = isPendingSection ? -1 : setNum

        Section {
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
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    deleteSetKey = key
                } label: {
                    Label("삭제", systemImage: "trash")
                }
            }
            .listRowBackground(Color(hex: "#1a1828"))

            if expandedSet == key {
                ForEach(setWords) { word in
                    wordRow(word, color: color)
                }
                .onDelete { offsets in deleteWords(at: offsets, in: setWords) }
            }
        }
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
                        word.word      = wordText.trimmingCharacters(in: .whitespaces)
                        word.meaning   = meaningText.trimmingCharacters(in: .whitespaces)
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
