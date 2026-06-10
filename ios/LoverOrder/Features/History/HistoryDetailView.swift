import SwiftUI

// 一顿的历史详情：场景头 + 菜列表 + 评价列表 + 补评 / 再来一次
struct HistoryDetailView: View {
    let mealId: UInt

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var meal: MealSession?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showReview: Bool = false
    @State private var showShoppingList: Bool = false
    @State private var isRepeating: Bool = false
    @State private var repeatedToast: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                if let meal {
                    headerCard(meal)
                    dishesCard(meal)
                    reviewsCard(meal)
                    Color.clear.frame(height: 80)
                } else if isLoading {
                    ProgressView().tint(Color.brandGreen).padding(.top, 40)
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(AppFont.body())
                        .foregroundStyle(Color.errorInk)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            if let meal {
                bottomBar(meal)
            }
        }
        .task {
            await load()
        }
        .navigationTitle("这一顿的记录")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showReview) {
            if let mid = meal?.id {
                MealReviewView(mealId: mid) {
                    Task { await load() }
                }
            }
        }
        .sheet(isPresented: $showShoppingList) {
            if let mid = meal?.id {
                ShoppingListView(mealId: mid)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showShoppingList = true
                } label: {
                    Image(systemName: "cart")
                        .foregroundStyle(Color.brandGreen)
                }
            }
        }
    }

    private func headerCard(_ meal: MealSession) -> some View {
        SectionCard {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                VStack(spacing: AppSpacing.xs) {
                    Image(systemName: meal.scene.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.brandGreen)
                        .clipShape(Circle())
                    Text(meal.scene.label)
                        .font(AppFont.caption(11))
                        .foregroundStyle(Color.inkMuted)
                }
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(meal.title?.isEmpty == false ? meal.title! : "这一顿")
                        .font(AppFont.title(20))
                        .foregroundStyle(Color.inkPrimary)
                    HStack(spacing: AppSpacing.sm) {
                        infoChip(icon: meal.mood.icon, text: meal.mood.label)
                        infoChip(icon: "fork.knife", text: "\((meal.dishes ?? []).count) 道")
                    }
                    if let when = meal.completedAt ?? meal.confirmedAt ?? meal.createdAt {
                        HStack(spacing: 4) {
                            Image(systemName: "clock").font(.system(size: 11))
                            Text(RelativeDateFormatter.format(when))
                        }
                        .font(AppFont.caption())
                        .foregroundStyle(Color.inkMuted)
                    }
                    if let note = meal.note, !note.isEmpty {
                        Text(note)
                            .font(AppFont.caption())
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
            }
        }
    }

    private func infoChip(icon: String, text: String) -> some View {
        TagChip(text: text, icon: icon, compact: true)
    }

    private func dishesCard(_ meal: MealSession) -> some View {
        SectionCard {
            HStack {
                Text("吃了这些")
                    .font(AppFont.headline(15))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                Text("\((meal.dishes ?? []).count) 道")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.inkMuted)
            }
            let dishes = meal.dishes ?? []
            if dishes.isEmpty {
                Text("这顿什么都没选")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.inkMuted)
            } else {
                ForEach(dishes) { dish in
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
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func reviewsCard(_ meal: MealSession) -> some View {
        let reviews = meal.reviews ?? []
        SectionCard {
            HStack {
                Text("感受")
                    .font(AppFont.headline(15))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                if meal.status == .completed {
                    Button {
                        showReview = true
                    } label: {
                        Label("补一份", systemImage: "plus.circle")
                            .font(AppFont.caption(13))
                            .foregroundStyle(Color.brandGreen)
                    }
                }
            }
            if reviews.isEmpty {
                Text(meal.status == .completed ? "还没人留下感受" : "等吃完再来留")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.inkMuted)
            } else {
                ForEach(reviews) { review in
                    reviewRow(review)
                }
            }
        }
    }

    private func reviewRow(_ review: MealReview) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                if let url = APIConfig.imageURL(review.user?.avatar) {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase {
                            img.resizable().scaledToFill()
                        } else {
                            Circle().fill(Color.brandGreen.opacity(0.1))
                        }
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                } else {
                    Text(String(review.user?.nickname.prefix(1) ?? "我"))
                        .font(AppFont.caption(13))
                        .frame(width: 32, height: 32)
                        .foregroundStyle(Color.brandGreen)
                        .background(Color.brandGreen.opacity(0.12))
                        .clipShape(Circle())
                }
                Text(review.user?.nickname ?? "我")
                    .font(AppFont.body(14))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= review.rating ? "leaf.fill" : "leaf")
                            .font(.system(size: 11))
                            .foregroundStyle(star <= review.rating ? Color.accentWarm : Color.inkMuted)
                    }
                }
            }
            if let comment = review.comment, !comment.isEmpty {
                Text(comment)
                    .font(AppFont.body(14))
                    .foregroundStyle(Color.inkSecondary)
            }
            if let photos = review.photos, !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        ForEach(photos, id: \.self) { url in
                            AsyncImageView(url: url, name: "")
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
                        }
                    }
                }
            }
        }
        .padding(AppSpacing.md)
        .background(Color.appBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
    }

    private func bottomBar(_ meal: MealSession) -> some View {
        VStack(spacing: AppSpacing.sm) {
            if let repeatedToast {
                Text(repeatedToast)
                    .font(AppFont.caption(12))
                    .foregroundStyle(Color.brandGreen)
            }
            HStack(spacing: AppSpacing.md) {
                if meal.status == .completed && (meal.reviews ?? []).isEmpty {
                    SecondaryButton(title: "留下感受", icon: "leaf") {
                        showReview = true
                    }
                }
                PrimaryButton(title: isRepeating ? "复制中" : "再来一次", icon: "arrow.clockwise", isLoading: isRepeating) {
                    Task { await repeatMeal(meal) }
                }
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
        .background(Color.appBackground)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            meal = try await MealService.shared.detail(id: mealId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // 把这一顿的菜复制到当前 scene 的规划中
    private func repeatMeal(_ meal: MealSession) async {
        isRepeating = true
        defer { isRepeating = false }
        do {
            let current = try await MealService.shared.current(scene: appState.currentScene, mood: appState.currentMood)
            let existingRecipeIds = Set((current.dishes ?? []).compactMap { $0.recipeId })
            let existingNames = Set((current.dishes ?? []).map { $0.recipeName })
            var added = 0
            for dish in meal.dishes ?? [] {
                if let rid = dish.recipeId {
                    if existingRecipeIds.contains(rid) { continue }
                    _ = try await MealService.shared.addDish(mealId: current.id, dish: DishInput(recipeId: rid, name: dish.recipeName, image: dish.recipeImage, note: dish.note))
                    added += 1
                } else if !dish.recipeName.isEmpty {
                    if existingNames.contains(dish.recipeName) { continue }
                    _ = try await MealService.shared.addDish(mealId: current.id, dish: DishInput(name: dish.recipeName, image: dish.recipeImage, note: dish.note))
                    added += 1
                }
            }
            repeatedToast = "已复制 \(added) 道到\(appState.currentScene.label)"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
