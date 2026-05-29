import AVFoundation
import os.log

private let speechLog = Logger(subsystem: "com.chulhoon.VocabApp", category: "SpeechService")

final class SpeechService: NSObject {
    static let shared = SpeechService()

    private var synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Never>?
    private var sessionLocked = false
    private var googleSpeakTask: Task<Void, Never>?

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

    // MARK: - Speak (fire-and-forget)
    // Google WaveNet → AVSpeechSynthesizer fallback

    func speak(_ text: String, language: String, slow: Bool = false) {
        guard !text.isEmpty else { return }
        let hasGoogle = KeychainService.shared.hasGoogleTTSKey
        speechLog.debug("speak() hasGoogleTTSKey=\(hasGoogle) slow=\(slow) text='\(text.prefix(40))'")
        synthesizer.stopSpeaking(at: .immediate)
        googleSpeakTask?.cancel()
        googleSpeakTask = nil
        GoogleTTSService.shared.stop()
        if !sessionLocked { try? AVAudioSession.sharedInstance().setActive(true) }

        let gRate = googleRate(slow: slow)
        if hasGoogle {
            googleSpeakTask = Task {
                do {
                    try await GoogleTTSService.shared.speak(text, rate: gRate)
                    speechLog.debug("speak() — GoogleTTS succeeded")
                    deactivateSession()
                } catch {
                    // Task.isCancelled: 이전 speak() 호출로 취소된 경우 — fallback 하지 않음
                    guard !Task.isCancelled else { return }
                    speechLog.error("speak() — GoogleTTS failed (\(error)), falling back to AVSpeech")
                    synthesizer.speak(makeUtterance(text, language: language, rate: avSpeechRate(slow: slow)))
                    // delegate handles deactivation
                }
            }
        } else {
            speechLog.debug("speak() — using AVSpeechSynthesizer")
            synthesizer.speak(makeUtterance(text, language: language, rate: avSpeechRate(slow: slow)))
        }
    }

    // MARK: - Speak and wait (async — 자동 넘기기 TTS 모드용)

    func speakAndWait(_ text: String, language: String = "en-US", slow: Bool = false) async {
        guard !text.isEmpty else { return }
        let hasGoogle = KeychainService.shared.hasGoogleTTSKey
        speechLog.debug("speakAndWait() hasGoogleTTSKey=\(hasGoogle) slow=\(slow) text='\(text.prefix(40))'")
        synthesizer.stopSpeaking(at: .immediate)
        GoogleTTSService.shared.stop()
        if !sessionLocked { try? AVAudioSession.sharedInstance().setActive(true) }

        let gRate = googleRate(slow: slow)
        if hasGoogle {
            do {
                try await GoogleTTSService.shared.speak(text, rate: gRate)
                speechLog.debug("speakAndWait() — GoogleTTS succeeded")
                deactivateSession()
                return
            } catch {
                guard !Task.isCancelled else {
                    speechLog.debug("speakAndWait() — task cancelled, skipping AVSpeech fallback")
                    return
                }
                speechLog.error("speakAndWait() — GoogleTTS failed (\(error)), falling back to AVSpeech")
            }
        }

        await withCheckedContinuation { cont in
            continuation = cont
            synthesizer.speak(makeUtterance(text, language: language, rate: avSpeechRate(slow: slow)))
        }
        // delegate calls deactivateSession()
    }

    // MARK: - Stop

    func stop() {
        googleSpeakTask?.cancel()
        googleSpeakTask = nil
        synthesizer.stopSpeaking(at: .immediate)
        GoogleTTSService.shared.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Rate helpers

    private func googleRate(slow: Bool) -> Float {
        let key = slow ? "ttsSlowRate" : "ttsNormalRate"
        let defaultValue: Double = slow ? 0.8 : 1.1
        let stored = UserDefaults.standard.double(forKey: key)
        return Float(stored > 0 ? stored : defaultValue)
    }

    // AVSpeech 0.42 ≈ natural rate, which corresponds to Google speakingRate 1.15
    private func avSpeechRate(slow: Bool) -> Float {
        return googleRate(slow: slow) * 0.42 / 1.15
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
