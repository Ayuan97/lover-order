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

struct MenuLocalCacheSnapshot: Codable {
    var categories: [RecipeCategory]
    var recipes: [Recipe]
    var total: Int
    var savedAt: Date
}

enum MenuLocalCache {
    private static var dirURL: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("LoverOrderMenuCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func fileURL(householdId: UInt) -> URL {
        dirURL.appendingPathComponent("menu-\(householdId).json", isDirectory: false)
    }

    static func load(householdId: UInt?) -> MenuLocalCacheSnapshot? {
        guard let hid = householdId, hid > 0,
              let data = try? Data(contentsOf: fileURL(householdId: hid)) else {
            return nil
        }
        return try? APIClient.makeDecoder().decode(MenuLocalCacheSnapshot.self, from: data)
    }

    static func save(householdId: UInt?, categories: [RecipeCategory], recipes: [Recipe], total: Int) {
        guard let hid = householdId, hid > 0 else { return }
        let snap = MenuLocalCacheSnapshot(categories: categories, recipes: recipes, total: total, savedAt: Date())
        guard let data = try? APIClient.makeEncoder().encode(snap) else { return }
        let target = fileURL(householdId: hid)
        Task.detached(priority: .utility) {
            try? data.write(to: target, options: .atomic)
        }
    }

    private static func mutateCachedFiles(_ transform: @Sendable @escaping (inout MenuLocalCacheSnapshot) -> Bool) {
        let dir = dirURL
        Task.detached(priority: .utility) {
            guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
                return
            }
            let decoder = APIClient.makeDecoder()
            let encoder = APIClient.makeEncoder()
            for file in files where file.pathExtension == "json" {
                guard let data = try? Data(contentsOf: file),
                      var snap = try? decoder.decode(MenuLocalCacheSnapshot.self, from: data) else {
                    continue
                }
                if transform(&snap) {
                    snap.savedAt = Date()
                    if let updated = try? encoder.encode(snap) {
                        try? updated.write(to: file, options: .atomic)
                    }
                }
            }
        }
    }

    static func upsertRecipe(_ recipe: Recipe) {
        mutateCachedFiles { snap in
            if let idx = snap.recipes.firstIndex(where: { $0.id == recipe.id }) {
                snap.recipes[idx] = recipe
            } else {
                snap.recipes.insert(recipe, at: 0)
                snap.total += 1
            }
            return true
        }
    }

    static func removeRecipes(ids: [UInt]) {
        let idSet = Set(ids)
        guard !idSet.isEmpty else { return }
        mutateCachedFiles { snap in
            let before = snap.recipes.count
            snap.recipes.removeAll { idSet.contains($0.id) }
            let removed = before - snap.recipes.count
            guard removed > 0 else { return false }
            snap.total = max(snap.recipes.count, snap.total - removed)
            return true
        }
    }

    static func updateRecipesCategory(ids: [UInt], categoryId: UInt?) {
        let idSet = Set(ids)
        guard !idSet.isEmpty else { return }
        mutateCachedFiles { snap in
            let targetCategory = categoryId.flatMap { cid in snap.categories.first(where: { $0.id == cid }) }
            var changed = false
            for idx in snap.recipes.indices where idSet.contains(snap.recipes[idx].id) {
                snap.recipes[idx].categoryId = categoryId
                snap.recipes[idx].category = targetCategory
                changed = true
            }
            return changed
        }
    }

    static func detachDeletedCategory(id: UInt) {
        mutateCachedFiles { snap in
            var changed = false
            let beforeCats = snap.categories.count
            snap.categories.removeAll { $0.id == id }
            if snap.categories.count != beforeCats {
                changed = true
            }
            for idx in snap.recipes.indices where snap.recipes[idx].categoryId == id {
                snap.recipes[idx].categoryId = nil
                snap.recipes[idx].category = nil
                changed = true
            }
            return changed
        }
    }
}

@MainActor
final class MenuViewModel: ObservableObject {
    @Published var categories: [RecipeCategory] = []
    @Published var recipes: [Recipe] = []
    @Published var selectedCategoryId: UInt?
    @Published var isUncategorizedSelected: Bool = false
    @Published var quickFilter: MenuFilter = .all
    @Published var keyword: String = ""
    @Published var pinnedDishes: [MealDish] = []
    @Published var meal: MealSession?
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var loadFailed: Bool = false
    @Published var errorMessage: String?
    @Published var tipMessage: String?

    private static let optimisticDishIDThreshold: UInt = UInt.max / 2
    private var page = 1
    private var total = 0
    private var recipesLoadID = 0
    private var categoriesLoadID = 0
    private var activeHouseholdId: UInt?
    private var hasBootstrapped = false
    private var nextOptimisticDishID: UInt = UInt.max - 1
    private var pendingAddRecipeIDs: Set<UInt> = []
    private var cancelledOptimisticRecipeIDs: Set<UInt> = []
    private var pendingRemoveDishIDs: Set<UInt> = []
    private var inFlightDishMutations = 0
    private var dishMutationGeneration = 0
    private var isConfirmingMeal = false

    var isMutatingMealLocally: Bool { inFlightDishMutations > 0 || isConfirmingMeal }
    var hasMore: Bool { recipes.count < total }
    var totalCount: Int { max(total, recipes.count) }

    private let recipeService = RecipeService.shared
    private let categoryService = CategoryService.shared
    private let mealService = MealService.shared

    private var isDefaultUnfilteredQuery: Bool {
        selectedCategoryId == nil
            && !isUncategorizedSelected
            && keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func restoreCacheIfNeeded(householdId: UInt?) {
        guard let hid = householdId, hid > 0 else { return }
        if activeHouseholdId != hid {
            activeHouseholdId = hid
            if let cached = MenuLocalCache.load(householdId: hid) {
                if categories.isEmpty {
                    categories = cached.categories
                }
                if recipes.isEmpty && isDefaultUnfilteredQuery {
                    total = cached.total
                    recipes = sortByFilter(cached.recipes)
                    prefetchRecipeAssets(cached.recipes)
                }
            }
        }
    }

    private func persistDefaultCacheIfApplicable() {
        guard isDefaultUnfilteredQuery else { return }
        MenuLocalCache.save(
            householdId: activeHouseholdId,
            categories: categories,
            recipes: recipes,
            total: total
        )
    }

    private func prefetchRecipeAssets(_ list: [Recipe]) {
        let paths = list.flatMap { [$0.coverImage, $0.creator?.avatar] }
        RemoteImageCache.shared.prefetch(paths: paths)
    }

    func bootstrap(householdId: UInt?, scene: MealScene, mood: Mood) async {
        restoreCacheIfNeeded(householdId: householdId)
        hasBootstrapped = true
        await refreshAll(householdId: householdId, scene: scene, mood: mood)
    }

    func refreshIfBootstrapped(householdId: UInt?, scene: MealScene, mood: Mood) async {
        guard hasBootstrapped else { return }
        await refreshAll(householdId: householdId, scene: scene, mood: mood, silent: !recipes.isEmpty)
    }

    func refreshAll(householdId: UInt?, scene: MealScene, mood: Mood, silent: Bool = false) async {
        restoreCacheIfNeeded(householdId: householdId)
        await Task { @MainActor in
            async let c: () = loadCategories(silent: silent)
            async let m: () = loadCurrentMeal(scene: scene, mood: mood, silent: silent)
            async let r: () = loadRecipes(silent: silent)
            _ = await (c, m, r)
        }.value
    }

    func loadCategories(silent: Bool = false) async {
        categoriesLoadID += 1
        let loadID = categoriesLoadID
        do {
            let latest = try await categoryService.list()
            guard loadID == categoriesLoadID else { return }
            categories = latest
            persistDefaultCacheIfApplicable()
            if let selectedCategoryId, !categories.contains(where: { $0.id == selectedCategoryId }) {
                await selectCategory(nil)
            }
        } catch {
            guard loadID == categoriesLoadID, !error.isCancellationError, !Task.isCancelled else { return }
            if !silent && categories.isEmpty && recipes.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
    }

    func loadCurrentMeal(scene: MealScene, mood: Mood, silent: Bool = false) async {
        let mutationGen = dishMutationGeneration
        do {
            let m = try await mealService.current(scene: scene, mood: mood)
            guard mutationGen == dishMutationGeneration, !isMutatingMealLocally else { return }
            meal = m
            pinnedDishes = m.dishes ?? []
        } catch {
            guard !error.isCancellationError, !Task.isCancelled else { return }
            if !silent && meal == nil && recipes.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
    }

    // 轮询静默同步这一顿 内容没变不动 UI
    func syncMeal(scene: MealScene, mood: Mood) async {
        guard !isMutatingMealLocally else { return }
        let mutationGen = dishMutationGeneration
        guard let m = try? await mealService.current(scene: scene, mood: mood) else { return }
        guard mutationGen == dishMutationGeneration, !isMutatingMealLocally else { return }
        if m.syncSignature != meal?.syncSignature {
            meal = m
            pinnedDishes = m.dishes ?? []
            AppNotifications.mealChanged()
        }
    }

    func loadRecipes(silent: Bool = false) async {
        recipesLoadID += 1
        let loadID = recipesLoadID
        if !silent || recipes.isEmpty {
            isLoading = true
        }
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
            loadFailed = false
            persistDefaultCacheIfApplicable()
            prefetchRecipeAssets(result.items)
        } catch {
            guard loadID == recipesLoadID, !error.isCancellationError, !Task.isCancelled else { return }
            if recipes.isEmpty {
                loadFailed = true
            }
            if !silent || recipes.isEmpty {
                errorMessage = error.localizedDescription
            }
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
            prefetchRecipeAssets(result.items)
        } catch {
            guard loadID == recipesLoadID, !error.isCancellationError, !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func buildQuery(page: Int) -> RecipeListQuery {
        RecipeListQuery(
            categoryId: isUncategorizedSelected ? nil : selectedCategoryId,
            uncategorized: isUncategorizedSelected,
            keyword: keyword.isEmpty ? nil : keyword,
            page: page,
            pageSize: 50
        )
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
        isUncategorizedSelected = false
        selectedCategoryId = id
        if id != nil {
            quickFilter = .all
        }
        await loadRecipes()
    }

    func selectUncategorized() async {
        selectedCategoryId = nil
        quickFilter = .all
        isUncategorizedSelected.toggle()
        await loadRecipes()
    }

    func selectFilter(_ f: MenuFilter) async {
        selectedCategoryId = nil
        isUncategorizedSelected = false
        quickFilter = f
        await loadRecipes()
    }

    func clearFilters() async {
        selectedCategoryId = nil
        isUncategorizedSelected = false
        quickFilter = .all
        await loadRecipes()
    }

    func searchChanged() async {
        await loadRecipes()
    }

    func deleteSingleRecipe(_ recipe: Recipe) async {
        do {
            try await recipeService.delete(id: recipe.id)
            Haptics.light()
            tipMessage = "已删除「\(recipe.name)」"
            AppNotifications.recipesChanged()
            AppNotifications.categoriesChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func moveRecipesToCategory(ids: [UInt], categoryId: UInt?, categoryName: String) async -> Bool {
        guard !ids.isEmpty else { return false }
        do {
            let count = try await recipeService.batchUpdateCategory(recipeIds: ids, categoryId: categoryId)
            Haptics.success()
            let displayCount = max(1, count)
            tipMessage = ids.count == 1
                ? "已归入「\(categoryName)」"
                : "已将 \(displayCount) 道菜归入「\(categoryName)」"
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func batchDeleteRecipes(ids: [UInt]) async -> Bool {
        guard !ids.isEmpty else { return false }
        do {
            let count = try await recipeService.batchDelete(recipeIds: ids)
            Haptics.success()
            tipMessage = "已删除 \(max(1, count)) 道菜谱"
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteCategory(_ category: RecipeCategory) async {
        do {
            try await categoryService.delete(id: category.id)
            if selectedCategoryId == category.id {
                selectedCategoryId = nil
            }
            Haptics.light()
            tipMessage = "已删除分类「\(category.name)」"
            AppNotifications.categoriesChanged()
            AppNotifications.recipesChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func applySavedRecipe(_ saved: Recipe) {
        let matchesCategory: Bool = {
            if isUncategorizedSelected {
                return saved.categoryId == nil
            }
            if let selectedCategoryId {
                return saved.categoryId == selectedCategoryId
            }
            return true
        }()
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matchesKeyword: Bool = {
            guard !trimmedKeyword.isEmpty else { return true }
            return saved.name.lowercased().contains(trimmedKeyword)
                || (saved.description?.lowercased().contains(trimmedKeyword) ?? false)
                || (saved.tags?.contains(where: { $0.lowercased().contains(trimmedKeyword) }) ?? false)
        }()
        let matchesFilter = matchesCategory && matchesKeyword

        if let idx = recipes.firstIndex(where: { $0.id == saved.id }) {
            if matchesFilter {
                recipes[idx] = saved
                recipes = sortByFilter(recipes)
            } else {
                recipes.remove(at: idx)
                total = max(recipes.count, total - 1)
            }
        } else if matchesFilter {
            recipes.insert(saved, at: 0)
            total += 1
            recipes = sortByFilter(recipes)
        }
        persistDefaultCacheIfApplicable()
        prefetchRecipeAssets([saved])
    }

    private func allocOptimisticDishID() -> UInt {
        let id = nextOptimisticDishID
        if nextOptimisticDishID > Self.optimisticDishIDThreshold + 1 {
            nextOptimisticDishID &-= 1
        } else {
            nextOptimisticDishID = UInt.max - 1
        }
        return id
    }

    private func makeOptimisticDish(for recipe: Recipe, currentUser: AppUser?) -> MealDish {
        MealDish(
            id: allocOptimisticDishID(),
            mealSessionId: meal?.id ?? 0,
            recipeId: recipe.id,
            recipeName: recipe.name,
            recipeImage: recipe.coverImage,
            recipeCutoutImage: recipe.cutoutImage,
            note: nil,
            sortOrder: pinnedDishes.count,
            addedBy: currentUser?.id,
            adder: currentUser
        )
    }

    private func syncMealDishesFromPinned() {
        guard var current = meal else { return }
        current.dishes = pinnedDishes
        meal = current
    }

    func addDish(
        _ recipe: Recipe,
        scene: MealScene = .household,
        mood: Mood? = nil,
        currentUser: AppUser? = nil
    ) async {
        if let meal, meal.status != .planning && meal.status != .confirmed {
            errorMessage = "这一顿已经结束了"
            return
        }
        if pinnedDishes.contains(where: { $0.recipeId == recipe.id }) {
            return
        }
        // 在途添加刚被乐观取消又重新点加时，直接恢复乐观项并复用同一个请求
        if pendingAddRecipeIDs.contains(recipe.id) {
            if cancelledOptimisticRecipeIDs.remove(recipe.id) != nil {
                let restored = makeOptimisticDish(for: recipe, currentUser: currentUser)
                dishMutationGeneration &+= 1
                pinnedDishes.append(restored)
                syncMealDishesFromPinned()
                Haptics.light()
                CanvasSoundEngine.shared.playDishPick()
            }
            return
        }

        let optimisticDish = makeOptimisticDish(for: recipe, currentUser: currentUser)
        pendingAddRecipeIDs.insert(recipe.id)
        cancelledOptimisticRecipeIDs.remove(recipe.id)
        dishMutationGeneration &+= 1
        inFlightDishMutations += 1
        pinnedDishes.append(optimisticDish)
        syncMealDishesFromPinned()
        Haptics.light()
        CanvasSoundEngine.shared.playDishPick()

        defer {
            pendingAddRecipeIDs.remove(recipe.id)
            inFlightDishMutations = max(0, inFlightDishMutations - 1)
        }

        do {
            let targetMeal: MealSession
            if let existingMeal = self.meal {
                targetMeal = existingMeal
            } else {
                let fetched = try await mealService.current(scene: scene, mood: mood)
                var merged = fetched
                var mergedDishes = fetched.dishes ?? []
                for item in pinnedDishes where !mergedDishes.contains(where: {
                    $0.id == item.id || ($0.recipeId != nil && $0.recipeId == item.recipeId)
                }) {
                    mergedDishes.append(item)
                }
                merged.dishes = mergedDishes
                self.meal = merged
                self.pinnedDishes = mergedDishes
                targetMeal = merged
            }

            let created = try await mealService.addDish(
                mealId: targetMeal.id,
                dish: DishInput(recipeId: recipe.id)
            )
            dishMutationGeneration &+= 1

            if cancelledOptimisticRecipeIDs.remove(recipe.id) != nil {
                pinnedDishes.removeAll { $0.recipeId == recipe.id }
                syncMealDishesFromPinned()
                inFlightDishMutations += 1
                defer { inFlightDishMutations = max(0, inFlightDishMutations - 1) }
                try? await mealService.removeDish(mealId: targetMeal.id, dishId: created.id)
                dishMutationGeneration &+= 1
                return
            }

            if let idx = pinnedDishes.firstIndex(where: { $0.recipeId == recipe.id }) {
                pinnedDishes[idx] = created
                for offset in pinnedDishes.indices.reversed() where offset != idx {
                    let item = pinnedDishes[offset]
                    if item.id == created.id || item.recipeId == recipe.id {
                        pinnedDishes.remove(at: offset)
                    }
                }
            } else {
                pinnedDishes.append(created)
            }
            syncMealDishesFromPinned()

            if targetMeal.status == .confirmed,
               let rIdx = recipes.firstIndex(where: { $0.id == recipe.id }) {
                recipes[rIdx].useCount = (recipes[rIdx].useCount ?? 0) + 1
            }
        } catch {
            dishMutationGeneration &+= 1
            cancelledOptimisticRecipeIDs.remove(recipe.id)
            pinnedDishes.removeAll {
                $0.id == optimisticDish.id || ($0.id >= Self.optimisticDishIDThreshold && $0.recipeId == recipe.id)
            }
            syncMealDishesFromPinned()
            errorMessage = error.localizedDescription
        }
    }

    func removeDish(_ dish: MealDish) async {
        if dish.id >= Self.optimisticDishIDThreshold {
            if let rid = dish.recipeId {
                cancelledOptimisticRecipeIDs.insert(rid)
            }
            dishMutationGeneration &+= 1
            pinnedDishes.removeAll { $0.id == dish.id || (dish.recipeId != nil && $0.recipeId == dish.recipeId) }
            syncMealDishesFromPinned()
            Haptics.soft()
            CanvasSoundEngine.shared.playDeletePoof()
            return
        }

        guard let meal, !pendingRemoveDishIDs.contains(dish.id) else { return }
        let previousMealStatus = meal.status
        let removedIndex = pinnedDishes.firstIndex(where: { $0.id == dish.id })
        pendingRemoveDishIDs.insert(dish.id)
        dishMutationGeneration &+= 1
        inFlightDishMutations += 1

        pinnedDishes.removeAll { $0.id == dish.id }
        if var current = self.meal {
            current.dishes = pinnedDishes
            if current.status == .confirmed && pinnedDishes.isEmpty {
                current.status = .planning
            }
            self.meal = current
        }
        Haptics.soft()
        CanvasSoundEngine.shared.playDeletePoof()

        defer {
            pendingRemoveDishIDs.remove(dish.id)
            inFlightDishMutations = max(0, inFlightDishMutations - 1)
        }

        do {
            try await mealService.removeDish(mealId: meal.id, dishId: dish.id)
            dishMutationGeneration &+= 1
            if previousMealStatus == .confirmed,
               let rid = dish.recipeId,
               let rIdx = recipes.firstIndex(where: { $0.id == rid }),
               let count = recipes[rIdx].useCount, count > 0 {
                recipes[rIdx].useCount = count - 1
            }
        } catch {
            dishMutationGeneration &+= 1
            if !pinnedDishes.contains(where: { $0.id == dish.id }) {
                let targetIdx = min(removedIndex ?? pinnedDishes.count, pinnedDishes.count)
                pinnedDishes.insert(dish, at: targetIdx)
            }
            if var current = self.meal {
                current.dishes = pinnedDishes
                current.status = previousMealStatus
                self.meal = current
            }
            errorMessage = error.localizedDescription
        }
    }

    func confirmMeal() async {
        guard meal != nil, !isConfirmingMeal else { return }
        if pinnedDishes.isEmpty {
            errorMessage = "先选一道菜再定下"
            return
        }
        while inFlightDishMutations > 0 {
            try? await Task.sleep(for: .milliseconds(40))
        }
        guard let latestMeal = self.meal, !pinnedDishes.isEmpty else { return }
        isConfirmingMeal = true
        defer { isConfirmingMeal = false }
        do {
            switch latestMeal.status {
            case .planning:
                let confirmed = try await mealService.confirm(id: latestMeal.id)
                dishMutationGeneration &+= 1
                self.meal = confirmed
                self.pinnedDishes = confirmed.dishes ?? self.pinnedDishes
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
