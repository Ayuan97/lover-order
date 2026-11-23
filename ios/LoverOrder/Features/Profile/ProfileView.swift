import SwiftUI
import UIKit
import PhotosUI

// "我的"页：资料、常用工具、家庭设置和退出。
struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    private let profileHeroHeight: CGFloat = 330

    @State private var inviteCode: String?

    @State private var showCategoryManagement: Bool = false
    @State private var confirmLeaveHousehold: Bool = false
    @State private var showEditProfile: Bool = false
    @State private var stats: HouseholdStats?
    @State private var errorMessage: String?
    @State private var tipMessage: String?
    @State private var showInvite: Bool = false
    // 客人扫/输房间号 放在「我的」次要区 不抢首页主路径
    @State private var showJoinDining: Bool = false
    @State private var profileBackgroundItem: PhotosPickerItem?
    @State private var profileBackgroundData: Data?
    @State private var showCoverPhotosPicker: Bool = false
    @State private var showLaunchIntroSettings: Bool = false
    @State private var showNotificationCenter: Bool = false
    @State private var showPasswordSheet: Bool = false
    @StateObject private var notificationManager = NotificationManager.shared

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        profileHero
                        VStack(alignment: .leading, spacing: AppSpacing.lg) {
                            if let stats {
                                StatsCard(stats: stats)
                            }
                            toolsCard
                            householdCard
                            actionsCard
                            Color.clear.frame(height: 96)
                        }
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.top, 24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            Color.appBackground,
                            in: UnevenRoundedRectangle(
                                topLeadingRadius: 28,
                                bottomLeadingRadius: 0,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: 28,
                                style: .continuous
                            )
                        )
                        .padding(.top, -24)
                        .zIndex(1)
                    }
                }
                .coordinateSpace(name: "profileScroll")
                .ignoresSafeArea(edges: .top)
                .background(Color.appBackground.ignoresSafeArea())
                .scrollIndicators(.hidden)

                if !appState.isProfileHeroVisible {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .overlay(Color.appBackground.opacity(0.76))
                        .overlay(alignment: .bottom) {
                            Divider().overlay(Color.dividerLine.opacity(0.55))
                        }
                        .frame(height: 58)
                        .ignoresSafeArea(edges: .top)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.18), value: appState.isProfileHeroVisible)
            .onAppear {
                appState.isProfileHeroVisible = true
            }
            .task {
                profileBackgroundData = ProfileHeaderImageStore.load()
                await appState.refreshHousehold()
                await loadStats()
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showCategoryManagement) {
                CategoryManagementView()
                    .preferredColorScheme(.light)
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileSheet()
                    .environmentObject(appState)
                    .preferredColorScheme(.light)
            }
            .sheet(isPresented: $showInvite) {
                if let h = appState.household {
                    // 与列表展示同一码：有临时邀请码则餐券/QR/分享都用它
                    InviteTicketView(
                        household: h,
                        inviterName: appState.currentUser?.nickname ?? "我",
                        displayCode: inviteCode
                    )
                    .preferredColorScheme(.light)
                }
            }
            .sheet(isPresented: $showJoinDining) {
                DiningJoinView()
                    .environmentObject(appState)
                    .preferredColorScheme(.light)
            }
            .fullScreenCover(isPresented: $showLaunchIntroSettings) {
                LaunchCanvasStudioView()
                    .environmentObject(appState)
            }
            .sheet(isPresented: $showNotificationCenter) {
                NotificationCenterSheet()
                    .environmentObject(appState)
                    .preferredColorScheme(.light)
            }
            .sheet(isPresented: $showPasswordSheet) {
                AccountPasswordSheet { message in
                    tipMessage = message
                }
                    .environmentObject(appState)
                    .preferredColorScheme(.light)
            }
            .photosPicker(isPresented: $showCoverPhotosPicker, selection: $profileBackgroundItem, matching: .images)
            .toast($errorMessage)
            .tipToast($tipMessage)
        }
    }

    private var toolsCard: some View {
        SectionCard {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "square.grid.2x2")
                    .foregroundStyle(Color.brandGreen)
                Text("常用工具")
                    .font(AppFont.headline(16))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
            }
            Button {
                showNotificationCenter = true
            } label: {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "bell.badge")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.actionInk)
                        .frame(width: 34, height: 34)
                        .background(Color.appBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.dividerLine.opacity(0.7), lineWidth: 0.7)
                        }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("消息动态与提醒")
                            .font(AppFont.body(15))
                            .foregroundStyle(Color.inkPrimary)
                        Text(notificationToolSubtitle)
                            .font(AppFont.caption(11))
                            .foregroundStyle(Color.inkMuted)
                    }
                    Spacer()
                    if appState.unreadNotificationCount > 0 {
                        Text("\(min(appState.unreadNotificationCount, 99))")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color(red: 0.90, green: 0.30, blue: 0.25), in: Capsule())
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.inkMuted)
                }
                .padding(.vertical, AppSpacing.sm)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Divider()
                .padding(.leading, 48)
            Button {
                showLaunchIntroSettings = true
            } label: {
                navRow(title: "定制开屏动画", subtitle: "自由画布排版、贴纸、涂鸦、滤镜与动效", icon: "sparkles.rectangle.stack")
            }
            .buttonStyle(.plain)
            Divider()
                .padding(.leading, 48)
            Button {
                showCategoryManagement = true
            } label: {
                navRow(title: "管理菜谱分类", subtitle: "新建、改名、删除", icon: "tag")
            }
            .buttonStyle(.plain)
            Divider()
                .padding(.leading, 48)
            // 聚会弱入口：进房(房间号)≠进家(餐券)；客人点菜不加入 household
            Button {
                showJoinDining = true
            } label: {
                navRow(title: "去朋友那儿点菜", subtitle: "扫码或输入房间号，临时一起吃饭", icon: "qrcode.viewfinder")
            }
            .buttonStyle(.plain)
            Divider()
                .padding(.leading, 48)
            Button {
                showPasswordSheet = true
            } label: {
                navRow(title: "账号与密码", subtitle: passwordToolSubtitle, icon: "key.fill")
            }
            .buttonStyle(.plain)
        }
    }

    private var passwordToolSubtitle: String {
        if appState.currentUser?.hasPassword == true {
            return "已设密码 · 可凭「\(appState.currentUser?.displayName ?? "")」跨设备登录"
        }
        return "设置登录密码，换手机时用昵称和密码找回"
    }

    private func navRow(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.actionInk)
                .frame(width: 34, height: 34)
                .background(Color.appBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.dividerLine.opacity(0.7), lineWidth: 0.7)
                }
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
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.inkMuted)
        }
        .padding(.vertical, AppSpacing.sm)
        .contentShape(Rectangle())
    }

    private var profileHero: some View {
        let memberCount = appState.household?.members?.count ?? 0
        return ZStack(alignment: .bottomLeading) {
            GeometryReader { proxy in
                let minY = proxy.frame(in: .named("profileScroll")).minY
                let stretch = max(0, minY)
                let heroVisible = minY > -195

                ZStack(alignment: .top) {
                    Group {
                        if let data = profileBackgroundData, let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image("ProfileHeroCover")
                                .resizable()
                                .scaledToFill()
                        }
                    }
                    .frame(width: proxy.size.width, height: profileHeroHeight + stretch)
                    .clipped()

                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [Color.black.opacity(0.34), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 112)
                        Spacer(minLength: 0)
                        LinearGradient(
                            colors: [.clear, Color.black.opacity(0.26), Color.black.opacity(0.72)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 175)
                    }
                    .frame(width: proxy.size.width, height: profileHeroHeight + stretch)
                    .allowsHitTesting(false)
                }
                .offset(y: -stretch)
                .onChange(of: heroVisible) { _, visible in
                    if appState.isProfileHeroVisible != visible {
                        appState.isProfileHeroVisible = visible
                    }
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Button {
                        Haptics.light()
                        showNotificationCenter = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: appState.unreadNotificationCount > 0 ? "bell.badge.fill" : "bell")
                                .font(.system(size: 13.5, weight: .semibold))
                            if appState.unreadNotificationCount > 0 {
                                Text("\(min(appState.unreadNotificationCount, 99))")
                                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, appState.unreadNotificationCount > 0 ? 11 : 0)
                        .frame(minWidth: 36)
                        .frame(height: 36)
                        .background(Color.black.opacity(0.32), in: Capsule())
                        .overlay {
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.36), lineWidth: 0.9)
                        }
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityLabel("消息动态与提醒")

                    Spacer()
                    if profileBackgroundData != nil {
                        Menu {
                            Button {
                                showCoverPhotosPicker = true
                            } label: {
                                Label("从相册换封面", systemImage: "photo")
                            }
                            Button {
                                ProfileHeaderImageStore.clear()
                                profileBackgroundData = nil
                                Haptics.light()
                            } label: {
                                Label("恢复默认封面", systemImage: "arrow.counterclockwise")
                            }
                        } label: {
                            coverPillLabel
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                        .accessibilityLabel("更换个人封面")
                    } else {
                        Button {
                            showCoverPhotosPicker = true
                        } label: {
                            coverPillLabel
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                        .accessibilityLabel("更换个人封面")
                    }

                    Button { showEditProfile = true } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.black.opacity(0.32), in: Circle())
                            .overlay {
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.36), lineWidth: 0.9)
                            }
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
                    .accessibilityLabel("编辑资料")
                }
                .padding(.top, 58)
                .padding(.horizontal, 18)

                Spacer(minLength: 0)

                HStack(spacing: 14) {
                    AvatarView(user: appState.currentUser, size: 70, ring: true)
                        .shadow(color: Color.black.opacity(0.28), radius: 10, y: 4)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(appState.currentUser?.displayName ?? "我")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: Color.black.opacity(0.28), radius: 6, y: 2)
                        HStack(spacing: 8) {
                            Text(householdSubtitle)
                                .font(AppFont.body(13.5))
                                .foregroundStyle(.white.opacity(0.90))
                                .lineLimit(1)
                            if memberCount > 0 {
                                Text("\(memberCount) 位家人")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.white.opacity(0.20), in: Capsule())
                                    .overlay {
                                        Capsule()
                                            .strokeBorder(Color.white.opacity(0.34), lineWidth: 0.8)
                                    }
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 44)
            }
        }
        .frame(height: profileHeroHeight)
        .task(id: profileBackgroundItem) {
            guard let item = profileBackgroundItem,
                  let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let compressed = ProfileHeaderImageStore.save(image: image) else { return }
            profileBackgroundData = compressed
        }
    }

    private var notificationToolSubtitle: String {
        let p = notificationManager.prefs
        let reminderCount = (p.lunchReminderEnabled ? 1 : 0) + (p.dinnerReminderEnabled ? 1 : 0)
        if appState.unreadNotificationCount > 0 {
            return "\(appState.unreadNotificationCount) 条未读动态 · 定点与推送提醒"
        }
        if reminderCount > 0 {
            return "已开启 \(reminderCount) 项饭点提醒 · 推送通知已就绪"
        }
        return "Ta 定菜、新评价提醒与每日饭点铃"
    }

    private var coverPillLabel: some View {
        HStack(spacing: 5) {
            Image(systemName: "photo")
                .font(.system(size: 13, weight: .semibold))
            Text("换封面")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Color.black.opacity(0.32), in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.white.opacity(0.36), lineWidth: 0.9)
        }
    }

    private var householdCard: some View {
        SectionCard {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "house.fill")
                    .foregroundStyle(Color.brandGreen)
                Text("我们的家")
                    .font(AppFont.headline(16))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                if let members = appState.household?.members, !members.isEmpty {
                    HStack(spacing: -8) {
                        ForEach(Array(members.prefix(4).enumerated()), id: \.offset) { idx, member in
                            AvatarView(user: member, size: 26)
                                .overlay(Circle().stroke(Color.cardBackground, lineWidth: 1.5))
                                .zIndex(Double(members.count - idx))
                        }
                    }
                }
            }
            if let h = appState.household {
                Text(h.name)
                    .font(AppFont.title(20))
                    .foregroundStyle(Color.inkPrimary)

                let displayInviteCode = inviteCode ?? h.inviteCode
                HStack(spacing: AppSpacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("邀请码")
                            .font(AppFont.caption(11))
                            .foregroundStyle(Color.inkMuted)
                        Text(displayInviteCode)
                            .font(AppFont.mono(15))
                            .foregroundStyle(Color.inkPrimary)
                    }
                    Spacer()
                    Button {
                        UIPasteboard.general.string = displayInviteCode
                        Haptics.light()
                        errorMessage = "邀请码已复制"
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.inkPrimary)
                            .frame(width: 34, height: 34)
                            .background(Color.cardBackground, in: Circle())
                            .overlay {
                                Circle().strokeBorder(Color.dividerLine.opacity(0.75), lineWidth: 0.7)
                            }
                    }
                    .buttonStyle(SoftPressStyle())
                    .accessibilityLabel("复制邀请码")

                    Button {
                        Task { await refreshInvite() }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.inkPrimary)
                            .frame(width: 34, height: 34)
                            .background(Color.cardBackground, in: Circle())
                            .overlay {
                                Circle().strokeBorder(Color.dividerLine.opacity(0.75), lineWidth: 0.7)
                            }
                    }
                    .buttonStyle(SoftPressStyle())
                    .accessibilityLabel("新建邀请码")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.dividerLine.opacity(0.7), lineWidth: 0.7)
                }

                PrimaryButton(title: "叫 Ta 进来", icon: "qrcode") {
                    showInvite = true
                }

                Button {
                    confirmLeaveHousehold = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "door.left.hand.open")
                        Text("退出这个家")
                    }
                    .font(AppFont.caption(12.5))
                    .foregroundStyle(Color.inkMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)
                }
            } else if appState.currentUser?.hasHousehold == true {
                // 有家但 info 没拉到：别写成「还没加入家」
                Text("家信息还没拉到")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.inkMuted)
                PrimaryButton(title: "点一下再试", icon: "arrow.triangle.2.circlepath") {
                    Task {
                        await appState.refreshHousehold()
                        if appState.householdLoadFailed {
                            errorMessage = "家信息还没拉到，点一下再试"
                        }
                    }
                }
            } else {
                Text("还没加入家").font(AppFont.caption()).foregroundStyle(Color.inkMuted)
            }
        }
        .confirmationDialog(leaveDialogTitle, isPresented: $confirmLeaveHousehold) {
            Button(isSoleHouseholdMember ? "退出并解散" : "退出", role: .destructive) {
                Task { await leaveHousehold() }
            }
            Button("再想想", role: .cancel) {}
        } message: {
            Text(leaveDialogMessage)
        }
    }

    private var householdSubtitle: String {
        if let name = appState.household?.name { return name }
        if appState.currentUser?.hasHousehold == true {
            return appState.householdLoadFailed ? "家信息还没拉到" : "正在加载家庭信息"
        }
        return "未加入家"
    }

    private var actionsCard: some View {
        Button {
            Task { await appState.didLogout() }
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("退出登录")
                    .font(AppFont.body(14))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(Color.errorInk)
            .padding(.horizontal, AppSpacing.lg)
            .frame(height: 48)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(Color.errorInk.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("退出登录")
    }

    private func refreshInvite() async {
        do {
            let invite = try await HouseholdService.shared.createInvite(.init(expiresIn: 86400 * 7, maxUses: 5))
            inviteCode = invite.code
            errorMessage = "已生成临时邀请码 7 天内可用 5 次"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // 仅自己时后端会软删这个家；菜单不一定立刻清空，但人回不去
    private var isSoleHouseholdMember: Bool {
        guard let members = appState.household?.members else { return true }
        return members.count <= 1
    }

    private var leaveDialogTitle: String {
        isSoleHouseholdMember ? "就你一个人了，还退吗？" : "退出当前的家？"
    }

    private var leaveDialogMessage: String {
        if isSoleHouseholdMember {
            return "就你一个人的话，这个家会收掉，你就退回「先有个家」。菜单不一定立刻没了，但你也进不去了。"
        }
        return "退了就看不到这个家的菜单和记录了，以后用邀请码还能再进来"
    }

    private func leaveHousehold() async {
        do {
            try await HouseholdService.shared.leave()
            appState.household = nil
            appState.householdLoadFailed = false
            if var u = appState.currentUser {
                u.householdId = nil
                appState.currentUser = u
            }
            let ok = await appState.refreshProfile()
            if !ok {
                errorMessage = "退了，资料还没跟上 过会儿再进一下就好"
            }
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

// 我们的小本本：总顿数 / 最近 30 天 / Top 5 常吃 / 吃饭场合分布
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
        let obsidian = Color(red: 0.067, green: 0.067, blue: 0.075)
        return HStack(spacing: 0) {
            statBox(value: "\(stats.totalMeals)", label: "累计餐次", accent: obsidian, divider: true)
            statBox(value: "\(stats.totalDishes)", label: "累计菜品", accent: obsidian, divider: true)
            statBox(value: "\(stats.recentMeals)", label: "近 30 天", accent: Color.inkPrimary, divider: false)
        }
    }

    private func statBox(value: String, label: String, accent: Color, divider: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(accent)
            Text(label)
                .font(AppFont.caption(11))
                .foregroundStyle(Color.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .overlay(alignment: .trailing) {
            if divider {
                Rectangle()
                    .fill(Color.dividerLine.opacity(0.8))
                    .frame(width: 1, height: 34)
            }
        }
    }

    private var topDishesView: some View {
        let maxCount = max(stats.topDishes.map(\.count).max() ?? 1, 1)
        let obsidian = Color(red: 0.067, green: 0.067, blue: 0.075)
        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("最爱吃的几道")
                .font(AppFont.caption(12))
                .foregroundStyle(Color.inkMuted)
            ForEach(Array(stats.topDishes.enumerated()), id: \.element.id) { idx, dish in
                let ratio = max(0.08, min(1.0, CGFloat(dish.count) / CGFloat(maxCount)))
                HStack(spacing: AppSpacing.md) {
                    Text("\(idx + 1)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(idx == 0 ? .white : Color.inkSecondary)
                        .frame(width: 22, height: 22)
                        .background(
                            idx == 0 ? obsidian : Color.appBackground,
                            in: Circle()
                        )
                    DishThumb(name: dish.name, image: dish.image)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(dish.name)
                            .font(AppFont.body(14))
                            .foregroundStyle(Color.inkPrimary)
                            .lineLimit(1)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.appBackground)
                                    .frame(height: 4)
                                Capsule()
                                    .fill(idx == 0 ? obsidian : Color.inkSecondary.opacity(0.45))
                                    .frame(width: geo.size.width * ratio, height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                    Text("× \(dish.count)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
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
                    let iconName = MealScene(rawValue: item.scene) == .household ? "house.fill" : "person.3.fill"
                    HStack(spacing: 5) {
                        Image(systemName: iconName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.inkSecondary)
                        Text(item.sceneLabel)
                            .foregroundStyle(Color.inkPrimary)
                        Text("× \(item.count)")
                            .monospacedDigit()
                            .foregroundStyle(Color.inkMuted)
                    }
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, 6)
                    .background(Color.appBackground, in: Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.dividerLine.opacity(0.75), lineWidth: 0.7)
                    }
                }
            }
        }
    }
}

private enum ProfileHeaderImageStore {
    private static var url: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("profile-header.jpg")
    }

    static func load() -> Data? {
        try? Data(contentsOf: url)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: url)
    }

    static func save(image: UIImage) -> Data? {
        guard let data = image.jpegData(compressionQuality: 0.78) else { return nil }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
            return data
        } catch {
            return nil
        }
    }
}

// MARK: - 程序外消息动态与提醒设置中心

private struct NotificationCenterSheet: View {
    enum SectionTab: String, CaseIterable, Identifiable {
        case feed = "动态消息"
        case settings = "提醒设置"
        var id: String { rawValue }
    }

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var manager = NotificationManager.shared

    @State private var tab: SectionTab = .feed
    @State private var isSendingTest = false
    @State private var tipMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    ForEach(SectionTab.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.md)

                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        if tab == .feed {
                            feedContent
                        } else {
                            settingsContent
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.xxl)
                }
                .refreshable {
                    await manager.refreshAuthorizationStatus()
                    await manager.syncServerNotifications(allowLocalBanner: false)
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("消息动态与提醒")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if tab == .feed && manager.unreadCount > 0 {
                        Button("全部已读") {
                            Task {
                                await manager.markAllRead()
                                Haptics.light()
                            }
                        }
                        .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    }
                }
            }
            .task {
                await manager.refreshAuthorizationStatus()
                await manager.syncServerNotifications(allowLocalBanner: false)
            }
            .tipToast($tipMessage)
        }
    }

    @ViewBuilder
    private var feedContent: some View {
        SectionCard {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("试试程序外通知")
                        .font(AppFont.headline(15))
                        .foregroundStyle(Color.inkPrimary)
                    Text("触发一条真实系统横幅，点通知可直接跳进画布或历史")
                        .font(AppFont.caption(11.5))
                        .foregroundStyle(Color.inkMuted)
                }
                Spacer(minLength: 8)
                Button {
                    Task { await sendTestBanner() }
                } label: {
                    HStack(spacing: 5) {
                        if isSendingTest {
                            ProgressView().tint(.white).controlSize(.mini)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        Text(isSendingTest ? "发送中" : "演示提醒")
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(Color.actionInk, in: Capsule())
                }
                .buttonStyle(SoftPressStyle())
                .disabled(isSendingTest)
            }
        }

        if manager.events.isEmpty {
            SectionCard {
                VStack(spacing: 10) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(Color.inkMuted)
                    Text("还没有收到新动态")
                        .font(AppFont.body(15))
                        .foregroundStyle(Color.inkPrimary)
                    Text("Ta 在画布加菜、定下今天吃什么或写完评价后，这里与系统横幅都会第一时间提醒你")
                        .font(AppFont.caption(12))
                        .foregroundStyle(Color.inkMuted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xl)
            }
        } else {
            VStack(spacing: AppSpacing.sm) {
                ForEach(manager.events) { event in
                    Button {
                        handleEventTap(event)
                    } label: {
                        eventRow(event)
                    }
                    .buttonStyle(SoftPressStyle())
                }
            }
        }
    }

    private func eventRow(_ event: AppNotificationEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(event.isRead ? Color.appBackground : Color.actionInk)
                    .frame(width: 38, height: 38)
                Image(systemName: event.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(event.isRead ? Color.inkSecondary : .white)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(event.title)
                        .font(AppFont.headline(14.5))
                        .foregroundStyle(Color.inkPrimary)
                        .lineLimit(1)
                    if !event.isRead {
                        Circle()
                            .fill(Color(red: 0.90, green: 0.30, blue: 0.25))
                            .frame(width: 7, height: 7)
                    }
                    Spacer(minLength: 4)
                    if let created = event.createdAt {
                        Text(RelativeDateFormatter.format(created))
                            .font(AppFont.caption(11))
                            .foregroundStyle(Color.inkMuted)
                    }
                }
                Text(event.body)
                    .font(AppFont.body(13))
                    .foregroundStyle(Color.inkSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.inkMuted.opacity(0.65))
                .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    event.isRead ? Color.dividerLine.opacity(0.6) : Color.actionInk.opacity(0.20),
                    lineWidth: event.isRead ? 0.7 : 1.0
                )
        }
    }

    @ViewBuilder
    private var settingsContent: some View {
        SectionCard {
            HStack(spacing: 12) {
                Image(systemName: permissionIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(permissionGranted ? Color.brandGreen : Color.inkSecondary)
                    .frame(width: 38, height: 38)
                    .background(Color.appBackground, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("系统通知权限")
                        .font(AppFont.headline(15))
                        .foregroundStyle(Color.inkPrimary)
                    Text(permissionSubtitle)
                        .font(AppFont.caption(11.5))
                        .foregroundStyle(Color.inkMuted)
                }
                Spacer(minLength: 8)
                if manager.authorizationStatus == .notDetermined {
                    Button("开启") {
                        Task {
                            _ = await manager.requestAuthorization()
                        }
                    }
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .background(Color.actionInk, in: Capsule())
                    .buttonStyle(SoftPressStyle())
                } else if manager.authorizationStatus == .denied {
                    Button("去设置") {
                        manager.openSystemNotificationSettings()
                    }
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.inkPrimary)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(Color.appBackground, in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(Color.dividerLine, lineWidth: 0.8)
                    }
                    .buttonStyle(SoftPressStyle())
                } else {
                    Text("已开启")
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.brandGreen)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.appBackground, in: Capsule())
                }
            }
        }

        SectionCard {
            Text("和 Ta 的吃饭动态")
                .font(AppFont.headline(15))
                .foregroundStyle(Color.inkPrimary)

            Toggle(isOn: prefBinding(\.notifyPartnerMealEvents)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("加菜与定下这一顿")
                        .font(AppFont.body(14.5))
                        .foregroundStyle(Color.inkPrimary)
                    Text("Ta 加了想吃的菜、定好了菜单或标记吃完时提醒")
                        .font(AppFont.caption(11))
                        .foregroundStyle(Color.inkMuted)
                }
            }
            .tint(Color.actionInk)

            Divider()

            Toggle(isOn: prefBinding(\.notifyReviews)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("餐后评论与新照片")
                        .font(AppFont.body(14.5))
                        .foregroundStyle(Color.inkPrimary)
                    Text("对方留下一顿的星级评分、评语或晒图时提醒")
                        .font(AppFont.caption(11))
                        .foregroundStyle(Color.inkMuted)
                }
            }
            .tint(Color.actionInk)

            Divider()

            Toggle(isOn: prefBinding(\.notifyDining)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("聚餐房间与家里新成员")
                        .font(AppFont.body(14.5))
                        .foregroundStyle(Color.inkPrimary)
                    Text("朋友扫房间码进房点菜，或 Ta 加入家时提醒")
                        .font(AppFont.caption(11))
                        .foregroundStyle(Color.inkMuted)
                }
            }
            .tint(Color.actionInk)
        }

        SectionCard {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("每日饭点提醒")
                        .font(AppFont.headline(15))
                        .foregroundStyle(Color.inkPrimary)
                    Text("每天固定时间轻轻问一句“今天吃什么”，点通知直达画布")
                        .font(AppFont.caption(11.5))
                        .foregroundStyle(Color.inkMuted)
                }

                Toggle(isOn: mealReminderToggle(\.lunchReminderEnabled)) {
                    Text("午饭前提醒")
                        .font(AppFont.body(14.5))
                        .foregroundStyle(Color.inkPrimary)
                }
                .tint(Color.actionInk)

                if manager.prefs.lunchReminderEnabled {
                    HStack {
                        Text("提醒时间")
                            .font(AppFont.caption(12.5))
                            .foregroundStyle(Color.inkSecondary)
                        Spacer()
                        DatePicker(
                            "",
                            selection: timeBinding(hourKey: \.lunchHour, minuteKey: \.lunchMinute),
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                    }
                    .padding(.vertical, 2)
                }

                Divider()

                Toggle(isOn: mealReminderToggle(\.dinnerReminderEnabled)) {
                    Text("晚饭前提醒")
                        .font(AppFont.body(14.5))
                        .foregroundStyle(Color.inkPrimary)
                }
                .tint(Color.actionInk)

                if manager.prefs.dinnerReminderEnabled {
                    HStack {
                        Text("提醒时间")
                            .font(AppFont.caption(12.5))
                            .foregroundStyle(Color.inkSecondary)
                        Spacer()
                        DatePicker(
                            "",
                            selection: timeBinding(hourKey: \.dinnerHour, minuteKey: \.dinnerMinute),
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var permissionGranted: Bool {
        manager.authorizationStatus == .authorized || manager.authorizationStatus == .provisional
    }

    private var permissionIcon: String {
        permissionGranted ? "checkmark.circle.fill" : "bell.badge"
    }

    private var permissionSubtitle: String {
        switch manager.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            if let tok = manager.apnsToken, !tok.isEmpty {
                return "已开启系统推送与本地通知（APNs 设备已注册）"
            }
            return "已开启系统横幅提醒；后台由本地与动态同步通道送达"
        case .denied:
            return "当前已关闭系统通知，开启后能在锁屏/桌面收到提醒"
        default:
            return "还未开启通知权限，开启后不错过 Ta 选好的这顿饭"
        }
    }

    private func prefBinding(_ keyPath: WritableKeyPath<NotificationPreferences, Bool>) -> Binding<Bool> {
        Binding(
            get: { manager.prefs[keyPath: keyPath] },
            set: { next in
                manager.updatePreferences { $0[keyPath: keyPath] = next }
            }
        )
    }

    private func mealReminderToggle(_ keyPath: WritableKeyPath<NotificationPreferences, Bool>) -> Binding<Bool> {
        Binding(
            get: { manager.prefs[keyPath: keyPath] },
            set: { next in
                if next && manager.authorizationStatus == .notDetermined {
                    Task {
                        _ = await manager.requestAuthorization()
                    }
                }
                manager.updatePreferences { $0[keyPath: keyPath] = next }
            }
        )
    }

    private func timeBinding(
        hourKey: WritableKeyPath<NotificationPreferences, Int>,
        minuteKey: WritableKeyPath<NotificationPreferences, Int>
    ) -> Binding<Date> {
        Binding(
            get: {
                var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                comps.hour = manager.prefs[keyPath: hourKey]
                comps.minute = manager.prefs[keyPath: minuteKey]
                return Calendar.current.date(from: comps) ?? Date()
            },
            set: { date in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                manager.updatePreferences {
                    $0[keyPath: hourKey] = comps.hour ?? 12
                    $0[keyPath: minuteKey] = comps.minute ?? 0
                }
            }
        )
    }

    private func sendTestBanner() async {
        isSendingTest = true
        defer { isSendingTest = false }
        do {
            _ = try await manager.sendTestAndDeliverBanner()
            Haptics.success()
            tipMessage = "已发出演示提醒，点开通知可直达页面"
        } catch {
            tipMessage = error.localizedDescription
        }
    }

    private func handleEventTap(_ event: AppNotificationEvent) {
        Task {
            await manager.markRead(event: event)
        }
        dismiss()
        if let link = event.resolvedDeepLink {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                appState.handleDeepLink(link)
            }
        }
    }
}

private struct AccountPasswordSheet: View {
    let onSaved: (String) -> Void

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private enum PasswordFocus: Hashable {
        case current, new, confirm
    }

    @State private var oldPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var showPasswords: Bool = false
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: PasswordFocus?

    private var hasPassword: Bool {
        appState.currentUser?.hasPassword == true
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    SectionCard {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "person.badge.key.fill")
                                .foregroundStyle(Color.brandGreen)
                            Text("当前登录昵称：\(appState.currentUser?.displayName ?? "我")")
                                .font(AppFont.headline(15))
                                .foregroundStyle(Color.inkPrimary)
                            Spacer()
                        }
                        Text(hasPassword ? "修改密码后，仍可用这个昵称搭配新密码在其他手机登录。" : "设置至少 6 位密码后，换手机或重装时可通过「昵称 + 密码」找回这一个家。")
                            .font(AppFont.caption(12.5))
                            .foregroundStyle(Color.inkMuted)
                    }

                    SectionCard {
                        HStack {
                            Spacer()
                            Button {
                                showPasswords.toggle()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: showPasswords ? "eye.slash" : "eye")
                                    Text(showPasswords ? "隐藏密码" : "显示密码")
                                }
                                .font(AppFont.caption(12))
                                .foregroundStyle(Color.inkSecondary)
                            }
                            .buttonStyle(.plain)
                        }

                        if hasPassword {
                            FieldLabel("当前密码", required: true)
                            passwordField("输入正在使用的密码", text: $oldPassword, field: .current, submitLabel: .next) {
                                focusedField = .new
                            }
                        }

                        FieldLabel(hasPassword ? "新密码" : "登录密码", required: true)
                        passwordField("至少 6 位字母、数字或符号", text: $newPassword, field: .new, submitLabel: .next) {
                            focusedField = .confirm
                        }

                        FieldLabel("确认密码", required: true)
                        passwordField("再输一遍确认", text: $confirmPassword, field: .confirm, submitLabel: .done) {
                            Task { await save() }
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(AppFont.caption())
                            .foregroundStyle(Color.errorInk)
                    }

                    Color.clear.frame(height: 40)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.appBackground.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: isSaving ? "保存中" : (hasPassword ? "更新密码" : "保存密码"), isLoading: isSaving) {
                    Task { await save() }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.sm)
                .background(Color.appBackground)
                .overlay(alignment: .top) {
                    Divider().overlay(Color.dividerLine.opacity(0.6))
                }
            }
            .navigationTitle(hasPassword ? "修改密码" : "设置登录密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("取消").foregroundStyle(Color.inkSecondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func passwordField(
        _ placeholder: String,
        text: Binding<String>,
        field: PasswordFocus,
        submitLabel: SubmitLabel,
        onSubmit: @escaping () -> Void
    ) -> some View {
        Group {
            if showPasswords {
                TextField(placeholder, text: text)
            } else {
                SecureField(placeholder, text: text)
            }
        }
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .focused($focusedField, equals: field)
        .submitLabel(submitLabel)
        .onSubmit(onSubmit)
        .padding(AppSpacing.md)
        .background(Color.appBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .strokeBorder(Color.dividerLine.opacity(0.75), lineWidth: 0.7)
        }
    }

    private func save() async {
        errorMessage = nil
        focusedField = nil
        if hasPassword && oldPassword.isEmpty {
            errorMessage = "请先填写当前密码"
            return
        }
        if newPassword.count < 6 {
            errorMessage = "密码至少需要 6 位"
            return
        }
        if newPassword.utf8.count > 72 {
            errorMessage = "密码太长了，请控制在 72 字节以内"
            return
        }
        if newPassword != confirmPassword {
            errorMessage = "两次输入的新密码不一致"
            return
        }
        let wasUpdating = hasPassword
        isSaving = true
        defer { isSaving = false }
        do {
            let updated = try await AuthService.shared.setPassword(
                oldPassword: wasUpdating ? oldPassword : nil,
                newPassword: newPassword
            )
            appState.currentUser = updated
            Haptics.success()
            onSaved(wasUpdating ? "登录密码已更新" : "登录密码已保存")
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
