import SwiftUI

// 一顿吃完后的评价表单 评分 + 留言 + 照片 URL
struct MealReviewView: View {
    let mealId: UInt
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var rating: Int = 5
    @State private var comment: String = ""
    @State private var photoLinks: [String] = []
    @State private var meal: MealSession?
    @State private var dishRatings: [UInt: Int] = [:]
    @State private var dishComments: [UInt: String] = [:]
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    header
                    ratingCard
                    dishRatingCard
                    commentCard
                    photosCard
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
                await loadMeal()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toast($errorMessage)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("以后再说").foregroundStyle(Color.inkSecondary)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        VStack(spacing: AppSpacing.xs) {
            HStack(spacing: 6) {
                Text("尝过了")
                    .font(AppFont.title(26))
                    .foregroundStyle(Color.inkPrimary)
                Image(systemName: "heart.fill")
                    .foregroundStyle(Color.accentWarm)
                    .font(.system(size: 13))
            }
            Text("留下点感受 下次更好选")
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

    private var ratingCard: some View {
        SectionCard {
            FieldLabel("这一顿怎么样")
            HStack(spacing: AppSpacing.sm) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        rating = star
                    } label: {
                        Image(systemName: star <= rating ? "leaf.fill" : "leaf")
                            .font(.system(size: 28))
                            .foregroundStyle(star <= rating ? Color.accentWarm : Color.inkMuted)
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
        case 2: return "还行"
        case 3: return "凑合吃"
        case 4: return "挺满意"
        default: return "很满足 意犹未尽"
        }
    }

    @ViewBuilder
    private var dishRatingCard: some View {
        if let dishes = meal?.dishes, !dishes.isEmpty {
            SectionCard {
                FieldLabel("单独菜品怎么样")
                VStack(spacing: AppSpacing.md) {
                    ForEach(dishes) { dish in
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            HStack(spacing: AppSpacing.md) {
                                DishThumb(name: dish.recipeName, image: dish.recipeImage)
                                Text(dish.recipeName)
                                    .font(AppFont.body(15))
                                    .foregroundStyle(Color.inkPrimary)
                                Spacer()
                            }
                            dishRatingRow(dish.id)
                            TextField("这道菜的感受", text: dishCommentBinding(dish.id), axis: .vertical)
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
                    Image(systemName: star <= (dishRatings[dishId] ?? rating) ? "leaf.fill" : "leaf")
                        .font(.system(size: 20))
                        .foregroundStyle(star <= (dishRatings[dishId] ?? rating) ? Color.accentWarm : Color.inkMuted)
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
            FieldLabel("想说点什么")
            TextField("写两句感受", text: $comment, axis: .vertical)
                .lineLimit(3...6)
                .padding(AppSpacing.md)
                .background(Color.appBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        }
    }

    private var photosCard: some View {
        SectionCard {
            HStack {
                FieldLabel("配图")
                Spacer()
                Text("最多 9 张")
                    .font(AppFont.caption(11))
                    .foregroundStyle(Color.inkMuted)
            }
            MultiPhotoPicker(urls: $photoLinks, maxCount: 9)
        }
    }

    private var bottomBar: some View {
        PrimaryButton(title: isSubmitting ? "保存中" : "留下这份感受", isLoading: isSubmitting) {
            Task { await submit() }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
        .background(Color.appBackground)
    }

    private func loadMeal() async {
        do {
            let detail = try await MealService.shared.detail(id: mealId)
            meal = detail
            for dish in detail.dishes ?? [] where dishRatings[dish.id] == nil {
                dishRatings[dish.id] = rating
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submit() async {
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
            onSaved()
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
}
