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

// MARK: - Schema V2 (현재 - 상세 필드 추가, 배열은 JSON String으로 저장)
enum WordSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [Word.self] }
}

// MARK: - Migration Plan
enum WordMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [WordSchemaV1.self, WordSchemaV2.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: WordSchemaV1.self, toVersion: WordSchemaV2.self)]
    }
}
