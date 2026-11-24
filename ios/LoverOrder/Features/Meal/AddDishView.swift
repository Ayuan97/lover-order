import SwiftUI

// 加菜面板：直接输入、菜谱筛选、已选菜品。
struct AddDishView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var sourceHighlight

    let mealId: UInt
    var onChanged: () -> Void = {}

    private static let optimisticDishIDThreshold: UInt = UInt.max / 2
    @State private var nextOptimisticDishID: UInt = UInt.max - 1
    @State private var customName: String = ""
    @State private var quickSource: QuickSource = .all
    @State private var recipes: [Recipe] = []
    @State private var pinnedDishes: [MealDish] = []
    @State private var isLoading: Bool = false
    @State private var isSubmittingCustom: Bool = false
    @State private var addingRecipeIDs: Set<UInt> = []
    @State private var cancelledOptimisticRecipeIDs: Set<UInt> = []
    @State private var removingDishIDs: Set<UInt> = []
    @State private var errorMessage: String?
    @State private var tipMessage: String?
    @State private var showCreateRecipe: Bool = false

    private var hasPendingChanges: Bool {
        isSubmittingCustom || !addingRecipeIDs.isEmpty || !removingDishIDs.isEmpty
    }

    private var trimmedQuery: String {
        customName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredRecipes: [Recipe] {
        guard !trimmedQuery.isEmpty else { return recipes }
        let q = trimmedQuery.lowercased()
        return recipes.filter { recipe in
            recipe.name.lowercased().contains(q)
                || (recipe.description?.lowercased().contains(q) ?? false)
                || (recipe.tags?.contains(where: { $0.lowercased().contains(q) }) ?? false)
        }
    }

    enum QuickSource: String, CaseIterable, Identifiable {
        case all
        case favorite
        case recent

        var id: String { rawValue }

        var label: String {
            switch self {
            case .all: return "全部"
            case .favorite: return "爱吃的"
            case .recent: return "常做的"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    header
                    if !pinnedDishes.isEmpty {
                        pinnedStrip
                    }
                    inputSection
                    quickEntries
                    recommendSection
                    if pinnedDishes.isEmpty {
                        pinnedEmptyHint
                    }
                    alsoSection
                    Color.clear.frame(height: 16)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
            .onAppear {
                if recipes.isEmpty, quickSource != .favorite,
                   let cached = MenuLocalCache.load(householdId: appState.currentUser?.householdId ?? appState.household?.id) {
                    recipes = sort(cached.recipes)
                    RemoteImageCache.shared.prefetch(paths: cached.recipes.map(\.coverImage))
                }
            }
            .task(id: quickSource) {
                if recipes.isEmpty {
                    isLoading = true
                }
                await loadPinned()
                guard !Task.isCancelled else { return }
                await loadRecipes()
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showCreateRecipe) {
                RecipeEditView(mode: .create) { saved in
                    if quickSource != .favorite {
                        recipes.removeAll { $0.id == saved.id }
                        recipes.insert(saved, at: 0)
                        recipes = sort(recipes)
                    }
                    Task { await loadRecipes() }
                }
                .environmentObject(appState)
            }
            .onReceive(NotificationCenter.default.publisher(for: .mealChanged)) { _ in
                guard !hasPendingChanges else { return }
                Task { await loadPinned() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .recipesChanged)) { _ in
                Task { await loadRecipes() }
            }
            .toast($errorMessage)
            .tipToast($tipMessage)
        }
        .interactiveDismissDisabled(hasPendingChanges)
    }

    private var header: some View {
        HStack {
            Text("加菜")
                .font(AppFont.title(24))
                .foregroundStyle(Color.inkPrimary)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.inkSecondary)
                    .frame(width: 44, height: 44)
                    .background(Color.cardBackground, in: Circle())
            }
            .buttonStyle(SoftPressStyle())
            .disabled(hasPendingChanges)
            .opacity(hasPendingChanges ? 0.4 : 1)
            .accessibilityLabel("关闭加菜")
        }
    }

    // 置顶已点菜单条
    private var pinnedStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("桌上 \(pinnedDishes.count) 道")
                    .font(AppFont.headline(14))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                Text("点 × 移除")
                    .font(AppFont.caption(11))
                    .foregroundStyle(Color.inkMuted)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(pinnedDishes) { dish in
                        HStack(spacing: 6) {
                            DishThumb(name: dish.recipeName, image: dish.recipeImage, size: 22, radius: 11)
                            Text(dish.recipeName)
                                .font(AppFont.body(13))
                                .foregroundStyle(Color.inkPrimary)
                                .lineLimit(1)
                            Button {
                                Task { await remove(dish) }
                            } label: {
                                Group {
                                    if removingDishIDs.contains(dish.id) {
                                        ProgressView().tint(Color.brandGreen).controlSize(.mini)
                                    } else {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(Color.inkMuted)
                                    }
                                }
                                .frame(width: 30, height: 32)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(removingDishIDs.contains(dish.id))
                            .accessibilityLabel("移除" + dish.recipeName)
                        }
                        .padding(.leading, 6)
                        .padding(.trailing, 4)
                        .frame(height: 34)
                        .background(Color.cardBackground, in: Capsule())
                        .overlay {
                            Capsule().strokeBorder(Color.dividerLine.opacity(0.85), lineWidth: 0.8)
                        }
                        .transition(.opacity)
                    }
                }
            }
        }
    }

    private var pinnedEmptyHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "fork.knife")
                .font(.system(size: 13))
                .foregroundStyle(Color.brandGreen)
            Text("桌上还是空的，上面搜一道或直接写菜名加进来")
                .font(AppFont.caption())
                .foregroundStyle(Color.inkMuted)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 12)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel("搜菜谱或加菜名")
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.inkMuted)
                    TextField("搜菜谱，或直接写菜名加菜", text: $customName)
                        .font(AppFont.body(15))
                        .submitLabel(.done)
                        .onSubmit { Task { await addCustom() } }
                    if !customName.isEmpty {
                        Button {
                            customName = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.inkMuted.opacity(0.75))
                                .frame(width: 30, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("清空输入")
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(Color.cardBackground, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(Color.dividerLine.opacity(0.8), lineWidth: 0.8)
                }

                Button { Task { await addCustom() } } label: {
                    Group {
                        if isSubmittingCustom { ProgressView().tint(.white) }
                        else { ProductIcon(kind: .add) }
                    }
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Color.actionInk, in: Circle())
                    .opacity(trimmedQuery.isEmpty ? 0.32 : 1)
                }
                .buttonStyle(SoftPressStyle())
                .disabled(trimmedQuery.isEmpty || isSubmittingCustom)
                .accessibilityLabel("加入这一顿")
            }
        }
    }

    private var quickEntries: some View {
        let obsidian = Color(red: 0.067, green: 0.067, blue: 0.075)
        return HStack(spacing: 8) {
            ForEach(QuickSource.allCases) { source in
                let isSelected = quickSource == source
                Button { select(source) } label: {
                    Text(source.label)
                        .font(.system(size: 13.5, weight: isSelected ? .semibold : .medium, design: .rounded))
                        .foregroundStyle(isSelected ? .white : Color.inkSecondary)
                        .padding(.horizontal, 16)
                        .frame(height: 36)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(obsidian)
                                    .matchedGeometryEffect(id: "source", in: sourceHighlight)
                            } else {
                                Capsule()
                                    .fill(Color.cardBackground)
                            }
                        }
                        .overlay {
                            if !isSelected {
                                Capsule()
                                    .strokeBorder(Color.dividerLine.opacity(0.85), lineWidth: 0.7)
                            }
                        }
                }
                .buttonStyle(SoftPressStyle())
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.86), value: quickSource)
    }

    // 菜谱列表网格
    @ViewBuilder
    private var recommendSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("从菜谱里选")
                    .font(AppFont.headline(15))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                if isLoading {
                    ProgressView().tint(Color.brandGreen).controlSize(.small)
                }
            }
            if filteredRecipes.isEmpty && !isLoading {
                Text(trimmedQuery.isEmpty ? emptyHint : "菜谱里没找到「\(trimmedQuery)」，点右侧 + 可直接加菜")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.inkMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.xl)
                    .padding(.horizontal, AppSpacing.md)
                    .multilineTextAlignment(.center)
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            } else {
                let columns = Array(repeating: GridItem(.flexible(), spacing: AppSpacing.md), count: 2)
                LazyVGrid(columns: columns, spacing: AppSpacing.md) {
                    ForEach(filteredRecipes) { recipe in
                        let pinned = pinnedDishes.first(where: { $0.recipeId == recipe.id })
                        RecipeCircleCard(
                            recipe: recipe,
                            alreadyAdded: pinned != nil,
                            allowToggleRemove: true,
                            isAdding: false
                        ) {
                            if let pinned {
                                Task { await remove(pinned) }
                            } else {
                                Task { await addRecipe(recipe) }
                            }
                        }
                    }
                }
            }
        }
    }

    private var alsoSection: some View {
        HStack(spacing: 10) {
            Button { Task { await batchFavorite() } } label: {
                Label("收藏已选菜谱", systemImage: "heart")
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(Color.cardBackground, in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(Color.dividerLine, lineWidth: 0.8)
                    }
            }
            Spacer()
            Button { showCreateRecipe = true } label: {
                Label("新建菜谱", systemImage: "square.and.pencil")
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(Color.cardBackground, in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(Color.dividerLine, lineWidth: 0.8)
                    }
            }
        }
        .font(AppFont.body(13))
        .foregroundStyle(Color.brandGreen)
        .frame(minHeight: 44)
        .buttonStyle(SoftPressStyle())
    }

    private var bottomBar: some View {
        PrimaryButton(title: pinnedDishes.isEmpty ? "挑好了" : "挑好了 · \(pinnedDishes.count) 道", icon: "checkmark") {
            onChanged()
            dismiss()
        }
        .disabled(hasPendingChanges)
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
        .background(Color.appBackground)
        .overlay(alignment: .top) {
            Divider().overlay(Color.dividerLine.opacity(0.6))
        }
    }

    private var emptyHint: String {
        switch quickSource {
        case .favorite: return "还没有爱吃的 详情里点 ❤ 就行"
        case .recent: return "多吃几顿 常做的会出现"
        default: return "菜单里还没有"
        }
    }

    private func alreadyOnTable(_ recipe: Recipe) -> Bool {
        pinnedDishes.contains { $0.recipeId == recipe.id }
    }

    private func select(_ source: QuickSource) {
        guard quickSource != source else { return }
        Haptics.light()
        quickSource = source
    }

    private func loadPinned() async {
        guard !hasPendingChanges else { return }
        do {
            let m = try await MealService.shared.detail(id: mealId)
            guard !Task.isCancelled, !hasPendingChanges else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
                pinnedDishes = m.dishes ?? []
            }
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func loadRecipes() async {
        let source = quickSource
        isLoading = true
        defer {
            if !Task.isCancelled && source == quickSource { isLoading = false }
        }
        do {
            var query = RecipeListQuery(page: 1, pageSize: 100)
            switch source {
            case .favorite:
                query.favorite = true
            case .all, .recent:
                break
            }
            let result = try await RecipeService.shared.list(query)
            guard !Task.isCancelled, source == quickSource else { return }
            recipes = sort(result.items)
            RemoteImageCache.shared.prefetch(paths: result.items.map(\.coverImage))
        } catch {
            guard !Task.isCancelled, !error.isCancellationError, source == quickSource else { return }
            if recipes.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func sort(_ items: [Recipe]) -> [Recipe] {
        switch quickSource {
        case .recent:
            return items.sorted { lhs, rhs in
                let lhsCount = lhs.useCount ?? 0
                let rhsCount = rhs.useCount ?? 0
                if lhsCount != rhsCount { return lhsCount > rhsCount }
                return (lhs.lastUsedAt ?? .distantPast) > (rhs.lastUsedAt ?? .distantPast)
            }
        default:
            return items
        }
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

    private func makeOptimisticDish(for recipe: Recipe) -> MealDish {
        MealDish(
            id: allocOptimisticDishID(),
            mealSessionId: mealId,
            recipeId: recipe.id,
            recipeName: recipe.name,
            recipeImage: recipe.coverImage,
            recipeCutoutImage: recipe.cutoutImage,
            note: nil,
            sortOrder: pinnedDishes.count,
            addedBy: appState.currentUser?.id,
            adder: appState.currentUser
        )
    }

    private func addRecipe(_ recipe: Recipe) async {
        if alreadyOnTable(recipe) {
            tipMessage = "这道已经在桌上了"
            Haptics.light()
            return
        }
        if addingRecipeIDs.contains(recipe.id) {
            if cancelledOptimisticRecipeIDs.remove(recipe.id) != nil {
                let restored = makeOptimisticDish(for: recipe)
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                    pinnedDishes.append(restored)
                }
                CanvasSoundEngine.shared.playDishPick()
                Haptics.medium()
            }
            return
        }

        let optimisticDish = makeOptimisticDish(for: recipe)
        addingRecipeIDs.insert(recipe.id)
        cancelledOptimisticRecipeIDs.remove(recipe.id)
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
            pinnedDishes.append(optimisticDish)
        }
        CanvasSoundEngine.shared.playDishPick()
        Haptics.medium()

        defer { addingRecipeIDs.remove(recipe.id) }
        do {
            let created = try await MealService.shared.addDish(mealId: mealId, dish: DishInput(recipeId: recipe.id))
            if cancelledOptimisticRecipeIDs.remove(recipe.id) != nil {
                pinnedDishes.removeAll { $0.recipeId == recipe.id }
                removingDishIDs.insert(created.id)
                defer { removingDishIDs.remove(created.id) }
                try? await MealService.shared.removeDish(mealId: mealId, dishId: created.id)
                onChanged()
                return
            }
            if let idx = pinnedDishes.firstIndex(where: { $0.recipeId == recipe.id }) {
                pinnedDishes[idx] = created
            } else {
                pinnedDishes.append(created)
            }
            onChanged()
        } catch {
            cancelledOptimisticRecipeIDs.remove(recipe.id)
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                pinnedDishes.removeAll { $0.id == optimisticDish.id }
            }
            errorMessage = error.localizedDescription
        }
    }

    private func addCustom() async {
        let name = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !isSubmittingCustom else { return }
        isSubmittingCustom = true
        customName = ""
        CanvasSoundEngine.shared.playDishPick()
        Haptics.medium()
        defer { isSubmittingCustom = false }
        do {
            let created = try await MealService.shared.addDish(
                mealId: mealId,
                dish: DishInput(name: name)
            )
            if !pinnedDishes.contains(where: { $0.id == created.id }) {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                    pinnedDishes.append(created)
                }
            }
            onChanged()
        } catch {
            customName = name
            errorMessage = error.localizedDescription
        }
    }

    private func remove(_ dish: MealDish) async {
        if dish.id >= Self.optimisticDishIDThreshold {
            if let rid = dish.recipeId {
                cancelledOptimisticRecipeIDs.insert(rid)
            }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                pinnedDishes.removeAll { $0.id == dish.id || (dish.recipeId != nil && $0.recipeId == dish.recipeId) }
            }
            CanvasSoundEngine.shared.playDeletePoof()
            Haptics.soft()
            return
        }

        guard !removingDishIDs.contains(dish.id) else { return }
        let removedIndex = pinnedDishes.firstIndex(where: { $0.id == dish.id })
        removingDishIDs.insert(dish.id)
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
            pinnedDishes.removeAll { $0.id == dish.id }
        }
        CanvasSoundEngine.shared.playDeletePoof()
        Haptics.soft()

        defer { removingDishIDs.remove(dish.id) }
        do {
            try await MealService.shared.removeDish(mealId: mealId, dishId: dish.id)
            onChanged()
        } catch {
            if !pinnedDishes.contains(where: { $0.id == dish.id }) {
                let targetIdx = min(removedIndex ?? pinnedDishes.count, pinnedDishes.count)
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                    pinnedDishes.insert(dish, at: targetIdx)
                }
            }
            errorMessage = error.localizedDescription
        }
    }

    // 把当前已选未收藏的菜谱批量加入收藏
    // 接口是 toggle 必须先查已收藏的跳过 否则会把它们反向取消
    private func batchFavorite() async {
        do {
            let favored = try await RecipeService.shared.list(.init(favorite: true, page: 1, pageSize: 100))
            let favoredIds = Set(favored.items.map { $0.id })
            var newlyFavored = 0
            for dish in pinnedDishes {
                guard let rid = dish.recipeId, !favoredIds.contains(rid) else { continue }
                if (try? await RecipeService.shared.toggleFavorite(id: rid)) == true {
                    newlyFavored += 1
                }
            }
            tipMessage = newlyFavored > 0 ? "已加入收藏 \(newlyFavored) 道" : "都已经在收藏里啦"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
