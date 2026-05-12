import SwiftUI

// 一顿吃完后的评价表单 评分 + 留言 + 照片 URL
struct MealReviewView: View {
    let mealId: UInt
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var rating: Int = 5
    @State private var comment: String = ""
    @State private var photoLinks: [String] = []
    @State private var newPhotoLink: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    header
                    ratingCard
                    commentCard
                    photosCard
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
            .navigationBarTitleDisplayMode(.inline)
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
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack {
                    Text("尝过了")
                        .font(AppFont.title(26))
                        .foregroundStyle(Color.inkPrimary)
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(Color.brandGreen)
                }
                Text("留下点感受 下次更好选")
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
                            .foregroundStyle(star <= rating ? Color.brandGreen : Color.inkMuted)
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
                Text("可选 链接")
                    .font(AppFont.caption(11))
                    .foregroundStyle(Color.inkMuted)
            }
            HStack(spacing: AppSpacing.sm) {
                TextField("贴一张照片的链接", text: $newPhotoLink)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .padding(AppSpacing.md)
                    .background(Color.appBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                Button {
                    addPhoto()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 36, height: 36)
                        .foregroundStyle(.white)
                        .background(Color.brandGreen)
                        .clipShape(Circle())
                }
            }
            if !photoLinks.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        ForEach(photoLinks, id: \.self) { link in
                            ZStack(alignment: .topTrailing) {
                                AsyncImageView(url: link, name: "")
                                    .frame(width: 96, height: 96)
                                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                                Button {
                                    photoLinks.removeAll { $0 == link }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white)
                                        .background(Circle().fill(Color.black.opacity(0.5)))
                                }
                                .padding(4)
                            }
                        }
                    }
                }
            }
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

    private func addPhoto() {
        let trimmed = newPhotoLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        photoLinks.append(trimmed)
        newPhotoLink = ""
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            _ = try await MealService.shared.review(
                mealId: mealId,
                ReviewInput(rating: rating, comment: comment.isEmpty ? nil : comment, photos: photoLinks.isEmpty ? nil : photoLinks)
            )
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
