import SwiftUI

// 添加菜品挑菜面板：已选 + 输入 + 4 列快速入口 + 6 列推荐 + 也可以 + 底部完成
struct AddDishView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let mealId: UInt
    var onChanged: () -> Void = {}

    @State private var customName: String = ""
    @State private var quickSource: QuickSource = .all
    @State private var recipes: [Recipe] = []
    @State private var pinnedDishes: [MealDish] = []
    @State private var isLoading: Bool = false
    @State private var isSubmittingCustom: Bool = false
    @State private var errorMessage: String?
    @State private var showCreateRecipe: Bool = false

    enum QuickSource: String, CaseIterable, Identifiable {
        case custom
        case all
        case favorite
        case recent

        var id: String { rawValue }

        var label: String {
            switch self {
            case .custom: return "自定义菜品"
            case .all: return "从图鉴选"
            case .favorite: return "收藏精选"
            case .recent: return "历史常用"
            }
        }

        var icon: String {
            switch self {
            case .custom: return "pencil"
            case .all: return "book"
            case .favorite: return "heart"
            case .recent: return "clock"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    header
                    pinnedSection
                    inputSection
                    quickEntries
                    recommendSection
                    alsoSection
                    Color.clear.frame(height: 80)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
            .task {
                await loadPinned()
                await loadRecipes()
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showCreateRecipe) {
                RecipeEditView(mode: .create) { _ in
                    Task { await loadRecipes() }
                }
                .environmentObject(appState)
            }
            .toast($errorMessage)
        }
    }

    // 头部
    private var header: some View {
        VStack(spacing: AppSpacing.xs) {
            HStack(spacing: 6) {
                Text("添加菜品")
                    .font(AppFont.title(26))
                    .foregroundStyle(Color.inkPrimary)
                Image(systemName: "heart.fill")
                    .foregroundStyle(Color.brandGreen)
                    .font(.system(size: 13))
            }
            Text("把想吃的菜加入这一顿")
                .font(AppFont.body())
                .foregroundStyle(Color.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .foregroundStyle(Color.inkSecondary)
                    .background(Color.cardBackground)
                    .clipShape(Circle())
                    .capsuleHairline()
            }
        }
        .padding(.vertical, AppSpacing.sm)
    }

    // 已选区
    private var pinnedSection: some View {
        SectionCard {
            HStack {
                Text("这一顿想加 \(pinnedDishes.count) 道菜")
                    .font(AppFont.headline(15))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                if !pinnedDishes.isEmpty {
                    Text("点击右侧 - 移除")
                        .font(AppFont.caption(11))
                        .foregroundStyle(Color.inkMuted)
                }
            }
            if pinnedDishes.isEmpty {
                Text("还没选 在下方挑挑")
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
                            Image(systemName: "minus.circle")
                                .foregroundStyle(Color.inkMuted)
                        }
                    }
                }
            }
        }
    }

    // 输入直加
    private var inputSection: some View {
        HStack(spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "fork.knife")
                    .foregroundStyle(Color.inkMuted)
                TextField("可输入菜名快速添加", text: $customName)
                    .submitLabel(.done)
                    .onSubmit {
                        Task { await addCustom() }
                    }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(Color.cardBackground)
            .clipShape(Capsule())
            .capsuleHairline()

            Button {
                Task { await addCustom() }
            } label: {
                Text(isSubmittingCustom ? "加入中" : "加入")
                    .font(AppFont.body(14))
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.sm)
                    .foregroundStyle(.white)
                    .background(Color.brandGreen.opacity(customName.isEmpty ? 0.4 : 1))
                    .clipShape(Capsule())
            }
            .disabled(customName.isEmpty || isSubmittingCustom)
        }
    }

    // 4 列快速入口
    private var quickEntries: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("快速添加")
                .font(AppFont.headline(15))
                .foregroundStyle(Color.inkPrimary)
            HStack(spacing: AppSpacing.sm) {
                ForEach(QuickSource.allCases) { source in
                    Button {
                        select(source)
                    } label: {
                        VStack(spacing: AppSpacing.xs) {
                            Image(systemName: source.icon)
                                .font(.system(size: 18, weight: .light))
                                .foregroundStyle(quickSource == source ? .white : Color.brandGreen)
                                .frame(width: 44, height: 44)
                                .background(quickSource == source ? Color.brandGreen : Color.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                                .hairline(AppRadius.md, color: quickSource == source ? .clear : Color.dividerLine.opacity(0.7))
                            Text(source.label)
                                .font(AppFont.caption(11))
                                .foregroundStyle(Color.inkPrimary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // 6 个推荐网格
    @ViewBuilder
    private var recommendSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text(quickSource == .custom ? "推荐加入" : "可以加入")
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
                let columns = Array(repeating: GridItem(.flexible(), spacing: AppSpacing.md), count: 3)
                LazyVGrid(columns: columns, spacing: AppSpacing.md) {
                    ForEach(recipes.prefix(6)) { recipe in
                        RecipeCircleCard(recipe: recipe) {
                            Task { await addRecipe(recipe) }
                        }
                    }
                }
            }
        }
    }

    // 也可以 3 个底部入口
    private var alsoSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("也可以")
                .font(AppFont.caption(12))
                .foregroundStyle(Color.inkMuted)
            HStack(spacing: AppSpacing.md) {
                alsoButton(icon: "heart", title: "加入收藏") {
                    Task { await batchFavorite() }
                }
                alsoButton(icon: "square.and.pencil", title: "手动新建") {
                    showCreateRecipe = true
                }
            }
        }
    }

    private func alsoButton(icon: String, title: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(enabled ? Color.brandGreen : Color.inkMuted)
                    .frame(width: 44, height: 44)
                    .background(Color.cardBackground)
                    .clipShape(Circle())
                    .capsuleHairline()
                Text(title)
                    .font(AppFont.caption(11))
                    .foregroundStyle(enabled ? Color.inkPrimary : Color.inkMuted)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private var bottomBar: some View {
        PrimaryButton(title: "挑好了", icon: "checkmark") {
            onChanged()
            dismiss()
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
        .background(Color.appBackground)
    }

    private var emptyHint: String {
        switch quickSource {
        case .favorite: return "还没收藏菜谱 在详情页点 ❤"
        case .recent: return "还没吃过哪道菜 多攒几顿就有了"
        default: return "暂时没有合适的推荐"
        }
    }

    private func select(_ source: QuickSource) {
        quickSource = source
        Task { await loadRecipes() }
    }

    private func loadPinned() async {
        do {
            let m = try await MealService.shared.detail(id: mealId)
            pinnedDishes = m.dishes ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadRecipes() async {
        if quickSource == .custom {
            recipes = []
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            var query = RecipeListQuery(page: 1, pageSize: 30)
            switch quickSource {
            case .favorite:
                query.favorite = true
            case .all:
                query.mood = appState.currentMood
                query.scene = appState.currentScene
            case .recent:
                break
            case .custom:
                break
            }
            let result = try await RecipeService.shared.list(query)
            recipes = sort(result.items)
        } catch {
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
        if pinnedDishes.contains(where: { $0.recipeId == recipe.id }) {
            return
        }
        do {
            _ = try await MealService.shared.addDish(mealId: mealId, dish: DishInput(recipeId: recipe.id))
            await loadPinned()
            onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addCustom() async {
        let name = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return }
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
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func remove(_ dish: MealDish) async {
        do {
            try await MealService.shared.removeDish(mealId: mealId, dishId: dish.id)
            await loadPinned()
            onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // 把当前已选未收藏的菜谱批量加入收藏
    private func batchFavorite() async {
        var newlyFavored = 0
        for dish in pinnedDishes {
            guard let rid = dish.recipeId else { continue }
            do {
                let favored = try await RecipeService.shared.toggleFavorite(id: rid)
                if favored { newlyFavored += 1 }
            } catch {}
        }
        if newlyFavored > 0 {
            errorMessage = "已加入收藏 \(newlyFavored) 道"
        }
    }
}
