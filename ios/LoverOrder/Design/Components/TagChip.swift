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
        .foregroundStyle(Color.accentInk)
        .background(Color.accentWarm.opacity(0.13))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.accentWarm.opacity(0.22), lineWidth: 0.8)
        }
    }
}
