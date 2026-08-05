import Foundation

// 待写两句：UserDefaults 落盘，杀进程后首页仍能补评
enum PendingReviewStore {
    static let mealIdKey = "meal.pendingReviewMealId"
    static let collapsedKey = "meal.pendingReviewCollapsed"

    static func save(mealId: UInt, collapsed: Bool) {
        UserDefaults.standard.set(Int(mealId), forKey: mealIdKey)
        UserDefaults.standard.set(collapsed, forKey: collapsedKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: mealIdKey)
        UserDefaults.standard.removeObject(forKey: collapsedKey)
    }

    static func load() -> (mealId: UInt, collapsed: Bool)? {
        let id = UserDefaults.standard.integer(forKey: mealIdKey)
        guard id > 0 else { return nil }
        return (UInt(id), UserDefaults.standard.bool(forKey: collapsedKey))
    }
}

@MainActor
final class MealNowViewModel: ObservableObject {
    @Published var meal: MealSession?
    @Published var suggestions: [Recipe] = []
    @Published var frequents: [Recipe] = []
    @Published var isLoading: Bool = false
    @Published var loadFailed: Bool = false
    @Published var errorMessage: String?
    // 成功/轻提示 与 errorMessage 分通道 避免安心反馈像报错
    @Published var tipMessage: String?
    // confirm / complete 防重入
    @Published var isActing: Bool = false
    // 吃完后待评价：关掉 sheet 也不丢 首页 banner 可再打开；杀进程后可恢复
    @Published var pendingReviewMealId: UInt?
    // 轻量收起 banner 仍保留入口
    @Published var reviewBannerCollapsed: Bool = false

    private let mealService = MealService.shared
    private let recipeService = RecipeService.shared
    // 串行化 load / 改心情 避免慢请求覆盖新状态
    private var loadSeq: UInt = 0

    var dishes: [MealDish] {
        meal?.dishes ?? []
    }

    var dishCount: Int {
        dishes.count
    }

    // 当前这顿是否开着未过期的点菜房间
    var hasActiveDiningRoom: Bool {
        guard let meal,
              let code = meal.roomCode, !code.isEmpty,
              let exp = meal.roomExpiresAt else { return false }
        return exp > Date()
    }

    var mealReady: Bool {
        meal != nil && !loadFailed
    }

    func load(scene: MealScene, mood: Mood) async {
        loadSeq &+= 1
        let seq = loadSeq
        isLoading = true
        errorMessage = nil
        loadFailed = false
        defer {
            if seq == loadSeq { isLoading = false }
        }
        do {
            async let current = mealService.current(scene: scene, mood: mood)
            async let suggList = recipeService.list(.init(mood: mood, scene: scene, page: 1, pageSize: 3))
            async let freqList = recipeService.list(.init(page: 1, pageSize: 4))
            let (m, s, f) = try await (current, suggList, freqList)
            guard seq == loadSeq else { return }
            self.meal = m
            self.suggestions = s.items
            self.frequents = f.items
            restorePendingReview()
        } catch {
            guard seq == loadSeq else { return }
            loadFailed = true
            errorMessage = error.localizedDescription
            restorePendingReview()
        }
    }

    // 别的页面改了这一顿后轻量同步 只刷 meal 不动推荐位
    // 也做完成检测 + 对方加菜/定下的轻感知
    func refreshMeal(scene: MealScene, mood: Mood, selfUserId: UInt? = nil) async {
        if let m = try? await mealService.current(scene: scene, mood: mood) {
            await applyRemoteMeal(old: meal, new: m, selfUserId: selfUserId, broadcast: false)
        }
    }

    // 轮询静默同步 让另一台手机的改动几秒内自动出现 内容没变不动 UI
    func syncMeal(scene: MealScene, mood: Mood, selfUserId: UInt? = nil) async {
        guard let m = try? await mealService.current(scene: scene, mood: mood) else { return }
        if m.syncSignature != meal?.syncSignature {
            await applyRemoteMeal(old: meal, new: m, selfUserId: selfUserId, broadcast: true)
        }
    }

    private func applyRemoteMeal(old: MealSession?, new m: MealSession, selfUserId: UInt?, broadcast: Bool) async {
        await noticePartnerActivity(old: old, new: m, selfUserId: selfUserId)
        await detectCompletedByOther(old: old, new: m)
        meal = m
        if broadcast {
            AppNotifications.mealChanged()
        }
    }

    // 对方在同一顿上的动作：加菜 / 定下 / 重选 — 只 tip，不打断
    private func noticePartnerActivity(old: MealSession?, new m: MealSession, selfUserId: UInt?) async {
        guard let old, old.id == m.id else { return }

        // 状态变化优先（比加菜更「大事」）
        if old.status == .planning, m.status == .confirmed {
            tipMessage = "Ta 定下了 就这些"
            Haptics.success()
            return
        }
        if old.status == .confirmed, m.status == .cancelled {
            tipMessage = "Ta 又改主意了"
            Haptics.light()
            return
        }
        // completed 走 noteNeedsReview，这里不抢 tip

        let oldIds = Set((old.dishes ?? []).map(\.id))
        let newlyAdded = (m.dishes ?? []).filter { !oldIds.contains($0.id) }
        let byOther = newlyAdded.filter { dish in
            guard let by = dish.addedBy else { return true }
            guard let me = selfUserId else { return true }
            return by != me
        }
        guard !byOther.isEmpty else { return }

        if byOther.count == 1, let name = byOther.first?.recipeName, !name.isEmpty {
            tipMessage = "Ta 加了 \(name)"
        } else {
            tipMessage = "Ta 加了 \(byOther.count) 道菜"
        }
        Haptics.light()
    }

    // confirmed 的单被对方收掉:同 id 变 completed 直接提醒;换了新单要回查旧单
    // 确认是 completed 而非"重新选"的 cancelled 否则会提醒去评价一顿被取消的饭
    private func detectCompletedByOther(old: MealSession?, new m: MealSession) async {
        guard let old, old.status == .confirmed else { return }
        if m.id == old.id, m.status == .completed {
            noteNeedsReview(old.id)
            // 对方点的吃完：补一句人话，和补评条一起出现
            if tipMessage == nil {
                tipMessage = "Ta 说吃完了"
            }
        } else if m.id != old.id {
            if let detail = try? await mealService.detail(id: old.id), detail.status == .completed {
                noteNeedsReview(old.id)
                if tipMessage == nil {
                    tipMessage = "Ta 说吃完了"
                }
            }
        }
    }

    func noteNeedsReview(_ mealId: UInt) {
        pendingReviewMealId = mealId
        reviewBannerCollapsed = false
        PendingReviewStore.save(mealId: mealId, collapsed: false)
    }

    func clearPendingReview() {
        pendingReviewMealId = nil
        reviewBannerCollapsed = false
        PendingReviewStore.clear()
    }

    // 收起 banner 也落盘，杀进程后仍知道「有待写、已收起」
    func setReviewBannerCollapsed(_ collapsed: Bool) {
        reviewBannerCollapsed = collapsed
        if let id = pendingReviewMealId {
            PendingReviewStore.save(mealId: id, collapsed: collapsed)
        }
    }

    private func restorePendingReview() {
        guard let saved = PendingReviewStore.load() else { return }
        pendingReviewMealId = saved.mealId
        reviewBannerCollapsed = saved.collapsed
    }

    // 改心情时 bump loadSeq 让在途 load 结果作废 再写 meal + 刷推荐
    func applyMood(_ mood: Mood, scene: MealScene) async {
        loadSeq &+= 1
        let seq = loadSeq
        if let meal {
            do {
                let updated = try await mealService.update(id: meal.id, req: MealInput(scene: meal.scene, mood: mood))
                guard seq == loadSeq else { return }
                self.meal = updated
            } catch {
                guard seq == loadSeq else { return }
                errorMessage = error.localizedDescription
            }
        }
        do {
            async let suggList = recipeService.list(.init(mood: mood, scene: scene, page: 1, pageSize: 3))
            async let freqList = recipeService.list(.init(page: 1, pageSize: 4))
            let (s, f) = try await (suggList, freqList)
            guard seq == loadSeq else { return }
            suggestions = s.items
            frequents = f.items
        } catch {
            guard seq == loadSeq else { return }
            errorMessage = error.localizedDescription
        }
    }

    func addDish(_ recipe: Recipe) async {
        guard let meal else {
            errorMessage = loadFailed ? "没连上 下拉再试" : "再等一小会儿"
            return
        }
        if dishes.contains(where: { $0.recipeId == recipe.id }) {
            errorMessage = "这道已经在桌上了"
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
        // confirmed 至少留一道；清光请走「算了 重选」，别卡成空 confirmed
        if meal.status == .confirmed && dishCount <= 1 {
            errorMessage = "定了至少留一道 要重选就点「算了 重选」"
            return
        }
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
        guard let meal, !isActing else { return }
        isActing = true
        defer { isActing = false }
        do {
            self.meal = try await mealService.confirm(id: meal.id)
            Haptics.success()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func complete() async {
        guard let meal, !isActing else { return }
        if dishCount == 0 {
            errorMessage = "菜都没了 先留一道"
            return
        }
        isActing = true
        defer { isActing = false }
        do {
            self.meal = try await mealService.complete(id: meal.id)
            Haptics.success()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
