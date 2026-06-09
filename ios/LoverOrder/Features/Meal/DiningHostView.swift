import SwiftUI

// host 端聚餐:开聚餐后出示房间号 + 二维码 让客人扫码进来一起点这一顿
struct DiningHostView: View {
    let mealId: UInt
    @Environment(\.dismiss) private var dismiss
    @State private var meal: MealSession?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var roomCode: String? {
        guard let c = meal?.roomCode, !c.isEmpty else { return nil }
        return c
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            if let code = roomCode {
                roomView(code)
            } else if isLoading {
                ProgressView().tint(Color.brandGreen)
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
            Text("开个聚餐 让大家扫码\n一起点这一顿")
                .multilineTextAlignment(.center)
                .font(AppFont.body())
                .foregroundStyle(Color.inkMuted)
            Spacer()
            PrimaryButton(title: "开启聚餐", icon: "qrcode") {
                Task { await open() }
            }
            .padding(.bottom, AppSpacing.xxl)
        }
        .padding(.horizontal, AppSpacing.xl)
    }

    private func roomView(_ code: String) -> some View {
        VStack(spacing: AppSpacing.lg) {
            VStack(spacing: AppSpacing.xs) {
                Text("聚餐进行中")
                    .font(AppFont.title(24))
                    .foregroundStyle(Color.inkPrimary)
                Text("让朋友扫码 加入一起点菜")
                    .font(AppFont.body(13))
                    .foregroundStyle(Color.inkMuted)
            }
            .padding(.top, AppSpacing.xxl)

            BrandQRCode(content: code, size: 196)
                .padding(AppSpacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                        .fill(Color.cardBackground)
                )
                .appCardShadow()

            VStack(spacing: 2) {
                Text("房间号")
                    .font(AppFont.caption(11))
                    .foregroundStyle(Color.inkMuted)
                Text(formatRoom(code))
                    .font(AppFont.mono(30))
                    .foregroundStyle(Color.brandGreen)
                    .tracking(3)
            }

            participantsRow

            Spacer()

            SecondaryButton(title: "结束聚餐", icon: "xmark.circle") {
                Task { await close() }
            }
            .padding(.bottom, AppSpacing.xxl)
        }
        .padding(.horizontal, AppSpacing.xl)
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

    // 轮询静默刷新 让 host 实时看到谁加入了
    private func silentReload() async {
        if let m = try? await MealService.shared.detail(id: mealId) {
            meal = m
        }
    }

    private func open() async {
        do {
            meal = try await DiningService.shared.open(mealId: mealId)
            Haptics.success()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func close() async {
        do {
            try await DiningService.shared.close(mealId: mealId)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
