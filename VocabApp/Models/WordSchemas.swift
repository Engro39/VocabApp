import Foundation
import SwiftData

// MARK: - Schema V1 (기존 - 상세 필드 없음)
enum WordSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Word.self] }

    @Model
    final class Word {
        var word: String
        var meaning: String
        var exampleEn: String
        var set: Int
        var isPending: Bool
        var addedDate: Date

        init(word: String, meaning: String, exampleEn: String, set: Int, isPending: Bool = true) {
            self.word = word
            self.meaning = meaning
            self.exampleEn = exampleEn
            self.set = set
            self.isPending = isPending
            self.addedDate = Date()
        }
    }
}

// MARK: - Schema V2 (상세 필드 추가, 배열은 JSON String으로 저장)
enum WordSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [Word.self] }
}

// MARK: - Schema V3 (ListeningRecord 추가 — userAnswer/attemptCount 없는 스냅샷)
enum WordSchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] { [Word.self, ListeningRecord.self] }

    @Model
    final class ListeningRecord {
        var sentence: String
        var topic: String
        var difficulty: String
        var practiceDate: Date
        var isCorrect: Bool

        init(sentence: String, topic: String, difficulty: String, isCorrect: Bool) {
            self.sentence = sentence
            self.topic = topic
            self.difficulty = difficulty
            self.practiceDate = Date()
            self.isCorrect = isCorrect
        }
    }
}

// MARK: - Schema V4 (ListeningRecord에 userAnswer, attemptCount 추가)
enum WordSchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(4, 0, 0)
    static var models: [any PersistentModel.Type] { [Word.self, ListeningRecord.self] }
}

// MARK: - Migration Plan
enum WordMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [WordSchemaV1.self, WordSchemaV2.self, WordSchemaV3.self, WordSchemaV4.self]
    }
    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: WordSchemaV1.self, toVersion: WordSchemaV2.self),
            .lightweight(fromVersion: WordSchemaV2.self, toVersion: WordSchemaV3.self),
            .lightweight(fromVersion: WordSchemaV3.self, toVersion: WordSchemaV4.self)
        ]
    }
}
