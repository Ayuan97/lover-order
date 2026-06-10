import SwiftUI

// 顶部场景说明 用于首页 / 菜单 / 记录
// 纯文字不加胶囊底 这是辅助信息 不该在首屏抢戏
struct CurrentSceneBadge: View {
    let scene: MealScene

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: scene.icon)
                .font(.system(size: 9))
            Text("\(scene.modeLabel) · 在'我的'里切换")
                .font(AppFont.caption(11))
        }
        .foregroundStyle(Color.inkMuted.opacity(0.85))
    }
}
