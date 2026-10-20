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
                    listContent
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
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
        HStack {
            Text("记录")
                .font(AppFont.title(27))
                .foregroundStyle(Color.inkPrimary)
            Spacer()
            Menu {
                Picker("筛选记录", selection: $filter) {
                    ForEach(Filter.allCases) { item in Text(item.label).tag(item) }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 19))
                    .foregroundStyle(filter == .all ? Color.inkMuted : Color.brandGreen)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("筛选记录：" + filter.label)
            Button { showManualEntry = true } label: {
                ProductIcon(kind: .add)
                    .foregroundStyle(Color.inkPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.cardBackground, in: Circle())
            }
            .buttonStyle(SoftPressStyle())
            .accessibilityLabel("记一顿")
        }
        .frame(height: 52)
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
        case .household: return "家人一起吃"
        case .dining: return "朋友聚餐"
        }
    }

    var historyIcon: String {
        switch self {
        case .household: return "house.fill"
        case .dining: return "person.3.fill"
        }
    }
}

private struct HistoryCard: View {
    let meal: MealSession

    var body: some View {
        HStack(spacing: 16) {
            artwork
                .frame(width: 100, height: 124)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 8) {
                Text(dateLabel)
                    .font(AppFont.headline(16))
                    .foregroundStyle(Color.inkPrimary)
                Text(meal.title?.isEmpty == false ? meal.title! : (meal.dishes ?? []).map(\.recipeName).joined(separator: "、"))
                    .font(AppFont.body(14))
                    .foregroundStyle(Color.inkSecondary)
                    .lineLimit(2)
                if let comment = meal.reviews?.first?.comment, !comment.isEmpty {
                    Text(comment)
                        .font(AppFont.body(13))
                        .foregroundStyle(Color.inkMuted)
                        .lineLimit(2)
                }
                Text("\((meal.dishes ?? []).count) 道菜")
                    .font(AppFont.caption(12))
                    .foregroundStyle(Color.brandGreen)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @ViewBuilder
    private var artwork: some View {
        if mealCanvasDocumentExists(mealID: meal.id) {
            MealCanvasSnapshotView(mealID: meal.id)
                .frame(width: 100)
        } else if let photo = meal.reviews?.compactMap({ $0.photos?.first }).first {
            AsyncImageView(url: photo, name: "这一顿")
        } else if let dish = meal.dishes?.first {
            DishThumb(name: dish.recipeName, image: dish.recipeImage, size: 124, radius: 16)
        } else {
            Color.paperGreen.overlay { ProductIcon(kind: .meal).foregroundStyle(Color.brandGreen) }
        }
    }

    private var dateLabel: String {
        guard let date = meal.completedAt ?? meal.confirmedAt ?? meal.createdAt else { return "这一顿" }
        return RelativeDateFormatter.format(date)
    }
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
            case .home: q.scene = .household
            case .friends: q.scene = .dining
            }
            let result = try await MealService.shared.list(q)
            meals = result.items
        } catch {
            loadFailed = true; errorMessage = error.localizedDescription
        }
    }

}
