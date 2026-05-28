import AVFoundation

final class SpeechService: NSObject {
    static let shared = SpeechService()

    private var synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Never>?
    private var sessionLocked = false

    private override init() {
        super.init()
        synthesizer.delegate = self
        try? AVAudioSession.sharedInstance().setCategory(
            .playback,
            mode: .spokenAudio,
            options: [.allowBluetoothA2DP, .duckOthers]
        )
    }

    // MARK: - Session lock (자동재생 루프용)

    func lockSession() {
        sessionLocked = true
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func unlockSession() {
        sessionLocked = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Voice selection

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
        if id.contains("eloquence")     { return 3 }
        if id.contains(".compact.")     { return 2 }
        if id.contains("super-compact") { return 1 }
        return 0
    }

    // MARK: - Speak (fire-and-forget)

    func speak(_ text: String, language: String, rate: Float = 0.42) {
        guard !text.isEmpty else { return }
        synthesizer.stopSpeaking(at: .immediate)
        if !sessionLocked { try? AVAudioSession.sharedInstance().setActive(true) }
        synthesizer.speak(makeUtterance(text, language: language, rate: rate))
    }

    // MARK: - Speak and wait (async — 자동 넘기기 TTS 모드용)

    func speakAndWait(_ text: String, language: String = "en-US", rate: Float = 0.42) async {
        guard !text.isEmpty else { return }
        await withCheckedContinuation { cont in
            continuation = cont
            synthesizer.stopSpeaking(at: .immediate)
            if !sessionLocked { try? AVAudioSession.sharedInstance().setActive(true) }
            synthesizer.speak(makeUtterance(text, language: language, rate: rate))
        }
    }

    // MARK: - Stop

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Private helpers

    private func makeUtterance(_ text: String, language: String, rate: Float) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice             = bestVoice(for: language)
        utterance.rate              = rate
        utterance.pitchMultiplier   = 1.0
        utterance.volume            = 1.0
        utterance.preUtteranceDelay = 0.05
        return utterance
    }

    private func deactivateSession() {
        if !sessionLocked {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension SpeechService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        deactivateSession()
        let cont = continuation
        continuation = nil
        cont?.resume()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        deactivateSession()
        let cont = continuation
        continuation = nil
        cont?.resume()
    }
}
