import SwiftUI

// 心情图标 + 文案 用于首页四档选择
// 轻松点 / 正常吃 / 认真吃 / 换换口味
struct MoodChip: View {
    let mood: Mood
    var isSelected: Bool = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.brandGreen.opacity(0.12) : Color.appBackground)
                        .frame(width: 56, height: 56)
                    Image(systemName: mood.icon)
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(isSelected ? Color.brandGreen : Color.inkSecondary)
                }
                Text(mood.label)
                    .font(AppFont.body(13))
                    .foregroundStyle(isSelected ? Color.brandGreen : Color.inkPrimary)
            }
            .frame(maxWidth: .infinity)
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

enum Scene: String, CaseIterable, Identifiable, Codable {
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
