import SwiftUI

// "我的"页：用户卡 + 场景切换 + 偏好 + 退出登录
struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @State private var tastes: String = ""
    @State private var isSavingTastes = false
    @State private var inviteCode: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    header
                    userCard
                    scenePicker
                    moodPicker
                    tastesCard
                    householdCard
                    actionsCard
                    Color.clear.frame(height: 40)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .task {
                tastes = (appState.currentUser?.tastePrefs ?? []).joined(separator: " ")
            }
            .navigationBarHidden(true)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text("我的")
                    .font(AppFont.title(30))
                    .foregroundStyle(Color.inkPrimary)
                Image(systemName: "leaf.fill").foregroundStyle(Color.brandGreen)
                Spacer()
            }
            Text("把这里调成你喜欢的样子")
                .font(AppFont.body())
                .foregroundStyle(Color.inkMuted)
        }
        .padding(.vertical, AppSpacing.sm)
    }

    private var userCard: some View {
        SectionCard {
            HStack(spacing: AppSpacing.md) {
                Avatar(user: appState.currentUser)
                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.currentUser?.displayName ?? "美食家")
                        .font(AppFont.headline(18))
                        .foregroundStyle(Color.inkPrimary)
                    Text(appState.household?.name ?? "未加入家")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.inkMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.inkMuted)
            }
        }
    }

    private var scenePicker: some View {
        SectionCard {
            NumberedSectionTitle(index: 1, title: "当前场景")
            VStack(spacing: AppSpacing.sm) {
                ForEach(Scene.allCases) { scene in
                    Button {
                        Task { await updateScene(scene) }
                    } label: {
                        HStack {
                            Image(systemName: scene.icon)
                                .foregroundStyle(appState.currentScene == scene ? Color.brandGreen : Color.inkMuted)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(scene.label).font(AppFont.body(15)).foregroundStyle(Color.inkPrimary)
                                Text(scene.hint).font(AppFont.caption(11)).foregroundStyle(Color.inkMuted)
                            }
                            Spacer()
                            Image(systemName: appState.currentScene == scene ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(appState.currentScene == scene ? Color.brandGreen : Color.inkMuted)
                        }
                        .padding(AppSpacing.md)
                        .background(appState.currentScene == scene ? Color.brandGreen.opacity(0.06) : Color.appBackground)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var moodPicker: some View {
        SectionCard {
            NumberedSectionTitle(index: 2, title: "默认心情")
            HStack(spacing: AppSpacing.sm) {
                ForEach(Mood.allCases) { mood in
                    MoodChip(mood: mood, isSelected: appState.currentMood == mood) {
                        Task { await updateMood(mood) }
                    }
                }
            }
        }
    }

    private var tastesCard: some View {
        SectionCard {
            NumberedSectionTitle(index: 3, title: "口味偏好", hint: "空格分隔")
            TextField("比如 清淡 少辣 爱海鲜", text: $tastes, axis: .vertical)
                .lineLimit(2...4)
                .padding(AppSpacing.md)
                .background(Color.appBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            HStack {
                Spacer()
                Button {
                    Task { await saveTastes() }
                } label: {
                    Text(isSavingTastes ? "保存中" : "保存口味")
                        .font(AppFont.caption(13))
                        .foregroundStyle(Color.brandGreen)
                }
            }
        }
    }

    private var householdCard: some View {
        SectionCard {
            NumberedSectionTitle(index: 4, title: "家的设置")
            if let h = appState.household {
                HStack {
                    Text("名字").font(AppFont.body(14)).foregroundStyle(Color.inkSecondary)
                    Spacer()
                    Text(h.name).font(AppFont.body(14)).foregroundStyle(Color.inkPrimary)
                }
                HStack {
                    Text("邀请码").font(AppFont.body(14)).foregroundStyle(Color.inkSecondary)
                    Spacer()
                    Text(inviteCode ?? h.inviteCode)
                        .font(AppFont.mono(14))
                        .foregroundStyle(Color.brandGreen)
                }
                HStack(spacing: AppSpacing.sm) {
                    SecondaryButton(title: "新建邀请码", icon: "arrow.triangle.2.circlepath") {
                        Task { await refreshInvite() }
                    }
                    SecondaryButton(title: "复制邀请码", icon: "doc.on.doc") {
                        UIPasteboard.general.string = inviteCode ?? h.inviteCode
                    }
                }
            } else {
                Text("还没加入家").font(AppFont.caption()).foregroundStyle(Color.inkMuted)
            }
        }
    }

    private var actionsCard: some View {
        VStack(spacing: AppSpacing.md) {
            SecondaryButton(title: "退出登录", icon: "rectangle.portrait.and.arrow.right") {
                Task { await appState.didLogout() }
            }
        }
    }

    private func updateScene(_ scene: Scene) async {
        appState.currentScene = scene
        do {
            let user = try await AuthService.shared.updateProfile(UpdateProfileRequest(defaultScene: scene))
            appState.currentUser = user
        } catch {
            // 静默 用户不需要被打扰
        }
    }

    private func updateMood(_ mood: Mood) async {
        appState.currentMood = mood
        do {
            let user = try await AuthService.shared.updateProfile(UpdateProfileRequest(defaultMood: mood))
            appState.currentUser = user
        } catch {}
    }

    private func saveTastes() async {
        isSavingTastes = true
        defer { isSavingTastes = false }
        let items = tastes.split(whereSeparator: { $0.isWhitespace }).map(String.init).filter { !$0.isEmpty }
        do {
            let user = try await AuthService.shared.updateProfile(UpdateProfileRequest(tastePrefs: items))
            appState.currentUser = user
        } catch {}
    }

    private func refreshInvite() async {
        do {
            let invite = try await HouseholdService.shared.createInvite(.init(expiresIn: 86400 * 7, maxUses: 5))
            inviteCode = invite.code
        } catch {}
    }
}

// 头像组件 用户没头像则显示首字
private struct Avatar: View {
    let user: AppUser?

    var body: some View {
        Group {
            if let urlString = user?.avatar, !urlString.isEmpty, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.brandGreen.opacity(0.3), lineWidth: 1))
    }

    private var placeholder: some View {
        ZStack {
            Color.brandGreen.opacity(0.12)
            Text(String(user?.displayName.prefix(1) ?? "你"))
                .font(AppFont.headline(20))
                .foregroundStyle(Color.brandGreen)
        }
    }
}
