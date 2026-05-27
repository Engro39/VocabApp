import Foundation
import SwiftData

@Model
final class ListeningRecord {
    var sentence: String
    var topic: String
    var difficulty: String   // "beginner" | "intermediate" | "advanced"
    var practiceDate: Date
    var isCorrect: Bool
    var userAnswer: String = ""
    var attemptCount: Int = 1

    init(sentence: String, topic: String, difficulty: String, isCorrect: Bool,
         userAnswer: String = "", attemptCount: Int = 1) {
        self.sentence = sentence
        self.topic = topic
        self.difficulty = difficulty
        self.practiceDate = Date()
        self.isCorrect = isCorrect
        self.userAnswer = userAnswer
        self.attemptCount = attemptCount
    }

    var difficultyLabel: String {
        switch difficulty {
        case "beginner":     return "초급"
        case "intermediate": return "중급"
        case "advanced":     return "상급"
        default:             return difficulty
        }
    }
}
