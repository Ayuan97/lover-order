import SwiftUI

// 菜单页 双列网格 + 已加入这一顿 + 底部「就这些」
struct MenuView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm = MenuViewModel()
    @State private var searchActive: Bool = false
    @State private var showCreateRecipe: Bool = false
    @Environment(\.scenePhase) private var scenePhase

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
                    filterPanel
                    grid_section
                    pinnedSection
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
            }
            .background {
                Color.appBackground.ignoresSafeArea()
            }
            .refreshable {
                await vm.loadCurrentMeal(scene: .pair, mood: appState.currentMood)
                await vm.loadRecipes()
            }
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
            .task {
                await vm.bootstrap(scene: .pair, mood: appState.currentMood)
            }
            .task {
                // 与首页同款轮询 另一台手机加的菜自动出现在"已加入这一顿"
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(4))
                    guard scenePhase == .active else { continue }
                    await vm.syncMeal(scene: .pair, mood: appState.currentMood)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .recipesChanged)) { _ in
                Task { await vm.loadRecipes() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .categoriesChanged)) { _ in
                Task { await vm.loadCategories() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .mealChanged)) { _ in
                Task { await vm.loadCurrentMeal(scene: .pair, mood: appState.currentMood) }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showCreateRecipe) {
                RecipeEditView(mode: .create) { _ in
                    Task { await vm.loadRecipes() }
                }
                .environmentObject(appState)
            }
            .toast($vm.errorMessage)
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 5) {
                Text("今日菜谱")
                    .font(AppFont.title(31))
                    .foregroundStyle(Color.inkPrimary)
                Text("选择菜品加入今天的菜单")
                .font(AppFont.body(13))
                .foregroundStyle(Color.inkMuted)
            }
            Spacer()
            Button {
                showCreateRecipe = true
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "pencil.tip")
                        .font(.system(size: 16, weight: .medium))
                    Text("记一道")
                        .font(AppFont.caption(10))
                }
                .foregroundStyle(Color.brandGreen)
                .frame(width: 48, height: 48)
                .background(Color.paperGreen)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.brandGreen.opacity(0.25), lineWidth: 1))
            }
        }
        .padding(.top, AppSpacing.sm)
    }

    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundStyle(Color.brandGreen)
                Text("筛选")
                    .font(AppFont.headline(15))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                if vm.selectedCategoryId != nil || vm.quickFilter != .all {
                    Text("已筛选")
                        .font(AppFont.caption(11))
                        .foregroundStyle(Color.accentWarm)
                    Button("清除") {
                        Task { await vm.clearFilters() }
                    }
                    .font(AppFont.caption(11))
                    .foregroundStyle(Color.inkMuted)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    CategoryChip(title: MenuFilter.recent.label, isSelected: vm.quickFilter == .recent) {
                        Task { await vm.selectFilter(vm.quickFilter == .recent ? .all : .recent) }
                    }
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(visibleCategories) { category in
                        CategoryChip(title: category.name, isSelected: vm.selectedCategoryId == category.id) {
                            Task { await vm.selectCategory(category.id) }
                        }
                    }
                }
            }
        }
        .padding(AppSpacing.md)
        .background(Color.cardBackground.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.inkPrimary.opacity(0.055), lineWidth: 1))
        .shadow(color: Color.inkPrimary.opacity(0.035), radius: 14, y: 5)
    }

    /// 后端分类允许用户自定义；如果有人把“最近做过”之类的快捷筛选也建成分类，页面只展示一次。
    private var visibleCategories: [RecipeCategory] {
        let quickLabels = Set(MenuFilter.allCases.map(\.label))
        return vm.categories.filter { !quickLabels.contains($0.name) }
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
        .padding(.vertical, 11)
        .background(Color.cardBackground.opacity(0.9))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.inkPrimary.opacity(0.055), lineWidth: 1))
        .overlay(alignment: .bottom) {
            Capsule().fill(Color.brandGreen.opacity(0.42)).frame(width: 38, height: 2)
                .padding(.bottom, 3)
        }
    }

    private var grid_section: some View {
        Group {
            if vm.isLoading && vm.recipes.isEmpty {
                ProgressView().tint(Color.brandGreen).padding(.top, 60)
            } else if vm.recipes.isEmpty {
                if vm.loadFailed {
                    LoadFailedView { await vm.loadRecipes() }
                } else {
                    emptyHint
                }
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
                        .onAppear {
                            if recipe.id == vm.recipes.last?.id {
                                Task { await vm.loadMore() }
                            }
                        }
                    }
                }
                if vm.isLoadingMore {
                    ProgressView()
                        .tint(Color.brandGreen)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
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
                SectionCard(padding: AppSpacing.lg, radius: 6) {
                    HStack {
                        Text("已选菜品")
                            .font(AppFont.title(19))
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
                                // confirmed 最后一道不能删，与首页一致
                                if canRemovePinnedDish {
                                    Button {
                                        Task { await vm.removeDish(dish) }
                                    } label: {
                                        Image(systemName: "minus.circle")
                                            .foregroundStyle(Color.inkMuted)
                                    }
                                }
                            }
                            Divider().overlay(Color.brandGreen.opacity(0.12))
                        }
                    }
                }
                .background(Color.paperWarm.opacity(0.82))
                .rotationEffect(.degrees(0.5))
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
                    Text("今天的菜单 · " + appState.currentMood.label)
                        .font(AppFont.caption())
                        .foregroundStyle(Color.inkMuted)
                }
                Spacer()
                PrimaryButton(title: confirmTitle) {
                    Task { await vm.confirmMeal() }
                }
                .frame(width: 180)
                .disabled(vm.meal?.status != .planning)
                .opacity(vm.meal?.status == .planning ? 1 : 0.55)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.sm)
        }
        .background(Color.cardBackground)
    }

    private func alreadyAdded(_ recipe: Recipe) -> Bool {
        vm.pinnedDishes.contains { $0.recipeId == recipe.id }
    }

    // planning 可删任意道；confirmed 至少留一道（与 MealNow 一致）
    private var canRemovePinnedDish: Bool {
        guard let status = vm.meal?.status else { return true }
        if status == .confirmed { return vm.pinnedDishes.count > 1 }
        return status == .planning
    }

    private var confirmTitle: String {
        guard let meal = vm.meal else { return "确认菜单" }
        switch meal.status {
        case .planning: return "确认菜单"
        case .confirmed: return "已确认"
        case .completed: return "已完成"
        case .cancelled: return "已取消"
        }
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
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? Color.inkPrimary : Color.inkSecondary)
                .background(isSelected ? Color.brandGreen.opacity(0.14) : Color.cardBackground.opacity(0.88))
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(isSelected ? Color.brandGreen.opacity(0.28) : Color.inkPrimary.opacity(0.07), lineWidth: 1)
                }
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Circle()
                            .fill(Color.liveOlive)
                            .frame(width: 5, height: 5)
                            .offset(x: -4, y: 3)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

// 菜谱网格卡
private struct MenuRecipeCard: View {
    let recipe: Recipe
    let alreadyAdded: Bool
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImageView(url: recipe.coverImage, name: recipe.name)
                    .frame(height: 142)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .overlay(alignment: .topTrailing) {
                        Text("✦")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.dopaminePink.opacity(0.9))
                            .padding(8)
                    }
                    .overlay(alignment: .topLeading) {
                        if let time = recipe.cookingTime, time > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "clock").font(.system(size: 10))
                                Text("\(time)分钟").font(AppFont.caption(11))
                            }
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, 4)
                            .background(Color.cardBackground.opacity(0.78))
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .foregroundStyle(Color.inkPrimary)
                            .padding(AppSpacing.sm)
                        }
                    }

                Button(action: onAdd) {
                    Image(systemName: alreadyAdded ? "checkmark" : "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(alreadyAdded ? Color.inkMuted : Color.accentWarm)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 2))
                }
                .padding(AppSpacing.sm)
            }
            VStack(alignment: .leading, spacing: 3) {
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
                HStack(spacing: 4) {
                    if let creator = recipe.creator {
                        AvatarView(user: creator, size: 16)
                        Text(creator.displayName)
                            .font(AppFont.caption(11))
                            .foregroundStyle(Color.inkMuted)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if let used = recipe.useCount, used > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "fork.knife").font(.system(size: 9))
                            Text("\(used)").font(AppFont.caption(11))
                        }
                        .foregroundStyle(Color.brandGreen)
                    }
                }
                .padding(.top, 1)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        .background(Color.cardBackground.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.inkPrimary.opacity(0.07), lineWidth: 1))
        .appCardShadow()
        .rotationEffect(.degrees(recipe.id.isMultiple(of: 2) ? -0.35 : 0.35))
    }
}

// 菜谱页用的极轻纸张底和几笔手绘装饰，保持白色为主，颜色只做小面积提示。
struct HandmadePaper<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            Color.appBackground
            Canvas { context, size in
                let step: CGFloat = 22
                var index = 0
                for y in stride(from: 0, through: size.height, by: step) {
                    for x in stride(from: 0, through: size.width, by: step) {
                        let n = CGFloat((index * 29) % 13) / 13
                        let dot = Path(ellipseIn: CGRect(x: x + n * 6, y: y + CGFloat((index * 7) % 5), width: 0.5 + n, height: 0.5 + n))
                        context.fill(dot, with: .color(Color.inkPrimary.opacity(0.004 + n * 0.005)))
                        index += 1
                    }
                }
            }
            .allowsHitTesting(false)
            content()
        }
    }
}

struct HandDrawnUnderline: View {
    var color: Color = Color.brandGreen
    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 1, y: size.height * 0.45))
            path.addCurve(to: CGPoint(x: size.width - 1, y: size.height * 0.58), control1: CGPoint(x: size.width * 0.28, y: size.height * 0.08), control2: CGPoint(x: size.width * 0.68, y: size.height * 0.92))
            context.stroke(path, with: .color(color.opacity(0.7)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        }
        .frame(height: 7)
    }
}

struct DoodleSprig: View {
    var body: some View {
        Image(systemName: "leaf.fill")
            .font(.system(size: 22, weight: .light))
            .foregroundStyle(Color.brandGreen.opacity(0.5))
            .rotationEffect(.degrees(-22))
            .allowsHitTesting(false)
    }
}

struct NotebookRule: View {
    var body: some View { Rectangle().fill(Color.brandGreen.opacity(0.11)).frame(height: 1) }
}
