import SwiftUI

// 餐后记录：备注、照片和口味。
struct MealReviewView: View {
    let mealId: UInt
    var currentUserId: UInt? = nil
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var rating: Int = 5
    @State private var comment: String = ""
    @State private var photoLinks: [String] = []
    @State private var photosUploading = false
    @State private var meal: MealSession?
    @State private var dishRatings: [UInt: Int] = [:]
    @State private var dishComments: [UInt: String] = [:]
    @State private var didPrefill: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?
    @State private var tipMessage: String?
    @State private var sharePosterMeal: MealSession?
    @State private var photoPickerDish: MealDish?
    @State private var coverPrompt: (recipeId: UInt, dishName: String, image: String, cutoutImage: String?)?
    @State private var coverPromptTask: Task<Void, Never>?
    @State private var isSettingCover: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    commentCard
                    photosCard
                    ratingCard
                    DisclosureGroup("每道菜的口味") {
                        dishRatingCard.padding(.top, 12)
                    }
                    .font(AppFont.body(14))
                    .foregroundStyle(Color.inkSecondary)
                    .padding(.horizontal, 4)
                    Color.clear.frame(height: 60)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    if let prompt = coverPrompt {
                        coverPromptBanner(prompt)
                            .padding(.horizontal, AppSpacing.lg)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    bottomBar
                }
                .animation(.spring(response: 0.30, dampingFraction: 0.84), value: coverPrompt?.image)
            }
            .task {
                await loadMeal()
            }
            .interactiveDismissDisabled(isSubmitting || photosUploading)
            .navigationTitle("记录这一顿")
            .navigationBarTitleDisplayMode(.inline)
            .toast($errorMessage)
            .tipToast($tipMessage)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("稍后记录").foregroundStyle(Color.inkSecondary)
                    }
                    .disabled(isSubmitting || photosUploading)
                }
            }
            .sheet(item: $photoPickerDish) { dish in
                DishPhotoPickerSheet(mealId: mealId, dish: dish) { result in
                    applyReplacedDishPhoto(result)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .preferredColorScheme(.light)
            }
            .sheet(item: $sharePosterMeal, onDismiss: {
                dismiss()
            }) { m in
                MealSharePosterSheet(meal: m)
                    .preferredColorScheme(.light)
            }
        }
    }

    private var ratingCard: some View {
        SectionCard {
            FieldLabel("这顿的口味")
            HStack(spacing: AppSpacing.sm) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        rating = star
                    } label: {
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .font(.system(size: 26))
                            .foregroundStyle(star <= rating ? Color.accentWarm : Color.dividerLine)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Text(ratingLabel)
                    .font(AppFont.body(14))
                    .foregroundStyle(Color.inkSecondary)
            }
        }
    }

    private var ratingLabel: String {
        switch rating {
        case 1: return "下次别做了"
        case 2: return "一般般"
        case 3: return "还行"
        case 4: return "挺好"
        default: return "太香了"
        }
    }

    @ViewBuilder
    private var dishRatingCard: some View {
        if let dishes = meal?.dishes, !dishes.isEmpty {
            SectionCard {
            FieldLabel("单道菜")
                VStack(spacing: AppSpacing.md) {
                    ForEach(dishes) { dish in
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            HStack(spacing: AppSpacing.md) {
                                DishThumb(name: dish.recipeName, image: dish.recipeImage)
                                    .id("\(dish.id)-\(dish.recipeImage ?? "")")
                                Text(dish.recipeName)
                                    .font(AppFont.body(15))
                                    .foregroundStyle(Color.inkPrimary)
                                Spacer()
                                Button {
                                    Haptics.light()
                                    photoPickerDish = dish
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "camera")
                                            .font(.system(size: 11.5, weight: .semibold))
                                        Text("换图")
                                            .font(AppFont.caption(12))
                                    }
                                    .foregroundStyle(Color.inkSecondary)
                                    .padding(.horizontal, 10)
                                    .frame(height: 28)
                                    .background(Color.appBackground, in: Capsule())
                                    .overlay {
                                        Capsule().strokeBorder(Color.dividerLine, lineWidth: 0.7)
                                    }
                                }
                                .buttonStyle(SoftPressStyle())
                            }
                            dishRatingRow(dish.id)
                            TextField("这道怎么样", text: dishCommentBinding(dish.id), axis: .vertical)
                                .lineLimit(2...4)
                                .font(AppFont.body(14))
                                .padding(AppSpacing.md)
                                .background(Color.appBackground)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                        }
                        .padding(.bottom, AppSpacing.sm)
                    }
                }
            }
        }
    }

    private func dishRatingRow(_ dishId: UInt) -> some View {
        HStack(spacing: AppSpacing.sm) {
            ForEach(1...5, id: \.self) { star in
                Button {
                    dishRatings[dishId] = star
                } label: {
                    Image(systemName: star <= (dishRatings[dishId] ?? rating) ? "star.fill" : "star")
                        .font(.system(size: 20))
                        .foregroundStyle(star <= (dishRatings[dishId] ?? rating) ? Color.accentWarm : Color.dividerLine)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Text(dishRatingLabel(dishRatings[dishId] ?? rating))
                .font(AppFont.caption(12))
                .foregroundStyle(Color.inkMuted)
        }
    }

    private func dishCommentBinding(_ dishId: UInt) -> Binding<String> {
        Binding(
            get: { dishComments[dishId] ?? "" },
            set: { dishComments[dishId] = $0 }
        )
    }

    private func dishRatingLabel(_ value: Int) -> String {
        switch value {
        case 1: return "不再做"
        case 2: return "一般"
        case 3: return "还行"
        case 4: return "好吃"
        default: return "下次还要"
        }
    }

    private var commentCard: some View {
        SectionCard {
            FieldLabel("备注")
            TextField("写两句也行", text: $comment, axis: .vertical)
                .lineLimit(3...6)
                .padding(AppSpacing.md)
                .background(Color.appBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        }
    }

    private var photosCard: some View {
        SectionCard {
            HStack {
                FieldLabel("照片")
                Spacer()
                Text("最多 9 张")
                    .font(AppFont.caption(11))
                    .foregroundStyle(Color.inkMuted)
            }
            MultiPhotoPicker(urls: $photoLinks, maxCount: 9) { photosUploading = $0 }
            if let dishes = meal?.dishes, !dishes.isEmpty {
                Divider().overlay(Color.dividerLine.opacity(0.6))
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("顺手替换本顿菜图（可选）")
                        .font(AppFont.caption(12))
                        .foregroundStyle(Color.inkMuted)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(dishes) { dish in
                                Button {
                                    Haptics.light()
                                    photoPickerDish = dish
                                } label: {
                                    HStack(spacing: 7) {
                                        DishThumb(name: dish.recipeName, image: dish.recipeImage, size: 28, radius: 7)
                                            .id("\(dish.id)-\(dish.recipeImage ?? "")")
                                        Text(dish.recipeName)
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundStyle(Color.inkPrimary)
                                            .lineLimit(1)
                                        Image(systemName: "camera")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(Color.inkMuted)
                                    }
                                    .padding(.leading, 5)
                                    .padding(.trailing, 10)
                                    .frame(height: 38)
                                    .background(Color.appBackground, in: Capsule())
                                    .overlay {
                                        Capsule().strokeBorder(Color.dividerLine, lineWidth: 0.7)
                                    }
                                }
                                .buttonStyle(SoftPressStyle())
                            }
                        }
                    }
                }
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: AppSpacing.sm) {
            Button {
                Task { await submit(openShareAfterSave: true) }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                    Text("保存并分享")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                }
                .foregroundStyle(Color.inkPrimary)
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.dividerLine, lineWidth: 0.8)
                }
            }
            .buttonStyle(SoftPressStyle())
            .disabled(photosUploading || isSubmitting)

            PrimaryButton(title: "保存记录", isLoading: isSubmitting) {
                Task { await submit(openShareAfterSave: false) }
            }
            .disabled(photosUploading)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
        .background(Color.appBackground)
        .overlay(alignment: .top) {
            Divider().overlay(Color.dividerLine.opacity(0.6))
        }
    }

    private func loadMeal() async {
        do {
            let detail = try await MealService.shared.detail(id: mealId)
            meal = detail
            if !didPrefill {
                if let currentUserId,
                   let existing = detail.reviews?.first(where: { $0.userId == currentUserId }) {
                    rating = existing.rating
                    comment = existing.comment ?? ""
                    photoLinks = existing.photos ?? []
                    for item in existing.dishReviews ?? [] {
                        dishRatings[item.mealDishId] = item.rating
                        if let text = item.comment, !text.isEmpty {
                            dishComments[item.mealDishId] = text
                        }
                    }
                }
                didPrefill = true
            }
            for dish in detail.dishes ?? [] where dishRatings[dish.id] == nil {
                dishRatings[dish.id] = rating
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submit(openShareAfterSave: Bool) async {
        isSubmitting = true
        defer { isSubmitting = false }
        let dishReviews = buildDishReviews()
        do {
            _ = try await MealService.shared.review(
                mealId: mealId,
                ReviewInput(
                    rating: rating,
                    comment: comment.isEmpty ? nil : comment,
                    photos: photoLinks.isEmpty ? nil : photoLinks,
                    dishReviews: dishReviews.isEmpty ? nil : dishReviews
                )
            )
            if PendingReviewStore.load()?.mealId == mealId {
                PendingReviewStore.clear()
            }
            AppNotifications.mealChanged()
            AppNotifications.historyChanged()
            onSaved()
            if openShareAfterSave {
                if let latest = try? await MealService.shared.detail(id: mealId) {
                    sharePosterMeal = latest
                    return
                }
                if let meal {
                    sharePosterMeal = meal
                    return
                }
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func buildDishReviews() -> [DishReviewInput] {
        (meal?.dishes ?? []).map { dish in
            let text = dishComments[dish.id]?.trimmingCharacters(in: .whitespacesAndNewlines)
            return DishReviewInput(
                mealDishId: dish.id,
                rating: dishRatings[dish.id] ?? rating,
                comment: text?.isEmpty == false ? text : nil
            )
        }
    }

    private func coverPromptBanner(_ prompt: (recipeId: UInt, dishName: String, image: String, cutoutImage: String?)) -> some View {
        HStack(spacing: 8) {
            Text("已更新「\(prompt.dishName)」")
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.92))
                .lineLimit(1)
            Spacer(minLength: 4)
            Button {
                Task { await promoteCover(prompt) }
            } label: {
                HStack(spacing: 4) {
                    if isSettingCover {
                        ProgressView().tint(Color.actionInk).controlSize(.mini)
                    }
                    Text("设为菜谱封面")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(Color.actionInk)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(Color.white, in: Capsule())
            }
            .buttonStyle(SoftPressStyle())
            .disabled(isSettingCover)

            Button {
                coverPromptTask?.cancel()
                withAnimation(.easeOut(duration: 0.2)) {
                    coverPrompt = nil
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭提示")
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(Color.actionInk.opacity(0.94), in: Capsule())
        .shadow(color: Color.black.opacity(0.18), radius: 10, y: 4)
    }

    private func applyReplacedDishPhoto(_ result: DishPhotoApplyResult) {
        let updatedDish = result.updatedDish
        if var list = meal?.dishes,
           let idx = list.firstIndex(where: { $0.id == updatedDish.id }) {
            list[idx] = updatedDish
            meal?.dishes = list
        }
        Task {
            _ = await syncRemoteMealCanvasIfNeeded(mealID: mealId, forceRefresh: true)
        }
        AppNotifications.historyChanged()

        if let rid = updatedDish.recipeId,
           let img = updatedDish.recipeImage, !img.isEmpty,
           !result.isAlreadyCover {
            coverPromptTask?.cancel()
            withAnimation(.spring(response: 0.30, dampingFraction: 0.84)) {
                coverPrompt = (rid, updatedDish.recipeName, img, updatedDish.recipeCutoutImage)
            }
            coverPromptTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(4.5))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    coverPrompt = nil
                }
            }
        } else {
            coverPromptTask?.cancel()
            coverPrompt = nil
            tipMessage = result.isAlreadyCover ? "已恢复菜谱默认图" : "已换成本顿实拍"
        }
    }

    @MainActor
    private func promoteCover(_ prompt: (recipeId: UInt, dishName: String, image: String, cutoutImage: String?)) async {
        guard !isSettingCover else { return }
        isSettingCover = true
        coverPromptTask?.cancel()
        defer { isSettingCover = false }
        do {
            _ = try await RecipeService.shared.setCover(
                id: prompt.recipeId,
                image: prompt.image,
                cutoutImage: prompt.cutoutImage
            )
            withAnimation(.easeOut(duration: 0.2)) {
                coverPrompt = nil
            }
            Haptics.success()
            tipMessage = "已设为「\(prompt.dishName)」默认封面"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
