import SwiftUI

// 记录页 按时间倒序展示已完成的"一顿"
struct HistoryView: View {
    @StateObject private var vm = HistoryViewModel()
    @State private var filter: Filter = .recent

    enum Filter: String, CaseIterable, Identifiable {
        case recent
        case completed
        case favorite
        case thisMonth

        var id: String { rawValue }

        var label: String {
            switch self {
            case .recent: return "最近"
            case .completed: return "已尝过"
            case .favorite: return "收藏"
            case .thisMonth: return "本月"
            }
        }
    }

    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    header
                    filterChips
                    listContent
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .task {
                await vm.load(filter: filter)
            }
            .onChange(of: filter) { _, newValue in
                Task { await vm.load(filter: newValue) }
            }
            .navigationBarHidden(true)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text("记录")
                    .font(AppFont.title(30))
                    .foregroundStyle(Color.inkPrimary)
                Image(systemName: "leaf.fill")
                    .foregroundStyle(Color.brandGreen)
                Spacer()
            }
            Text("把每一顿吃过的留下来")
                .font(AppFont.body())
                .foregroundStyle(Color.inkMuted)
            CurrentSceneBadge(scene: appState.currentScene)
                .padding(.top, AppSpacing.xs)
        }
        .padding(.vertical, AppSpacing.sm)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(Filter.allCases) { f in
                    Button {
                        filter = f
                    } label: {
                        Text(f.label)
                            .font(AppFont.body(14))
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.vertical, 10)
                            .foregroundStyle(filter == f ? .white : Color.inkPrimary)
                            .background(filter == f ? Color.brandGreen : Color.cardBackground)
                            .clipShape(Capsule(style: .continuous))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var listContent: some View {
        if vm.isLoading && vm.meals.isEmpty {
            ProgressView().tint(Color.brandGreen).padding(.top, 60)
        } else if vm.meals.isEmpty {
            VStack(spacing: AppSpacing.md) {
                Image(systemName: "tray")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.inkMuted)
                Text("还没有记录")
                    .font(AppFont.body())
                    .foregroundStyle(Color.inkMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.xxxl)
        } else {
            VStack(spacing: AppSpacing.md) {
                ForEach(vm.meals) { meal in
                    NavigationLink {
                        HistoryDetailView(mealId: meal.id)
                    } label: {
                        HistoryCard(meal: meal)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// 历史卡片：水平长条 左侧场景小徽章 + 中间文字 + 右侧菜品图横向
private struct HistoryCard: View {
    let meal: MealSession

    private let thumbSize: CGFloat = 56

    var body: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.sm) {
                    sceneBadge
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(meal.scene.label)
                                .font(AppFont.headline(15))
                                .foregroundStyle(Color.inkPrimary)
                            Text("·")
                                .foregroundStyle(Color.inkMuted)
                            Text(formatDate(meal.completedAt ?? meal.confirmedAt ?? meal.createdAt))
                                .font(AppFont.caption(12))
                                .foregroundStyle(Color.inkMuted)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "person.2")
                                .font(.system(size: 10))
                            Text(peopleHint)
                            Text("·")
                            Text(meal.mood.label)
                        }
                        .font(AppFont.caption(11))
                        .foregroundStyle(Color.inkMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color.inkMuted)
                }

                if let comment = meal.reviews?.first?.comment, !comment.isEmpty {
                    Text("\u{201C}\(comment)\u{201D}")
                        .font(AppFont.caption(12))
                        .foregroundStyle(Color.inkSecondary)
                }

                if let dishes = meal.dishes, !dishes.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppSpacing.sm) {
                            ForEach(dishes.prefix(4)) { dish in
                                dishThumb(name: dish.recipeName, image: dish.recipeImage)
                            }
                            if dishes.count > 4 {
                                Text("+\(dishes.count - 4)")
                                    .font(AppFont.caption(12))
                                    .frame(width: thumbSize, height: thumbSize)
                                    .background(Color.appBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                                    .foregroundStyle(Color.inkMuted)
                            }
                        }
                    }
                }
            }
        }
    }

    // 场景徽章 区分三种场景配色
    private var sceneBadge: some View {
        ZStack {
            Color.brandGreen.opacity(0.12)
            Image(systemName: meal.scene.icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.brandGreen)
        }
        .frame(width: 36, height: 36)
        .clipShape(Circle())
    }

    private var peopleHint: String {
        switch meal.scene {
        case .pair: return "两个人"
        case .family: return "一家人"
        case .future: return "未来计划"
        }
    }

    private func dishThumb(name: String, image: String?) -> some View {
        Group {
            if let urlString = image, !urlString.isEmpty, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        placeholder(name: name)
                    }
                }
            } else {
                placeholder(name: name)
            }
        }
        .frame(width: thumbSize, height: thumbSize)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
    }

    private func placeholder(name: String) -> some View {
        ZStack {
            Color.appBackground
            Text(String(name.prefix(1)))
                .font(AppFont.headline(16))
                .foregroundStyle(Color.brandGreen)
        }
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "" }
        return RelativeDateFormatter.format(date)
    }
}

// 相对时间格式化 今天/昨天 HH:mm 其他显示 M月d日 HH:mm
enum RelativeDateFormatter {
    static func format(_ date: Date) -> String {
        let cal = Calendar.current
        let now = Date()
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "zh_CN")
        timeFormatter.dateFormat = "HH:mm"
        let time = timeFormatter.string(from: date)

        if cal.isDateInToday(date) {
            return "今天 \(time)"
        }
        if cal.isDateInYesterday(date) {
            return "昨天 \(time)"
        }
        let dayDiff = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: now)).day ?? 0
        if dayDiff > 0 && dayDiff <= 6 {
            let weekday = DateFormatter()
            weekday.locale = Locale(identifier: "zh_CN")
            weekday.dateFormat = "EEEE"
            return "\(weekday.string(from: date)) \(time)"
        }
        let absolute = DateFormatter()
        absolute.locale = Locale(identifier: "zh_CN")
        absolute.dateFormat = "M月d日 HH:mm"
        return absolute.string(from: date)
    }
}

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var meals: [MealSession] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    func load(filter: HistoryView.Filter) async {
        isLoading = true
        defer { isLoading = false }
        do {
            var q = MealListQuery()
            q.pageSize = 50
            switch filter {
            case .recent:
                break
            case .completed:
                q.status = .completed
            case .favorite:
                q.status = .completed
            case .thisMonth:
                q.status = .completed
            }
            let result = try await MealService.shared.list(q)
            meals = filterMeals(result.items, by: filter)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func filterMeals(_ items: [MealSession], by filter: HistoryView.Filter) -> [MealSession] {
        switch filter {
        case .thisMonth:
            let cal = Calendar.current
            return items.filter { meal in
                guard let date = meal.completedAt ?? meal.confirmedAt ?? meal.createdAt else { return false }
                return cal.isDate(date, equalTo: Date(), toGranularity: .month)
            }
        default:
            return items
        }
    }
}
