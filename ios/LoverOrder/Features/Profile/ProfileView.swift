import SwiftUI
import UIKit

// "我的"页：用户卡 + 5 个偏好分组 + 家的设置 + 退出
struct ProfileView: View {
    @EnvironmentObject private var appState: AppState

    // 后端持久化字段
    @State private var selectedTastes: Set<String> = []
    @State private var isSavingTastes = false
    @State private var inviteCode: String?

    // 本地持久化字段
    @AppStorage("profile.showScene") private var showSceneInList: Bool = true

    @State private var showCategoryManagement: Bool = false
    @State private var confirmLeaveHousehold: Bool = false
    @State private var showEditProfile: Bool = false
    @State private var stats: HouseholdStats?
    @State private var errorMessage: String?
    @State private var showInvite: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    header
                    userCard
                    if let stats {
                        StatsCard(stats: stats)
                    }
                    modePicker
                    moodPicker
                    tastesCard
                    displayCard
                    toolsCard
                    householdCard
                    actionsCard
                    Color.clear.frame(height: 40)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .task {
                selectedTastes = Set(appState.currentUser?.tastePrefs ?? [])
                await loadStats()
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showCategoryManagement) {
                CategoryManagementView()
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileSheet()
                    .environmentObject(appState)
            }
            .sheet(isPresented: $showInvite) {
                if let h = appState.household {
                    InviteTicketView(household: h, inviterName: appState.currentUser?.nickname ?? "我")
                }
            }
            .toast($errorMessage)
        }
    }

    private var toolsCard: some View {
        SectionCard {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "square.grid.2x2")
                    .foregroundStyle(Color.brandGreen)
                Text("整理一下")
                    .font(AppFont.headline(16))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
            }
            NavigationLink {
                FuturePlansView()
                    .environmentObject(appState)
            } label: {
                navRow(title: "未来这顿", subtitle: "留着以后吃的菜单", icon: "moon.stars")
            }
            .buttonStyle(.plain)
            Button {
                showCategoryManagement = true
            } label: {
                navRow(title: "管理菜谱分类", subtitle: "新建 改名 删除", icon: "square.grid.2x2")
            }
            .buttonStyle(.plain)
        }
    }

    private func navRow(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .foregroundStyle(Color.brandGreen)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.body(15))
                    .foregroundStyle(Color.inkPrimary)
                Text(subtitle)
                    .font(AppFont.caption(11))
                    .foregroundStyle(Color.inkMuted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(Color.inkMuted)
        }
        .padding(AppSpacing.md)
        .background(Color.appBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
    }

    private var header: some View {
        VStack(spacing: AppSpacing.xs) {
            HStack(spacing: 6) {
                Text("我的")
                    .font(AppFont.title(30))
                    .foregroundStyle(Color.inkPrimary)
                Image(systemName: "heart.fill")
                    .foregroundStyle(Color.brandGreen)
                    .font(.system(size: 14))
            }
            Text("把这里调成你喜欢的样子")
                .font(AppFont.body())
                .foregroundStyle(Color.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
    }

    private var userCard: some View {
        SectionCard {
            HStack(spacing: AppSpacing.md) {
                AvatarView(user: appState.currentUser, size: 56, ring: true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.currentUser?.displayName ?? "美食家")
                        .font(AppFont.headline(18))
                        .foregroundStyle(Color.inkPrimary)
                    Text(appState.household?.name ?? "未加入家")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.inkMuted)
                }
                Spacer()
                Button {
                    showEditProfile = true
                } label: {
                    Text("编辑")
                        .font(AppFont.caption(13))
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, 6)
                        .foregroundStyle(Color.brandGreen)
                        .background(Color.brandGreen.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var modePicker: some View {
        SectionCard {
            NumberedSectionTitle(index: 1, title: "相处模式", hint: "俩人世界还是家庭聚餐 决定首页这一顿")
            HStack(spacing: AppSpacing.sm) {
                modeButton(.pair, icon: "heart.fill")
                modeButton(.family, icon: "house.fill")
            }
        }
    }

    private func modeButton(_ scene: MealScene, icon: String) -> some View {
        let selected = appState.currentScene == scene
        return Button {
            Task { await updateScene(scene) }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .light))
                Text(scene.modeLabel)
                    .font(AppFont.body(14))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.lg)
            .foregroundStyle(selected ? .white : Color.inkPrimary)
            .background(selected ? Color.brandGreen : Color.appBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            .capsuleHairline(color: selected ? .clear : Color.dividerLine.opacity(0.7))
        }
        .buttonStyle(.plain)
    }

    private var moodPicker: some View {
        SectionCard {
            NumberedSectionTitle(index: 2, title: "默认心情", hint: "首页默认打开哪一档")
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
            NumberedSectionTitle(index: 3, title: "口味偏好", hint: "多选 推荐时会偏向这些口味")
            FlowLayout(spacing: AppSpacing.sm) {
                ForEach(TastePresets.all, id: \.self) { taste in
                    Button {
                        toggleTaste(taste)
                    } label: {
                        Text(taste)
                            .font(AppFont.body(13))
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, 8)
                            .foregroundStyle(selectedTastes.contains(taste) ? .white : Color.inkPrimary)
                            .background(selectedTastes.contains(taste) ? Color.brandGreen : Color.appBackground)
                            .clipShape(Capsule())
                            .capsuleHairline(color: selectedTastes.contains(taste) ? .clear : Color.dividerLine.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
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

    private var displayCard: some View {
        SectionCard {
            NumberedSectionTitle(index: 4, title: "显示方式")
            Toggle(isOn: $showSceneInList) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("在列表里显示场景标签")
                        .font(AppFont.body(15))
                        .foregroundStyle(Color.inkPrimary)
                    Text("方便区分这是哪一顿")
                        .font(AppFont.caption(11))
                        .foregroundStyle(Color.inkMuted)
                }
            }
            .tint(Color.brandGreen)
        }
    }

    private var householdCard: some View {
        SectionCard {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "house.fill")
                    .foregroundStyle(Color.brandGreen)
                Text("家的设置")
                    .font(AppFont.headline(16))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
            }
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
                PrimaryButton(title: "邀请家人 · 出示餐券", icon: "qrcode") {
                    showInvite = true
                }
                HStack(spacing: AppSpacing.sm) {
                    SecondaryButton(title: "新建邀请码", icon: "arrow.triangle.2.circlepath") {
                        Task { await refreshInvite() }
                    }
                    SecondaryButton(title: "复制邀请码", icon: "doc.on.doc") {
                        UIPasteboard.general.string = inviteCode ?? h.inviteCode
                        Haptics.light()
                        errorMessage = "邀请码已复制"
                    }
                }
                Button {
                    confirmLeaveHousehold = true
                } label: {
                    HStack {
                        Image(systemName: "door.left.hand.open")
                        Text("退出这个家")
                    }
                    .font(AppFont.caption(13))
                    .foregroundStyle(Color.inkMuted)
                    .padding(.top, AppSpacing.sm)
                }
            } else {
                Text("还没加入家").font(AppFont.caption()).foregroundStyle(Color.inkMuted)
            }
        }
        .confirmationDialog("退出当前的家？", isPresented: $confirmLeaveHousehold) {
            Button("退出", role: .destructive) {
                Task { await leaveHousehold() }
            }
            Button("再想想", role: .cancel) {}
        } message: {
            Text("退出后你将看不到这个家的菜单和记录 重新加入即可恢复")
        }
    }

    private var actionsCard: some View {
        VStack(spacing: AppSpacing.md) {
            SecondaryButton(title: "退出登录", icon: "rectangle.portrait.and.arrow.right") {
                Task { await appState.didLogout() }
            }
        }
    }

    private func updateScene(_ scene: MealScene) async {
        appState.currentScene = scene
        do {
            let user = try await AuthService.shared.updateProfile(UpdateProfileRequest(defaultScene: scene))
            appState.currentUser = user
            Haptics.light()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateMood(_ mood: Mood) async {
        appState.currentMood = mood
        do {
            let user = try await AuthService.shared.updateProfile(UpdateProfileRequest(defaultMood: mood))
            appState.currentUser = user
            Haptics.light()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleTaste(_ taste: String) {
        if selectedTastes.contains(taste) {
            selectedTastes.remove(taste)
        } else {
            selectedTastes.insert(taste)
        }
    }

    private func saveTastes() async {
        isSavingTastes = true
        defer { isSavingTastes = false }
        do {
            let user = try await AuthService.shared.updateProfile(
                UpdateProfileRequest(tastePrefs: Array(selectedTastes))
            )
            appState.currentUser = user
            errorMessage = "口味偏好已保存"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshInvite() async {
        do {
            let invite = try await HouseholdService.shared.createInvite(.init(expiresIn: 86400 * 7, maxUses: 5))
            inviteCode = invite.code
            errorMessage = "已生成新邀请码 旧码失效"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func leaveHousehold() async {
        do {
            try await HouseholdService.shared.leave()
            appState.household = nil
            await appState.refreshProfile()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadStats() async {
        guard appState.currentUser?.hasHousehold == true else { return }
        do {
            stats = try await MealService.shared.stats()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// 我们的小本本：总顿数 / 最近 30 天 / Top 5 常吃 / 场景分布
private struct StatsCard: View {
    let stats: HouseholdStats

    var body: some View {
        SectionCard {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "book.pages")
                    .foregroundStyle(Color.brandGreen)
                Text("我们的小本本")
                    .font(AppFont.headline(16))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
            }
            numbersRow
            if !stats.topDishes.isEmpty {
                Divider().background(Color.dividerLine)
                topDishesView
            }
            if !stats.sceneBreakdown.isEmpty {
                Divider().background(Color.dividerLine)
                sceneBreakdownView
            }
        }
    }

    private var numbersRow: some View {
        HStack(spacing: AppSpacing.md) {
            statBox(value: "\(stats.totalMeals)", label: "一共吃过这么多顿")
            statBox(value: "\(stats.totalDishes)", label: "一共下肚这么多道")
            statBox(value: "\(stats.recentMeals)", label: "最近 30 天")
        }
    }

    private func statBox(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(AppFont.title(22))
                .foregroundStyle(Color.brandGreen)
            Text(label)
                .font(AppFont.caption(11))
                .foregroundStyle(Color.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(Color.appBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
    }

    private var topDishesView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("最爱吃的几道")
                .font(AppFont.caption(12))
                .foregroundStyle(Color.inkMuted)
            ForEach(Array(stats.topDishes.enumerated()), id: \.element.id) { idx, dish in
                HStack(spacing: AppSpacing.md) {
                    Text("\(idx + 1)")
                        .font(AppFont.mono(13))
                        .frame(width: 24)
                        .foregroundStyle(Color.brandGreen)
                    DishThumb(name: dish.name, image: dish.image)
                    Text(dish.name)
                        .font(AppFont.body(14))
                        .foregroundStyle(Color.inkPrimary)
                    Spacer()
                    Text("× \(dish.count)")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.inkMuted)
                }
            }
        }
    }

    private var sceneBreakdownView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("吃饭的场合")
                .font(AppFont.caption(12))
                .foregroundStyle(Color.inkMuted)
            FlowLayout(spacing: AppSpacing.sm) {
                ForEach(stats.sceneBreakdown) { item in
                    HStack(spacing: 4) {
                        Text(item.sceneLabel)
                        Text("× \(item.count)")
                            .foregroundStyle(Color.brandGreen)
                    }
                    .font(AppFont.caption(12))
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, 6)
                    .background(Color.appBackground)
                    .clipShape(Capsule())
                }
            }
        }
    }
}

// 常见口味预设
enum TastePresets {
    static let all = ["麻辣", "清淡", "酸甜", "咸鲜", "海鲜", "烧烤", "凉拌", "蒸煮", "炖煮", "面食", "米饭", "汤水"]
}

