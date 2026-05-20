import AVFoundation

final class SpeechService {
    static let shared = SpeechService()
    private let synthesizer = AVSpeechSynthesizer()
    private init() {
        configureAudioSession()
    }

    // MARK: - Audio Session
    private func configureAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(
            .playback,
            mode: .spokenAudio,
            options: .duckOthers
        )
    }

    // MARK: - Voice 선택
    // 우선순위: Premium > Enhanced > Eloquence(compact) > compact > super-compact
    // com.apple.speech.synthesis.voice.* (Albert, Fred, Bahh 등 로봇 음성) 제외
    private var bestVoice: AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == "en-US" }
            .filter { !$0.identifier.contains("speech.synthesis.voice") }   // 로봇 음성 제외
            .sorted { lhs, rhs in
                // 1차: quality 내림차순 (Premium=3 > Enhanced=2 > Default=1)
                if lhs.quality.rawValue != rhs.quality.rawValue {
                    return lhs.quality.rawValue > rhs.quality.rawValue
                }
                // 2차: Default 내에서 eloquence > compact > super-compact 순
                return identifierRank(lhs.identifier) > identifierRank(rhs.identifier)
            }
        return voices.first ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    private func identifierRank(_ id: String) -> Int {
        if id.contains("eloquence")    { return 3 }
        if id.contains(".compact.")    { return 2 }
        if id.contains("super-compact") { return 1 }
        return 0
    }

    // MARK: - Speak
    func speak(_ text: String, rate: Float = 0.42) {
        guard !text.isEmpty else { return }
        synthesizer.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setActive(true)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice             = bestVoice
        utterance.rate              = rate
        utterance.pitchMultiplier   = 1.0
        utterance.volume            = 1.0
        utterance.preUtteranceDelay = 0.05

        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

}
