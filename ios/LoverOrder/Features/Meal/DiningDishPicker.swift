import SwiftUI

// 聚餐点菜：所有参与者共用主家菜单，支持桌上已选同步、实时搜索、主家常做排序与报菜名
struct DiningDishPicker: View {
    let mealId: UInt
    var initialDishes: [MealDish] = []
    var currentUserId: UInt? = nil
    var hostName: String? = nil
    var onChanged: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var sortHighlight

    @State private var tableDishes: [MealDish]
    @State private var recipes: [Recipe]?
    @State private var recipesLoadID = 0
    @State private var keyword = ""
    @State private var sortMode: DiningRecipeSort = .all
    @State private var isLoading = false
    @State private var isSubmittingCustom = false
    @State private var addingRecipeIDs: Set<UInt> = []
    @State private var removingDishIDs: Set<UInt> = []
    @State private var errorMessage: String?
    @State private var tipMessage: String?

    init(
        mealId: UInt,
        initialDishes: [MealDish] = [],
        currentUserId: UInt? = nil,
        hostName: String? = nil,
        onChanged: @escaping () -> Void = {}
    ) {
        self.mealId = mealId
        self.initialDishes = initialDishes
        self.currentUserId = currentUserId
        self.hostName = hostName
        self.onChanged = onChanged
        _tableDishes = State(initialValue: initialDishes)
    }

    enum DiningRecipeSort: String, CaseIterable, Identifiable {
        case all
        case frequent

        var id: String { rawValue }

        var label: String {
            switch self {
            case .all: return "全部"
            case .frequent: return "主家常做"
            }
        }
    }

    private var hasPendingChanges: Bool {
        isSubmittingCustom || !addingRecipeIDs.isEmpty || !removingDishIDs.isEmpty
    }

    private var trimmedKeyword: String {
        keyword.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredRecipes: [Recipe] {
        let recipes = recipes ?? []
        let base: [Recipe]
        if trimmedKeyword.isEmpty {
            base = recipes
        } else {
            let q = trimmedKeyword.lowercased()
            base = recipes.filter { recipe in
                recipe.name.lowercased().contains(q)
                    || (recipe.description?.lowercased().contains(q) ?? false)
                    || (recipe.tags?.contains(where: { $0.lowercased().contains(q) }) ?? false)
            }
        }
        switch sortMode {
        case .all:
            return base
        case .frequent:
            return base.sorted { lhs, rhs in
                let lhsCount = lhs.useCount ?? 0
                let rhsCount = rhs.useCount ?? 0
                if lhsCount != rhsCount { return lhsCount > rhsCount }
                return (lhs.lastUsedAt ?? .distantPast) > (rhs.lastUsedAt ?? .distantPast)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    header
                    if !tableDishes.isEmpty {
                        pinnedStrip
                    }
                    inputSection
                    sortFilterBar
                    recipesGridSection
                    Color.clear.frame(height: 16)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
            .task {
                async let recipesRefresh: () = loadRecipes()
                await refreshTableOnly()
                await recipesRefresh
            }
            .onReceive(NotificationCenter.default.publisher(for: .mealChanged)) { _ in
                Task { await refreshTableOnly() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .recipesChanged)) { _ in
                Task { await loadRecipes() }
            }
            .toolbar(.hidden, for: .navigationBar)
            .toast($errorMessage)
            .tipToast($tipMessage)
        }
        .interactiveDismissDisabled(hasPendingChanges)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("挑菜")
                    .font(AppFont.title(24))
                    .foregroundStyle(Color.inkPrimary)
                if let hostName, !hostName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("来自 \(hostName) 家的菜单")
                        .font(AppFont.caption(12))
                        .foregroundStyle(Color.inkMuted)
                }
            }
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
            .accessibilityLabel("关闭挑菜")
        }
    }

    private var pinnedStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("桌上 \(tableDishes.count) 道")
                    .font(AppFont.headline(14))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                Text("点 × 可移出桌上菜品")
                    .font(AppFont.caption(11))
                    .foregroundStyle(Color.inkMuted)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tableDishes) { dish in
                        let isMine = currentUserId != nil && dish.addedBy == currentUserId
                        HStack(spacing: 6) {
                            DishThumb(name: dish.recipeName, image: dish.recipeImage, size: 22, radius: 11)
                            Text(dish.recipeName)
                                .font(AppFont.body(13))
                                .foregroundStyle(Color.inkPrimary)
                                .lineLimit(1)
                            if !isMine, let adder = dish.adder {
                                AvatarView(user: adder, size: 18)
                            }
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
                                .frame(width: 22, height: 22)
                                .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .disabled(removingDishIDs.contains(dish.id))
                            .accessibilityLabel("移出" + dish.recipeName)
                        }
                        .padding(.leading, 6)
                        .padding(.trailing, 8)
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

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel("搜菜谱或直接报菜名")
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.inkMuted)
                    TextField("搜主家菜谱，或写个想吃的菜名", text: $keyword)
                        .font(AppFont.body(15))
                        .submitLabel(.done)
                        .onSubmit { Task { await addCustom() } }
                    if !keyword.isEmpty {
                        Button {
                            keyword = ""
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
                    .opacity(trimmedKeyword.isEmpty ? 0.32 : 1)
                }
                .buttonStyle(SoftPressStyle())
                .disabled(trimmedKeyword.isEmpty || isSubmittingCustom)
                .accessibilityLabel("报菜名加入")
            }
        }
    }

    private var sortFilterBar: some View {
        let obsidian = Color(red: 0.067, green: 0.067, blue: 0.075)
        return HStack(spacing: 8) {
            ForEach(DiningRecipeSort.allCases) { mode in
                let isSelected = sortMode == mode
                Button {
                    guard sortMode != mode else { return }
                    Haptics.light()
                    sortMode = mode
                } label: {
                    Text(mode.label)
                        .font(.system(size: 13.5, weight: isSelected ? .semibold : .medium, design: .rounded))
                        .foregroundStyle(isSelected ? .white : Color.inkSecondary)
                        .padding(.horizontal, 16)
                        .frame(height: 36)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(obsidian)
                                    .matchedGeometryEffect(id: "diningSort", in: sortHighlight)
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
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.86), value: sortMode)
    }

    @ViewBuilder
    private var recipesGridSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("主家的菜谱")
                    .font(AppFont.headline(15))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                if isLoading {
                    ProgressView().tint(Color.brandGreen).controlSize(.small)
                }
            }
            if filteredRecipes.isEmpty && !isLoading {
                VStack(spacing: AppSpacing.md) {
                    Text(trimmedKeyword.isEmpty ? "这家还没有录入菜谱，可以在上面输入菜名直接点" : "主家菜谱里没找到「\(trimmedKeyword)」")
                        .font(AppFont.caption(13))
                        .foregroundStyle(Color.inkMuted)
                        .multilineTextAlignment(.center)
                    if !trimmedKeyword.isEmpty {
                        Button {
                            Task { await addCustom() }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .bold))
                                Text("直接报菜名加入「\(trimmedKeyword)」")
                                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .frame(height: 38)
                            .background(Color.actionInk, in: Capsule())
                        }
                        .buttonStyle(SoftPressStyle())
                        .disabled(isSubmittingCustom)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xl)
                .padding(.horizontal, AppSpacing.md)
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            } else {
                let columns = Array(repeating: GridItem(.flexible(), spacing: AppSpacing.md), count: 2)
                LazyVGrid(columns: columns, spacing: AppSpacing.md) {
                    ForEach(filteredRecipes) { recipe in
                        let existing = tableDishes.first(where: { $0.recipeId == recipe.id })
                        let canRemove = existing != nil
                        let updating = addingRecipeIDs.contains(recipe.id) || (existing.map { removingDishIDs.contains($0.id) } ?? false)
                        RecipeCircleCard(
                            recipe: recipe,
                            alreadyAdded: existing != nil,
                            allowToggleRemove: canRemove,
                            isAdding: updating
                        ) {
                            if let existing {
                                Task { await remove(existing) }
                            } else {
                                Task { await addRecipe(recipe) }
                            }
                        }
                    }
                }
            }
        }
    }

    private var bottomBar: some View {
        PrimaryButton(
            title: tableDishes.isEmpty ? "挑好了" : "挑好了 · 桌上 \(tableDishes.count) 道",
            icon: "checkmark"
        ) {
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

    private func refreshTableOnly() async {
        if let currentMeal = try? await DiningService.shared.current(mealId: mealId) {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                tableDishes = currentMeal.dishes ?? []
            }
        }
    }

    @MainActor
    private func loadRecipes() async {
        recipesLoadID += 1
        let loadID = recipesLoadID
        isLoading = recipes == nil
        defer {
            if loadID == recipesLoadID { isLoading = false }
        }
        do {
            let latest = try await DiningService.shared.recipes(mealId: mealId)
            guard loadID == recipesLoadID else { return }
            recipes = latest
        } catch {
            guard loadID == recipesLoadID, recipes == nil else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func addRecipe(_ recipe: Recipe) async {
        guard !addingRecipeIDs.contains(recipe.id) else { return }
        if tableDishes.contains(where: { $0.recipeId == recipe.id }) {
            tipMessage = "这道已经在桌上了"
            Haptics.light()
            return
        }
        addingRecipeIDs.insert(recipe.id)
        defer { addingRecipeIDs.remove(recipe.id) }
        do {
            let updatedMeal = try await DiningService.shared.addDish(
                mealId: mealId,
                dish: DishInput(recipeId: recipe.id)
            )
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
                tableDishes = updatedMeal.dishes ?? tableDishes
            }
            CanvasSoundEngine.shared.playDishPick()
            Haptics.medium()
            onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addCustom() async {
        let name = trimmedKeyword
        guard !name.isEmpty, !isSubmittingCustom else { return }
        isSubmittingCustom = true
        defer { isSubmittingCustom = false }
        do {
            let updatedMeal = try await DiningService.shared.addDish(
                mealId: mealId,
                dish: DishInput(name: name)
            )
            keyword = ""
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
                tableDishes = updatedMeal.dishes ?? tableDishes
            }
            CanvasSoundEngine.shared.playDishPick()
            Haptics.medium()
            onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func remove(_ dish: MealDish) async {
        guard !removingDishIDs.contains(dish.id) else { return }
        removingDishIDs.insert(dish.id)
        defer { removingDishIDs.remove(dish.id) }
        do {
            try await DiningService.shared.removeDish(mealId: mealId, dishId: dish.id)
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
                tableDishes.removeAll { $0.id == dish.id }
            }
            CanvasSoundEngine.shared.playDeletePoof()
            Haptics.soft()
            onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
