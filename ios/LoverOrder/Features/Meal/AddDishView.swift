import SwiftUI

// 加菜面板：直接输入、菜谱筛选、已选菜品。
struct AddDishView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var sourceHighlight

    let mealId: UInt
    var onChanged: () -> Void = {}

    @State private var customName: String = ""
    @State private var quickSource: QuickSource = .all
    @State private var recipes: [Recipe] = []
    @State private var pinnedDishes: [MealDish] = []
    @State private var isLoading: Bool = false
    @State private var isSubmittingCustom: Bool = false
    @State private var addingRecipeIDs: Set<UInt> = []
    @State private var removingDishIDs: Set<UInt> = []
    @State private var errorMessage: String?
    @State private var tipMessage: String?
    @State private var showCreateRecipe: Bool = false

    private var hasPendingChanges: Bool {
        isSubmittingCustom || !addingRecipeIDs.isEmpty || !removingDishIDs.isEmpty
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
                    inputSection
                    quickEntries
                    recommendSection
                    pinnedSection
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
            .task(id: quickSource) {
                isLoading = true
                await loadPinned()
                guard !Task.isCancelled else { return }
                await loadRecipes()
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showCreateRecipe) {
                RecipeEditView(mode: .create) { _ in
                    Task { await loadRecipes() }
                }
                .environmentObject(appState)
            }
            .onReceive(NotificationCenter.default.publisher(for: .mealChanged)) { _ in
                Task { await loadPinned() }
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

    // 已选区
    private var pinnedSection: some View {
        SectionCard {
            HStack {
                Text(pinnedDishes.isEmpty ? "还没点" : "桌上 \(pinnedDishes.count) 道了")
                    .font(AppFont.headline(15))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                if !pinnedDishes.isEmpty {
                    Text("点 − 去掉")
                        .font(AppFont.caption(11))
                        .foregroundStyle(Color.inkMuted)
                }
            }
            if pinnedDishes.isEmpty {
                Text("下面挑几道呗")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.inkMuted)
            } else {
                ForEach(pinnedDishes) { dish in
                    HStack(spacing: AppSpacing.md) {
                        DishThumb(name: dish.recipeName, image: dish.recipeImage)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dish.recipeName)
                                .font(AppFont.body(15))
                                .foregroundStyle(Color.inkPrimary)
                            if let note = dish.note, !note.isEmpty {
                                Text(note)
                                    .font(AppFont.caption())
                                    .foregroundStyle(Color.inkMuted)
                            }
                        }
                        Spacer()
                        Button {
                            Task { await remove(dish) }
                        } label: {
                            Group {
                                if removingDishIDs.contains(dish.id) {
                                    ProgressView().tint(Color.brandGreen)
                                } else {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(Color.inkMuted)
                                }
                            }
                            .frame(width: 44, height: 44)
                        }
                        .buttonStyle(SoftPressStyle())
                        .disabled(removingDishIDs.contains(dish.id))
                        .accessibilityLabel("移除" + dish.recipeName)
                    }
                    .transition(.opacity)
                }
            }
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel("想吃什么")
            HStack(spacing: 8) {
                TextField("直接写个菜名", text: $customName)
                    .font(AppFont.body(15))
                    .submitLabel(.done)
                    .onSubmit { Task { await addCustom() } }
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))
                Button { Task { await addCustom() } } label: {
                    Group {
                        if isSubmittingCustom { ProgressView().tint(.white) }
                        else { ProductIcon(kind: .add) }
                    }
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.actionInk, in: RoundedRectangle(cornerRadius: 16))
                    .opacity(customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.35 : 1)
                }
                .buttonStyle(SoftPressStyle())
                .disabled(customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmittingCustom)
                .accessibilityLabel("加入这一顿")
            }
        }
    }

    private var quickEntries: some View {
        HStack(spacing: 8) {
            ForEach(QuickSource.allCases) { source in
                Button { select(source) } label: {
                    Text(source.label)
                        .font(AppFont.body(14))
                        .foregroundStyle(quickSource == source ? Color.brandGreen : Color.inkMuted)
                        .padding(.horizontal, 18)
                        .frame(height: 44)
                        .background {
                            if quickSource == source {
                                Capsule()
                                    .fill(Color.paperGreen)
                                    .matchedGeometryEffect(id: "source", in: sourceHighlight)
                            }
                        }
                }
                .buttonStyle(SoftPressStyle())
                .accessibilityAddTraits(quickSource == source ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.86), value: quickSource)
    }

    // 6 个推荐网格
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
            if recipes.isEmpty && !isLoading {
                Text(emptyHint)
                    .font(AppFont.caption())
                    .foregroundStyle(Color.inkMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.xl)
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            } else {
                let columns = Array(repeating: GridItem(.flexible(), spacing: AppSpacing.md), count: 2)
                LazyVGrid(columns: columns, spacing: AppSpacing.md) {
                    ForEach(recipes.prefix(6)) { recipe in
                        let onTable = alreadyOnTable(recipe)
                        RecipeCircleCard(recipe: recipe, alreadyAdded: onTable, isAdding: addingRecipeIDs.contains(recipe.id)) {
                            Task { await addRecipe(recipe) }
                        }
                    }
                }
            }
        }
    }

    private var alsoSection: some View {
        HStack {
            Button { Task { await batchFavorite() } } label: {
                Label("收藏已选菜谱", systemImage: "heart")
            }
            Spacer()
            Button { showCreateRecipe = true } label: {
                Label("新建菜谱", systemImage: "square.and.pencil")
            }
        }
        .font(AppFont.body(13))
        .foregroundStyle(Color.brandGreen)
        .frame(minHeight: 44)
        .buttonStyle(SoftPressStyle())
    }

    private var bottomBar: some View {
        PrimaryButton(title: "挑好了", icon: "checkmark") {
            onChanged()
            dismiss()
        }
        .disabled(hasPendingChanges)
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
        .background(Color.appBackground)
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
        do {
            let m = try await MealService.shared.detail(id: mealId)
            guard !Task.isCancelled else { return }
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
            var query = RecipeListQuery(page: 1, pageSize: 30)
            switch source {
            case .favorite:
                query.favorite = true
            case .all:
                query.mood = appState.currentMood
                query.scene = .household
            case .recent:
                break
            }
            let result = try await RecipeService.shared.list(query)
            guard !Task.isCancelled, source == quickSource else { return }
            recipes = sort(result.items)
        } catch {
            guard !Task.isCancelled, source == quickSource else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func sort(_ items: [Recipe]) -> [Recipe] {
        switch quickSource {
        case .recent:
            return items.sorted { lhs, rhs in
                (lhs.lastUsedAt ?? .distantPast) > (rhs.lastUsedAt ?? .distantPast)
            }
        default:
            return items
        }
    }

    private func addRecipe(_ recipe: Recipe) async {
        guard !addingRecipeIDs.contains(recipe.id) else { return }
        if alreadyOnTable(recipe) {
            tipMessage = "这道已经在桌上了"
            Haptics.light()
            return
        }
        addingRecipeIDs.insert(recipe.id)
        defer { addingRecipeIDs.remove(recipe.id) }
        do {
            _ = try await MealService.shared.addDish(mealId: mealId, dish: DishInput(recipeId: recipe.id))
            await loadPinned()
            onChanged()
            Haptics.light()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addCustom() async {
        let name = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !isSubmittingCustom else { return }
        isSubmittingCustom = true
        defer { isSubmittingCustom = false }
        do {
            _ = try await MealService.shared.addDish(
                mealId: mealId,
                dish: DishInput(name: name)
            )
            customName = ""
            await loadPinned()
            onChanged()
            Haptics.light()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func remove(_ dish: MealDish) async {
        guard !removingDishIDs.contains(dish.id) else { return }
        removingDishIDs.insert(dish.id)
        defer { removingDishIDs.remove(dish.id) }
        do {
            try await MealService.shared.removeDish(mealId: mealId, dishId: dish.id)
            await loadPinned()
            onChanged()
        } catch {
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
            errorMessage = newlyFavored > 0 ? "已加入收藏 \(newlyFavored) 道" : "都已经在收藏里啦"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
