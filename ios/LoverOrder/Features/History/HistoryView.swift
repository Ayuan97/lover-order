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

// 历史卡片：左侧场景图标 + 右侧菜品快照
private struct HistoryCard: View {
    let meal: MealSession

    var body: some View {
        SectionCard {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                VStack(spacing: AppSpacing.xs) {
                    Image(systemName: meal.scene.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.brandGreen)
                        .clipShape(Circle())
                    Text(meal.scene.label)
                        .font(AppFont.caption(11))
                        .foregroundStyle(Color.inkMuted)
                }

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    HStack {
                        Text(meal.title?.isEmpty == false ? meal.title! : "这一顿")
                            .font(AppFont.headline(15))
                            .foregroundStyle(Color.inkPrimary)
                        Spacer()
                        Text(formatDate(meal.completedAt ?? meal.confirmedAt ?? meal.createdAt))
                            .font(AppFont.caption(12))
                            .foregroundStyle(Color.inkMuted)
                    }
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 11))
                        Text("\((meal.dishes ?? []).count) 道菜")
                        Text("·")
                        Text(meal.mood.label)
                    }
                    .font(AppFont.caption(12))
                    .foregroundStyle(Color.inkMuted)

                    if let dishes = meal.dishes, !dishes.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: AppSpacing.sm) {
                                ForEach(dishes.prefix(4)) { dish in
                                    DishThumb(name: dish.recipeName, image: dish.recipeImage)
                                }
                                if dishes.count > 4 {
                                    Text("+\(dishes.count - 4)")
                                        .font(AppFont.caption(12))
                                        .frame(width: 48, height: 48)
                                        .background(Color.appBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
                                        .foregroundStyle(Color.inkMuted)
                                }
                            }
                        }
                    }

                    if let comment = meal.reviews?.first?.comment, !comment.isEmpty {
                        Text("\u{201C}\(comment)\u{201D}")
                            .font(AppFont.caption(12))
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
            }
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
