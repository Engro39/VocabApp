import Foundation

struct GeneratedWord: Decodable {
    let word: String
    let meaning: String
    let exampleEn: String
}

final class ClaudeService {
    static let shared = ClaudeService()
    private init() {}

    func generateWord(_ input: String) async throws -> GeneratedWord {
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

다음 JSON 형식으로만 응답하세요 (다른 텍스트 없이):
{
  "word": "정확한 단어/표현",
  "meaning": "한국어 뜻 (간결하게, 30자 이내)",
  "exampleEn": "짧은 영어 예문 (10단어 내외)"
}
"""

        let body: [String: Any] = [
            "model": "claude-haiku-4-5",
            "max_tokens": 300,
            "messages": [["role": "user", "content": prompt]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw ClaudeError.invalidResponse }
        guard http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClaudeError.apiError("HTTP \(http.statusCode): \(msg)")
        }

        // Parse Anthropic response envelope
        struct AnthropicResponse: Decodable {
            struct Content: Decodable { let text: String }
            let content: [Content]
        }
        let envelope = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        guard let text = envelope.content.first?.text else { throw ClaudeError.invalidResponse }

        // Strip possible markdown fences
        let clean = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = clean.data(using: .utf8) else { throw ClaudeError.parseError }
        return try JSONDecoder().decode(GeneratedWord.self, from: jsonData)
    }
}

enum ClaudeError: LocalizedError {
    case noAPIKey
    case invalidResponse
    case apiError(String)
    case parseError

    var errorDescription: String? {
        switch self {
        case .noAPIKey:       return "API 키가 없습니다. 설정에서 입력해주세요."
        case .invalidResponse: return "서버 응답이 올바르지 않습니다."
        case .apiError(let m): return m
        case .parseError:     return "응답 파싱 실패"
        }
    }
}
