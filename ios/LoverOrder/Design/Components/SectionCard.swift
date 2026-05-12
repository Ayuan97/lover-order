import SwiftUI

// 通用白卡片容器 内嵌 padding 用于首页/我的/记录的分组卡
struct SectionCard<Content: View>: View {
    var padding: CGFloat = AppSpacing.lg
    var radius: CGFloat = AppRadius.lg
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            content()
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

// 章节标题 数字 + 中文标题 用于"我的"页
struct NumberedSectionTitle: View {
    let index: Int
    let title: String
    var hint: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
            Text("\(index).")
                .font(AppFont.headline(16))
                .foregroundStyle(Color.brandGreen)
            Text(title)
                .font(AppFont.headline(16))
                .foregroundStyle(Color.inkPrimary)
            if let hint {
                Text(hint)
                    .font(AppFont.caption(12))
                    .foregroundStyle(Color.inkMuted)
            }
            Spacer()
        }
    }
}
