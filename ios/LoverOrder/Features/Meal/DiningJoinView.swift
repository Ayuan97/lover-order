import SwiftUI

// 访客加入聚餐：扫码或输房间号，临时一起点菜，不改自己的家
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

    private var trimmedRoomCode: String {
        roomCode.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    heroHeader
                    whiteSheetContent
                }
            }
            .ignoresSafeArea(edges: .top)
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider().overlay(Color.dividerLine.opacity(0.6))
                PrimaryButton(title: "进入点菜房", icon: "arrow.right", isLoading: joining) {
                    Task { await joinTyped(roomCode) }
                }
                .disabled(trimmedRoomCode.isEmpty || joining)
                .padding(.horizontal, AppSpacing.xl)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.lg)
            }
            .background(Color.appBackground)
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.42), in: Circle())
                    .overlay {
                        Circle().strokeBorder(Color.white.opacity(0.28), lineWidth: 0.7)
                    }
            }
            .buttonStyle(SoftPressStyle())
            .padding(.top, AppSpacing.lg)
            .padding(.trailing, AppSpacing.lg)
            .accessibilityLabel("关闭")
        }
        .toast($errorMessage)
        .fullScreenCover(isPresented: $showScanner) {
            QRScannerScreen(
                hint: "对准家宴入场券上的二维码",
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

    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            GeometryReader { proxy in
                Image("CanvasMeadow")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }
            LinearGradient(
                colors: [Color.black.opacity(0.24), Color.black.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 8) {
                Image("StickerEmoji_food_cheers")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 54, height: 54)
                    .shadow(color: Color.black.opacity(0.24), radius: 10, y: 4)
                Text("去朋友那儿点菜")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("扫码或填 6 位房间号，加入今天这一顿")
                    .font(.system(size: 13.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.bottom, 38)
        }
        .frame(height: 252)
    }

    private var whiteSheetContent: some View {
        VStack(spacing: AppSpacing.lg) {
            // 主推扫码入口
            Button { showScanner = true } label: {
                HStack(spacing: 14) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("扫一扫家宴入场券")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("对准朋友手机或群里的二维码")
                            .font(AppFont.caption(12))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.actionInk, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.black.opacity(0.10), radius: 12, y: 5)
            }
            .buttonStyle(SoftPressStyle())

            HStack(spacing: 12) {
                Rectangle()
                    .fill(Color.dividerLine.opacity(0.8))
                    .frame(height: 0.7)
                Text("或输入 6 位房间号")
                    .font(AppFont.caption(12))
                    .foregroundStyle(Color.inkMuted)
                    .fixedSize()
                Rectangle()
                    .fill(Color.dividerLine.opacity(0.8))
                    .frame(height: 0.7)
            }
            .padding(.vertical, 2)

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
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.inkSecondary)
                    Text("仅本次临时一起点菜，不会改变你自己的家")
                        .font(AppFont.caption(11.5))
                        .foregroundStyle(Color.inkMuted)
                }
                .padding(.top, 2)
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
