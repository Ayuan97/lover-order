import SwiftUI

// 菜品详情：图片画廊 + 简介 + 食材 + 做法 + 评价记录
struct RecipeDetailView: View {
    let recipeId: UInt

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var recipe: Recipe?
    @State private var categories: [RecipeCategory] = []
    @State private var meal: MealSession?
    @State private var isFavored: Bool = false
    @State private var reviewMeals: [MealSession] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var tipMessage: String?
    @State private var editingRecipe: Recipe?
    @State private var photoStudioRecipe: Recipe?
    @State private var confirmDelete: Bool = false
    @State private var tabBarToken = UUID()
    @State private var currentPhotoIndex: Int = 0
    @State private var previewGallery: PhotoGalleryPresentation?
    @State private var recipeLoadID = 0
    @State private var mealLoadID = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heroGallery
                if let recipe {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        titleSection(recipe)
                        ingredientsSection(recipe)
                        stepsToggle(recipe)
                        if let tips = recipe.tips, !tips.isEmpty { tipsSection(tips) }
                        reviewsSection(recipe)
                        Color.clear.frame(height: 16)
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, 22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Color.appBackground,
                        in: UnevenRoundedRectangle(
                            topLeadingRadius: 26,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 26,
                            style: .continuous
                        )
                    )
                    .padding(.top, -22)
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .background {
            Color.appBackground.ignoresSafeArea()
        }
        .safeAreaInset(edge: .bottom) {
            if recipe != nil, meal != nil {
                bottomBar
            }
        }
        .onAppear {
            appState.setTabBarHidden(true, token: tabBarToken)
        }
        .onDisappear {
            appState.setTabBarHidden(false, token: tabBarToken)
        }
        .task {
            async let recipeLoad: Void = loadRecipe()
            async let categoriesLoad: Void = loadCategories()
            await loadMeal()
            await recipeLoad
            await categoriesLoad
        }
        .onReceive(NotificationCenter.default.publisher(for: .recipesChanged)) { _ in
            Task { await loadRecipe() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .categoriesChanged)) { _ in
            Task {
                await loadCategories()
                await loadRecipe()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .mealChanged)) { _ in
            Task { await loadMeal() }
        }
        .toolbar(.visible, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: AppSpacing.sm) {
                    Button {
                        Task { await toggleFavor() }
                    } label: {
                        Image(systemName: isFavored ? "heart.fill" : "heart")
                            .foregroundStyle(isFavored ? Color.accentWarm : Color.inkPrimary)
                    }
                    .accessibilityLabel(isFavored ? "取消收藏" : "收藏菜谱")

                    Button {
                        editingRecipe = recipe
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(Color.inkPrimary)
                    }
                    .accessibilityLabel("编辑菜谱")

                    Menu {
                        Button {
                            photoStudioRecipe = recipe
                        } label: {
                            Label("自定义主图与抠图", systemImage: "sparkles.rectangle.stack")
                        }
                        Button {
                            editingRecipe = recipe
                        } label: {
                            Label("编辑菜谱内容", systemImage: "square.and.pencil")
                        }
                        categorySubmenu
                        Divider()
                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            Label("删除菜谱", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(Color.inkPrimary)
                    }
                    .accessibilityLabel("更多操作")
                }
                .disabled(recipe == nil)
            }
        }
        .sheet(item: $editingRecipe) { openedRecipe in
            RecipeEditView(
                mode: .edit(openedRecipe),
                onSaved: { updated in
                    self.recipe = updated
                },
                onDeleted: {
                    dismiss()
                }
            )
            .environmentObject(appState)
        }
        .sheet(item: $photoStudioRecipe) { openedRecipe in
            RecipePhotoStudioSheet(recipe: openedRecipe) { updated in
                self.recipe = updated
                self.currentPhotoIndex = 0
                self.tipMessage = "主图与抠图已更新"
            }
        }
        .fullScreenCover(item: $previewGallery) { presentation in
            PhotoGalleryViewer(slides: presentation.slides, initialIndex: presentation.initialIndex) { newIndex in
                if let index = galleryImages.firstIndex(of: presentation.slides[newIndex].url) {
                    currentPhotoIndex = index
                }
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
        .toast($errorMessage)
        .tipToast($tipMessage)
    }

    private var heroGallery: some View {
        let images = galleryImages
        return TabView(selection: $currentPhotoIndex) {
            ForEach(Array(images.enumerated()), id: \.element) { idx, image in
                AsyncImageView(url: image, name: recipe?.name ?? "菜品")
                    .frame(maxWidth: .infinity)
                    .frame(height: 340)
                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let image { openHeroPhoto(image) }
                    }
                    .accessibilityAddTraits(image != nil ? .isButton : [])
                    .accessibilityLabel(image != nil ? "查看大图" : (recipe?.name ?? "菜品"))
                    .tag(idx)
            }
        }
        .frame(height: 340)
        .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .automatic : .never))
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [Color.white.opacity(0.42), Color.white.opacity(0.14), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 96)
            .allowsHitTesting(false)
        }
        .overlay(alignment: .bottomLeading) {
            LinearGradient(colors: [.clear, .black.opacity(0.28)], startPoint: .top, endPoint: .bottom)
                .frame(height: 80)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottomLeading) {
            if let recipe {
                Button {
                    Haptics.light()
                    photoStudioRecipe = recipe
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: (recipe.cutoutImage?.isEmpty == false) ? "sparkles.rectangle.stack.fill" : "photo.badge.plus")
                            .font(.system(size: 11.5, weight: .semibold))
                        Text((recipe.cutoutImage?.isEmpty == false) ? "主图与抠图" : "编辑主图/抠图")
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5.5)
                    .background(Color.actionInk.opacity(0.72), in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(Color.white.opacity(0.24), lineWidth: 0.6)
                    }
                }
                .buttonStyle(SoftPressStyle())
                .padding(.leading, 16)
                .padding(.bottom, 32)
                .accessibilityLabel("自定义主图与抠图")
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if images.count > 1 {
                Text("\(min(currentPhotoIndex + 1, images.count)) / \(images.count)")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4.5)
                    .background(Color.actionInk.opacity(0.68), in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 0.6)
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 34)
                    .allowsHitTesting(false)
            }
        }
    }

    private var galleryImages: [String?] {
        guard let recipe else { return [nil] }
        let choices = recipe.photoChoices
        if !choices.isEmpty {
            return choices.map(\.image)
        }
        if let cutout = recipe.cutoutImage?.trimmingCharacters(in: .whitespacesAndNewlines), !cutout.isEmpty {
            return [cutout]
        }
        return [nil]
    }

    private func openHeroPhoto(_ image: String) {
        let choices = recipe?.photoChoices ?? []
        guard let index = choices.firstIndex(where: { $0.image == image }) else { return }
        let slides = choices.map { choice in
            PhotoGallerySlide(
                id: choice.id,
                url: choice.image,
                caption: formattedHeroCaption(for: choice, total: choices.count)
            )
        }
        Haptics.light()
        previewGallery = PhotoGalleryPresentation(slides: slides, initialIndex: index)
    }

    private func formattedHeroCaption(for choice: RecipePhotoChoice, total: Int) -> String? {
        if total <= 1 {
            return recipe?.name
        }
        if choice.isDefaultCover {
            return "默认封面"
        }
        guard let raw = choice.createdAt?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        let dateOnly = raw.split(separator: "T").first.map(String.init) ?? raw
        let parts = dateOnly.split(separator: "-")
        if parts.count == 3 {
            return "\(parts[1]).\(parts[2])"
        }
        return raw
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
            FlowLayout(spacing: 6) {
                Menu {
                    categoryMenuItems
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "tag")
                            .font(.system(size: 10.5, weight: .semibold))
                        Text(currentCategoryLabel(for: r))
                            .font(AppFont.caption(11.5))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(Color.inkSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.cardBackground, in: Capsule())
                }
                if let time = r.cookingTime, time > 0 {
                    Label("\(time) 分钟", systemImage: "clock")
                        .font(AppFont.caption(11.5))
                        .foregroundStyle(Color.inkSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.cardBackground, in: Capsule())
                }
                if let used = r.useCount, used > 0 {
                    Text("做过 \(used) 次")
                        .font(AppFont.caption(11.5))
                        .foregroundStyle(Color.inkSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.cardBackground, in: Capsule())
                }
                ForEach((r.tags ?? []).prefix(2), id: \.self) { tag in
                    Text(tag)
                        .font(AppFont.caption(11.5))
                        .foregroundStyle(Color.inkMuted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.cardBackground, in: Capsule())
                }
            }
            .padding(.top, 2)
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
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, ing in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.inkPrimary.opacity(0.28))
                            .frame(width: 6, height: 6)
                        Text(ing.name)
                            .font(AppFont.body(14))
                            .foregroundStyle(Color.inkPrimary)
                        Spacer()
                        Text(ing.amount)
                            .font(AppFont.body(14))
                            .foregroundStyle(Color.inkMuted)
                    }
                    if idx < items.count - 1 {
                        Divider().background(Color.dividerLine.opacity(0.5))
                    }
                }
            } else {
                Text("还没列出食材").font(AppFont.caption()).foregroundStyle(Color.inkMuted)
            }
        }
    }

    // 做法 NavigationLink 进入独立步骤页
    private func stepsToggle(_ r: Recipe) -> some View {
        let obsidian = Color(red: 0.067, green: 0.067, blue: 0.075)
        return NavigationLink {
            RecipeStepsView(recipe: r)
        } label: {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    obsidian
                    Image(systemName: "list.number")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
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
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.inkMuted)
            }
            .padding(AppSpacing.lg)
            .background(Color.cardBackground.opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.dividerLine.opacity(0.6), lineWidth: 0.7)
            }
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

    private func reviewsSection(_ r: Recipe) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("评价记录")
                    .font(AppFont.title(20))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                Text("\(recipeReviews(r).count) 条")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.inkMuted)
            }
            let reviews = recipeReviews(r)
            if reviews.isEmpty {
                Text("还没有这道菜的评价")
                    .font(AppFont.body(14))
                    .foregroundStyle(Color.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, AppSpacing.lg)
            } else {
                VStack(spacing: AppSpacing.sm) {
                    ForEach(reviews) { review in
                        reviewRow(review)
                    }
                }
            }
        }
    }

    private struct RecipeReviewItem: Identifiable {
        let id: String
        let user: AppUser?
        let rating: Int
        let comment: String?
        let createdAt: Date?
    }

    private func recipeReviews(_ r: Recipe) -> [RecipeReviewItem] {
        var result: [RecipeReviewItem] = []
        for meal in reviewMeals {
            guard let dish = meal.dishes?.first(where: { $0.recipeId == r.id }) else { continue }
            for review in meal.reviews ?? [] {
                let dishReview = review.dishReviews?.first(where: { item in item.mealDishId == dish.id })
                result.append(RecipeReviewItem(
                    id: "\(review.id)-\(dish.id)",
                    user: review.user ?? meal.creator,
                    rating: dishReview?.rating ?? review.rating,
                    comment: dishReview?.comment ?? review.comment,
                    createdAt: dishReview?.createdAt ?? review.createdAt
                ))
            }
        }
        return result.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    private func reviewRow(_ review: RecipeReviewItem) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            AvatarView(user: review.user, size: 34)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(review.user?.displayName ?? "家人")
                        .font(AppFont.body(14))
                        .foregroundStyle(Color.inkPrimary)
                    Spacer()
                    if let date = review.createdAt {
                        Text(RelativeDateFormatter.format(date))
                            .font(AppFont.caption(10))
                            .foregroundStyle(Color.inkMuted)
                    }
                }
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= review.rating ? "star.fill" : "star")
                            .font(.system(size: 11))
                            .foregroundStyle(star <= review.rating ? Color.accentWarm : Color.dividerLine)
                    }
                }
                if let comment = review.comment, !comment.isEmpty {
                    Text(comment)
                        .font(AppFont.body(13))
                        .foregroundStyle(Color.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(Color.cardBackground.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.dividerLine.opacity(0.6), lineWidth: 0.7))
    }

    private var bottomBar: some View {
        HStack {
            if alreadyAdded {
                Button {
                    Haptics.light()
                    dismiss()
                    appState.switchToMealTab()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                        Text("已加入 · 去画布")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(red: 0.067, green: 0.067, blue: 0.075), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(SoftPressStyle())
            } else {
                Button {
                    Task { await addToMeal() }
                } label: {
                    HStack(spacing: 6) {
                        if isLoading {
                            ProgressView().tint(.white).controlSize(.small)
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                        }
                        Text("加入这一顿")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(red: 0.067, green: 0.067, blue: 0.075), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(SoftPressStyle())
                .disabled(isLoading)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, 10)
        .background(Color.appBackground)
        .overlay(alignment: .top) {
            Divider().overlay(Color.dividerLine.opacity(0.6))
        }
    }

    private var alreadyAdded: Bool {
        guard let meal, let recipe else { return false }
        return (meal.dishes ?? []).contains { $0.recipeId == recipe.id }
    }

    private func loadRecipe() async {
        recipeLoadID += 1
        let loadID = recipeLoadID
        do {
            let r = try await RecipeService.shared.detail(id: recipeId)
            guard loadID == recipeLoadID else { return }
            self.recipe = r
            self.isFavored = r.isFavored ?? false
        } catch {
            guard loadID == recipeLoadID else { return }
            if let apiError = error as? APIError, case .server(404, _) = apiError {
                recipe = nil
            }
            errorMessage = error.localizedDescription
            return
        }
        await loadReviews()
    }

    private func loadMeal() async {
        mealLoadID += 1
        let loadID = mealLoadID
        do {
            let current = try await MealService.shared.current(scene: .household, mood: appState.currentMood)
            guard loadID == mealLoadID else { return }
            meal = current
        } catch {
            guard loadID == mealLoadID else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func loadReviews() async {
        var query = MealListQuery()
        query.status = .completed
        query.pageSize = 100
        reviewMeals = (try? await MealService.shared.list(query).items) ?? []
    }

    private func toggleFavor() async {
        guard let recipe else { return }
        do {
            isFavored = try await RecipeService.shared.toggleFavorite(id: recipe.id)
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
            let dish = try await MealService.shared.addDish(mealId: meal.id, dish: DishInput(recipeId: recipe.id))
            if var current = self.meal, current.id == meal.id,
               !(current.dishes ?? []).contains(where: { $0.id == dish.id }) {
                current.dishes = (current.dishes ?? []) + [dish]
                self.meal = current
            }
            Haptics.light()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @ViewBuilder
    private var categorySubmenu: some View {
        Menu {
            categoryMenuItems
        } label: {
            Label("移动到分类", systemImage: "tag")
        }
    }

    @ViewBuilder
    private var categoryMenuItems: some View {
        Button {
            Task { await changeCategory(to: nil) }
        } label: {
            if recipe?.categoryId == nil {
                Label("未分类", systemImage: "checkmark")
            } else {
                Text("未分类")
            }
        }
        ForEach(categories) { cat in
            let title = (cat.icon?.isEmpty == false ? "\(cat.icon!) " : "") + cat.name
            Button {
                Task { await changeCategory(to: cat.id) }
            } label: {
                if recipe?.categoryId == cat.id {
                    Label(title, systemImage: "checkmark")
                } else {
                    Text(title)
                }
            }
        }
    }

    private func currentCategoryLabel(for r: Recipe) -> String {
        if let cid = r.categoryId, let cat = categories.first(where: { $0.id == cid }) {
            return (cat.icon?.isEmpty == false ? "\(cat.icon!) " : "") + cat.name
        }
        if let cat = r.category, r.categoryId != nil {
            return (cat.icon?.isEmpty == false ? "\(cat.icon!) " : "") + cat.name
        }
        return "未分类"
    }

    private func loadCategories() async {
        categories = (try? await CategoryService.shared.list()) ?? categories
    }

    private func changeCategory(to targetCategoryId: UInt?) async {
        guard let recipe else { return }
        do {
            _ = try await RecipeService.shared.batchUpdateCategory(recipeIds: [recipe.id], categoryId: targetCategoryId)
            await loadRecipe()
            let targetName = targetCategoryId.flatMap { id in categories.first(where: { $0.id == id })?.name } ?? "未分类"
            tipMessage = "已归入「\(targetName)」"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteRecipe() async {
        guard let recipe else { return }
        do {
            try await RecipeService.shared.delete(id: recipe.id)
            AppNotifications.recipesChanged()
            AppNotifications.categoriesChanged()
            dismiss()
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
