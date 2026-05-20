import AVFoundation

final class SpeechService {
    static let shared = SpeechService()
    private let synthesizer = AVSpeechSynthesizer()
    private init() {}

    // 최고 품질 en-US 보이스 캐시
    private lazy var bestVoice: AVSpeechSynthesisVoice? = {
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == "en-US" }

        // 1순위: premium (Neural TTS — 다운로드 필요)
        if let v = voices.first(where: { $0.quality == .premium }) { return v }
        // 2순위: enhanced (개선된 TTS — 다운로드 필요)
        if let v = voices.first(where: { $0.quality == .enhanced }) { return v }
        // 3순위: 기본 보이스
        return AVSpeechSynthesisVoice(language: "en-US")
    }()

    func speak(_ text: String, rate: Float = 0.42) {
        synthesizer.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: text)
        u.voice = bestVoice
        u.rate = rate
        u.pitchMultiplier = 1.0
        u.volume = 1.0
        synthesizer.speak(u)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
