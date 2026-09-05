import SwiftUI

// 心情胶囊 轻松点 / 正常吃 / 认真吃 / 换换口味
// 压成单行小胶囊 把首屏空间让给菜
struct MoodChip: View {
    let mood: Mood
    var isSelected: Bool = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: mood.icon)
                    .font(.system(size: 12, weight: .medium))
                Text(mood.label)
                    .font(AppFont.body(13))
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 9)
            .foregroundStyle(isSelected ? .white : Color.inkSecondary)
            .background(isSelected ? Color.dopaminePink : Color.cardBackground)
            .clipShape(Capsule(style: .continuous))
            .capsuleHairline(color: isSelected ? .clear : Color.dividerLine.opacity(0.7))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

enum Mood: String, CaseIterable, Identifiable, Codable {
    case easy
    case normal
    case serious
    case change

    var id: String { rawValue }

    var label: String {
        switch self {
        case .easy: return "轻松点"
        case .normal: return "正常吃"
        case .serious: return "认真吃"
        case .change: return "换换口味"
        }
    }

    var icon: String {
        switch self {
        case .easy: return "face.smiling"
        case .normal: return "leaf"
        case .serious: return "fork.knife"
        case .change: return "arrow.triangle.2.circlepath"
        }
    }
}

// 餐次数据标签（非产品「模式」）。
// household = 家庭；dining = 聚餐。
enum MealScene: String, CaseIterable, Identifiable, Codable {
    case household = "pair"
    case dining = "family"

    var id: String { rawValue }

    /// 常用短名；历史详情页会用更完整的记录文案。
    var label: String {
        switch self {
        case .household: return "家庭"
        case .dining: return "聚餐"
        }
    }

    var hint: String {
        switch self {
        case .household: return "今天想吃点什么"
        case .dining: return ""
        }
    }

    var icon: String {
        switch self {
        case .household: return "heart.fill"
        case .dining: return "clock.arrow.circlepath"
        }
    }

    /// 用户可选标签（编辑菜谱等）。
    static var productCases: [MealScene] { [.household] }
}
