import SwiftUI
import UIKit

// host 端聚餐：开房后出示家宴入场券（房间号 + 二维码）；展示到场朋友与已点菜品
struct DiningHostView: View {
    let mealId: UInt
    // 本次 sheet 内是否真关过房 供首页 onDismiss 决定要不要催「可以定下来了」
    @Binding var didCloseRoom: Bool
    var householdName: String? = nil
    var hostName: String? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var meal: MealSession?
    @State private var isLoading = true
    @State private var isActing = false
    @State private var errorMessage: String?
    @State private var tipMessage: String?
    @State private var showCloseConfirm = false
    @State private var shareRoomItem: DiningRoomShareItem?

    init(
        mealId: UInt,
        didCloseRoom: Binding<Bool> = .constant(false),
        householdName: String? = nil,
        hostName: String? = nil
    ) {
        self.mealId = mealId
        self._didCloseRoom = didCloseRoom
        self.householdName = householdName
        self.hostName = hostName
    }

    private var roomCode: String? {
        guard let c = meal?.roomCode, !c.isEmpty else { return nil }
        return c
    }

    // 与后端 roomAlive 一致：有码且未过期才算进行中
    private var isRoomAlive: Bool {
        guard let code = roomCode,
              let exp = meal?.roomExpiresAt else { return false }
        return !code.isEmpty && exp > Date()
    }

    // 码还在但已过期 → 提示重新开房，避免继续展示失效二维码
    private var isRoomExpired: Bool {
        guard let code = roomCode,
              let exp = meal?.roomExpiresAt else { return false }
        return !code.isEmpty && exp <= Date()
    }

    private var dishes: [MealDish] { meal?.dishes ?? [] }

    private var resolvedHostName: String {
        let raw = (hostName ?? meal?.creator?.displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? "主人" : raw
    }

    private var usesDarkHeroClose: Bool {
        !isRoomAlive && !isLoading && !isRoomExpired
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            if isRoomAlive, let code = roomCode {
                roomView(code)
            } else if isLoading {
                ProgressView().tint(Color.brandGreen)
            } else if isRoomExpired {
                expiredView
            } else {
                startView
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(usesDarkHeroClose ? .white : Color.inkSecondary)
                    .frame(width: 36, height: 36)
                    .background(
                        usesDarkHeroClose ? Color.black.opacity(0.42) : Color.cardBackground,
                        in: Circle()
                    )
                    .overlay {
                        Circle()
                            .strokeBorder(
                                usesDarkHeroClose ? Color.white.opacity(0.28) : Color.dividerLine.opacity(0.75),
                                lineWidth: 0.7
                            )
                    }
            }
            .buttonStyle(SoftPressStyle())
            .padding(.top, AppSpacing.lg)
            .padding(.trailing, AppSpacing.lg)
            .accessibilityLabel("关闭")
        }
        .task {
            await load()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                await silentReload()
            }
        }
        .toast($errorMessage)
        .tipToast($tipMessage)
        .confirmationDialog("关掉房间？", isPresented: $showCloseConfirm) {
            Button("收摊关房", role: .destructive) {
                Task { await close() }
            }
            Button("再等等", role: .cancel) {}
        } message: {
            Text("朋友就不能继续加菜了，桌上已经点的都会留着")
        }
        .sheet(item: $shareRoomItem) { item in
            ShareSheet(items: item.items)
        }
    }

    // MARK: - 未开房引导态

    private var startView: some View {
        ScrollView {
            VStack(spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    GeometryReader { proxy in
                        Image("CanvasWarmCafe")
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                    }
                    LinearGradient(
                        colors: [Color.black.opacity(0.26), Color.black.opacity(0.72)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    VStack(alignment: .leading, spacing: 8) {
                        Image("StickerEmoji_food_cheers")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 58, height: 58)
                            .shadow(color: Color.black.opacity(0.24), radius: 10, y: 4)
                        Text("邀朋友一起来点菜")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("发一张家宴入场券，扫码或输码就能一起挑菜")
                            .font(.system(size: 13.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.88))
                    }
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.bottom, 38)
                }
                .frame(height: 230)

                VStack(spacing: AppSpacing.lg) {
                    SectionCard {
                        introRow(
                            icon: "qrcode",
                            title: "扫码或分享票图进房",
                            subtitle: "生成 6 位房间号与入场券图片，面对面扫或发给朋友"
                        )
                        Divider().background(Color.dividerLine.opacity(0.6))
                        introRow(
                            icon: "fork.knife",
                            title: "共用家里菜谱，也能自由报菜名",
                            subtitle: "朋友只参与这一顿点菜，不会加入或改动你们的家"
                        )
                        Divider().background(Color.dividerLine.opacity(0.6))
                        introRow(
                            icon: "clock",
                            title: "房间 6 小时有效，随时可收摊",
                            subtitle: "点得差不多随时关房，已选的菜都会自动落上桌"
                        )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                            .strokeBorder(Color.dividerLine.opacity(0.65), lineWidth: 0.7)
                    }
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.top, 24)
                .padding(.bottom, AppSpacing.xxl)
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
            }
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider().overlay(Color.dividerLine.opacity(0.6))
                PrimaryButton(title: "开一间点菜房", icon: "qrcode", isLoading: isActing) {
                    Task { await open() }
                }
                .disabled(isActing)
                .padding(.horizontal, AppSpacing.xl)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.lg)
            }
            .background(Color.appBackground)
        }
    }

    private func introRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.actionInk)
                .frame(width: 34, height: 34)
                .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.dividerLine.opacity(0.75), lineWidth: 0.7)
                }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppFont.headline(15))
                    .foregroundStyle(Color.inkPrimary)
                Text(subtitle)
                    .font(AppFont.caption(12))
                    .foregroundStyle(Color.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - 已过期态

    private var expiredView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            Image("StickerEmoji_food_tea")
                .resizable()
                .scaledToFit()
                .frame(width: 82, height: 82)
                .shadow(color: Color.black.opacity(0.10), radius: 10, y: 4)
            Text("房间过期了")
                .font(AppFont.title(24))
                .foregroundStyle(Color.inkPrimary)
            Text("再开一间，让大家重新扫码或输房间号就行")
                .multilineTextAlignment(.center)
                .font(AppFont.body())
                .foregroundStyle(Color.inkMuted)
            if !dishes.isEmpty {
                Text("刚才点的 \(dishes.count) 道菜都还在桌上")
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.inkSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.cardBackground, in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(Color.dividerLine.opacity(0.7), lineWidth: 0.7)
                    }
            }
            Spacer()
            PrimaryButton(title: "再开一间", icon: "qrcode", isLoading: isActing) {
                Task { await open() }
            }
            .disabled(isActing)
            .padding(.bottom, AppSpacing.xxl)
        }
        .padding(.horizontal, AppSpacing.xl)
    }

    // MARK: - 开房中（家宴入场券）

    private func roomView(_ code: String) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    VStack(spacing: 4) {
                        Text("聚餐点菜房")
                            .font(AppFont.title(24))
                            .foregroundStyle(Color.inkPrimary)
                        Text("亮给朋友扫码，或发一张入场券到群里")
                            .font(AppFont.body(13))
                            .foregroundStyle(Color.inkMuted)
                    }
                    .padding(.top, AppSpacing.xl)

                    DiningInvitationTicketView(
                        code: code,
                        householdName: householdName,
                        hostName: resolvedHostName,
                        expiresAt: meal?.roomExpiresAt,
                        notchColor: Color.appBackground
                    ) {
                        UIPasteboard.general.string = code
                        Haptics.light()
                        tipMessage = "房间号已复制，发给朋友吧"
                    }

                    roomStatusCard
                    dishesSection
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.bottom, AppSpacing.lg)
            }
            .scrollIndicators(.hidden)

            HStack(spacing: AppSpacing.md) {
                SecondaryButton(title: "收摊关房", icon: "lock") {
                    showCloseConfirm = true
                }
                .disabled(isActing)
                .opacity(isActing ? 0.55 : 1)

                PrimaryButton(title: "发邀请票", icon: "square.and.arrow.up") {
                    shareTicket(code: code)
                }
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.bottom, AppSpacing.lg)
            .padding(.top, AppSpacing.sm)
            .background(Color.appBackground)
            .overlay(alignment: .top) {
                Divider().overlay(Color.dividerLine.opacity(0.6))
            }
        }
    }

    private var roomStatusCard: some View {
        let people = meal?.participants ?? []
        let remaining = remainingTimeText(until: meal?.roomExpiresAt)
        let namesSummary = people.prefix(4).compactMap { $0.user?.displayName }.joined(separator: "、")
        return SectionCard(padding: 14, radius: AppRadius.lg) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(red: 0.24, green: 0.68, blue: 0.40))
                    .frame(width: 7, height: 7)
                Text("开放中")
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                if let remaining {
                    Label(remaining, systemImage: "clock")
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.inkMuted)
                }
            }

            Divider().background(Color.dividerLine.opacity(0.5))

            HStack(spacing: 10) {
                if people.isEmpty {
                    Image(systemName: "person.2")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.inkMuted)
                    Text("还没朋友进来，把入场券发给他们吧")
                        .font(AppFont.caption(12))
                        .foregroundStyle(Color.inkMuted)
                } else {
                    HStack(spacing: -8) {
                        ForEach(people.prefix(6)) { p in
                            AvatarView(user: p.user, size: 28, ring: true)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(people.count) 位朋友已到场")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.inkPrimary)
                        if !namesSummary.isEmpty {
                            Text(namesSummary + (people.count > 4 ? " 等" : ""))
                                .font(AppFont.caption(11.5))
                                .foregroundStyle(Color.inkMuted)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .strokeBorder(Color.dividerLine.opacity(0.65), lineWidth: 0.7)
        }
    }

    private var dishesSection: some View {
        SectionCard {
            HStack {
                Text("已经点了")
                    .font(AppFont.headline(15))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                Text("\(dishes.count) 道")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.inkSecondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Color.appBackground, in: Capsule())
            }
            if dishes.isEmpty {
                Text("桌上还空着，等朋友进来挑菜")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.inkMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
            } else {
                VStack(spacing: AppSpacing.sm) {
                    ForEach(Array(dishes.enumerated()), id: \.element.id) { idx, dish in
                        HStack(spacing: AppSpacing.md) {
                            DishThumb(name: dish.recipeName, image: dish.recipeImage, size: 46, radius: 12)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(dish.recipeName)
                                    .font(AppFont.body(15))
                                    .foregroundStyle(Color.inkPrimary)
                                    .lineLimit(1)
                                if let adderName = dish.adder?.displayName, !adderName.isEmpty {
                                    Text("\(adderName) 点的")
                                        .font(AppFont.caption(11.5))
                                        .foregroundStyle(Color.inkMuted)
                                }
                            }
                            Spacer()
                            if let adder = dish.adder {
                                AvatarView(user: adder, size: 24)
                            }
                        }
                        if idx < dishes.count - 1 {
                            Divider().background(Color.dividerLine.opacity(0.5))
                        }
                    }
                }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .strokeBorder(Color.dividerLine.opacity(0.65), lineWidth: 0.7)
        }
    }

    private func remainingTimeText(until date: Date?) -> String? {
        guard let date else { return nil }
        let seconds = Int(date.timeIntervalSinceNow)
        guard seconds > 0 else { return "即将过期" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return minutes > 0 ? "剩余 \(hours) 小时 \(minutes) 分" : "剩余 \(hours) 小时"
        }
        return "还剩 \(max(1, minutes)) 分钟"
    }

    private func shareTicket(code: String) {
        let link = LoverScanLink.roomPayload(code)
        let titlePrefix: String
        if let h = householdName?.trimmingCharacters(in: .whitespacesAndNewlines), !h.isEmpty {
            titlePrefix = "「\(h)」今晚开饭啦，"
        } else {
            titlePrefix = ""
        }
        let text = "\(titlePrefix)一起来点菜吧！\n房间号：\(code)\n点开直达：\(link)"

        if let image = renderTicketImage(code: code) {
            shareRoomItem = DiningRoomShareItem(items: [image, text])
        } else {
            shareRoomItem = DiningRoomShareItem(items: [text])
        }
    }

    @MainActor
    private func renderTicketImage(code: String) -> UIImage? {
        let posterBackground = Color(red: 0.965, green: 0.965, blue: 0.972)
        let content = VStack(spacing: 14) {
            DiningInvitationTicketView(
                code: code,
                householdName: householdName,
                hostName: resolvedHostName,
                expiresAt: meal?.roomExpiresAt,
                notchColor: posterBackground,
                onCopyCode: nil
            )
            Text("我们这顿 · 家宴点菜")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color(red: 0.56, green: 0.56, blue: 0.58))
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 18)
        .frame(width: 360)
        .background(posterBackground)
        .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 3.0
        return renderer.uiImage
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            meal = try await MealService.shared.detail(id: mealId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // 轮询静默刷新 让 host 实时看到谁加入、点了什么；本地也会按过期时间切 UI
    private func silentReload() async {
        if let m = try? await MealService.shared.detail(id: mealId) {
            meal = m
        }
    }

    private func open() async {
        guard !isActing else { return }
        isActing = true
        defer { isActing = false }
        do {
            meal = try await DiningService.shared.open(mealId: mealId)
            Haptics.success()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func close() async {
        guard !isActing else { return }
        isActing = true
        defer { isActing = false }
        do {
            try await DiningService.shared.close(mealId: mealId)
            didCloseRoom = true
            Haptics.light()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - 纯 SwiftUI 家宴入场券卡片（同时支持页面交互与 ImageRenderer 海报导出）

private struct DiningInvitationTicketView: View {
    let code: String
    let householdName: String?
    let hostName: String
    let expiresAt: Date?
    let notchColor: Color
    let onCopyCode: (() -> Void)?

    private var ticketNo: String {
        String(code.suffix(4)).uppercased()
    }

    private var headlineText: String {
        let trimmed = householdName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "今天这一顿" : "\(trimmed) 的这一顿"
    }

    private var expiryText: String? {
        guard let expiresAt else { return nil }
        let cal = Calendar.current
        let hm = DateFormatter()
        hm.locale = Locale(identifier: "zh_CN")
        hm.dateFormat = "HH:mm"
        if cal.isDateInToday(expiresAt) {
            return "今天 \(hm.string(from: expiresAt)) 前有效"
        }
        let mdhm = DateFormatter()
        mdhm.locale = Locale(identifier: "zh_CN")
        mdhm.dateFormat = "M月d日 HH:mm"
        return "\(mdhm.string(from: expiresAt)) 前有效"
    }

    private var formattedCode: String {
        guard code.count == 6 else { return code }
        let mid = code.index(code.startIndex, offsetBy: 3)
        return "\(code[..<mid]) \(code[mid...])"
    }

    var body: some View {
        let obsidian = Color(red: 0.067, green: 0.067, blue: 0.075)
        VStack(spacing: 0) {
            // 曜石黑票头
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 11, weight: .semibold))
                    Text("家宴入场券 · NO.\(ticketNo)")
                        .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                }
                .foregroundStyle(.white.opacity(0.88))
                .padding(.horizontal, 11)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.14), in: Capsule())

                Text(headlineText)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("\(hostName) 邀你一起点菜")
                    if let expiryText {
                        Text("·")
                        Text(expiryText)
                    }
                }
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.76))
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppSpacing.xl)
            .padding(.vertical, 20)
            .background(obsidian)

            // 中段二维码
            VStack(spacing: AppSpacing.md) {
                BrandQRCode(content: LoverScanLink.roomPayload(code), size: 176, badge: .dining)
                    .padding(14)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.dividerLine.opacity(0.75), lineWidth: 0.7)
                    }

                Text("打开「我们这顿」扫一扫加入")
                    .font(AppFont.body(13))
                    .foregroundStyle(Color.inkSecondary)
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.top, AppSpacing.xl)
            .padding(.bottom, AppSpacing.lg)

            perforation

            // 票根房间号
            Group {
                if let onCopyCode {
                    Button(action: onCopyCode) {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("房间号 · 点一下复制")
                                    .font(AppFont.caption(10.5))
                                    .foregroundStyle(Color.inkMuted)
                                Text(formattedCode)
                                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color.inkPrimary)
                                    .tracking(2.5)
                            }
                            Spacer()
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.inkPrimary)
                                .frame(width: 34, height: 34)
                                .background(Color.cardBackground, in: Circle())
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.dividerLine.opacity(0.7), lineWidth: 0.7)
                        }
                    }
                    .buttonStyle(SoftPressStyle())
                } else {
                    VStack(spacing: 5) {
                        Text("房间号")
                            .font(AppFont.caption(11))
                            .foregroundStyle(Color.inkMuted)
                        Text(formattedCode)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.inkPrimary)
                            .tracking(2.5)
                        Text("打开「我们这顿」→ 去朋友那儿点菜 → 扫码或输房间号")
                            .font(AppFont.caption(11))
                            .foregroundStyle(Color.inkSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.dividerLine.opacity(0.7), lineWidth: 0.7)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.lg)
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.dividerLine.opacity(0.7), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.07), radius: 16, y: 7)
    }

    private var perforation: some View {
        ZStack {
            PerforationLine()
                .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                .foregroundStyle(Color.inkMuted.opacity(0.45))
                .frame(height: 1)
                .padding(.horizontal, AppSpacing.xl)
            HStack {
                Circle()
                    .fill(notchColor)
                    .frame(width: 22, height: 22)
                Spacer()
                Circle()
                    .fill(notchColor)
                    .frame(width: 22, height: 22)
            }
            .padding(.horizontal, -11)
        }
    }
}

private struct DiningRoomShareItem: Identifiable {
    let id = UUID()
    let items: [Any]
}
