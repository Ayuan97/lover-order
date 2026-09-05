import SwiftUI
import UIKit
import PhotosUI

// "我的"页：资料、常用工具、家庭设置和退出。
struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    // 封面要承担页面第一视觉，不能只像一条横幅。
    private let profileHeroHeight: CGFloat = 300

    @State private var inviteCode: String?

    @State private var showCategoryManagement: Bool = false
    @State private var confirmLeaveHousehold: Bool = false
    @State private var showEditProfile: Bool = false
    @State private var stats: HouseholdStats?
    @State private var errorMessage: String?
    @State private var showInvite: Bool = false
    // 客人扫/输房间号 放在「我的」次要区 不抢首页主路径
    @State private var showJoinDining: Bool = false
    @State private var profileBackgroundItem: PhotosPickerItem?
    @State private var profileBackgroundData: Data?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    profileHero
                    if let stats {
                        StatsCard(stats: stats)
                    }
                    toolsCard
                    householdCard
                    actionsCard
                    Color.clear.frame(height: 40)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, 0)
            }
            .background(Color.appBackground.ignoresSafeArea())
            // 封面是页面的沉浸式背景，允许它延伸到刘海屏后面。
            .ignoresSafeArea(edges: .top)
            .scrollIndicators(.hidden)
            .task {
                profileBackgroundData = ProfileHeaderImageStore.load()
                await appState.refreshHousehold()
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
                    // 与列表展示同一码：有临时邀请码则餐券/QR/分享都用它
                    InviteTicketView(
                        household: h,
                        inviterName: appState.currentUser?.nickname ?? "我",
                        displayCode: inviteCode
                    )
                }
            }
            .sheet(isPresented: $showJoinDining) {
                DiningJoinView()
                    .environmentObject(appState)
            }
            .toast($errorMessage)
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
                showCategoryManagement = true
            } label: {
                navRow(title: "管理菜谱分类", subtitle: "新建、改名、删除", icon: "square.grid.2x2")
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
        }
    }

    private func navRow(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.actionInk)
                .frame(width: 32, height: 32)
                .background(icon == "qrcode.viewfinder" ? Color.dopaminePink.opacity(0.28) : Color.dopamineYellow.opacity(0.42))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
        ZStack(alignment: .bottomLeading) {
            Group {
                if let data = profileBackgroundData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [Color.dopamineYellow.opacity(0.72), Color.dopaminePink.opacity(0.36), Color.appBackground],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 54, weight: .light))
                            .foregroundStyle(.white.opacity(0.62))
                            .rotationEffect(.degrees(12))
                            .padding(28)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: profileHeroHeight)
            .clipped()

            LinearGradient(
                colors: [.black.opacity(0.04), .black.opacity(0.62)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(alignment: .top) {
                    Spacer()
                    HStack(spacing: 8) {
                        PhotosPicker(selection: $profileBackgroundItem, matching: .images) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 34, height: 34)
                        }
                        Button {
                            showEditProfile = true
                        } label: {
                            Text("编辑")
                                .font(AppFont.caption(13))
                                .padding(.horizontal, 12)
                                .frame(height: 34)
                        }
                    }
                    .foregroundStyle(Color.actionInk)
                    .background(.white.opacity(0.90), in: Capsule())
                }

                Spacer(minLength: 0)

                HStack(spacing: AppSpacing.md) {
                    AvatarView(user: appState.currentUser, size: 76, ring: true)
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(0.78), lineWidth: 2)
                        }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(appState.currentUser?.displayName ?? "美食家")
                            .font(AppFont.title(24))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
                        HStack(spacing: 5) {
                            Image(systemName: "house.fill")
                                .font(.system(size: 10, weight: .semibold))
                            Text(householdSubtitle)
                                .font(AppFont.caption(12))
                        }
                        .foregroundStyle(.white.opacity(0.9))
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, 54)
            .padding(.bottom, AppSpacing.lg)
        }
        .frame(height: profileHeroHeight)
        // 沉浸式封面是页面背景，不做卡片式底部收口或阴影。
        .padding(.horizontal, -AppSpacing.lg)
        .task(id: profileBackgroundItem) {
            guard let item = profileBackgroundItem,
                  let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let compressed = ProfileHeaderImageStore.save(image: image) else { return }
            profileBackgroundData = compressed
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
                PrimaryButton(title: "叫 Ta 进来", icon: "qrcode") {
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
        HStack(spacing: 0) {
            statBox(value: "\(stats.totalMeals)", label: "累计餐次", accent: Color.dopaminePink, divider: true)
            statBox(value: "\(stats.totalDishes)", label: "累计菜品", accent: Color.brandGreen, divider: true)
            statBox(value: "\(stats.recentMeals)", label: "近 30 天", accent: Color.accentWarm, divider: false)
        }
    }

    private func statBox(value: String, label: String, accent: Color, divider: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(AppFont.title(22))
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

private enum ProfileHeaderImageStore {
    private static var url: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("profile-header.jpg")
    }

    static func load() -> Data? {
        try? Data(contentsOf: url)
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
