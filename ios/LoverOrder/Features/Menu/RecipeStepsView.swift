import SwiftUI

// 独立做法步骤页 从详情页"做法"卡片点击进入
struct RecipeStepsView: View {
    let recipe: Recipe

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var tabBarToken = UUID()

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
        .onAppear {
            appState.setTabBarHidden(true, token: tabBarToken)
        }
        .onDisappear {
            appState.setTabBarHidden(false, token: tabBarToken)
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
                FlowLayout(spacing: 8) {
                    ForEach(items) { ing in
                        HStack(spacing: 5) {
                            Text(ing.name)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.inkPrimary)
                            if !ing.amount.isEmpty {
                                Text(ing.amount)
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(Color.inkMuted)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.appBackground, in: Capsule())
                        .overlay {
                            Capsule()
                                .strokeBorder(Color.dividerLine.opacity(0.7), lineWidth: 0.7)
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
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.inkPrimary.opacity(0.08), lineWidth: 1))
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
        let obsidian = Color(red: 0.067, green: 0.067, blue: 0.075)
        return VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                Text("\(step.index)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .frame(width: 28, height: 28)
                    .foregroundStyle(.white)
                    .background(obsidian, in: Circle())
                Text(step.text)
                    .font(AppFont.body(14))
                    .lineSpacing(4)
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
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.dividerLine.opacity(0.55), lineWidth: 0.7)
        }
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
        .background(Color.appBackground)
        .overlay(alignment: .top) {
            Divider().overlay(Color.dividerLine.opacity(0.6))
        }
    }
}
