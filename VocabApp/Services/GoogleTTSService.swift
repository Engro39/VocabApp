import AVFoundation
import Foundation

enum GoogleTTSError: Error {
    case apiError, decodeFailed
}

final class GoogleTTSService {
    static let shared = GoogleTTSService()
    private var player: AVAudioPlayer?
    private var playerDelegate: PlayerDelegate?
    // Set by stop() so a pending fetchAudio result is discarded without playing.
    private var isStopped = false

    private init() {}

    // Fetches WaveNet audio and plays it. Throws on network/API/playback errors.
    // rate: Google speakingRate (1.0 = normal; map from AVSpeech rate via `avRate / 0.5`).
    func speak(_ text: String, rate: Float = 1.0) async throws {
        isStopped = false
        let key = KeychainService.shared.loadGoogleTTSKey() ?? ""
        guard !key.isEmpty else { throw GoogleTTSError.apiError }

        let audioData = try await fetchAudio(text: text, rate: Double(rate), apiKey: key)
        guard !isStopped else { return }
        try await playAudio(audioData)
    }

    func stop() {
        isStopped = true
        player?.stop()
        player = nil
        playerDelegate?.resumeWithCancellation()
        playerDelegate = nil
    }

    // MARK: - Private

    private func fetchAudio(text: String, rate: Double, apiKey: String) async throws -> Data {
        let urlString = "https://texttospeech.googleapis.com/v1/text:synthesize?key=\(apiKey)"
        guard let url = URL(string: urlString) else { throw GoogleTTSError.apiError }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "input":       ["text": text],
            "voice":       ["languageCode": "en-US", "name": "en-US-Wavenet-D"],
            "audioConfig": ["audioEncoding": "MP3", "speakingRate": rate]
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw GoogleTTSError.apiError
        }

        struct Body: Decodable { let audioContent: String }
        let body = try JSONDecoder().decode(Body.self, from: data)
        guard let audio = Data(base64Encoded: body.audioContent) else {
            throw GoogleTTSError.decodeFailed
        }
        return audio
    }

    private func playAudio(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            do {
                let p = try AVAudioPlayer(data: data)
                let d = PlayerDelegate(continuation: cont)
                p.delegate = d
                playerDelegate = d
                player = p
                p.play()
            } catch {
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

        func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
            let cont = continuation
            continuation = nil
            cont?.resume()
        }

        func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
            let cont = continuation
            continuation = nil
            cont?.resume(throwing: error ?? GoogleTTSError.decodeFailed)
        }
    }
}
