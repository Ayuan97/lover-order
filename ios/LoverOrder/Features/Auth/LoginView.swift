import SwiftUI

// 登录页：基于设备唯一身份设个昵称即可进入，也支持用昵称 + 密码跨设备找回账号
struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("auth.last.nickname") private var savedNickname: String = ""

    private enum FocusField: Hashable {
        case nickname
        case password
    }

    @State private var nickname: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @State private var isPasswordMode: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: FocusField?

    private var trimmedNickname: String {
        nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        if trimmedNickname.isEmpty { return false }
        if isPasswordMode && password.isEmpty { return false }
        return true
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 24)

                    VStack(spacing: AppSpacing.md) {
                        Image("StickerEmoji_food_cheers")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 86, height: 86)
                            .shadow(color: Color.black.opacity(0.28), radius: 14, y: 6)

                        Text("我们这顿")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: Color.black.opacity(0.26), radius: 8, y: 2)

                        Text("把今天这一顿，摆成一张会动的画")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.88))
                    }

                    Spacer(minLength: 24)

                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(isPasswordMode ? "昵称密码登录" : "起个名字就开始")
                                .font(AppFont.title(20))
                                .foregroundStyle(Color.inkPrimary)
                            Text(isPasswordMode ? "用已设置密码的昵称，在新设备上找回账号" : "本机将自动绑定唯一身份，之后可随时设密码跨设备登录")
                                .font(AppFont.caption(12.5))
                                .foregroundStyle(Color.inkMuted)
                        }

                        HStack(spacing: 10) {
                            Image(systemName: "person")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.inkMuted)
                            TextField(isPasswordMode ? "输入你的昵称" : "输入你的昵称，比如 小满", text: $nickname)
                                .font(AppFont.body(15.5))
                                .foregroundStyle(Color.inkPrimary)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .nickname)
                                .submitLabel(isPasswordMode ? .next : .go)
                                .onSubmit {
                                    if isPasswordMode {
                                        focusedField = .password
                                    } else {
                                        submit()
                                    }
                                }
                            if !nickname.isEmpty {
                                Button {
                                    nickname = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 15))
                                        .foregroundStyle(Color.inkMuted.opacity(0.7))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("清空昵称")
                            }
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.dividerLine.opacity(0.85), lineWidth: 0.7)
                        }

                        if isPasswordMode {
                            HStack(spacing: 10) {
                                Image(systemName: "lock")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.inkMuted)
                                Group {
                                    if showPassword {
                                        TextField("输入登录密码", text: $password)
                                            .focused($focusedField, equals: .password)
                                    } else {
                                        SecureField("输入登录密码", text: $password)
                                            .focused($focusedField, equals: .password)
                                    }
                                }
                                .font(AppFont.body(15.5))
                                .foregroundStyle(Color.inkPrimary)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .submitLabel(.go)
                                .onSubmit {
                                    submit()
                                }
                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.inkMuted)
                                        .frame(width: 28, height: 28)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(showPassword ? "隐藏密码" : "显示密码")
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 48)
                            .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.dividerLine.opacity(0.85), lineWidth: 0.7)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(AppFont.caption(12.5))
                                .foregroundStyle(Color.errorInk)
                        }

                        Button {
                            submit()
                        } label: {
                            HStack(spacing: 8) {
                                if isLoading {
                                    ProgressView().tint(.white).controlSize(.small)
                                }
                                Text(isPasswordMode ? "登录" : "进入我们这顿")
                                    .font(AppFont.headline(16))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.actionInk, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .opacity(canSubmit ? 1 : 0.55)
                        }
                        .buttonStyle(SoftPressStyle())
                        .disabled(isLoading)

                        Button {
                            Haptics.light()
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                isPasswordMode.toggle()
                                errorMessage = nil
                                if !isPasswordMode {
                                    password = ""
                                }
                            }
                        } label: {
                            Text(isPasswordMode ? "首次使用？只需填个昵称直接进入" : "已有账号？用昵称和密码登录")
                                .font(AppFont.caption(13))
                                .foregroundStyle(Color.inkSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading)
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
                .frame(minHeight: proxy.size.height)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .background {
            ZStack {
                GeometryReader { bgProxy in
                    Image("ProfileHeroCover")
                        .resizable()
                        .scaledToFill()
                        .frame(width: bgProxy.size.width, height: bgProxy.size.height)
                        .clipped()
                }
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.30),
                        Color.black.opacity(0.38),
                        Color.black.opacity(0.80)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = nil
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if nickname.isEmpty, !savedNickname.isEmpty {
                nickname = savedNickname
            }
        }
    }

    private func submit() {
        guard !isLoading else { return }
        if trimmedNickname.isEmpty {
            errorMessage = "先写一个昵称再进来"
            return
        }
        if isPasswordMode {
            if password.isEmpty {
                errorMessage = "请输入登录密码"
                return
            }
            focusedField = nil
            Task { await handlePasswordLogin() }
        } else {
            focusedField = nil
            Task { await handleDeviceLogin() }
        }
    }

    private func handleDeviceLogin() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let res = try await AuthService.shared.loginWithDevice(
                deviceId: DeviceIdentity.shared.deviceID,
                nickname: trimmedNickname
            )
            savedNickname = res.user.nickname
            Haptics.success()
            await appState.didLogin(res)
        } catch APIError.server(let code, let message) where code == 409 {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                isPasswordMode = true
            }
            errorMessage = message
            focusedField = .password
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handlePasswordLogin() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let res = try await AuthService.shared.loginWithPassword(
                nickname: trimmedNickname,
                password: password
            )
            Haptics.success()
            await appState.didLogin(res)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
