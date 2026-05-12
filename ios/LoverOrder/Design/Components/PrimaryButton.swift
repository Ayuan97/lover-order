import SwiftUI

// 主操作按钮 墨绿大圆角 用于"一起选好了"等关键动作
struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                if isLoading {
                    ProgressView().tint(.white)
                } else if let icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(AppFont.headline(17))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(.white)
            .background(Color.brandGreen)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.pill, style: .continuous))
        }
        .disabled(isLoading)
    }
}

// 次要按钮 透明背景 墨绿描边
struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(AppFont.headline(15))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .foregroundStyle(Color.brandGreen)
            .background(Color.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.pill, style: .continuous)
                    .stroke(Color.brandGreen.opacity(0.2), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.pill, style: .continuous))
        }
    }
}
