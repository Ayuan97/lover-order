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
    @AppStorage("profile.householdMode") private var householdMode: String = HouseholdMode.couple.rawValue
    @AppStorage("profile.showScene") private var showSceneInList: Bool = true

    @State private var showCategoryManagement: Bool = false
    @State private var confirmLeaveHousehold: Bool = false
    @State private var showEditProfile: Bool = false
    @State private var stats: HouseholdStats?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    header
                    userCard
                    if let stats {
                        StatsCard(stats: stats)
                    }
                    scenePicker
                    householdModeCard
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

    private var scenePicker: some View {
        SectionCard {
            NumberedSectionTitle(index: 1, title: "当前场景", hint: "决定你打开 App 看到哪一顿")
            VStack(spacing: AppSpacing.sm) {
                ForEach(MealScene.allCases) { scene in
                    SceneRow(scene: scene, selected: appState.currentScene == scene) {
                        Task { await updateScene(scene) }
                    }
                }
            }
        }
    }

    private var householdModeCard: some View {
        SectionCard {
            NumberedSectionTitle(index: 2, title: "家庭目前状态", hint: "告诉 App 你家几口人")
            FlowLayout(spacing: AppSpacing.sm) {
                ForEach(HouseholdMode.allCases) { mode in
                    Button {
                        householdMode = mode.rawValue
                    } label: {
                        Text(mode.label)
                            .font(AppFont.body(13))
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, 8)
                            .foregroundStyle(householdMode == mode.rawValue ? .white : Color.inkPrimary)
                            .background(householdMode == mode.rawValue ? Color.brandGreen : Color.appBackground)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var moodPicker: some View {
        SectionCard {
            NumberedSectionTitle(index: 3, title: "默认心情", hint: "首页默认打开哪一档")
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
            NumberedSectionTitle(index: 4, title: "口味偏好", hint: "多选 推荐时会偏向这些口味")
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
            NumberedSectionTitle(index: 5, title: "显示方式")
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
                HStack(spacing: AppSpacing.sm) {
                    SecondaryButton(title: "新建邀请码", icon: "arrow.triangle.2.circlepath") {
                        Task { await refreshInvite() }
                    }
                    SecondaryButton(title: "复制邀请码", icon: "doc.on.doc") {
                        UIPasteboard.general.string = inviteCode ?? h.inviteCode
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
        } catch {}
    }

    private func updateMood(_ mood: Mood) async {
        appState.currentMood = mood
        do {
            let user = try await AuthService.shared.updateProfile(UpdateProfileRequest(defaultMood: mood))
            appState.currentUser = user
        } catch {}
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
        } catch {}
    }

    private func refreshInvite() async {
        do {
            let invite = try await HouseholdService.shared.createInvite(.init(expiresIn: 86400 * 7, maxUses: 5))
            inviteCode = invite.code
        } catch {}
    }

    private func leaveHousehold() async {
        do {
            try await HouseholdService.shared.leave()
            appState.household = nil
            await appState.refreshProfile()
        } catch {}
    }

    private func loadStats() async {
        guard appState.currentUser?.hasHousehold == true else { return }
        do {
            stats = try await MealService.shared.stats()
        } catch {}
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

// 家庭组成模式 仅本地存
enum HouseholdMode: String, CaseIterable, Identifiable {
    case couple
    case family3
    case friends

    var id: String { rawValue }

    var label: String {
        switch self {
        case .couple: return "两个人"
        case .family3: return "三口之家"
        case .friends: return "朋友亲戚一起聚聚"
        }
    }
}

// 常见口味预设
enum TastePresets {
    static let all = ["麻辣", "清淡", "酸甜", "咸鲜", "海鲜", "烧烤", "凉拌", "蒸煮", "炖煮", "面食", "米饭", "汤水"]
}

// 单条场景选项行
private struct SceneRow: View {
    let scene: MealScene
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: scene.icon)
                    .foregroundStyle(selected ? Color.brandGreen : Color.inkMuted)
                VStack(alignment: .leading, spacing: 2) {
                    Text(scene.label).font(AppFont.body(15)).foregroundStyle(Color.inkPrimary)
                    Text(scene.hint).font(AppFont.caption(11)).foregroundStyle(Color.inkMuted)
                }
                Spacer()
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? Color.brandGreen : Color.inkMuted)
            }
            .padding(AppSpacing.md)
            .background(selected ? Color.brandGreen.opacity(0.06) : Color.appBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// 头像组件
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
