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
                    Color.clear.frame(height: 150)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
            }
            .background {
                Color.appBackground.ignoresSafeArea()
            }
            .refreshable {
                await vm.loadCurrentMeal(scene: .household, mood: appState.currentMood)
                await vm.loadRecipes()
            }
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
            .onChange(of: appState.activeTab) { _, tab in
                if tab == 1 {
                    Task { await vm.loadCurrentMeal(scene: .household, mood: appState.currentMood) }
                }
            }
            .task {
                await vm.bootstrap(scene: .household, mood: appState.currentMood)
            }
            .task {
                // 与首页同款轮询 另一台手机加的菜自动出现在"已加入这一顿"
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(4))
                    guard scenePhase == .active else { continue }
                    await vm.syncMeal(scene: .household, mood: appState.currentMood)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .recipesChanged)) { _ in
                Task { await vm.loadRecipes() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .categoriesChanged)) { _ in
                Task { await vm.loadCategories() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .mealChanged)) { _ in
                Task { await vm.loadCurrentMeal(scene: .household, mood: appState.currentMood) }
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
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("菜谱")
                    .font(AppFont.title(27))
                    .foregroundStyle(Color.inkPrimary)
                if !vm.recipes.isEmpty {
                    Text("共 \(vm.recipes.count) 道菜")
                        .font(AppFont.caption(12))
                        .foregroundStyle(Color.inkMuted)
                }
            }
            Spacer()
            Button {
                showCreateRecipe = true
            } label: {
                ProductIcon(kind: .add)
                    .foregroundStyle(Color.inkPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.cardBackground, in: Circle())
            }
            .buttonStyle(SoftPressStyle())
            .accessibilityLabel("添加菜谱")
        }
        .frame(minHeight: 54)
    }

    private var filterPanel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(title: "全部", isSelected: vm.selectedCategoryId == nil && vm.quickFilter == .all) {
                    Task { await vm.clearFilters() }
                }
                CategoryChip(title: MenuFilter.recent.label, isSelected: vm.quickFilter == .recent) {
                    Task { await vm.selectFilter(vm.quickFilter == .recent ? .all : .recent) }
                }
                ForEach(visibleCategories) { category in
                    CategoryChip(title: category.name, isSelected: vm.selectedCategoryId == category.id) {
                        Task { await vm.selectCategory(category.id) }
                    }
                }
            }
        }
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
        .accessibilityLabel("搜索菜谱")
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
                        let pinned = pinnedDish(for: recipe)
                        MenuRecipeCard(
                            recipe: recipe,
                            alreadyAdded: pinned != nil,
                            canToggle: pinned == nil || canRemovePinnedDish
                        ) {
                            if let pinned {
                                Task { await vm.removeDish(pinned) }
                            } else {
                                Task { await vm.addDish(recipe) }
                            }
                        }
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
                SectionCard(padding: AppSpacing.lg, radius: 20) {
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
                        ForEach(Array(vm.pinnedDishes.enumerated()), id: \.element.id) { idx, dish in
                            HStack(spacing: AppSpacing.md) {
                                DishThumb(name: dish.recipeName, image: dish.recipeImage)
                                Text(dish.recipeName)
                                    .font(AppFont.body(15))
                                    .foregroundStyle(Color.inkPrimary)
                                Spacer()
                                // 已定下的最后一道也可移除，移除后回到挑菜态
                                if canRemovePinnedDish {
                                    Button {
                                        Task { await vm.removeDish(dish) }
                                    } label: {
                                        Image(systemName: "minus.circle")
                                            .foregroundStyle(Color.inkMuted)
                                    }
                                }
                            }
                            if idx < vm.pinnedDishes.count - 1 {
                                Divider().overlay(Color.brandGreen.opacity(0.12))
                            }
                        }
                    }
                }

            }
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        if !vm.pinnedDishes.isEmpty {
            HStack(spacing: 12) {
                HStack(spacing: -8) {
                    ForEach(vm.pinnedDishes.prefix(3)) { dish in
                        DishThumb(name: dish.recipeName, image: dish.recipeImage, size: 28, radius: 14)
                            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                    }
                }

                Text("已选 \(vm.pinnedDishes.count) 道")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.inkPrimary)

                Spacer(minLength: 4)

                if vm.meal?.status == .planning {
                    Button {
                        Haptics.light()
                        Task { await vm.confirmMeal() }
                    } label: {
                        Text("定下这顿")
                            .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .frame(height: 38)
                            .background(Color(red: 0.067, green: 0.067, blue: 0.075), in: Capsule())
                    }
                    .buttonStyle(SoftPressStyle())
                } else {
                    Button {
                        Haptics.light()
                        appState.switchToMealTab()
                    } label: {
                        HStack(spacing: 4) {
                            Text("去画布看看")
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 15)
                        .frame(height: 38)
                        .background(Color(red: 0.067, green: 0.067, blue: 0.075), in: Capsule())
                    }
                    .buttonStyle(SoftPressStyle())
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 7)
            .frame(height: 52)
            .background {
                ZStack {
                    Capsule().fill(.ultraThinMaterial)
                    Capsule().fill(Color.white.opacity(0.86))
                }
            }
            .overlay {
                Capsule().strokeBorder(Color.black.opacity(0.08), lineWidth: 0.7)
            }
            .shadow(color: Color.black.opacity(0.10), radius: 16, y: 6)
            .padding(.horizontal, 18)
            .padding(.bottom, 76)
        }
    }

    private func pinnedDish(for recipe: Recipe) -> MealDish? {
        vm.pinnedDishes.first { $0.recipeId == recipe.id }
    }

    // planning 与 confirmed 均可移除菜品，删空后回到挑菜态
    private var canRemovePinnedDish: Bool {
        guard let status = vm.meal?.status else { return true }
        return status == .planning || status == .confirmed
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
        Button {
            Haptics.light()
            action()
        } label: {
            Text(title)
                .font(.system(size: 13.5, weight: isSelected ? .semibold : .medium, design: .rounded))
                .padding(.horizontal, 15)
                .frame(height: 36)
                .foregroundStyle(isSelected ? .white : Color.inkSecondary)
                .background(
                    isSelected ? Color(red: 0.067, green: 0.067, blue: 0.075) : Color.cardBackground,
                    in: Capsule()
                )
                .overlay {
                    if !isSelected {
                        Capsule()
                            .stroke(Color.dividerLine.opacity(0.9), lineWidth: 0.7)
                    }
                }
        }
        .buttonStyle(SoftPressStyle())
    }
}

// 菜谱网格卡
private struct MenuRecipeCard: View {
    let recipe: Recipe
    let alreadyAdded: Bool
    var canToggle: Bool = true
    let onAdd: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            NavigationLink {
                RecipeDetailView(recipeId: recipe.id)
            } label: {
                VStack(alignment: .leading, spacing: 0) {
                    cover
                    information
                }
            }
            .buttonStyle(.plain)
            Button(action: onAdd) {
                Image(systemName: alreadyAdded ? "checkmark" : "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        alreadyAdded ? Color(red: 0.067, green: 0.067, blue: 0.075) : Color.black.opacity(0.68),
                        in: Circle()
                    )
                    .overlay {
                        Circle().strokeBorder(Color.white.opacity(0.32), lineWidth: 0.7)
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(SoftPressStyle())
            .padding(.top, 95)
            .padding(.trailing, 3)
            .disabled(!canToggle)
            .accessibilityLabel(alreadyAdded ? "移出这一顿：" + recipe.name : "加入" + recipe.name)
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.dividerLine.opacity(0.6), lineWidth: 0.7)
        }
    }

    private var cover: some View {
        GeometryReader { proxy in
            AsyncImageView(url: recipe.coverImage, name: recipe.name)
                .frame(width: proxy.size.width, height: 142)
                .clipped()
                .overlay(alignment: .bottom) {
                    LinearGradient(colors: [.clear, Color.black.opacity(0.18)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 46)
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .topLeading) {
                    if let time = recipe.cookingTime, time > 0 {
                        Text("\(time) 分钟")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.48), in: Capsule())
                            .overlay {
                                Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 0.6)
                            }
                            .padding(8)
                    }
                }
        }
        .frame(height: 142)
    }

    private var information: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(recipe.name)
                .font(AppFont.headline(15))
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(1)
            if let desc = recipe.description, !desc.isEmpty {
                Text(desc)
                    .font(AppFont.caption(12))
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
                    Text("做过 \(used) 次")
                        .font(AppFont.caption(11))
                        .foregroundStyle(Color.brandGreen)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
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
