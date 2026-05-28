import SwiftUI
import SwiftData

@main
struct VocabApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Word.self, ListeningRecord.self, migrationPlan: WordMigrationPlan.self)
            seedIfNeeded(context: container.mainContext)
        } catch {
            fatalError("SwiftData 초기화 실패: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }

    private func seedIfNeeded(context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Word>())) ?? 0
        guard count == 0 else { return }
        for w in SeedData.sampleSet {
            context.insert(Word(
                word: w.word,
                meaning: w.meaning,
                exampleEn: w.exampleEn,
                set: w.set,
                isPending: false,
                pronunciation: w.pronunciation,
                partOfSpeech: w.partOfSpeech,
                detailedDefinition: w.detailedDefinition,
                examples: w.examples,
                nuance: w.nuance,
                relatedWords: w.relatedWords
            ))
        }
        try? context.save()
    }
}
