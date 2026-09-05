import SwiftUI

// 独立做法步骤页 从详情页"做法"卡片点击进入
struct RecipeStepsView: View {
    let recipe: Recipe

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                headerCard
                ingredientsGrid
                stepsSection
                if let tips = recipe.tips, !tips.isEmpty {
                    tipsSection(tips)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .navigationTitle("做法 · \(recipe.name)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        HStack(spacing: AppSpacing.md) {
            AsyncImageView(url: recipe.coverImage, name: recipe.name)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(AppFont.title(20))
                    .foregroundStyle(Color.inkPrimary)
                if let desc = recipe.description, !desc.isEmpty {
                    Text(desc)
                        .font(AppFont.caption())
                        .foregroundStyle(Color.inkSecondary)
                        .lineLimit(2)
                }
            }
            Spacer()
        }
    }

    private var ingredientsGrid: some View {
        SectionCard {
            HStack {
                Text("准备食材")
                    .font(AppFont.headline(15))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                Text("\(recipe.ingredients?.count ?? 0) 样")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.inkMuted)
            }
            let items = recipe.ingredients ?? []
            if items.isEmpty {
                Text("还没列出食材")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.inkMuted)
            } else {
                let columns = Array(repeating: GridItem(.flexible(), spacing: AppSpacing.md), count: 4)
                LazyVGrid(columns: columns, spacing: AppSpacing.md) {
                    ForEach(items) { ing in
                        VStack(spacing: 4) {
                            ZStack {
                                Color.appBackground
                                Image(systemName: "leaf.circle")
                                    .font(.system(size: 20, weight: .light))
                                    .foregroundStyle(Color.brandGreen)
                            }
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                            Text(ing.name)
                                .font(AppFont.caption(11))
                                .foregroundStyle(Color.inkPrimary)
                                .lineLimit(1)
                            Text(ing.amount)
                                .font(AppFont.caption(10))
                                .foregroundStyle(Color.inkMuted)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("步骤")
                    .font(AppFont.headline(17))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                Text("\(recipe.steps?.count ?? 0) 步")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.inkMuted)
            }
            let steps = recipe.steps ?? []
            if steps.isEmpty {
                Text("还没补充步骤")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.inkMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.xl)
            .background(Color.cardBackground.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.inkPrimary.opacity(0.08), lineWidth: 1))
            .appCardShadow()
            } else {
                VStack(spacing: AppSpacing.sm) {
                    ForEach(steps) { step in
                        stepCard(step)
                    }
                }
            }
        }
    }

    private func stepCard(_ step: CookingStep) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                Text("\(step.index)")
                    .font(AppFont.headline(15))
                    .frame(width: 28, height: 28)
                    .foregroundStyle(.white)
        .background(step.index.isMultiple(of: 2) ? Color.accentWarm : Color.brandGreen)
                    .clipShape(Circle())
                Text(step.text)
                    .font(AppFont.body(14))
                    .foregroundStyle(Color.inkPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let image = step.image, !image.isEmpty {
                AsyncImageView(url: image, name: "步骤 \(step.index)")
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(AppSpacing.lg)
        .background(step.index.isMultiple(of: 2) ? Color.paperWarm : Color.paperGreen)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.inkPrimary.opacity(0.07), lineWidth: 1))
    }

    private func tipsSection(_ tips: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: 4) {
                Image(systemName: "lightbulb")
                    .foregroundStyle(Color.brandGreen)
                Text("小贴士")
                    .font(AppFont.headline(15))
                    .foregroundStyle(Color.inkPrimary)
            }
            Text(tips)
                .font(AppFont.body(14))
                .foregroundStyle(Color.inkSecondary)
        }
        .padding(AppSpacing.lg)
        .background(Color.paperWarm)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
    }

    private var bottomBar: some View {
        HStack(spacing: AppSpacing.md) {
            SecondaryButton(title: "返回详情", icon: "chevron.left") {
                dismiss()
            }
            PrimaryButton(title: "做完这个", icon: "checkmark") {
                dismiss()
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
        .background(Color.cardBackground)
    }
}
