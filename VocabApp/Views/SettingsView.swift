import SwiftUI

struct SettingsView: View {
    @State private var apiKey: String = ""
    @State private var isRevealed: Bool = false
    @State private var saved: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0f0e17").ignoresSafeArea()

                Form {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Anthropic API Key")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)

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
                                .textFieldStyle(.plain)
                                .foregroundStyle(.white)

                                Button {
                                    isRevealed.toggle()
                                } label: {
                                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .listRowBackground(Color(hex: "#1a1828"))

                        Button {
                            saveKey()
                        } label: {
                            HStack {
                                Image(systemName: "key.fill")
                                Text(saved ? "저장됨 ✓" : "Keychain에 저장")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
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
                        Text("API 키 설정")
                            .foregroundStyle(Color(hex: "#e8c547"))
                    } footer: {
                        Text("키는 iOS Keychain에 안전하게 저장됩니다.\n단어 추가 시 Claude Haiku 4.5 모델 사용 (단어 1개 ≈ $0.000001)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                apiKey = KeychainService.shared.loadAPIKey() ?? ""
            }
        }
    }

    private func saveKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespaces)
        KeychainService.shared.saveAPIKey(trimmed)
        saved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            saved = false
        }
    }
}
