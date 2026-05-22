import AVFoundation
import NaturalLanguage

final class SpeechService: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = SpeechService()
    private let synthesizer = AVSpeechSynthesizer()
    private var pendingContinuation: CheckedContinuation<Void, Never>? = nil

    private override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }

    // MARK: - Audio Session
    private func configureAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(
            .playback, mode: .spokenAudio, options: .duckOthers
        )
    }

    // MARK: - Language detection
    func detectLanguage(_ text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        switch recognizer.dominantLanguage {
        case .korean:             return "ko-KR"
        case .japanese:           return "ja-JP"
        case .simplifiedChinese:  return "zh-CN"
        case .traditionalChinese: return "zh-TW"
        case .french:             return "fr-FR"
        case .german:             return "de-DE"
        case .spanish:            return "es-ES"
        default:                  return "en-US"
        }
    }

    // MARK: - Voice selection
    // 우선순위: Premium > Enhanced > Eloquence > compact > super-compact
    // com.apple.speech.synthesis.voice.* (로봇 음성) 제외
    private func bestVoice(for language: String) -> AVSpeechSynthesisVoice? {
        let prefix = String(language.prefix(2))
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(prefix) }
            .filter { !$0.identifier.contains("speech.synthesis.voice") }
            .sorted { l, r in
                l.quality.rawValue != r.quality.rawValue
                    ? l.quality.rawValue > r.quality.rawValue
                    : identifierRank(l.identifier) > identifierRank(r.identifier)
            }
        return voices.first ?? AVSpeechSynthesisVoice(language: language)
    }

    private func identifierRank(_ id: String) -> Int {
        if id.contains("eloquence")      { return 3 }
        if id.contains(".compact.")      { return 2 }
        if id.contains("super-compact")  { return 1 }
        return 0
    }

    // MARK: - Speak (fire-and-forget)
    // 기존 호출부 호환 — en-US 고정
    func speak(_ text: String, rate: Float = 0.42) {
        speak(text, language: "en-US", rate: rate)
    }

    func speak(_ text: String, language: String, rate: Float = 0.42) {
        guard !text.isEmpty else { return }
        synthesizer.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setActive(true)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice             = bestVoice(for: language)
        utterance.rate              = rate
        utterance.pitchMultiplier   = 1.0
        utterance.volume            = 1.0
        utterance.preUtteranceDelay = 0.05
        synthesizer.speak(utterance)
    }

    // MARK: - Speak and wait (async — 자동 넘기기 TTS 모드용)
    func speakAndWait(_ text: String, language: String = "en-US", rate: Float = 0.42) async {
        guard !text.isEmpty else { return }
        await withCheckedContinuation { cont in
            pendingContinuation = cont
            speak(text, language: language, rate: rate)
        }
    }

    // MARK: - Stop
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        // didCancel 델리게이트 → resumePending() → pendingContinuation 재개
    }

    // MARK: - AVSpeechSynthesizerDelegate
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        resumePending()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        resumePending()
    }

    private func resumePending() {
        let cont = pendingContinuation
        pendingContinuation = nil
        cont?.resume()
    }
}
