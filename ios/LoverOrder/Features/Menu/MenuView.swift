import SwiftUI

// 菜单页 双列网格 + 已加入这一顿 + 底部"定下这一顿"
struct MenuView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm = MenuViewModel()
    @State private var searchActive: Bool = false
    @State private var showCreateRecipe: Bool = false

    private let grid = [
        GridItem(.flexible(), spacing: AppSpacing.md),
        GridItem(.flexible(), spacing: AppSpacing.md)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    header
                    searchBar
                    quickFilterChips
                    categoryChips
                    grid_section
                    pinnedSection
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
                await vm.bootstrap(scene: appState.currentScene, mood: appState.currentMood)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showCreateRecipe) {
                RecipeEditView(mode: .create) { _ in
                    Task { await vm.loadRecipes() }
                }
                .environmentObject(appState)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text("菜单")
                    .font(AppFont.title(30))
                    .foregroundStyle(Color.inkPrimary)
                Image(systemName: "leaf.fill")
                    .foregroundStyle(Color.brandGreen)
                Spacer()
                Button {
                    showCreateRecipe = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .foregroundStyle(.white)
                        .background(Color.brandGreen)
                        .clipShape(Circle())
                }
            }
            Text("把这一顿想选的菜放在这里")
                .font(AppFont.body())
                .foregroundStyle(Color.inkMuted)
            CurrentSceneBadge(scene: appState.currentScene)
                .padding(.top, AppSpacing.xs)
        }
        .padding(.vertical, AppSpacing.sm)
    }

    private var quickFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(MenuFilter.allCases) { f in
                    CategoryChip(title: f.label, isSelected: vm.quickFilter == f) {
                        Task { await vm.selectFilter(f) }
                    }
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.inkMuted)
            TextField("搜搜想吃的", text: $vm.keyword)
                .submitLabel(.search)
                .onSubmit {
                    Task { await vm.searchChanged() }
                }
            if !vm.keyword.isEmpty {
                Button {
                    vm.keyword = ""
                    Task { await vm.searchChanged() }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.inkMuted)
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.pill, style: .continuous))
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                CategoryChip(title: "全部", isSelected: vm.selectedCategoryId == nil) {
                    Task { await vm.selectCategory(nil) }
                }
                ForEach(vm.categories) { cat in
                    CategoryChip(title: cat.name, isSelected: vm.selectedCategoryId == cat.id) {
                        Task { await vm.selectCategory(cat.id) }
                    }
                }
            }
        }
    }

    private var grid_section: some View {
        Group {
            if vm.isLoading && vm.recipes.isEmpty {
                ProgressView().tint(Color.brandGreen).padding(.top, 60)
            } else if vm.recipes.isEmpty {
                emptyHint
            } else {
                LazyVGrid(columns: grid, spacing: AppSpacing.md) {
                    ForEach(vm.recipes) { recipe in
                        NavigationLink {
                            RecipeDetailView(recipeId: recipe.id)
                        } label: {
                            MenuRecipeCard(recipe: recipe, alreadyAdded: alreadyAdded(recipe)) {
                                Task { await vm.addDish(recipe) }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var emptyHint: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundStyle(Color.inkMuted)
            Text("还没有菜谱 先去添加一道吧")
                .font(AppFont.body())
                .foregroundStyle(Color.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xxl)
    }

    private var pinnedSection: some View {
        Group {
            if !vm.pinnedDishes.isEmpty {
                SectionCard {
                    HStack {
                        Text("已加入这一顿")
                            .font(AppFont.headline(15))
                            .foregroundStyle(Color.inkPrimary)
                        Spacer()
                        Text("\(vm.pinnedDishes.count) 道")
                            .font(AppFont.caption())
                            .foregroundStyle(Color.inkMuted)
                    }
                    VStack(spacing: AppSpacing.sm) {
                        ForEach(vm.pinnedDishes) { dish in
                            HStack(spacing: AppSpacing.md) {
                                DishThumb(name: dish.recipeName, image: dish.recipeImage)
                                Text(dish.recipeName)
                                    .font(AppFont.body(15))
                                    .foregroundStyle(Color.inkPrimary)
                                Spacer()
                                Button {
                                    Task { await vm.removeDish(dish) }
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(Color.inkMuted)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider().background(Color.dividerLine)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(vm.pinnedDishes.count) 道菜")
                        .font(AppFont.headline(15))
                        .foregroundStyle(Color.inkPrimary)
                    Text(appState.currentScene.label + " · " + appState.currentMood.label)
                        .font(AppFont.caption())
                        .foregroundStyle(Color.inkMuted)
                }
                Spacer()
                PrimaryButton(title: "定下这一顿") {
                    Task { await vm.confirmMeal() }
                }
                .frame(width: 180)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.sm)
        }
        .background(Color.appBackground)
    }

    private func alreadyAdded(_ recipe: Recipe) -> Bool {
        vm.pinnedDishes.contains { $0.recipeId == recipe.id }
    }
}

// 单条 chip
private struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.body(14))
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, 10)
                .foregroundStyle(isSelected ? .white : Color.inkPrimary)
                .background(isSelected ? Color.brandGreen : Color.cardBackground)
                .clipShape(Capsule(style: .continuous))
        }
    }
}

// 菜谱网格卡
private struct MenuRecipeCard: View {
    let recipe: Recipe
    let alreadyAdded: Bool
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            ZStack(alignment: .topTrailing) {
                AsyncImageView(url: recipe.coverImage, name: recipe.name)
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))

                if let time = recipe.cookingTime, time > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "clock").font(.system(size: 10))
                        Text("\(time)分钟").font(AppFont.caption(11))
                    }
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(AppSpacing.sm)
                    .foregroundStyle(Color.inkPrimary)
                }

                Button(action: onAdd) {
                    Image(systemName: alreadyAdded ? "checkmark" : "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.brandGreen)
                        .clipShape(Circle())
                }
                .padding(AppSpacing.sm)
                .offset(y: 110)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(recipe.name)
                    .font(AppFont.body(15))
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
                if let desc = recipe.description, !desc.isEmpty {
                    Text(desc)
                        .font(AppFont.caption())
                        .foregroundStyle(Color.inkMuted)
                        .lineLimit(1)
                }
                if let used = recipe.useCount, used > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 9))
                        Text("吃过 \(used) 次")
                            .font(AppFont.caption(11))
                    }
                    .foregroundStyle(Color.brandGreen)
                }
            }
        }
    }
}
