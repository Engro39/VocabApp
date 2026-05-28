import AVFoundation
import Foundation
import os.log

private let ttsLog = Logger(subsystem: "com.chulhoon.VocabApp", category: "GoogleTTS")

enum GoogleTTSError: Error {
    case apiError(statusCode: Int, body: String)
    case decodeFailed
    case playbackFailed
}

final class GoogleTTSService {
    static let shared = GoogleTTSService()
    private var player: AVAudioPlayer?
    private var playerDelegate: PlayerDelegate?
    // Set by stop() so a pending fetchAudio result is discarded without playing.
    private var isStopped = false

    private init() {}

    // Fetches WaveNet audio and plays it. Throws on network/API/playback errors.
    // rate: Google speakingRate (1.0 = normal).
    // Map from AVSpeech rate via `(avRate / 0.42) * 1.15`:
    //   avRate 0.42 (normal) → 1.15,  avRate 0.30 (slow) → ~0.82
    func speak(_ text: String, rate: Float = 1.15) async throws {
        isStopped = false
        ttsLog.debug("speak() called — text='\(text.prefix(40))' rate=\(rate)")

        let key = KeychainService.shared.loadGoogleTTSKey() ?? ""
        guard !key.isEmpty else {
            ttsLog.error("speak() aborted — Google TTS key is empty")
            throw GoogleTTSError.apiError(statusCode: 0, body: "No API key")
        }
        ttsLog.debug("speak() — key loaded (len=\(key.count))")

        let audioData = try await fetchAudio(text: text, rate: Double(rate), apiKey: key)
        ttsLog.debug("speak() — fetchAudio succeeded, audioData=\(audioData.count) bytes")

        guard !isStopped else {
            ttsLog.debug("speak() — isStopped=true after fetch, skipping playback")
            return
        }
        try await playAudio(audioData)
        ttsLog.debug("speak() — playback finished")
    }

    func stop() {
        ttsLog.debug("stop() called")
        isStopped = true
        player?.stop()
        player = nil
        playerDelegate?.resumeWithCancellation()
        playerDelegate = nil
    }

    // MARK: - Private

    private func fetchAudio(text: String, rate: Double, apiKey: String) async throws -> Data {
        ttsLog.debug("fetchAudio() — rate=\(rate)")
        let urlString = "https://texttospeech.googleapis.com/v1/text:synthesize?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            ttsLog.error("fetchAudio() — invalid URL")
            throw GoogleTTSError.apiError(statusCode: 0, body: "Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Bundle.main.bundleIdentifier ?? "", forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "input":       ["text": text],
            "voice":       ["languageCode": "en-US", "name": "en-US-Wavenet-D"],
            "audioConfig": ["audioEncoding": "MP3", "speakingRate": rate]
        ])

        ttsLog.debug("fetchAudio() — sending POST to Google TTS API")
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        ttsLog.debug("fetchAudio() — HTTP status=\(statusCode), responseSize=\(data.count) bytes")

        guard statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "(non-UTF8 body)"
            ttsLog.error("fetchAudio() — API error \(statusCode): \(body)")
            throw GoogleTTSError.apiError(statusCode: statusCode, body: body)
        }

        struct Body: Decodable { let audioContent: String }
        let body = try JSONDecoder().decode(Body.self, from: data)
        ttsLog.debug("fetchAudio() — audioContent base64 length=\(body.audioContent.count)")

        guard let audio = Data(base64Encoded: body.audioContent) else {
            ttsLog.error("fetchAudio() — base64 decode failed")
            throw GoogleTTSError.decodeFailed
        }
        ttsLog.debug("fetchAudio() — decoded audio \(audio.count) bytes")
        return audio
    }

    private func playAudio(_ data: Data) async throws {
        ttsLog.debug("playAudio() — \(data.count) bytes")
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            do {
                // fileTypeHint helps AVAudioPlayer recognise MP3 without sniffing
                let p = try AVAudioPlayer(data: data, fileTypeHint: AVFileType.mp3.rawValue)
                p.prepareToPlay()
                let d = PlayerDelegate(continuation: cont)
                p.delegate = d
                playerDelegate = d
                player = p
                let started = p.play()
                ttsLog.debug("playAudio() — AVAudioPlayer.play() returned \(started)")
                if !started {
                    // play() failed to start — clean up and resume continuation with error
                    p.delegate = nil      // prevent future delegate callbacks on d
                    player = nil
                    playerDelegate = nil
                    d.resumeWith(error: GoogleTTSError.playbackFailed)
                }
            } catch {
                ttsLog.error("playAudio() — AVAudioPlayer init error: \(error)")
                cont.resume(throwing: error)
            }
        }
        player = nil
        playerDelegate = nil
    }

    // MARK: - Player delegate

    private final class PlayerDelegate: NSObject, AVAudioPlayerDelegate {
        private var continuation: CheckedContinuation<Void, Error>?

        init(continuation: CheckedContinuation<Void, Error>) {
            self.continuation = continuation
        }

        func resumeWithCancellation() {
            let cont = continuation
            continuation = nil
            cont?.resume(throwing: CancellationError())
        }

        func resumeWith(error: Error) {
            let cont = continuation
            continuation = nil
            cont?.resume(throwing: error)
        }

        func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
            ttsLog.debug("audioPlayerDidFinishPlaying — successfully=\(flag)")
            let cont = continuation
            continuation = nil
            cont?.resume()
        }

        func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
            ttsLog.error("audioPlayerDecodeErrorDidOccur — \(String(describing: error))")
            let cont = continuation
            continuation = nil
            cont?.resume(throwing: error ?? GoogleTTSError.decodeFailed)
        }
    }
}
