import SwiftUI

// 菜品详情：图片画廊 + 简介 + 食材 + 做法 + 评价记录
struct RecipeDetailView: View {
    let recipeId: UInt

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var recipe: Recipe?
    @State private var meal: MealSession?
    @State private var isFavored: Bool = false
    @State private var reviewMeals: [MealSession] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showEdit: Bool = false
    @State private var confirmDelete: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                heroGallery
                if let recipe {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        titleSection(recipe)
                        ingredientsSection(recipe)
                        stepsToggle(recipe)
                        if let tips = recipe.tips, !tips.isEmpty { tipsSection(tips) }
                        reviewsSection(recipe)
                    }
                    .padding(.horizontal, AppSpacing.lg)
                }
            }
            .padding(.top, 0)
        }
        .background {
            Color.appBackground.ignoresSafeArea()
        }
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
                            .foregroundStyle(isFavored ? Color.accentWarm : Color.inkSecondary)
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
    }

    private var heroGallery: some View {
        let images = galleryImages
        return TabView {
            ForEach(Array(images.enumerated()), id: \.offset) { _, image in
                AsyncImageView(url: image, name: recipe?.name ?? "菜品")
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .clipped()
            }
        }
        .frame(height: 300)
        .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .automatic : .never))
        .overlay(alignment: .bottomLeading) {
            LinearGradient(colors: [.clear, .black.opacity(0.32)], startPoint: .top, endPoint: .bottom)
                .frame(height: 90)
                .allowsHitTesting(false)
        }
    }

    private var galleryImages: [String?] {
        guard let recipe else { return [nil] }
        var result: [String?] = []
        if recipe.coverImage != nil { result.append(recipe.coverImage) }
        for image in recipe.images ?? [] where !image.isEmpty {
            if image != recipe.coverImage { result.append(image) }
        }
        return result.isEmpty ? [nil] : result
    }

    private func titleSection(_ r: Recipe) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("菜谱详情")
                .font(AppFont.caption(10))
                .tracking(1.1)
                .foregroundStyle(Color.accentWarm)
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
            .background(Color.cardBackground.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.accentWarm.opacity(0.18), lineWidth: 1))
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
        .background(Color.cardBackground.opacity(0.84))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.inkPrimary.opacity(0.08), lineWidth: 1))
    }

    private var bottomBar: some View {
        HStack {
            PrimaryButton(title: alreadyAdded ? "已加入这一顿" : "加入这一顿", isLoading: isLoading) {
                Task { await addToMeal() }
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
        .background(Color.cardBackground)
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
            async let current = MealService.shared.current(scene: .pair, mood: appState.currentMood)
            let (r, m) = try await (detail, current)
            self.recipe = r
            self.meal = m
            self.isFavored = r.isFavored ?? false
            await loadReviews()
        } catch {
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
