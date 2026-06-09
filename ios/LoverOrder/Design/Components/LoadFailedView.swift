import SwiftUI

// 列表加载失败时的占位 区别于"没有数据"的空态 给一个明确的重试入口
// 避免把网络错误伪装成"你还没有内容"误导用户
struct LoadFailedView: View {
    var message: String = "没加载出来"
    let retry: () async -> Void

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 32))
                .foregroundStyle(Color.inkMuted)
            Text(message)
                .font(AppFont.body())
                .foregroundStyle(Color.inkSecondary)
            Text("检查下网络 再试一次")
                .font(AppFont.caption())
                .foregroundStyle(Color.inkMuted)
            Button {
                Task { await retry() }
            } label: {
                Text("重试")
                    .font(AppFont.body(14))
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, AppSpacing.sm)
                    .background(Color.brandGreen)
                    .clipShape(Capsule(style: .continuous))
            }
            .padding(.top, AppSpacing.xs)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xxl)
    }
}
