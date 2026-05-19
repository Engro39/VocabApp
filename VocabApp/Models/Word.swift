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

    init(word: String, meaning: String, exampleEn: String, set: Int, isPending: Bool = true) {
        self.word = word
        self.meaning = meaning
        self.exampleEn = exampleEn
        self.set = set
        self.isPending = isPending
        self.addedDate = Date()
    }
}
