import SwiftUI
import UIKit

// 首次使用 / 菜单还空着时的引导卡
struct EmptyMealHint: View {
    let onCreateRecipe: () -> Void
    let onInvite: () -> Void

    @State private var copied: Bool = false

    var body: some View {
        SectionCard(padding: AppSpacing.xl) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.brandGreen)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("先一起填上菜单")
                            .font(AppFont.headline(17))
                            .foregroundStyle(Color.inkPrimary)
                        Text("菜单里有几道喜欢的菜 之后这里才会出现推荐和常吃")
                            .font(AppFont.caption(12))
                            .foregroundStyle(Color.inkMuted)
                    }
                }
                VStack(spacing: AppSpacing.sm) {
                    PrimaryButton(title: "创建第一道菜", icon: "plus") {
                        onCreateRecipe()
                    }
                    SecondaryButton(title: copied ? "邀请码已复制" : "邀请 Ta 一起填", icon: "person.crop.circle.badge.plus") {
                        onInvite()
                        withAnimation {
                            copied = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { copied = false }
                        }
                    }
                }
            }
        }
    }
}
