import SwiftUI

// 首次使用 / 菜单还空着时的引导卡
struct EmptyMealHint: View {
    let onCreateRecipe: () -> Void
    let onInvite: () -> Void
    var inviteEnabled: Bool = true
    var inviteHint: String? = nil

    var body: some View {
        SectionCard(padding: AppSpacing.xl) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.brandGreen)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("菜单还空着")
                            .font(AppFont.headline(17))
                            .foregroundStyle(Color.inkPrimary)
                        Text("先记几道你们爱吃的 以后才好挑")
                            .font(AppFont.caption(12))
                            .foregroundStyle(Color.inkMuted)
                    }
                }
                VStack(spacing: AppSpacing.sm) {
                    PrimaryButton(title: "记一道菜", icon: "plus") {
                        onCreateRecipe()
                    }
                    SecondaryButton(title: "叫 Ta 一起来", icon: "qrcode") {
                        onInvite()
                    }
                    .opacity(inviteEnabled ? 1 : 0.55)
                    if let inviteHint {
                        Text(inviteHint)
                            .font(AppFont.caption(11))
                            .foregroundStyle(Color.inkMuted)
                    }
                }
            }
        }
    }
}
