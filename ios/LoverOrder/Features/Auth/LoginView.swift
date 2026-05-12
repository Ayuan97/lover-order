import AuthenticationServices
import SwiftUI

// 登录页 仅 Apple Sign In
struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isLoading = false
    @State private var errorMessage: String?

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

                if let errorMessage {
                    Text(errorMessage)
                        .font(AppFont.caption())
                        .foregroundStyle(.red)
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
