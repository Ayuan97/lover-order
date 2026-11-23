import AuthenticationServices
import SwiftUI

// 登录页 Apple Sign In + DEBUG 时支持开发登录
struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showDevLogin: Bool = false
    @State private var devNickname: String = ""
    @AppStorage("dev.server.code") private var devCode: String = ""

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                Image("ProfileHeroCover")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }
            .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.30),
                    Color.black.opacity(0.38),
                    Color.black.opacity(0.78)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: AppSpacing.md) {
                    Image("StickerEmoji_food_cheers")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88, height: 88)
                        .shadow(color: Color.black.opacity(0.28), radius: 14, y: 6)

                    Text("我们这顿")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: Color.black.opacity(0.26), radius: 8, y: 2)

                    Text("把今天这一顿，摆成一张会动的画")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.88))
                }

                Spacer()

                VStack(spacing: AppSpacing.md) {
                    SignInWithAppleButton(.signIn, onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    }, onCompletion: handleApple)
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    #if DEBUG
                    Button {
                        showDevLogin = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "hammer")
                            Text("开发模式登录")
                        }
                        .font(AppFont.caption(13))
                        .foregroundStyle(Color.inkSecondary)
                        .padding(.vertical, 4)
                    }
                    #endif

                    if let errorMessage {
                        Text(errorMessage)
                            .font(AppFont.caption())
                            .foregroundStyle(Color.errorInk)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(20)
                .environment(\.colorScheme, .light)
                .background(
                    Color.white.opacity(0.96),
                    in: RoundedRectangle(cornerRadius: 28, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.45), lineWidth: 0.8)
                }
                .shadow(color: Color.black.opacity(0.22), radius: 20, y: 8)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, 16)
            }
        }
        .preferredColorScheme(.dark)
        .overlay(alignment: .center) {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    ProgressView().tint(.white)
                }
            }
        }
        .alert("开发模式登录", isPresented: $showDevLogin) {
            TextField("起个昵称", text: $devNickname)
            TextField("服务器暗号 本地可留空", text: $devCode)
            Button("登录") {
                let name = devNickname.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                Task { await handleDev(nickname: name) }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("跳过 Apple Sign In 用昵称作为身份，仅用于调试")
        }
    }

    private func handleDev(nickname: String) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let trimmedCode = devCode.trimmingCharacters(in: .whitespacesAndNewlines)
            let res = try await AuthService.shared.loginDev(
                nickname: nickname,
                code: trimmedCode.isEmpty ? nil : trimmedCode
            )
            await appState.didLogin(res)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        errorMessage = nil
        switch result {
        case .failure(let err):
            errorMessage = err.localizedDescription
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8)
            else {
                errorMessage = "无法获取 Apple 凭证"
                return
            }
            let nickname: String? = {
                let parts = [credential.fullName?.familyName, credential.fullName?.givenName].compactMap { $0 }
                let s = parts.joined()
                return s.isEmpty ? nil : s
            }()

            Task {
                isLoading = true
                defer { isLoading = false }
                do {
                    let res = try await AuthService.shared.loginWithApple(
                        identityToken: identityToken,
                        nickname: nickname
                    )
                    await appState.didLogin(res)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
