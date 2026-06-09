import SwiftUI

// 访客加入聚餐:输房间号或扫码 进去临时点菜 不改自己的家
struct DiningJoinView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var roomCode = ""
    @State private var joined: MealSession?
    @State private var showScanner = false
    @State private var joining = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: AppSpacing.xl) {
                header
                SectionCard {
                    Text("房间号")
                        .font(AppFont.headline(15))
                        .foregroundStyle(Color.inkPrimary)
                    TextField("对方报的 6 位房间号", text: $roomCode)
                        .keyboardType(.numberPad)
                        .padding(AppSpacing.md)
                        .background(Color.appBackground)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                }
                Button { showScanner = true } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "qrcode.viewfinder")
                        Text("扫一扫 · 对方的聚餐码")
                    }
                    .font(AppFont.body(14))
                    .foregroundStyle(Color.brandGreen)
                }
                Spacer()
                PrimaryButton(title: "加入聚餐", isLoading: joining) {
                    Task { await join(roomCode) }
                }
            }
            .padding(AppSpacing.xl)
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
        .toast($errorMessage)
        .fullScreenCover(isPresented: $showScanner) {
            QRScannerScreen { code in
                Task { await join(code) }
            }
        }
        .fullScreenCover(item: $joined) { m in
            DiningGuestView(meal: m)
                .environmentObject(appState)
        }
    }

    private var header: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "person.2.wave.2.fill")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Color.brandGreen)
            Text("加入聚餐")
                .font(AppFont.title(26))
                .foregroundStyle(Color.inkPrimary)
            Text("输房间号或扫码 临时一起点这一顿\n不会变成对方家的人")
                .multilineTextAlignment(.center)
                .font(AppFont.body(13))
                .foregroundStyle(Color.inkMuted)
        }
        .padding(.top, AppSpacing.xl)
    }

    private func join(_ code: String) async {
        let c = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !c.isEmpty else { return }
        joining = true
        defer { joining = false }
        do {
            joined = try await DiningService.shared.join(roomCode: c)
            Haptics.success()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
