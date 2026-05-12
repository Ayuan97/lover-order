import SwiftUI

// 顶部小标签 用于首页 / 菜单 / 记录 让用户随时知道当前场景
struct CurrentSceneBadge: View {
    let scene: MealScene

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
                .font(.system(size: 11))
            Text("当前场景：\(scene.label)")
                .font(AppFont.caption(11))
            Text("·")
            Text("可在'我的'里切换")
                .font(AppFont.caption(11))
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 6)
        .foregroundStyle(Color.inkMuted)
        .background(Color.cardBackground)
        .clipShape(Capsule(style: .continuous))
    }
}
