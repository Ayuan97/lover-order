import SwiftUI

// 墨绿底胶囊标签 用于风味/时间/份量/难度等信息标记
struct TagChip: View {
    let text: String
    var icon: String? = nil
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon).font(.system(size: 11))
            }
            Text(text)
        }
        .font(AppFont.caption(12))
        .padding(.horizontal, compact ? AppSpacing.sm : AppSpacing.md)
        .padding(.vertical, compact ? 4 : 6)
        .foregroundStyle(Color.brandGreen)
        .background(Color.brandGreen.opacity(0.1))
        .clipShape(Capsule())
    }
}
