import Foundation

@MainActor
final class MenuViewModel: ObservableObject {
    @Published var categories: [RecipeCategory] = []
    @Published var recipes: [Recipe] = []
    @Published var selectedCategoryId: UInt?
    @Published var keyword: String = ""
    @Published var pinnedDishes: [MealDish] = []
    @Published var meal: MealSession?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let recipeService = RecipeService.shared
    private let categoryService = CategoryService.shared
    private let mealService = MealService.shared

    func bootstrap(scene: Scene, mood: Mood) async {
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

    func loadCurrentMeal(scene: Scene, mood: Mood) async {
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
        defer { isLoading = false }
        do {
            let result = try await recipeService.list(
                .init(
                    categoryId: selectedCategoryId,
                    keyword: keyword.isEmpty ? nil : keyword,
                    page: 1,
                    pageSize: 50
                )
            )
            recipes = result.items
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectCategory(_ id: UInt?) async {
        selectedCategoryId = id
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
        do {
            self.meal = try await mealService.confirm(id: meal.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
