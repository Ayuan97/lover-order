import Foundation

// 菜单页快捷筛选：只保留真实有用的最近使用。
enum MenuFilter: String, CaseIterable, Identifiable {
    case all
    case recent

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "全部菜谱"
        case .recent: return "最近做过"
        }
    }
}

@MainActor
final class MenuViewModel: ObservableObject {
    @Published var categories: [RecipeCategory] = []
    @Published var recipes: [Recipe] = []
    @Published var selectedCategoryId: UInt?
    @Published var quickFilter: MenuFilter = .all
    @Published var keyword: String = ""
    @Published var pinnedDishes: [MealDish] = []
    @Published var meal: MealSession?
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var loadFailed: Bool = false
    @Published var errorMessage: String?

    private var page = 1
    private var total = 0
    private var recipesLoadID = 0
    private var categoriesLoadID = 0
    var hasMore: Bool { recipes.count < total }

    private let recipeService = RecipeService.shared
    private let categoryService = CategoryService.shared
    private let mealService = MealService.shared

    func bootstrap(scene: MealScene, mood: Mood) async {
        await loadCategories()
        await loadCurrentMeal(scene: scene, mood: mood)
        await loadRecipes()
    }

    func loadCategories() async {
        categoriesLoadID += 1
        let loadID = categoriesLoadID
        do {
            let latest = try await categoryService.list()
            guard loadID == categoriesLoadID else { return }
            categories = latest
            if let selectedCategoryId, !categories.contains(where: { $0.id == selectedCategoryId }) {
                await selectCategory(nil)
            }
        } catch {
            guard loadID == categoriesLoadID else { return }
            errorMessage = error.localizedDescription
        }
    }

    func loadCurrentMeal(scene: MealScene, mood: Mood) async {
        do {
            let m = try await mealService.current(scene: scene, mood: mood)
            meal = m
            pinnedDishes = m.dishes ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // 轮询静默同步这一顿 内容没变不动 UI
    func syncMeal(scene: MealScene, mood: Mood) async {
        guard let m = try? await mealService.current(scene: scene, mood: mood) else { return }
        if m.syncSignature != meal?.syncSignature {
            meal = m
            pinnedDishes = m.dishes ?? []
            AppNotifications.mealChanged()
        }
    }

    func loadRecipes() async {
        recipesLoadID += 1
        let loadID = recipesLoadID
        isLoading = true
        isLoadingMore = false
        loadFailed = false
        defer {
            if loadID == recipesLoadID { isLoading = false }
        }
        do {
            let result = try await recipeService.list(buildQuery(page: 1))
            guard loadID == recipesLoadID else { return }
            page = 1
            total = result.total
            recipes = sortByFilter(result.items)
        } catch {
            guard loadID == recipesLoadID else { return }
            loadFailed = true
            errorMessage = error.localizedDescription
        }
    }

    // 菜谱攒多了 50 条装不下 滚到底自动加载下一页
    func loadMore() async {
        guard hasMore, !isLoadingMore, !isLoading else { return }
        let loadID = recipesLoadID
        isLoadingMore = true
        defer {
            if loadID == recipesLoadID { isLoadingMore = false }
        }
        do {
            let result = try await recipeService.list(buildQuery(page: page + 1))
            guard loadID == recipesLoadID else { return }
            page += 1
            total = result.total
            recipes = sortByFilter(recipes + result.items)
        } catch {
            guard loadID == recipesLoadID else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func buildQuery(page: Int) -> RecipeListQuery {
        var query = RecipeListQuery(
            categoryId: selectedCategoryId,
            keyword: keyword.isEmpty ? nil : keyword,
            page: page,
            pageSize: 50
        )
        return query
    }

    private func sortByFilter(_ items: [Recipe]) -> [Recipe] {
        switch quickFilter {
        case .recent:
            return items.sorted { lhs, rhs in
                (lhs.lastUsedAt ?? .distantPast) > (rhs.lastUsedAt ?? .distantPast)
            }
        default:
            return items
        }
    }

    func selectCategory(_ id: UInt?) async {
        selectedCategoryId = id
        await loadRecipes()
    }

    func selectFilter(_ f: MenuFilter) async {
        quickFilter = f
        await loadRecipes()
    }

    func clearFilters() async {
        selectedCategoryId = nil
        quickFilter = .all
        await loadRecipes()
    }

    func searchChanged() async {
        await loadRecipes()
    }

    func addDish(_ recipe: Recipe) async {
        guard let meal else { return }
        if pinnedDishes.contains(where: { $0.recipeId == recipe.id }) {
            errorMessage = "这道已经在这一顿里啦"
            return
        }
        do {
            _ = try await mealService.addDish(mealId: meal.id, dish: DishInput(recipeId: recipe.id))
            let updated = try await mealService.detail(id: meal.id)
            self.meal = updated
            self.pinnedDishes = updated.dishes ?? []
            Haptics.light()
            AppNotifications.mealChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeDish(_ dish: MealDish) async {
        guard let meal else { return }
        do {
            try await mealService.removeDish(mealId: meal.id, dishId: dish.id)
            let updated = try await mealService.detail(id: meal.id)
            self.meal = updated
            self.pinnedDishes = updated.dishes ?? []
            AppNotifications.mealChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func confirmMeal() async {
        guard let meal else { return }
        if pinnedDishes.isEmpty {
            errorMessage = "先选一道菜再定下"
            return
        }
        do {
            switch meal.status {
            case .planning:
                self.meal = try await mealService.confirm(id: meal.id)
                Haptics.success()
                AppNotifications.mealChanged()
            case .confirmed:
                errorMessage = "这一顿已经定下了"
            case .completed, .cancelled:
                errorMessage = "这一顿已经结束了"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
