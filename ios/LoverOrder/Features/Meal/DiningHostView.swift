import SwiftUI
import UIKit

// host 端聚餐:开房后出示房间号 + 二维码；展示已点菜与点菜人；按过期时间判存活
struct DiningHostView: View {
    let mealId: UInt
    // 本次 sheet 内是否真关过房 供首页 onDismiss 决定要不要催「可以定下来了」
    @Binding var didCloseRoom: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var meal: MealSession?
    @State private var isLoading = true
    @State private var isActing = false
    @State private var errorMessage: String?
    @State private var showCloseConfirm = false
    @State private var shareRoomItem: DiningRoomShareItem?

    init(mealId: UInt, didCloseRoom: Binding<Bool> = .constant(false)) {
        self.mealId = mealId
        self._didCloseRoom = didCloseRoom
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
                    .foregroundStyle(Color.inkSecondary)
                    .frame(width: 36, height: 36)
                    .background(Color.cardBackground)
                    .clipShape(Circle())
            }
            .padding(AppSpacing.lg)
        }
        .task {
            await load()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                await silentReload()
            }
        }
        .toast($errorMessage)
        .confirmationDialog("关掉房间？", isPresented: $showCloseConfirm) {
            Button("关掉", role: .destructive) {
                Task { await close() }
            }
            Button("再等等", role: .cancel) {}
        } message: {
            Text("他们就不能再加了 已经点的还在")
        }
        .sheet(item: $shareRoomItem) { item in
            ShareSheet(items: [item.text])
        }
    }

    private var startView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            Image(systemName: "person.3.sequence.fill")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(Color.brandGreen)
            Text("家里来人了")
                .font(AppFont.title(26))
                .foregroundStyle(Color.inkPrimary)
            Text("开个房间 让大家扫码一起点")
                .multilineTextAlignment(.center)
                .font(AppFont.body())
                .foregroundStyle(Color.inkMuted)
            Spacer()
            PrimaryButton(title: "开房间", icon: "qrcode", isLoading: isActing) {
                Task { await open() }
            }
            .disabled(isActing)
            .padding(.bottom, AppSpacing.xxl)
        }
        .padding(.horizontal, AppSpacing.xl)
    }

    private var expiredView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(Color.accentWarm)
            Text("房间过期了")
                .font(AppFont.title(24))
                .foregroundStyle(Color.inkPrimary)
            Text("再开一间 让大家重新扫一下")
                .multilineTextAlignment(.center)
                .font(AppFont.body())
                .foregroundStyle(Color.inkMuted)
            if !dishes.isEmpty {
                Text("刚才点的 \(dishes.count) 道还在")
                    .font(AppFont.caption(12))
                    .foregroundStyle(Color.inkSecondary)
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

    private func roomView(_ code: String) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    VStack(spacing: AppSpacing.xs) {
                        Text("大家在点")
                            .font(AppFont.title(24))
                            .foregroundStyle(Color.inkPrimary)
                        Text("让他们扫这个码")
                            .font(AppFont.body(13))
                            .foregroundStyle(Color.inkMuted)
                    }
                    .padding(.top, AppSpacing.xxl)

                    // QR 带 lo://room/ 前缀，避免被扫进进家流
                    let obsidian = Color(red: 0.067, green: 0.067, blue: 0.075)
                    VStack(spacing: 0) {
                        HStack(spacing: 6) {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 11, weight: .semibold))
                            Text("聚餐点菜房")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(obsidian)

                        VStack(spacing: 14) {
                            BrandQRCode(content: LoverScanLink.roomPayload(code), size: 176)
                                .padding(12)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(Color.dividerLine.opacity(0.7), lineWidth: 0.7)
                                }

                            Button {
                                UIPasteboard.general.string = code
                                Haptics.light()
                                errorMessage = "抄好了 发给他们吧"
                            } label: {
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("房间号 · 点一下复制")
                                            .font(AppFont.caption(10.5))
                                            .foregroundStyle(Color.inkMuted)
                                        Text(formatRoom(code))
                                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                                            .foregroundStyle(Color.inkPrimary)
                                            .tracking(2)
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
                        }
                        .padding(16)
                    }
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Color.dividerLine.opacity(0.65), lineWidth: 0.7)
                    }
                    .shadow(color: Color.black.opacity(0.06), radius: 14, y: 6)

                    participantsRow
                    dishesSection
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.bottom, AppSpacing.lg)
            }

            HStack(spacing: AppSpacing.md) {
                SecondaryButton(title: "关掉房间", icon: "xmark.circle") {
                    showCloseConfirm = true
                }
                .disabled(isActing)
                .opacity(isActing ? 0.55 : 1)

                PrimaryButton(title: "发给朋友", icon: "square.and.arrow.up") {
                    let link = LoverScanLink.roomPayload(code)
                    shareRoomItem = DiningRoomShareItem(
                        text: "今晚一起点菜啦！\n房间号：\(code)\n点开直达：\(link)"
                    )
                }
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xxl)
            .padding(.top, AppSpacing.sm)
            .background(Color.appBackground)
            .overlay(alignment: .top) {
                Divider().overlay(Color.dividerLine.opacity(0.6))
            }
        }
    }

    private var participantsRow: some View {
        let people = meal?.participants ?? []
        return HStack(spacing: AppSpacing.sm) {
            if people.isEmpty {
                Text("还没人进来 把号发过去就行")
                    .font(AppFont.caption(12))
                    .foregroundStyle(Color.inkMuted)
            } else {
                HStack(spacing: -8) {
                    ForEach(people.prefix(6)) { p in
                        AvatarView(user: p.user, size: 28, ring: true)
                    }
                }
                Text("\(people.count) 个人在")
                    .font(AppFont.caption(12))
                    .foregroundStyle(Color.inkSecondary)
            }
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
                    .font(AppFont.caption())
                    .foregroundStyle(Color.inkMuted)
            }
            if dishes.isEmpty {
                Text("还空着 等他们扫进来再点")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.inkMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
            } else {
                VStack(spacing: AppSpacing.sm) {
                    ForEach(Array(dishes.enumerated()), id: \.element.id) { idx, dish in
                        HStack(spacing: AppSpacing.md) {
                            DishThumb(name: dish.recipeName, image: dish.recipeImage)
                            Text(dish.recipeName)
                                .font(AppFont.body(15))
                                .foregroundStyle(Color.inkPrimary)
                                .lineLimit(1)
                            Spacer()
                            if let adder = dish.adder {
                                AvatarView(user: adder, size: 22)
                            }
                        }
                        if idx < dishes.count - 1 {
                            Divider().background(Color.dividerLine.opacity(0.5))
                        }
                    }
                }
            }
        }
    }

    private func formatRoom(_ code: String) -> String {
        guard code.count == 6 else { return code }
        let mid = code.index(code.startIndex, offsetBy: 3)
        return "\(code[..<mid]) \(code[mid...])"
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

private struct DiningRoomShareItem: Identifiable {
    let id = UUID()
    let text: String
}
