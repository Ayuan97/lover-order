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
            .background(isSelected ? Color.brandGreen : Color.cardBackground)
            .clipShape(Capsule(style: .continuous))
            .capsuleHairline(color: isSelected ? .clear : Color.dividerLine.opacity(0.7))
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

// 与 SwiftUI.Scene 协议同名会冲突 用 MealScene 区分
enum MealScene: String, CaseIterable, Identifiable, Codable {
    case pair
    case family
    case future

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pair: return "我们这顿"
        case .family: return "家里这顿"
        case .future: return "未来这顿"
        }
    }

    // 在"相处模式"语境下的叫法
    var modeLabel: String {
        switch self {
        case .pair: return "俩人世界"
        case .family: return "家庭聚餐"
        case .future: return "未来这顿"
        }
    }

    var hint: String {
        switch self {
        case .pair: return "两个人轻松决定吃什么"
        case .family: return "家里人聚一聚 想吃点什么"
        case .future: return "暂时还没安排 留个心愿"
        }
    }

    var icon: String {
        switch self {
        case .pair: return "heart.fill"
        case .family: return "house.fill"
        case .future: return "moon.stars.fill"
        }
    }
}
