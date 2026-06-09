import SwiftUI

// 聚餐点菜:所有参与者共用召集者家的菜单 在这里浏览并加菜 找不到也能报个菜名
struct DiningDishPicker: View {
    let mealId: UInt
    var onChanged: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

    @State private var recipes: [Recipe] = []
    @State private var keyword = ""
    @State private var isLoading = false
    @State private var addedIds: Set<UInt> = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    header
                    searchBar
                    grid
                    Color.clear.frame(height: 40)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .task { await load() }
            .toolbar(.hidden, for: .navigationBar)
            .toast($errorMessage)
        }
    }

    private var header: some View {
        VStack(spacing: AppSpacing.xs) {
            Text("点菜")
                .font(AppFont.title(26))
                .foregroundStyle(Color.inkPrimary)
            Text("大家一起点这桌的菜")
                .font(AppFont.body())
                .foregroundStyle(Color.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
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

    private var searchBar: some View {
        HStack(spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.inkMuted)
                TextField("找菜 找不到就报个菜名", text: $keyword)
                    .submitLabel(.search)
                    .onSubmit { Task { await load() } }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(Color.cardBackground)
            .clipShape(Capsule())
            .capsuleHairline()

            if !trimmedKeyword.isEmpty {
                Button {
                    Task { await addCustom() }
                } label: {
                    Text("报菜名")
                        .font(AppFont.body(14))
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .foregroundStyle(.white)
                        .background(Color.brandGreen)
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var grid: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("这桌的菜单")
                    .font(AppFont.headline(15))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                if isLoading {
                    ProgressView().tint(Color.brandGreen).controlSize(.small)
                }
            }
            if recipes.isEmpty && !isLoading {
                Text(trimmedKeyword.isEmpty ? "这家还没有菜谱" : "没找到 试试上面报菜名")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.inkMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.xl)
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            } else {
                let columns = Array(repeating: GridItem(.flexible(), spacing: AppSpacing.md), count: 3)
                LazyVGrid(columns: columns, spacing: AppSpacing.md) {
                    ForEach(recipes) { recipe in
                        RecipeCircleCard(recipe: recipe) {
                            Task { await addRecipe(recipe) }
                        }
                        .opacity(addedIds.contains(recipe.id) ? 0.4 : 1)
                    }
                }
            }
        }
    }

    private var trimmedKeyword: String {
        keyword.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            recipes = try await DiningService.shared.recipes(mealId: mealId, keyword: trimmedKeyword)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addRecipe(_ recipe: Recipe) async {
        if addedIds.contains(recipe.id) { return }
        do {
            _ = try await DiningService.shared.addDish(mealId: mealId, dish: DishInput(recipeId: recipe.id))
            addedIds.insert(recipe.id)
            Haptics.light()
            onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addCustom() async {
        let name = trimmedKeyword
        guard !name.isEmpty else { return }
        do {
            _ = try await DiningService.shared.addDish(mealId: mealId, dish: DishInput(name: name))
            keyword = ""
            Haptics.light()
            onChanged()
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
