import SwiftUI

// 已完成用餐记录列表。
struct HistoryView: View {
    @StateObject private var vm = HistoryViewModel()
    @State private var filter: Filter = .all
    @State private var showManualEntry = false

    enum Filter: String, CaseIterable, Identifiable {
        case all, home, friends
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: return "全部"
            case .home: return "家里吃饭"
            case .friends: return "朋友聚餐"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header
                    filterChips
                    listContent
                }
                .padding(.horizontal, 18)
                .padding(.top, 30)
                .padding(.bottom, 28)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .refreshable { await vm.load(filter: filter) }
            .task { await vm.load(filter: filter) }
            .onChange(of: filter) { _, value in Task { await vm.load(filter: value) } }
            .onReceive(NotificationCenter.default.publisher(for: .mealChanged)) { _ in
                Task { await vm.load(filter: filter) }
            }
            .navigationBarHidden(true)
            .toast($vm.errorMessage)
            .sheet(isPresented: $showManualEntry) {
                ManualHistoryEntryView {
                    Task { await vm.load(filter: filter) }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 7) {
                Text("记录")
                    .font(AppFont.title(34))
                    .foregroundStyle(Color.inkPrimary)
                Text("记下和家人、朋友吃过的饭")
                    .font(AppFont.body(15))
                    .foregroundStyle(Color.inkMuted)
            }
            Spacer()
            Button {
                showManualEntry = true
            } label: {
                Label("记一顿", systemImage: "plus")
                    .font(AppFont.body(13))
                    .foregroundStyle(Color.brandGreen)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(Color.paperGreen)
                    .clipShape(Capsule())
            }
            .accessibilityLabel("记一顿")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var filterChips: some View {
        HStack(spacing: 8) {
            ForEach(Filter.allCases) { item in
                Button { filter = item } label: {
                    Text(item.label)
                        .font(AppFont.body(12))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .foregroundStyle(filter == item ? Color.white : Color.inkSecondary)
                    .background(filter == item ? Color.brandGreen : Color.cardBackground)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(filter == item ? Color.clear : Color.black.opacity(0.09), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var listContent: some View {
        if vm.isLoading && vm.meals.isEmpty {
            ProgressView().tint(Color.brandGreen).padding(.top, 54)
        } else if vm.meals.isEmpty {
            if vm.loadFailed {
                LoadFailedView { await vm.load(filter: filter) }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "note.text")
                        .font(.system(size: 31, weight: .light))
                        .foregroundStyle(Color.inkMuted)
                    Text("还没有记录")
                        .font(AppFont.body(15))
                        .foregroundStyle(Color.inkMuted)
                    Text("点右上角“记一顿”")
                        .font(AppFont.caption(12))
                        .foregroundStyle(Color.inkMuted.opacity(0.78))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 66)
            }
        } else {
            VStack(spacing: 14) {
                ForEach(vm.meals) { meal in
                    NavigationLink { HistoryDetailView(mealId: meal.id) } label: {
                        HistoryCard(meal: meal)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

extension MealScene {
    var historyLabel: String {
        switch self {
        case .pair: return "家人一起吃"
        case .family: return "朋友聚餐"
        case .future: return "以后想吃"
        }
    }

    var historyIcon: String {
        switch self {
        case .pair: return "house.fill"
        case .family: return "person.3.fill"
        case .future: return "bookmark"
        }
    }
}

private struct HistoryCard: View {
    let meal: MealSession
    private let thumbSize: CGFloat = 74

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(badgeColor)
                        .frame(width: 7, height: 7)
                    Text(meal.scene.historyLabel)
                        .font(AppFont.body(13))
                }
                .foregroundStyle(Color.inkPrimary)

                Text(formatDate(meal.completedAt ?? meal.confirmedAt ?? meal.createdAt))
                    .font(AppFont.caption(12))
                    .foregroundStyle(Color.inkMuted)

                if let dishes = meal.dishes, !dishes.isEmpty {
                    Text("\(dishes.count) 道菜")
                        .font(AppFont.caption(11))
                        .foregroundStyle(Color.inkMuted)
                }

                if let comment = meal.reviews?.first?.comment, !comment.isEmpty {
                    Text(comment)
                        .font(AppFont.caption(12))
                        .foregroundStyle(Color.inkSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                ForEach((meal.dishes ?? []).prefix(2)) { dish in
                    DishThumb(name: dish.recipeName, image: dish.recipeImage, size: thumbSize, radius: 12)
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white, lineWidth: 1.5))
                }
                if (meal.dishes ?? []).isEmpty { placeholder }
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.inkMuted.opacity(0.8))
                .padding(.top, 38)
        }
        .padding(14)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.black.opacity(0.075), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.045), radius: 8, y: 3)
    }

    private var badgeColor: Color {
        switch meal.scene { case .pair: return Color.brandGreen; case .family: return Color.clay; case .future: return Color.inkMuted }
    }
    private var placeholder: some View {
        ZStack { Color.paperGreen; Image(systemName: "leaf").foregroundStyle(Color.brandGreen.opacity(0.55)) }
            .frame(width: thumbSize, height: thumbSize).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    private func formatDate(_ date: Date?) -> String { guard let date else { return "" }; return RelativeDateFormatter.format(date) }
}

enum RelativeDateFormatter {
    static func format(_ date: Date) -> String {
        let cal = Calendar.current
        let timeFormatter = DateFormatter(); timeFormatter.locale = Locale(identifier: "zh_CN"); timeFormatter.dateFormat = "HH:mm"
        let time = timeFormatter.string(from: date)
        if cal.isDateInToday(date) { return "今天 \(time)" }
        if cal.isDateInYesterday(date) { return "昨天 \(time)" }
        let dayDiff = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: Date())).day ?? 0
        if dayDiff > 0 && dayDiff <= 6 { let weekday = DateFormatter(); weekday.locale = Locale(identifier: "zh_CN"); weekday.dateFormat = "EEEE"; return "\(weekday.string(from: date)) \(time)" }
        let absolute = DateFormatter(); absolute.locale = Locale(identifier: "zh_CN"); absolute.dateFormat = "M月d日 HH:mm"; return absolute.string(from: date)
    }
}

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var meals: [MealSession] = []
    @Published var isLoading = false
    @Published var loadFailed = false
    @Published var errorMessage: String?

    func load(filter: HistoryView.Filter) async {
        isLoading = true; loadFailed = false; defer { isLoading = false }
        do {
            var q = MealListQuery(); q.pageSize = 50
            q.status = .completed
            switch filter {
            case .all: break
            case .home: q.scene = .pair
            case .friends: q.scene = .family
            }
            let result = try await MealService.shared.list(q)
            meals = result.items
        } catch {
            loadFailed = true; errorMessage = error.localizedDescription
        }
    }

}
