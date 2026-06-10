import Foundation

@MainActor
final class MealNowViewModel: ObservableObject {
    @Published var meal: MealSession?
    @Published var suggestions: [Recipe] = []
    @Published var frequents: [Recipe] = []
    @Published var isLoading: Bool = false
    @Published var loadFailed: Bool = false
    @Published var errorMessage: String?
    // 对方把这顿标记"做好了"后 提醒本机也留一份感受
    @Published var completedPromptMealId: UInt?

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

    // 别的页面改了这一顿后轻量同步 只刷 meal 不动推荐位
    // 也做完成检测:人在菜单页时对方标记"做好了" 走的是这条路 不能丢提醒
    func refreshMeal(scene: MealScene, mood: Mood) async {
        if let m = try? await mealService.current(scene: scene, mood: mood) {
            await detectCompletedByOther(old: meal, new: m)
            meal = m
        }
    }

    // 轮询静默同步 让另一台手机的改动几秒内自动出现 内容没变不动 UI
    func syncMeal(scene: MealScene, mood: Mood) async {
        guard let m = try? await mealService.current(scene: scene, mood: mood) else { return }
        if m.syncSignature != meal?.syncSignature {
            await detectCompletedByOther(old: meal, new: m)
            meal = m
            // 广播给开着的挑菜面板等弹层 让它们也跟上
            AppNotifications.mealChanged()
        }
    }

    // confirmed 的单被对方收掉:同 id 变 completed 直接提醒;换了新单要回查旧单
    // 确认是 completed 而非"重新选"的 cancelled 否则会提醒去评价一顿被取消的饭
    private func detectCompletedByOther(old: MealSession?, new m: MealSession) async {
        guard let old, old.status == .confirmed else { return }
        if m.id == old.id, m.status == .completed {
            completedPromptMealId = old.id
        } else if m.id != old.id {
            if let detail = try? await mealService.detail(id: old.id), detail.status == .completed {
                completedPromptMealId = old.id
            }
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
        if dishes.contains(where: { $0.recipeId == recipe.id }) {
            errorMessage = "这道已经在这一顿里啦"
            return
        }
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

    // 定下后改主意 取消这顿回到挑菜(已选的菜会清空)
    func cancelMeal(scene: MealScene, mood: Mood) async {
        guard let meal else { return }
        do {
            try await mealService.cancel(id: meal.id)
            Haptics.light()
            await load(scene: scene, mood: mood)
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
