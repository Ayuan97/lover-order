import SwiftUI

// 菜品详情：大图 + 简介 + 标签 + 食材 + 做法步骤 + 底部加入按钮
struct RecipeDetailView: View {
    let recipeId: UInt

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var recipe: Recipe?
    @State private var meal: MealSession?
    @State private var isFavored: Bool = false
    @State private var related: [Recipe] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSteps: Bool = false
    @State private var showEdit: Bool = false
    @State private var confirmDelete: Bool = false
    @State private var saveToFutureNote: String = ""
    @State private var showSaveToFuture: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                heroImage
                if let recipe {
                    titleSection(recipe)
                    metricsGrid(recipe)
                    tagsRow(recipe)
                    ingredientsSection(recipe)
                    stepsToggle(recipe)
                    if let tips = recipe.tips, !tips.isEmpty {
                        tipsSection(tips)
                    }
                    relatedSection
                }
                Color.clear.frame(height: 80)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.sm)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .task {
            await load()
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(recipe?.name ?? "菜品")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: AppSpacing.md) {
                    Button {
                        Task { await toggleFavor() }
                    } label: {
                        Image(systemName: isFavored ? "heart.fill" : "heart")
                            .foregroundStyle(isFavored ? Color.brandGreen : Color.inkSecondary)
                    }
                    Menu {
                        Button {
                            showEdit = true
                        } label: {
                            Label("编辑菜谱", systemImage: "square.and.pencil")
                        }
                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            if let recipe {
                RecipeEditView(mode: .edit(recipe)) { updated in
                    self.recipe = updated
                }
                .environmentObject(appState)
            }
        }
        .confirmationDialog("删除这道菜谱？", isPresented: $confirmDelete) {
            Button("删除", role: .destructive) {
                Task { await deleteRecipe() }
            }
            Button("再想想", role: .cancel) {}
        } message: {
            Text("删除后这道菜不会再出现在菜单里 但已经记下的历史不受影响")
        }
        .alert("已留到周末", isPresented: $showSaveToFuture) {
            Button("好") {}
        } message: {
            Text("可以在'未来这顿'里找到它")
        }
    }

    private var heroImage: some View {
        AsyncImageView(url: recipe?.coverImage, name: recipe?.name ?? "")
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
    }

    private func titleSection(_ r: Recipe) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(r.name)
                .font(AppFont.title(26))
                .foregroundStyle(Color.inkPrimary)
            if let desc = r.description, !desc.isEmpty {
                Text(desc)
                    .font(AppFont.body())
                    .foregroundStyle(Color.inkSecondary)
            }
        }
    }

    // metrics 4 个气质标签 横向排开 描述这道菜的气质
    private func metricsGrid(_ r: Recipe) -> some View {
        let items = buildMetrics(r)
        return HStack(alignment: .top, spacing: AppSpacing.sm) {
            ForEach(items, id: \.label) { item in
                VStack(spacing: AppSpacing.xs) {
                    Image(systemName: item.icon)
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(Color.brandGreen)
                    Text(item.label)
                        .font(AppFont.caption(11))
                        .foregroundStyle(Color.inkMuted)
                    Text(item.value)
                        .font(AppFont.body(13))
                        .foregroundStyle(Color.inkPrimary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private struct MetricItem {
        let icon: String
        let label: String
        let value: String
    }

    private func buildMetrics(_ r: Recipe) -> [MetricItem] {
        [
            .init(icon: "heart", label: "什么口味", value: flavorPhrase(r)),
            .init(icon: "leaf", label: "适合一顿", value: feelPhrase(r)),
            .init(icon: "person.2", label: "适合多人", value: peoplePhrase(r)),
            .init(icon: "calendar", label: "工作日做饭", value: timePhrase(r)),
        ]
    }

    // 风味短语：优先取标签首项 否则按难度推断
    private func flavorPhrase(_ r: Recipe) -> String {
        if let tags = r.tags, let first = tags.first { return first }
        switch r.difficulty {
        case .easy: return "简单家常"
        case .medium: return "有点讲究"
        case .hard: return "下点功夫"
        case nil: return "随心而做"
        }
    }

    // 情绪短语：按 moodTags 推断
    private func feelPhrase(_ r: Recipe) -> String {
        guard let moods = r.moodTags, let m = moods.first else {
            return "怎么吃都好"
        }
        switch m {
        case .easy: return "不想费脑筋"
        case .normal: return "正常吃一顿"
        case .serious: return "想吃得好一些"
        case .change: return "想换换口味"
        }
    }

    // 适合人份
    private func peoplePhrase(_ r: Recipe) -> String {
        switch r.servings ?? 0 {
        case 0: return "几个人都行"
        case 1: return "一个人吃"
        case 2: return "两个人一起吃"
        case 3...4: return "三四个人合适"
        default: return "招呼客人也够"
        }
    }

    // 是否适合工作日
    private func timePhrase(_ r: Recipe) -> String {
        switch r.cookingTime ?? 0 {
        case 0: return "看心情"
        case 1...15: return "15 分钟搞定"
        case 16...30: return "半小时左右"
        case 31...60: return "正经做一顿"
        default: return "周末慢慢做"
        }
    }

    private func tagsRow(_ r: Recipe) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if let moods = r.moodTags, !moods.isEmpty {
                tagGroup(label: "适合心情", tags: moods.map { $0.label })
            }
            if let scenes = r.sceneTags, !scenes.isEmpty {
                tagGroup(label: "适合场景", tags: scenes.map { $0.label })
            }
            if let flavors = r.tags, !flavors.isEmpty {
                tagGroup(label: "风味", tags: flavors)
            }
        }
    }

    private func tagGroup(label: String, tags: [String]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(label)
                .font(AppFont.caption())
                .foregroundStyle(Color.inkMuted)
            FlowLayout(spacing: AppSpacing.sm) {
                ForEach(tags, id: \.self) { t in
                    Text(t)
                        .font(AppFont.caption(12))
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, 6)
                        .foregroundStyle(Color.brandGreen)
                        .background(Color.brandGreen.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
    }

    private func ingredientsSection(_ r: Recipe) -> some View {
        SectionCard {
            HStack {
                Text("准备食材")
                    .font(AppFont.headline(15))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                if let count = r.ingredients?.count {
                    Text("\(count) 项")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.inkMuted)
                }
            }
            if let items = r.ingredients, !items.isEmpty {
                ForEach(items) { ing in
                    HStack {
                        Image(systemName: "leaf.circle")
                            .foregroundStyle(Color.brandGreen)
                        Text(ing.name)
                            .font(AppFont.body(14))
                            .foregroundStyle(Color.inkPrimary)
                        Spacer()
                        Text(ing.amount)
                            .font(AppFont.body(14))
                            .foregroundStyle(Color.inkMuted)
                    }
                    Divider().background(Color.dividerLine.opacity(0.5))
                }
            } else {
                Text("还没列出食材").font(AppFont.caption()).foregroundStyle(Color.inkMuted)
            }
        }
    }

    // 做法 NavigationLink 进入独立步骤页
    private func stepsToggle(_ r: Recipe) -> some View {
        NavigationLink {
            RecipeStepsView(recipe: r)
        } label: {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    Color.brandGreen.opacity(0.12)
                    Image(systemName: "list.number")
                        .foregroundStyle(Color.brandGreen)
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("做法")
                        .font(AppFont.headline(15))
                        .foregroundStyle(Color.inkPrimary)
                    Text("查看怎么做 \(r.steps?.count ?? 0) 步")
                        .font(AppFont.caption(11))
                        .foregroundStyle(Color.inkMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.inkMuted)
            }
            .padding(AppSpacing.lg)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func tipsSection(_ tips: String) -> some View {
        SectionCard {
            Text("小贴士")
                .font(AppFont.headline(15))
                .foregroundStyle(Color.inkPrimary)
            Text(tips)
                .font(AppFont.body(14))
                .foregroundStyle(Color.inkSecondary)
        }
    }

    @ViewBuilder
    private var relatedSection: some View {
        if !related.isEmpty {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("可以怎么吃")
                    .font(AppFont.headline(15))
                    .foregroundStyle(Color.inkPrimary)
                let columns = Array(repeating: GridItem(.flexible(), spacing: AppSpacing.md), count: 3)
                LazyVGrid(columns: columns, spacing: AppSpacing.md) {
                    ForEach(related.prefix(3)) { r in
                        RecipeCircleCard(recipe: r) {
                            Task { await quickAdd(r) }
                        }
                    }
                }
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: AppSpacing.md) {
            SecondaryButton(title: "留到周末", icon: "calendar") {
                Task { await saveToFuture() }
            }
            PrimaryButton(title: alreadyAdded ? "已加入" : "加入这一顿", isLoading: isLoading) {
                Task { await addToMeal() }
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
        .background(Color.appBackground)
    }

    private var alreadyAdded: Bool {
        guard let meal, let recipe else { return false }
        return (meal.dishes ?? []).contains { $0.recipeId == recipe.id }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let detail = RecipeService.shared.detail(id: recipeId)
            async let current = MealService.shared.current(scene: appState.currentScene, mood: appState.currentMood)
            let (r, m) = try await (detail, current)
            self.recipe = r
            self.meal = m
            await loadRelated(r)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadRelated(_ r: Recipe) async {
        var query = RecipeListQuery(page: 1, pageSize: 6)
        if let cid = r.categoryId {
            query.categoryId = cid
        }
        do {
            let result = try await RecipeService.shared.list(query)
            related = result.items.filter { $0.id != r.id }
        } catch {}
    }

    private func toggleFavor() async {
        guard let recipe else { return }
        do {
            isFavored = try await RecipeService.shared.toggleFavorite(id: recipe.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func quickAdd(_ r: Recipe) async {
        guard let meal else { return }
        do {
            _ = try await MealService.shared.addDish(mealId: meal.id, dish: DishInput(recipeId: r.id))
            self.meal = try await MealService.shared.detail(id: meal.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addToMeal() async {
        guard let recipe, let meal else { return }
        if alreadyAdded { return }
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await MealService.shared.addDish(mealId: meal.id, dish: DishInput(recipeId: recipe.id))
            self.meal = try await MealService.shared.detail(id: meal.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteRecipe() async {
        guard let recipe else { return }
        do {
            try await RecipeService.shared.delete(id: recipe.id)
            AppNotifications.recipesChanged()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveToFuture() async {
        guard let recipe else { return }
        do {
            let future = try await MealService.shared.current(scene: .future, mood: appState.currentMood)
            _ = try await MealService.shared.addDish(mealId: future.id, dish: DishInput(recipeId: recipe.id))
            showSaveToFuture = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// 简易流式布局
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (idx, sub) in subviews.enumerated() {
            sub.place(at: CGPoint(x: bounds.minX + result.points[idx].x, y: bounds.minY + result.points[idx].y), proposal: ProposedViewSize(result.sizes[idx]))
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, points: [CGPoint], sizes: [CGSize]) {
        let maxWidth = proposal.width ?? .infinity
        var points: [CGPoint] = []
        var sizes: [CGSize] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            sizes.append(size)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x)
        }
        let totalHeight = y + rowHeight
        return (CGSize(width: maxX, height: totalHeight), points, sizes)
    }
}
