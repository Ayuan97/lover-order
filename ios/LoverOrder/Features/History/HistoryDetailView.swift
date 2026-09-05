import SwiftUI

// 一顿的历史详情：头 + 菜列表 + 评价 + 补评 / 再来一次
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
                    titleBlock(meal)
                    peopleCard(meal)
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
        .navigationTitle("这顿饭")
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

    private func titleBlock(_ meal: MealSession) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(meal.title?.isEmpty == false ? meal.title! : meal.scene.historyLabel)
                .font(AppFont.title(24))
                .foregroundStyle(Color.inkPrimary)
            HStack(spacing: 8) {
                Text(meal.scene.historyLabel)
                if let when = meal.completedAt ?? meal.confirmedAt ?? meal.createdAt {
                    Text("·")
                    Text(RelativeDateFormatter.format(when))
                }
            }
            .font(AppFont.caption(12))
            .foregroundStyle(Color.inkMuted)
            if let note = meal.note, !note.isEmpty {
                Text(note)
                    .font(AppFont.caption(13))
                    .foregroundStyle(Color.inkSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.top, 4)
    }

    private func peopleCard(_ meal: MealSession) -> some View {
        let people = peopleFor(meal)
        return SectionCard {
            HStack(alignment: .center, spacing: 14) {
                avatarMosaic(people)
                VStack(alignment: .leading, spacing: 5) {
                    Text("一起吃饭的人")
                        .font(AppFont.headline(15))
                        .foregroundStyle(Color.inkPrimary)
                    if people.isEmpty {
                        Text("还没记同行的人")
                            .font(AppFont.caption(12))
                            .foregroundStyle(Color.inkMuted)
                    } else {
                        Text(people.prefix(4).map(\.displayName).joined(separator: "、") + (people.count > 4 ? " 等" : ""))
                            .font(AppFont.caption(12))
                            .foregroundStyle(Color.inkMuted)
                        Text("共 \(people.count) 人")
                            .font(AppFont.caption(11))
                            .foregroundStyle(Color.brandGreen)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func avatarMosaic(_ people: [AppUser]) -> some View {
        let positions: [(CGFloat, CGFloat)] = [(0, 0), (31, -13), (34, 20), (-27, 18), (-30, -15), (2, 31)]
        return ZStack {
            ForEach(Array(people.prefix(6).enumerated()), id: \.offset) { index, person in
                AvatarView(user: person, size: index == 0 ? 52 : 42, ring: true)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .offset(x: positions[index].0, y: positions[index].1)
                    .zIndex(Double(people.count - index))
            }
            if people.count > 6 {
                Text("+\(people.count - 6)")
                    .font(AppFont.caption(12))
                    .foregroundStyle(Color.inkSecondary)
                    .frame(width: 42, height: 42)
                    .background(Color.appBackground)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .offset(x: 28, y: 25)
            }
        }
        .frame(width: 116, height: 88)
    }

    private func peopleFor(_ meal: MealSession) -> [AppUser] {
        var people: [AppUser] = (meal.participants ?? []).compactMap(\.user)
        if meal.scene == .pair, let members = appState.household?.members, !members.isEmpty {
            people = members
        }
        if let creator = meal.creator, !people.contains(where: { $0.id == creator.id }) {
            people.insert(creator, at: 0)
        }
        return people
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
                Text("还没记菜")
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
                Text("留言")
                    .font(AppFont.headline(15))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                if meal.status == .completed {
                    Button {
                        showReview = true
                    } label: {
                        Label("留言和照片", systemImage: "plus.circle")
                            .font(AppFont.caption(13))
                            .foregroundStyle(Color.brandGreen)
                    }
                }
            }
            if reviews.isEmpty {
                Text("还没人留言")
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
                    historyAction(
                        title: "写留言",
                        subtitle: "补一句话或加照片",
                        icon: "square.and.pencil",
                        tint: Color.brandGreen
                    ) {
                        showReview = true
                    }
                }
                historyAction(
                    title: isRepeating ? "正在添加" : "把菜加到这一顿",
                    subtitle: "下次继续吃",
                    icon: "arrow.clockwise",
                    tint: Color.actionInk,
                    isLoading: isRepeating
                ) {
                    Task { await repeatMeal(meal) }
                }
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, 12)
        .padding(.bottom, 76)
        .background(Color.appBackground)
    }

    private func historyAction(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Group {
                    if isLoading {
                        ProgressView().tint(tint)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(tint)
                    }
                }
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.11), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppFont.headline(14))
                        .foregroundStyle(Color.inkPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(AppFont.caption(10))
                        .foregroundStyle(Color.inkMuted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.inkMuted)
            }
            .padding(.horizontal, 11)
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(tint.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
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

    // 把这一顿的菜复制到日常「我们这顿」
    private func repeatMeal(_ meal: MealSession) async {
        isRepeating = true
        defer { isRepeating = false }
        do {
            let current = try await MealService.shared.current(scene: .pair, mood: appState.currentMood)
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
            // 再来一次始终打进日常我们这顿
            repeatedToast = "已加 \(added) 道菜到这一顿"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
