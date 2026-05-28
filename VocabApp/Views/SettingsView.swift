import SwiftUI

struct SettingsView: View {
    // Anthropic
    @State private var apiKey: String = ""
    @State private var isRevealed: Bool = false
    @State private var saved: Bool = false
    // Google TTS
    @State private var googleAPIKey: String = ""
    @State private var isGoogleRevealed: Bool = false
    @State private var googleSaved: Bool = false
    @State private var googleKeyExists: Bool = false

    @AppStorage("setBatchSize") private var setBatchSize: Int = 20
    @AppStorage("autoPlayMode")  private var autoPlayMode: String = "timer"
    @AppStorage("autoPlayCount") private var autoPlayCount: Int = 3

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0f0e17").ignoresSafeArea()
                Form {
                    // ── 세트 크기 설정 ──────────────────────────
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("세트당 단어 수")
                                    .foregroundStyle(.white)
                                Spacer()
                                Text("\(setBatchSize)개")
                                    .font(.headline.bold())
                                    .foregroundStyle(Color(hex: "#e8c547"))
                            }
                            Slider(value: Binding(
                                get: { Double(setBatchSize) },
                                set: { setBatchSize = Int($0) }
                            ), in: 1...100, step: 1)
                            .tint(Color(hex: "#e8c547"))

                            HStack {
                                Text("1개").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Text("100개").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .listRowBackground(Color(hex: "#1a1828"))
                    } header: {
                        Text("세트 설정").foregroundStyle(Color(hex: "#e8c547"))
                    } footer: {
                        Text("새로 만들어지는 세트에만 적용됩니다. 기존 세트는 변경되지 않습니다.")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    // ── 자동 넘기기 설정 ─────────────────────────
                    Section {
                        Picker("모드", selection: $autoPlayMode) {
                            Text("표시 시간").tag("timer")
                            Text("발음 읽어주기").tag("tts")
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color(hex: "#1a1828"))

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(autoPlayMode == "tts" ? "반복 횟수" : "카드 표시 시간")
                                    .foregroundStyle(.white)
                                Spacer()
                                Text(autoPlayMode == "tts" ? "\(autoPlayCount)회" : "\(autoPlayCount)초")
                                    .font(.headline.bold())
                                    .foregroundStyle(Color(hex: "#e8c547"))
                            }
                            Slider(value: Binding(
                                get: { Double(autoPlayCount) },
                                set: { autoPlayCount = Int($0) }
                            ), in: 1...10, step: 1)
                            .tint(Color(hex: "#e8c547"))
                            HStack {
                                Text(autoPlayMode == "tts" ? "1회" : "1초")
                                    .font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Text(autoPlayMode == "tts" ? "10회" : "10초")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .listRowBackground(Color(hex: "#1a1828"))
                    } header: {
                        Text("자동 넘기기").foregroundStyle(Color(hex: "#e8c547"))
                    } footer: {
                        Text(autoPlayMode == "tts"
                             ? "단어를 설정한 횟수만큼 읽어준 뒤 다음 카드로 넘어갑니다."
                             : "플레이 버튼을 누르면 설정한 시간마다 다음 카드로 자동으로 넘어갑니다.")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    // ── Anthropic API 키 ─────────────────────────
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Anthropic API Key")
                                .font(.caption.bold()).foregroundStyle(.secondary)
                            HStack {
                                Group {
                                    if isRevealed {
                                        TextField("sk-ant-...", text: $apiKey)
                                            .autocorrectionDisabled()
                                            .textInputAutocapitalization(.never)
                                    } else {
                                        SecureField("sk-ant-...", text: $apiKey)
                                    }
                                }
                                .textFieldStyle(.plain).foregroundStyle(.white)
                                Button { isRevealed.toggle() } label: {
                                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .listRowBackground(Color(hex: "#1a1828"))

                        Button {
                            KeychainService.shared.saveAPIKey(
                                apiKey.trimmingCharacters(in: .whitespaces))
                            saved = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saved = false }
                        } label: {
                            HStack {
                                Image(systemName: "key.fill")
                                Text(saved ? "저장됨 ✓" : "Keychain에 저장")
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 4)
                        }
                        .listRowBackground(Color(hex: "#e8c547"))
                        .foregroundStyle(Color(hex: "#0f0e17"))
                        .fontWeight(.bold)

                        Button(role: .destructive) {
                            KeychainService.shared.deleteAPIKey()
                            apiKey = ""
                            saved = false
                        } label: {
                            Label("API 키 삭제", systemImage: "trash")
                        }
                        .listRowBackground(Color(hex: "#1a1828"))

                    } header: {
                        Text("API 키 설정").foregroundStyle(Color(hex: "#e8c547"))
                    } footer: {
                        Text("키는 iOS Keychain에 안전하게 저장됩니다.\nClaude Haiku 4.5 사용 (단어 1개 ≈ $0.000001)")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    // ── Google TTS API 키 ────────────────────────
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Google Cloud API Key")
                                    .font(.caption.bold()).foregroundStyle(.secondary)
                                Spacer()
                                if googleKeyExists {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("WaveNet 사용 중")
                                            .font(.caption.bold())
                                    }
                                    .foregroundStyle(Color(hex: "#4ecdc4"))
                                }
                            }
                            HStack {
                                Group {
                                    if isGoogleRevealed {
                                        TextField("AIza...", text: $googleAPIKey)
                                            .autocorrectionDisabled()
                                            .textInputAutocapitalization(.never)
                                    } else {
                                        SecureField("AIza...", text: $googleAPIKey)
                                    }
                                }
                                .textFieldStyle(.plain).foregroundStyle(.white)
                                Button { isGoogleRevealed.toggle() } label: {
                                    Image(systemName: isGoogleRevealed ? "eye.slash" : "eye")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .listRowBackground(Color(hex: "#1a1828"))

                        Button {
                            KeychainService.shared.saveGoogleTTSKey(
                                googleAPIKey.trimmingCharacters(in: .whitespaces))
                            googleKeyExists = !googleAPIKey.trimmingCharacters(in: .whitespaces).isEmpty
                            googleSaved = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { googleSaved = false }
                        } label: {
                            HStack {
                                Image(systemName: "key.fill")
                                Text(googleSaved ? "저장됨 ✓" : "Keychain에 저장")
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 4)
                        }
                        .listRowBackground(Color(hex: "#4ecdc4"))
                        .foregroundStyle(Color(hex: "#0f0e17"))
                        .fontWeight(.bold)

                        Button(role: .destructive) {
                            KeychainService.shared.deleteGoogleTTSKey()
                            googleAPIKey = ""
                            googleKeyExists = false
                            googleSaved = false
                        } label: {
                            Label("Google TTS 키 삭제", systemImage: "trash")
                        }
                        .listRowBackground(Color(hex: "#1a1828"))

                    } header: {
                        Text("Google TTS API 키").foregroundStyle(Color(hex: "#e8c547"))
                    } footer: {
                        Text("Google Cloud WaveNet 목소리를 사용합니다 (en-US-Wavenet-D).\n키가 없으면 기기 내장 TTS로 재생됩니다.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                apiKey = KeychainService.shared.loadAPIKey() ?? ""
                googleAPIKey = KeychainService.shared.loadGoogleTTSKey() ?? ""
                googleKeyExists = KeychainService.shared.hasGoogleTTSKey
            }
        }
    }
}
