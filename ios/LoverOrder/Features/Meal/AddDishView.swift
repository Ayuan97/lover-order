import SwiftUI

// 添加菜品弹层 4 种添加方式 + 已加入展示
struct AddDishView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let mealId: UInt
    var onChanged: () -> Void = {}

    @State private var mode: AddMode = .recommend
    @State private var customName: String = ""
    @State private var customNote: String = ""
    @State private var recipes: [Recipe] = []
    @State private var pinnedDishes: [MealDish] = []
    @State private var isLoading: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?

    enum AddMode: String, CaseIterable, Identifiable {
        case custom
        case recommend
        case favorite
        case recent

        var id: String { rawValue }

        var label: String {
            switch self {
            case .custom: return "自定义"
            case .recommend: return "推荐"
            case .favorite: return "收藏"
            case .recent: return "常用"
            }
        }

        var icon: String {
            switch self {
            case .custom: return "pencil"
            case .recommend: return "wand.and.stars"
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
                    modePicker
                    contentSection
                    if let errorMessage {
                        Text(errorMessage)
                            .font(AppFont.caption())
                            .foregroundStyle(.red)
                    }
                    Color.clear.frame(height: 60)
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack {
                    Text("添加菜品")
                        .font(AppFont.title(26))
                        .foregroundStyle(Color.inkPrimary)
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(Color.brandGreen)
                }
                Text("把想吃的菜加入这一顿")
                    .font(AppFont.body())
                    .foregroundStyle(Color.inkMuted)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .foregroundStyle(Color.inkSecondary)
                    .background(Color.cardBackground)
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, AppSpacing.sm)
    }

    private var pinnedSection: some View {
        SectionCard {
            HStack {
                Text("这一顿已加 \(pinnedDishes.count) 道")
                    .font(AppFont.headline(15))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
            }
            if pinnedDishes.isEmpty {
                Text("还没选 慢慢挑")
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

    private var modePicker: some View {
        HStack(spacing: AppSpacing.sm) {
            ForEach(AddMode.allCases) { m in
                Button {
                    mode = m
                    Task { await loadRecipes() }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: m.icon)
                            .font(.system(size: 16))
                        Text(m.label)
                            .font(AppFont.caption(12))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .foregroundStyle(mode == m ? .white : Color.inkPrimary)
                    .background(mode == m ? Color.brandGreen : Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        switch mode {
        case .custom:
            customInputCard
        default:
            recipeListSection
        }
    }

    private var customInputCard: some View {
        SectionCard {
            Text("输入菜名直接加入这一顿")
                .font(AppFont.headline(15))
                .foregroundStyle(Color.inkPrimary)
            Text("不用先建菜谱 想吃啥写啥")
                .font(AppFont.caption())
                .foregroundStyle(Color.inkMuted)

            VStack(spacing: AppSpacing.sm) {
                TextField("菜名 比如 番茄炒蛋", text: $customName)
                    .padding(AppSpacing.md)
                    .background(Color.appBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                TextField("备注（可选）比如 不要太辣", text: $customNote)
                    .padding(AppSpacing.md)
                    .background(Color.appBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            }
            PrimaryButton(title: isSubmitting ? "添加中" : "加入这一顿", isLoading: isSubmitting) {
                Task { await addCustom() }
            }
        }
    }

    @ViewBuilder
    private var recipeListSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text(mode.label + "加入")
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
                    ForEach(recipes) { recipe in
                        RecipeCircleCard(recipe: recipe) {
                            Task { await addRecipe(recipe) }
                        }
                    }
                }
            }
        }
    }

    private var emptyHint: String {
        switch mode {
        case .favorite: return "还没收藏菜谱 长按菜品点心形添加"
        case .recent: return "还没吃过哪道菜 多攒几顿就有了"
        default: return "暂时没有合适的推荐"
        }
    }

    private var bottomBar: some View {
        HStack(spacing: AppSpacing.md) {
            SecondaryButton(title: "完成", icon: "checkmark") {
                onChanged()
                dismiss()
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
        .background(Color.appBackground)
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
        if mode == .custom {
            recipes = []
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            var query = RecipeListQuery(page: 1, pageSize: 30)
            switch mode {
            case .favorite:
                query.favorite = true
            case .recommend:
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
        switch mode {
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
        if name.isEmpty {
            errorMessage = "请先填写菜名"
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            _ = try await MealService.shared.addDish(
                mealId: mealId,
                dish: DishInput(name: name, note: customNote.isEmpty ? nil : customNote)
            )
            customName = ""
            customNote = ""
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
}
