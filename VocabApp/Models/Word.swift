import Foundation
import SwiftData

@Model
final class Word {
    var word: String
    var meaning: String
    var exampleEn: String
    var set: Int          // 세트 번호 (구 session)
    var isPending: Bool   // 아직 세트 미완성 (20개 미만)
    var addedDate: Date

    // 상세 정보 (검색으로 추가된 단어에만 저장, 기존 단어는 빈값)
    // [String] 대신 JSON 문자열로 저장 → lightweight migration 호환
    var pronunciation: String
    var partOfSpeech: String
    var detailedDefinition: String
    var examplesJSON: String       // JSON 인코딩된 [String]
    var nuance: String
    var relatedWordsJSON: String   // JSON 인코딩된 [String]

    var hasDetail: Bool { !pronunciation.isEmpty }

    var examples: [String] {
        get { Self.decodeJSON(examplesJSON) }
        set { examplesJSON = Self.encodeJSON(newValue) }
    }

    var relatedWords: [String] {
        get { Self.decodeJSON(relatedWordsJSON) }
        set { relatedWordsJSON = Self.encodeJSON(newValue) }
    }

    init(word: String, meaning: String, exampleEn: String, set: Int, isPending: Bool = true,
         pronunciation: String = "", partOfSpeech: String = "", detailedDefinition: String = "",
         examples: [String] = [], nuance: String = "", relatedWords: [String] = []) {
        self.word = word
        self.meaning = meaning
        self.exampleEn = exampleEn
        self.set = set
        self.isPending = isPending
        self.addedDate = Date()
        self.pronunciation = pronunciation
        self.partOfSpeech = partOfSpeech
        self.detailedDefinition = detailedDefinition
        self.examplesJSON = Self.encodeJSON(examples)
        self.nuance = nuance
        self.relatedWordsJSON = Self.encodeJSON(relatedWords)
    }

    static func decodeJSON(_ json: String) -> [String] {
        guard let data = json.data(using: .utf8),
              let arr = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return arr
    }

    private static func encodeJSON(_ arr: [String]) -> String {
        guard let data = try? JSONEncoder().encode(arr),
              let str = String(data: data, encoding: .utf8) else { return "[]" }
        return str
    }
}
