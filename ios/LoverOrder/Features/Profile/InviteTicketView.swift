import SwiftUI
import UIKit

// 入伙餐券 邀请家人扫码进家 票券风格
// displayCode：临时邀请码与家永久码双轨时 餐券/QR/分享统一用当前展示的码
struct InviteTicketView: View {
    let household: Household
    let inviterName: String
    var displayCode: String? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var shareItem: ShareItem?
    @State private var tipMessage: String?

    private var code: String {
        let raw = displayCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? household.inviteCode : raw
    }
    private var isTemporaryCode: Bool {
        guard let d = displayCode?.trimmingCharacters(in: .whitespacesAndNewlines), !d.isEmpty else {
            return false
        }
        return d != household.inviteCode
    }
    private var ticketNo: String { String(code.suffix(4)).uppercased() }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: AppSpacing.xxl) {
                ticket
                actionButtons
            }
            .padding(.horizontal, AppSpacing.xl)
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
        .tipToast($tipMessage)
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.text])
        }
    }

    private var ticket: some View {
        let obsidian = Color(red: 0.067, green: 0.067, blue: 0.075)
        return VStack(spacing: 0) {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 11, weight: .semibold))
                    Text(isTemporaryCode ? "临时餐券 · NO.\(ticketNo)" : "入伙餐券 · NO.\(ticketNo)")
                        .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                }
                .foregroundStyle(.white.opacity(0.86))
                .padding(.horizontal, 11)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.14), in: Capsule())

                Text(household.name)
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppSpacing.xl)
            .padding(.vertical, 20)
            .background(obsidian)

            VStack(spacing: AppSpacing.md) {
                // QR 带 lo://home/ 前缀，避免被扫进蹭饭房间流
                BrandQRCode(content: LoverScanLink.homePayload(code), size: 184)
                    .padding(14)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.dividerLine.opacity(0.75), lineWidth: 0.7)
                    }

                Text(isTemporaryCode ? "扫一下，限时进我们家" : "扫一下，进我们家")
                    .font(AppFont.body(13))
                    .foregroundStyle(Color.inkSecondary)
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.vertical, AppSpacing.xl)

            perforation

            VStack(spacing: 4) {
                Text("\(inviterName) 叫你进来")
                    .font(AppFont.headline(16))
                    .foregroundStyle(Color.inkPrimary)
                Text("扫不了就手输  \(code)")
                    .font(AppFont.mono(13))
                    .foregroundStyle(Color.inkSecondary)
                if isTemporaryCode {
                    Text("这个码有期限，跟家里固定的不一样")
                        .font(AppFont.caption(11))
                        .foregroundStyle(Color.inkMuted)
                }
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.vertical, AppSpacing.lg)
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.dividerLine.opacity(0.7), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 18, y: 8)
    }

    // 撕口 中间虚线 + 两侧半圆缺口
    private var perforation: some View {
        ZStack {
            PerforationLine()
                .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                .foregroundStyle(Color.inkMuted.opacity(0.45))
                .frame(height: 1)
                .padding(.horizontal, AppSpacing.xl)
            HStack {
                notch
                Spacer()
                notch
            }
            .padding(.horizontal, -11)
        }
    }

    private var notch: some View {
        Circle()
            .fill(Color.appBackground)
            .frame(width: 22, height: 22)
    }

    private var actionButtons: some View {
        HStack(spacing: AppSpacing.md) {
            SecondaryButton(title: "复制邀请码", icon: "doc.on.doc") {
                UIPasteboard.general.string = code
                Haptics.light()
                tipMessage = "邀请码已复制"
            }
            PrimaryButton(title: "发给 Ta", icon: "square.and.arrow.up") {
                let deepLink = LoverScanLink.homePayload(code)
                shareItem = ShareItem(text: "来「\(household.name)」一起决定今天吃什么吧\n邀请码：\(code)\n直达链接：\(deepLink)")
            }
        }
    }
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let text: String
}

// 撕口虚线 一条水平居中线
struct PerforationLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

// 系统分享面板
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
