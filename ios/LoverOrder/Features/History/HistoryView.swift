import SwiftUI

// 已完成用餐记录列表。
struct HistoryView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
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
                .padding(.bottom, 92)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .refreshable { await vm.load(filter: filter) }
            .task { await vm.load(filter: filter) }
            .onChange(of: filter) { _, value in Task { await vm.load(filter: value) } }
            .onChange(of: appState.activeTab) { _, tab in
                guard tab == 2 else { return }
                Task { await vm.load(filter: filter) }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active, appState.activeTab == 2 else { return }
                Task { await vm.load(filter: filter) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .historyChanged)) { _ in
                Task { await vm.load(filter: filter) }
            }
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
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("记录")
                    .font(AppFont.title(27))
                    .foregroundStyle(Color.inkPrimary)
                if !vm.meals.isEmpty || filter != .all {
                    let countPart = "共 \(vm.meals.count) 顿"
                    let subtitle = filter == .all ? countPart : "\(countPart) · \(filter.label)"
                    Text(subtitle)
                        .font(AppFont.caption(12))
                        .foregroundStyle(Color.inkMuted)
                }
            }
            Spacer()
            Menu {
                Picker("筛选记录", selection: $filter) {
                    ForEach(Filter.allCases) { item in Text(item.label).tag(item) }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(filter == .all ? Color.inkPrimary : .white)
                    .frame(width: 44, height: 44)
                    .background(
                        filter == .all ? Color.cardBackground : Color(red: 0.067, green: 0.067, blue: 0.075),
                        in: Circle()
                    )
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
        .frame(minHeight: 54)
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
                ForEach(Array(vm.meals.enumerated()), id: \.element.id) { index, meal in
                    NavigationLink { HistoryDetailView(mealId: meal.id) } label: {
                        if index == 0, mealHasPosterArtwork(meal) {
                            HistoryHeroCard(meal: meal, canvasSyncVersion: vm.canvasSyncVersion)
                        } else {
                            HistoryCard(meal: meal, canvasSyncVersion: vm.canvasSyncVersion)
                        }
                    }
                    .buttonStyle(SoftPressStyle())
                }
            }
        }
    }

    private func mealHasPosterArtwork(_ meal: MealSession) -> Bool {
        _ = vm.canvasSyncVersion
        return mealCanvasDocumentExists(mealID: meal.id) || (meal.reviews?.compactMap({ $0.photos?.first }).first != nil)
    }
}

extension MealScene {
    var historyLabel: String {
        switch self {
        case .household: return "家里吃饭"
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

private struct HistoryHeroCard: View {
    let meal: MealSession
    let canvasSyncVersion: Int

    private var summaryTitle: String {
        if let title = meal.title, !title.isEmpty { return title }
        let names = (meal.dishes ?? []).map(\.recipeName)
        return names.isEmpty ? "这一顿" : names.joined(separator: "、")
    }

    private var dateLabel: String {
        guard let date = meal.completedAt ?? meal.confirmedAt ?? meal.createdAt else { return "这一顿" }
        return RelativeDateFormatter.format(date)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            heroArtwork
                .frame(maxWidth: .infinity)
                .frame(height: 264)
                .clipped()

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.28), Color.black.opacity(0.76)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 140)
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    Text(dateLabel)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                    Spacer(minLength: 8)
                    Text("\((meal.dishes ?? []).count) 道菜")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.20), in: Capsule())
                }
                Text(summaryTitle)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let comment = meal.reviews?.first?.comment, !comment.isEmpty {
                    Text(comment)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.white.opacity(0.84))
                        .lineLimit(1)
                }
            }
            .padding(16)
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.7)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 14, y: 6)
    }

    @ViewBuilder
    private var heroArtwork: some View {
        if canvasSyncVersion >= 0, mealCanvasDocumentExists(mealID: meal.id) {
            MealCanvasSnapshotView(mealID: meal.id, fillsContainer: true)
                .id("hero-\(meal.id)-\(canvasSyncVersion)")
        } else if let photo = meal.reviews?.compactMap({ $0.photos?.first }).first {
            GeometryReader { proxy in
                AsyncImageView(url: photo, name: "这一顿")
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }
        }
    }
}

private struct HistoryCard: View {
    let meal: MealSession
    let canvasSyncVersion: Int

    private var summaryTitle: String {
        if let title = meal.title, !title.isEmpty { return title }
        let names = (meal.dishes ?? []).map(\.recipeName)
        return names.isEmpty ? "家常一顿" : names.joined(separator: "、")
    }

    var body: some View {
        HStack(spacing: 14) {
            artwork
                .frame(width: 106, height: 132)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.05), lineWidth: 0.6)
                }
            VStack(alignment: .leading, spacing: 6) {
                Text(dateLabel)
                    .font(AppFont.headline(16))
                    .foregroundStyle(Color.inkPrimary)
                Text(summaryTitle)
                    .font(AppFont.body(14))
                    .foregroundStyle(Color.inkSecondary)
                    .lineLimit(2)
                if let comment = meal.reviews?.first?.comment, !comment.isEmpty {
                    Text(comment)
                        .font(AppFont.body(13))
                        .foregroundStyle(Color.inkMuted)
                        .lineLimit(2)
                }
                Spacer(minLength: 2)
                HStack {
                    Text("\((meal.dishes ?? []).count) 道菜")
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.inkSecondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.appBackground, in: Capsule())
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.inkMuted.opacity(0.7))
                }
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.dividerLine.opacity(0.55), lineWidth: 0.7)
        }
    }

    @ViewBuilder
    private var artwork: some View {
        if canvasSyncVersion >= 0, mealCanvasDocumentExists(mealID: meal.id) {
            MealCanvasSnapshotView(mealID: meal.id, fillsContainer: true)
                .id("card-\(meal.id)-\(canvasSyncVersion)")
        } else if let photo = meal.reviews?.compactMap({ $0.photos?.first }).first {
            GeometryReader { proxy in
                AsyncImageView(url: photo, name: "这一顿")
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }
        } else if let dish = meal.dishes?.first {
            DishThumb(name: dish.recipeName, image: dish.recipeImage, size: 132, radius: 18)
        } else {
            LinearGradient(
                colors: [Color(red: 0.965, green: 0.953, blue: 0.933), Color(red: 0.935, green: 0.922, blue: 0.902)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay {
                if let parts = emptyDateParts {
                    VStack(spacing: 2) {
                        Text(parts.month)
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.inkMuted)
                        Text(parts.day)
                            .font(.system(size: 27, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color.inkPrimary.opacity(0.75))
                        ProductIcon(kind: .meal, size: 12)
                            .foregroundStyle(Color.inkMuted.opacity(0.65))
                            .padding(.top, 2)
                    }
                } else {
                    ProductIcon(kind: .meal, size: 22)
                        .foregroundStyle(Color.inkMuted.opacity(0.65))
                }
            }
        }
    }

    private var emptyDateParts: (month: String, day: String)? {
        guard let date = meal.completedAt ?? meal.confirmedAt ?? meal.createdAt else { return nil }
        let cal = Calendar.current
        return ("\(cal.component(.month, from: date))月", "\(cal.component(.day, from: date))")
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
    @Published var canvasSyncVersion: Int = 0
    private var listLoadID = 0

    func load(filter: HistoryView.Filter) async {
        listLoadID += 1
        let loadID = listLoadID
        isLoading = true
        loadFailed = false
        defer {
            if loadID == listLoadID { isLoading = false }
        }
        do {
            var q = MealListQuery(); q.pageSize = 50
            q.status = .completed
            switch filter {
            case .all: break
            case .home: q.scene = .household
            case .friends: q.scene = .dining
            }
            let result = try await MealService.shared.list(q)
            guard loadID == listLoadID else { return }
            meals = result.items
            let syncTargets = Array(result.items.prefix(12))
            if !syncTargets.isEmpty {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    var updated = false
                    for item in syncTargets {
                        guard loadID == self.listLoadID else { return }
                        if await syncRemoteMealCanvasIfNeeded(mealID: item.id, forceRefresh: true) {
                            updated = true
                        }
                    }
                    if updated, loadID == self.listLoadID {
                        self.canvasSyncVersion += 1
                    }
                }
            }
        } catch {
            guard loadID == listLoadID else { return }
            loadFailed = true; errorMessage = error.localizedDescription
        }
    }

}
