import Foundation
import SwiftData

@Model
final class Word {
    var word: String
    var meaning: String
    var exampleEn: String
    var session: Int
    var isNew: Bool
    var addedDate: Date

    init(word: String, meaning: String, exampleEn: String, session: Int, isNew: Bool = false) {
        self.word = word
        self.meaning = meaning
        self.exampleEn = exampleEn
        self.session = session
        self.isNew = isNew
        self.addedDate = Date()
    }
}
