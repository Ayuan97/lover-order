import SwiftUI

// 独立做法步骤页 从详情页"做法"卡片点击进入
struct RecipeStepsView: View {
    let recipe: Recipe

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                headerCard
                quickFacts
                ingredientsGrid
                stepsSection
                if let tips = recipe.tips, !tips.isEmpty {
                    tipsSection(tips)
                }
                Color.clear.frame(height: 80)
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

    private var quickFacts: some View {
        FlowLayout(spacing: AppSpacing.sm) {
            if let t = recipe.cookingTime, t > 0 {
                factChip(icon: "clock", text: "\(t) 分钟")
            }
            if let s = recipe.servings, s > 0 {
                factChip(icon: "person.2", text: "\(s) 人份")
            }
            if let d = recipe.difficulty {
                factChip(icon: "flame", text: d.label)
            }
            if let tags = recipe.tags, let first = tags.first {
                factChip(icon: "leaf", text: first)
            }
        }
    }

    private func factChip(icon: String, text: String) -> some View {
        TagChip(text: text, icon: icon)
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
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
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
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Text("\(step.index)")
                .font(AppFont.headline(15))
                .frame(width: 28, height: 28)
                .foregroundStyle(.white)
                .background(Color.brandGreen)
                .clipShape(Circle())
            Text(step.text)
                .font(AppFont.body(14))
                .foregroundStyle(Color.inkPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppSpacing.md)
        .background(Color.brandGreen.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
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
        .background(Color(red: 0.97, green: 0.93, blue: 0.83))
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
        .background(Color.appBackground)
    }
}
