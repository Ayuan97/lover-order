import Foundation

@MainActor
final class MealNowViewModel: ObservableObject {
    @Published var meal: MealSession?
    @Published var suggestions: [Recipe] = []
    @Published var frequents: [Recipe] = []
    @Published var isLoading: Bool = false
    @Published var loadFailed: Bool = false
    @Published var errorMessage: String?

    private let mealService = MealService.shared
    private let recipeService = RecipeService.shared

    var dishes: [MealDish] {
        meal?.dishes ?? []
    }

    var dishCount: Int {
        dishes.count
    }

    func load(scene: MealScene, mood: Mood) async {
        isLoading = true
        errorMessage = nil
        loadFailed = false
        defer { isLoading = false }
        do {
            async let current = mealService.current(scene: scene, mood: mood)
            async let suggList = recipeService.list(.init(mood: mood, scene: scene, page: 1, pageSize: 3))
            async let freqList = recipeService.list(.init(page: 1, pageSize: 4))
            let (m, s, f) = try await (current, suggList, freqList)
            self.meal = m
            self.suggestions = s.items
            self.frequents = f.items
        } catch {
            loadFailed = true
            errorMessage = error.localizedDescription
        }
    }

    func changeMood(to mood: Mood) async {
        guard let meal else { return }
        do {
            self.meal = try await mealService.update(id: meal.id, req: MealInput(scene: meal.scene, mood: mood))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addDish(_ recipe: Recipe) async {
        guard let meal else { return }
        do {
            _ = try await mealService.addDish(mealId: meal.id, dish: DishInput(recipeId: recipe.id))
            self.meal = try await mealService.detail(id: meal.id)
            Haptics.light()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeDish(_ dish: MealDish) async {
        guard let meal else { return }
        do {
            try await mealService.removeDish(mealId: meal.id, dishId: dish.id)
            self.meal = try await mealService.detail(id: meal.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func confirm() async {
        guard let meal else { return }
        do {
            self.meal = try await mealService.confirm(id: meal.id)
            Haptics.success()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func complete() async {
        guard let meal else { return }
        do {
            self.meal = try await mealService.complete(id: meal.id)
            Haptics.success()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
