import SwiftUI

// 访客加入聚餐:输房间号或扫码 进去临时点菜 不改自己的家
struct DiningJoinView: View {
    var initialRoomCode: String? = nil

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var roomCode = ""
    @State private var joined: MealSession?
    @State private var showScanner = false
    @State private var joining = false
    @State private var errorMessage: String?
    @State private var didConsumeInitialCode = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: AppSpacing.xl) {
                header
                SectionCard {
                    Text("房间号")
                        .font(AppFont.headline(15))
                        .foregroundStyle(Color.inkPrimary)
                    TextField("6 位房间号", text: $roomCode)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .padding(.vertical, 14)
                        .padding(.horizontal, AppSpacing.md)
                        .background(Color.appBackground)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                                .strokeBorder(Color.dividerLine.opacity(0.75), lineWidth: 0.7)
                        }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                        .strokeBorder(Color.dividerLine.opacity(0.6), lineWidth: 0.7)
                }
                Button { showScanner = true } label: {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "qrcode.viewfinder")
                        Text("扫一扫房间码")
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.inkPrimary)
                    .padding(.horizontal, 18)
                    .frame(height: 42)
                    .background(Color.cardBackground, in: Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.inkPrimary.opacity(0.20), lineWidth: 0.9)
                    }
                }
                .buttonStyle(SoftPressStyle())
                Spacer()
                VStack(spacing: 0) {
                    Divider().overlay(Color.dividerLine.opacity(0.6))
                        .padding(.bottom, 12)
                    PrimaryButton(title: "进去", isLoading: joining) {
                        Task { await joinTyped(roomCode) }
                    }
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
            QRScannerScreen(
                hint: "对准房间二维码",
                manualEntryTitle: "改用手输房间号"
            ) { code in
                Task { await joinScanned(code) }
            }
        }
        .fullScreenCover(item: $joined, onDismiss: {
            dismiss()
        }) { m in
            DiningGuestView(meal: m)
                .environmentObject(appState)
        }
        .onAppear {
            guard !didConsumeInitialCode,
                  let initial = initialRoomCode?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !initial.isEmpty else { return }
            didConsumeInitialCode = true
            roomCode = initial
            if initial.count == 6 {
                Task { await joinRoom(initial) }
            }
        }
    }

    private var header: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "person.2.wave.2.fill")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Color.brandGreen)
            Text("去朋友那儿点菜")
                .font(AppFont.title(26))
                .foregroundStyle(Color.inkPrimary)
            Text("扫码用房间二维码\n手输就填 6 位房间号\n不会变成他们家的人")
                .multilineTextAlignment(.center)
                .font(AppFont.body(13))
                .foregroundStyle(Color.inkMuted)
        }
        .padding(.top, AppSpacing.xl)
    }

    // 扫码：只认 lo://room/…，裸串 / 餐券一律拒绝（无兼容）
    private func joinScanned(_ raw: String) async {
        switch LoverScanLink.parse(raw) {
        case .room(let c):
            await joinRoom(c)
        case .home:
            errorMessage = "这是入伙餐券，蹭饭要扫房间码"
        case nil:
            errorMessage = "请扫房间二维码（手输房间号用上面输入框）"
        }
    }

    // 手输：只接受文本框里的房间号本体（可 6 位数字）
    private func joinTyped(_ raw: String) async {
        let c = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !c.isEmpty else { return }
        if c.lowercased().hasPrefix("lo://") {
            // 手输框贴了深链：只接受 room，不把裸路径当兼容
            switch LoverScanLink.parse(c) {
            case .room(let code):
                await joinRoom(code)
            case .home:
                errorMessage = "这是入伙餐券，蹭饭填房间号"
            case nil:
                errorMessage = "房间号不对"
            }
            return
        }
        await joinRoom(c)
    }

    private func joinRoom(_ room: String) async {
        let c = room.trimmingCharacters(in: .whitespacesAndNewlines)
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
