import SwiftUI
import UIKit

// 入伙餐券 邀请家人扫码进家 票券风格
struct InviteTicketView: View {
    let household: Household
    let inviterName: String
    @Environment(\.dismiss) private var dismiss
    @State private var shareItem: ShareItem?

    private var code: String { household.inviteCode }
    private var ticketNo: String { String(code.suffix(4)).uppercased() }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: AppSpacing.xxl) {
                ticket
                shareButton
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
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.text])
        }
    }

    private var ticket: some View {
        VStack(spacing: 0) {
            VStack(spacing: AppSpacing.md) {
                HStack(spacing: 6) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.brandGreen)
                    Text(household.name)
                        .font(AppFont.title(22))
                        .foregroundStyle(Color.inkPrimary)
                }
                Text("入伙餐券 · No.\(ticketNo)")
                    .font(AppFont.mono(12))
                    .foregroundStyle(Color.inkMuted)

                BrandQRCode(content: code, size: 188)
                    .padding(.vertical, AppSpacing.sm)

                Text("扫一扫 · 进我们家")
                    .font(AppFont.body(13))
                    .foregroundStyle(Color.inkSecondary)
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.top, AppSpacing.xxl)
            .padding(.bottom, AppSpacing.lg)

            perforation

            VStack(spacing: AppSpacing.xs) {
                Text("\(inviterName) 请你来吃饭")
                    .font(AppFont.headline(16))
                    .foregroundStyle(Color.inkPrimary)
                Text("没相机就手输邀请码  \(code)")
                    .font(AppFont.caption(12))
                    .foregroundStyle(Color.inkMuted)
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.vertical, AppSpacing.lg)
        }
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                .fill(Color.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                .stroke(Color.dividerLine.opacity(0.6), lineWidth: 1)
        )
        .appCardShadow()
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

    private var shareButton: some View {
        PrimaryButton(title: "把餐券发给 Ta", icon: "square.and.arrow.up") {
            shareItem = ShareItem(text: "来加入「\(household.name)」，一起决定每天吃什么～邀请码：\(code)")
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
