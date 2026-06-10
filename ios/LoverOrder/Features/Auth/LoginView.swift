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
        VStack(spacing: AppSpacing.xxl) {
            Spacer()

            VStack(spacing: AppSpacing.md) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(Color.brandGreen)
                Text("我们这顿")
                    .font(AppFont.title(36))
                    .foregroundStyle(Color.inkPrimary)
                Text("两个人轻松决定吃什么")
                    .font(AppFont.body())
                    .foregroundStyle(Color.inkMuted)
            }

            Spacer()

            VStack(spacing: AppSpacing.md) {
                SignInWithAppleButton(.signIn, onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                }, onCompletion: handleApple)
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.pill, style: .continuous))

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
                    .padding(.vertical, 6)
                }
                #endif

                if let errorMessage {
                    Text(errorMessage)
                        .font(AppFont.caption())
                        .foregroundStyle(Color.errorInk)
                        .multilineTextAlignment(.center)
                }

                Text("继续即表示同意我们的服务条款")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.inkMuted)
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xxl)
        }
        .padding(.horizontal, AppSpacing.xl)
        .background(Color.appBackground.ignoresSafeArea())
        .overlay(alignment: .center) {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.15).ignoresSafeArea()
                    ProgressView().tint(Color.brandGreen)
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
