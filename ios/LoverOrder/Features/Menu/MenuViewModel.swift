import Foundation

// 菜单页虚拟筛选 与设计稿四档对齐
enum MenuFilter: String, CaseIterable, Identifiable {
    case all
    case loved
    case recent
    case filling

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "全部"
        case .loved: return "我们都爱吃"
        case .recent: return "最近做过"
        case .filling: return "人多管饱"
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
    @Published var loadFailed: Bool = false
    @Published var errorMessage: String?

    private let recipeService = RecipeService.shared
    private let categoryService = CategoryService.shared
    private let mealService = MealService.shared

    func bootstrap(scene: MealScene, mood: Mood) async {
        await loadCategories()
        await loadCurrentMeal(scene: scene, mood: mood)
        await loadRecipes()
    }

    func loadCategories() async {
        do {
            categories = try await categoryService.list()
        } catch {
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

    func loadRecipes() async {
        isLoading = true
        loadFailed = false
        defer { isLoading = false }
        do {
            var query = RecipeListQuery(
                categoryId: selectedCategoryId,
                keyword: keyword.isEmpty ? nil : keyword,
                page: 1,
                pageSize: 50
            )
            switch quickFilter {
            case .all:
                break
            case .loved:
                query.favorite = true
            case .recent, .filling:
                break
            }
            let result = try await recipeService.list(query)
            recipes = sortByFilter(result.items)
        } catch {
            loadFailed = true
            errorMessage = error.localizedDescription
        }
    }

    private func sortByFilter(_ items: [Recipe]) -> [Recipe] {
        switch quickFilter {
        case .recent:
            return items.sorted { lhs, rhs in
                (lhs.lastUsedAt ?? .distantPast) > (rhs.lastUsedAt ?? .distantPast)
            }
        case .filling:
            return items.sorted { lhs, rhs in
                (lhs.servings ?? 0) > (rhs.servings ?? 0)
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

    func searchChanged() async {
        await loadRecipes()
    }

    func addDish(_ recipe: Recipe) async {
        guard let meal else { return }
        do {
            _ = try await mealService.addDish(mealId: meal.id, dish: DishInput(recipeId: recipe.id))
            let updated = try await mealService.detail(id: meal.id)
            self.meal = updated
            self.pinnedDishes = updated.dishes ?? []
            Haptics.light()
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
