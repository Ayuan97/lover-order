import SwiftUI
import UIKit

// host 端聚餐:开房后出示房间号 + 二维码；展示已点菜与点菜人；按过期时间判存活
struct DiningHostView: View {
    let mealId: UInt
    @Environment(\.dismiss) private var dismiss
    @State private var meal: MealSession?
    @State private var isLoading = true
    @State private var isActing = false
    @State private var errorMessage: String?
    @State private var showCloseConfirm = false

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
        .confirmationDialog("关闭点菜房间？", isPresented: $showCloseConfirm) {
            Button("关闭房间", role: .destructive) {
                Task { await close() }
            }
            Button("再等等", role: .cancel) {}
        } message: {
            Text("关闭后朋友不能再加菜，已点的菜还在这一顿里")
        }
    }

    private var startView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            Image(systemName: "person.3.sequence.fill")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(Color.brandGreen)
            Text("家里来客了?")
                .font(AppFont.title(26))
                .foregroundStyle(Color.inkPrimary)
            Text("开个点菜房间 让大家扫码\n一起点这一顿")
                .multilineTextAlignment(.center)
                .font(AppFont.body())
                .foregroundStyle(Color.inkMuted)
            Spacer()
            PrimaryButton(title: "开启点菜房间", icon: "qrcode", isLoading: isActing) {
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
            Text("点菜房间已过期")
                .font(AppFont.title(24))
                .foregroundStyle(Color.inkPrimary)
            Text("之前的房间号不能用了\n重新开一间让朋友再扫一次")
                .multilineTextAlignment(.center)
                .font(AppFont.body())
                .foregroundStyle(Color.inkMuted)
            if !dishes.isEmpty {
                Text("已点 \(dishes.count) 道菜还在这一顿里")
                    .font(AppFont.caption(12))
                    .foregroundStyle(Color.inkSecondary)
            }
            Spacer()
            PrimaryButton(title: "重新开房", icon: "qrcode", isLoading: isActing) {
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
                        Text("点菜房间进行中")
                            .font(AppFont.title(24))
                            .foregroundStyle(Color.inkPrimary)
                        Text("让朋友扫码 加入一起点菜")
                            .font(AppFont.body(13))
                            .foregroundStyle(Color.inkMuted)
                    }
                    .padding(.top, AppSpacing.xxl)

                    BrandQRCode(content: code, size: 180)
                        .padding(AppSpacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                                .fill(Color.cardBackground)
                        )
                        .appCardShadow()

                    VStack(spacing: 2) {
                        Text("房间号 · 点一下复制")
                            .font(AppFont.caption(11))
                            .foregroundStyle(Color.inkMuted)
                        // 人不在场的朋友扫不了码 复制房间号发微信
                        Button {
                            UIPasteboard.general.string = code
                            Haptics.light()
                            errorMessage = "房间号已复制 发给朋友吧"
                        } label: {
                            Text(formatRoom(code))
                                .font(AppFont.mono(30))
                                .foregroundStyle(Color.brandGreen)
                                .tracking(3)
                        }
                        .buttonStyle(.plain)
                    }

                    participantsRow
                    dishesSection
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.bottom, AppSpacing.lg)
            }

            SecondaryButton(title: "关闭点菜房间", icon: "xmark.circle") {
                showCloseConfirm = true
            }
            .disabled(isActing)
            .opacity(isActing ? 0.55 : 1)
            .padding(.horizontal, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xxl)
            .padding(.top, AppSpacing.sm)
            .background(Color.appBackground)
        }
    }

    private var participantsRow: some View {
        let people = meal?.participants ?? []
        return HStack(spacing: AppSpacing.sm) {
            if people.isEmpty {
                Text("还没有人加入 把房间号发给大家")
                    .font(AppFont.caption(12))
                    .foregroundStyle(Color.inkMuted)
            } else {
                HStack(spacing: -8) {
                    ForEach(people.prefix(6)) { p in
                        AvatarView(user: p.user, size: 28, ring: true)
                    }
                }
                Text("\(people.count) 人已加入")
                    .font(AppFont.caption(12))
                    .foregroundStyle(Color.inkSecondary)
            }
        }
    }

    private var dishesSection: some View {
        SectionCard {
            HStack {
                Text("这一顿已点")
                    .font(AppFont.headline(15))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                Text("\(dishes.count) 道")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.inkMuted)
            }
            if dishes.isEmpty {
                Text("还没点菜 等朋友扫码后一起挑")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.inkMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
            } else {
                VStack(spacing: AppSpacing.sm) {
                    ForEach(dishes) { dish in
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
            Haptics.light()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
