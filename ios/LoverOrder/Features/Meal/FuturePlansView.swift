import SwiftUI

// 未来这顿：future 场景下还没定下的菜单
struct FuturePlansView: View {
    @EnvironmentObject private var appState: AppState

    @State private var meal: MealSession?
    @State private var futureList: [MealSession] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showAddDish: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                header
                if let meal {
                    plannedCard(meal)
                }
                otherFutureList
                Color.clear.frame(height: 40)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .task {
            await load()
        }
        .navigationTitle("未来这顿")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddDish) {
            if let mid = meal?.id {
                AddDishView(mealId: mid) {
                    Task { await load() }
                }
                .environmentObject(appState)
            }
        }
        .toast($errorMessage)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("把以后想吃的留到这里")
                .font(AppFont.body())
                .foregroundStyle(Color.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func plannedCard(_ meal: MealSession) -> some View {
        SectionCard {
            HStack {
                Image(systemName: "moon.stars.fill")
                    .foregroundStyle(Color.brandGreen)
                Text("等着做的")
                    .font(AppFont.headline(15))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                Text("\((meal.dishes ?? []).count) 道")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.inkMuted)
            }
            let dishes = meal.dishes ?? []
            if dishes.isEmpty {
                Text("在菜谱详情里点'留到周末'就能加进来")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.inkMuted)
            } else {
                ForEach(dishes) { dish in
                    HStack(spacing: AppSpacing.md) {
                        DishThumb(name: dish.recipeName, image: dish.recipeImage)
                        Text(dish.recipeName)
                            .font(AppFont.body(15))
                            .foregroundStyle(Color.inkPrimary)
                        Spacer()
                        Button {
                            Task { await removeDish(dish) }
                        } label: {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(Color.inkMuted)
                        }
                    }
                }
            }
            HStack(spacing: AppSpacing.md) {
                SecondaryButton(title: "加进来", icon: "plus") {
                    showAddDish = true
                }
                PrimaryButton(title: "转到这一顿", icon: "arrow.right.circle") {
                    Task { await moveToNow(meal) }
                }
            }
        }
    }

    private var otherFutureList: some View {
        Group {
            if !futureList.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("过往的未来计划")
                        .font(AppFont.headline(15))
                        .foregroundStyle(Color.inkPrimary)
                    ForEach(futureList) { item in
                        NavigationLink {
                            HistoryDetailView(mealId: item.id)
                        } label: {
                            futureRow(item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func futureRow(_ item: MealSession) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: item.status.icon)
                .foregroundStyle(Color.brandGreen)
                .frame(width: 32, height: 32)
                .background(Color.brandGreen.opacity(0.1))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title?.isEmpty == false ? item.title! : "未来的一顿")
                    .font(AppFont.body(15))
                    .foregroundStyle(Color.inkPrimary)
                Text(item.status.label + " · \((item.dishes ?? []).count) 道")
                    .font(AppFont.caption(11))
                    .foregroundStyle(Color.inkMuted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(Color.inkMuted)
        }
        .padding(AppSpacing.md)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let current = MealService.shared.current(scene: .future, mood: appState.currentMood)
            async let list = MealService.shared.list(.init(scene: .future, page: 1, pageSize: 30))
            let (m, l) = try await (current, list)
            meal = m
            futureList = l.items.filter { $0.id != m.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeDish(_ dish: MealDish) async {
        guard let mid = meal?.id else { return }
        do {
            try await MealService.shared.removeDish(mealId: mid, dishId: dish.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func moveToNow(_ future: MealSession) async {
        do {
            let now = try await MealService.shared.current(scene: appState.currentScene, mood: appState.currentMood)
            let existingRecipeIds = Set((now.dishes ?? []).compactMap { $0.recipeId })
            let existingNames = Set((now.dishes ?? []).map { $0.recipeName })
            for dish in future.dishes ?? [] {
                if let rid = dish.recipeId {
                    if existingRecipeIds.contains(rid) { continue }
                    _ = try await MealService.shared.addDish(mealId: now.id, dish: DishInput(recipeId: rid, note: dish.note))
                } else if !dish.recipeName.isEmpty {
                    if existingNames.contains(dish.recipeName) { continue }
                    _ = try await MealService.shared.addDish(mealId: now.id, dish: DishInput(name: dish.recipeName, image: dish.recipeImage, note: dish.note))
                }
            }
            try await MealService.shared.cancel(id: future.id)
            Haptics.success()
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

extension MealStatus {
    var icon: String {
        switch self {
        case .planning: return "moon.stars"
        case .confirmed: return "checkmark.circle"
        case .completed: return "leaf.fill"
        case .cancelled: return "xmark"
        }
    }
}
