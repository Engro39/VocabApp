import Foundation

struct GeneratedWord: Decodable {
    let word: String
    let meaning: String
    let exampleEn: String
}

struct WordDetail {
    let word: String
    let pronunciation: String
    let partOfSpeech: String
    let meaningKo: String
    let detailedDefinition: String
    let examples: [String]
    let nuance: String
    let relatedWords: [String]

    var cardMeaning: String { meaningKo }
    var cardExample: String { examples.first ?? "" }
}

final class ClaudeService {
    static let shared = ClaudeService()
    private init() {}

    func generateWordDetail(_ input: String) async throws -> WordDetail {
        guard let apiKey = KeychainService.shared.loadAPIKey(), !apiKey.isEmpty else {
            throw ClaudeError.noAPIKey
        }

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let prompt = """
영어 단어 또는 표현: "\(input)"

아래 JSON 형식으로만 응답 (마크다운 없이 순수 JSON):
{
  "word": "정확한 단어/표현",
  "pronunciation": "발음 기호 (예: /səˈrɛndɪpɪti/)",
  "partOfSpeech": "품사 (예: noun, verb, adjective, idiom)",
  "meaningKo": "한국어 뜻 (30자 이내)",
  "detailedDefinition": "영어 상세 정의 2-3문장",
  "examples": [
    "영어 예문 1",
    "영어 예문 2",
    "영어 예문 3"
  ],
  "nuance": "한국어로 뉘앙스/사용팁/주의사항 2-3문장",
  "relatedWords": ["관련단어1", "관련단어2", "관련단어3"]
}
"""

        let body: [String: Any] = [
            "model": "claude-haiku-4-5",
            "max_tokens": 800,
            "messages": [["role": "user", "content": prompt]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClaudeError.invalidResponse }
        guard http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown"
            throw ClaudeError.apiError("HTTP \(http.statusCode): \(msg)")
        }

        struct AnthropicResponse: Decodable {
            struct Content: Decodable { let text: String }
            let content: [Content]
        }
        let envelope = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        guard let text = envelope.content.first?.text else { throw ClaudeError.invalidResponse }

        let clean = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = clean.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        else { throw ClaudeError.parseError }

        return WordDetail(
            word:               obj["word"] as? String ?? input,
            pronunciation:      obj["pronunciation"] as? String ?? "",
            partOfSpeech:       obj["partOfSpeech"] as? String ?? "",
            meaningKo:          obj["meaningKo"] as? String ?? "",
            detailedDefinition: obj["detailedDefinition"] as? String ?? "",
            examples:           obj["examples"] as? [String] ?? [],
            nuance:             obj["nuance"] as? String ?? "",
            relatedWords:       obj["relatedWords"] as? [String] ?? []
        )
    }
}

enum ClaudeError: LocalizedError {
    case noAPIKey
    case invalidResponse
    case apiError(String)
    case parseError

    var errorDescription: String? {
        switch self {
        case .noAPIKey:        return "API 키가 없습니다. 설정에서 입력해주세요."
        case .invalidResponse: return "서버 응답이 올바르지 않습니다."
        case .apiError(let m): return m
        case .parseError:      return "응답 파싱 실패"
        }
    }
}
