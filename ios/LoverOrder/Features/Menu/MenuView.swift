import SwiftUI

// 菜单页 双列网格 + 分类管理 + 单卡编辑删除 + 批量移动分类/删除 + 已加入这一顿
struct MenuView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm = MenuViewModel()
    @State private var searchActive: Bool = false
    @State private var showCreateRecipe: Bool = false
    @State private var editingRecipe: Recipe?
    @State private var photoStudioRecipe: Recipe?
    @State private var pendingDeleteRecipe: Recipe?

    // 分类管理与删除确认
    @State private var categorySheetTarget: CategorySheetPresentation?
    @State private var pendingDeleteCategory: RecipeCategory?

    // 批量管理状态
    @State private var isManaging: Bool = false
    @State private var selectedRecipeIds: Set<UInt> = []
    @State private var showBatchCategorySheet: Bool = false
    @State private var confirmBatchDelete: Bool = false

    @State private var previewGallery: PhotoGalleryPresentation?
    @State private var activeCardMenuRecipeId: UInt?
    @State private var activeCardMenuAnchor: CGRect = .zero
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct CategorySheetPresentation: Identifiable {
        let id = UUID()
        let initialEditing: RecipeCategory?
    }

    private let grid = [
        GridItem(.flexible(), spacing: AppSpacing.md),
        GridItem(.flexible(), spacing: AppSpacing.md)
    ]

    var body: some View {
        NavigationStack {
            menuScrollStage
                .sheet(isPresented: $showCreateRecipe) {
                RecipeEditView(mode: .create) { _ in
                    Task {
                        await vm.loadCategories()
                        await vm.loadRecipes()
                    }
                }
                .environmentObject(appState)
            }
            .sheet(item: $editingRecipe) { target in
                RecipeEditView(
                    mode: .edit(target),
                    onSaved: { _ in
                        Task {
                            await vm.loadCategories()
                            await vm.loadRecipes()
                        }
                    },
                    onDeleted: {
                        Task {
                            await vm.loadCategories()
                            await vm.loadRecipes()
                        }
                    }
                )
                .environmentObject(appState)
            }
            .sheet(item: $photoStudioRecipe) { target in
                RecipePhotoStudioSheet(recipe: target) { _ in
                    vm.tipMessage = "主图与抠图已保存"
                    Task { await vm.loadRecipes() }
                }
            }
            .sheet(item: $categorySheetTarget) { sheet in
                CategoryManagementView(initialEditingCategory: sheet.initialEditing)
                    .preferredColorScheme(.light)
            }
            .sheet(isPresented: $showBatchCategorySheet) {
                BatchCategoryPickerSheet(
                    selectedCount: selectedRecipeIds.count,
                    categories: vm.categories
                ) { targetCategoryId, targetCategoryName in
                    let ids = Array(selectedRecipeIds)
                    let ok = await vm.moveRecipesToCategory(
                        ids: ids,
                        categoryId: targetCategoryId,
                        categoryName: targetCategoryName
                    )
                    if ok {
                        exitManaging()
                    }
                    return ok
                }
                .presentationDetents([.medium, .large])
                .preferredColorScheme(.light)
            }
            .fullScreenCover(item: $previewGallery) { presentation in
                PhotoGalleryViewer(slides: presentation.slides, initialIndex: presentation.initialIndex)
            }
            .confirmationDialog(
                pendingDeleteRecipe.map { "删除「\($0.name)」？" } ?? "删除这道菜谱？",
                isPresented: Binding(
                    get: { pendingDeleteRecipe != nil },
                    set: { if !$0 { pendingDeleteRecipe = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("删除菜谱", role: .destructive) {
                    if let target = pendingDeleteRecipe {
                        pendingDeleteRecipe = nil
                        Task { await vm.deleteSingleRecipe(target) }
                    }
                }
                Button("再想想", role: .cancel) {
                    pendingDeleteRecipe = nil
                }
            } message: {
                Text("删除后这道菜不会再出现在菜单里，但已经记下的历史不受影响。")
            }
            .confirmationDialog(
                "删除选中的 \(selectedRecipeIds.count) 道菜谱？",
                isPresented: $confirmBatchDelete,
                titleVisibility: .visible
            ) {
                Button("批量删除", role: .destructive) {
                    let ids = Array(selectedRecipeIds)
                    Task {
                        if await vm.batchDeleteRecipes(ids: ids) {
                            exitManaging()
                        }
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("删除后这些菜谱将从列表中移除，已经记下的用餐历史不受影响。")
            }
            .confirmationDialog(
                pendingDeleteCategory.map { "删除分类「\($0.name)」？" } ?? "删除分类？",
                isPresented: Binding(
                    get: { pendingDeleteCategory != nil },
                    set: { if !$0 { pendingDeleteCategory = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("删除分类", role: .destructive) {
                    if let target = pendingDeleteCategory {
                        pendingDeleteCategory = nil
                        Task { await vm.deleteCategory(target) }
                    }
                }
                Button("取消", role: .cancel) {
                    pendingDeleteCategory = nil
                }
            } message: {
                let count = pendingDeleteCategory?.recipeCount ?? 0
                if count > 0 {
                    Text("该分类下的 \(count) 道菜谱不会被删除，将自动归为「未分类」。")
                } else {
                    Text("删除后该分类将从筛选栏移除，不会影响已有菜谱。")
                }
            }
            .toast($vm.errorMessage)
            .tipToast($vm.tipMessage)
        }
    }

    private var menuScrollStage: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                header
                searchBar
                filterPanel
                grid_section
                if !isManaging {
                    pinnedSection
                }
                Color.clear.frame(height: 150)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
        }
        .background {
            Color.appBackground.ignoresSafeArea()
        }
        .onAppear {
            vm.restoreCacheIfNeeded(householdId: appState.currentUser?.householdId ?? appState.household?.id)
        }
        .refreshable {
            await vm.refreshAll(
                householdId: appState.currentUser?.householdId ?? appState.household?.id,
                scene: .household,
                mood: appState.currentMood
            )
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .coordinateSpace(name: "menuMoreSpace")
        .overlay {
            cardMoreMenuOverlay
        }
        .onChange(of: appState.activeTab) { _, tab in
            if tab != 1 && activeCardMenuRecipeId != nil {
                activeCardMenuRecipeId = nil
            }
            if tab == 1 {
                Task {
                    await vm.refreshIfBootstrapped(
                        householdId: appState.currentUser?.householdId ?? appState.household?.id,
                        scene: .household,
                        mood: appState.currentMood
                    )
                }
            } else if isManaging {
                exitManaging()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, appState.activeTab == 1 else { return }
            Task {
                await vm.refreshIfBootstrapped(
                    householdId: appState.currentUser?.householdId ?? appState.household?.id,
                    scene: .household,
                    mood: appState.currentMood
                )
            }
        }
        .task {
            await vm.bootstrap(
                householdId: appState.currentUser?.householdId ?? appState.household?.id,
                scene: .household,
                mood: appState.currentMood
            )
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
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(isManaging ? "批量管理" : "菜谱")
                    .font(AppFont.title(27))
                    .foregroundStyle(Color.inkPrimary)
                if isManaging {
                    Text(selectedRecipeIds.isEmpty ? "轻点卡片勾选需要批量整理的菜品" : "已选 \(selectedRecipeIds.count) 道菜")
                        .font(AppFont.caption(12))
                        .foregroundStyle(Color.inkMuted)
                        .monospacedDigit()
                } else if vm.totalCount > 0 {
                    Text("共 \(vm.totalCount) 道菜")
                        .font(AppFont.caption(12))
                        .foregroundStyle(Color.inkMuted)
                }
            }
            Spacer()

            if isManaging {
                let allVisibleIds = Set(vm.recipes.map(\.id))
                let isAllSelected = !allVisibleIds.isEmpty && allVisibleIds.isSubset(of: selectedRecipeIds)
                Button {
                    Haptics.light()
                    if isAllSelected {
                        selectedRecipeIds.subtract(allVisibleIds)
                    } else {
                        selectedRecipeIds.formUnion(allVisibleIds)
                    }
                } label: {
                    Text(isAllSelected ? "取消全选" : "全选")
                        .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.inkPrimary)
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                        .background(Color.cardBackground, in: Capsule())
                        .overlay {
                            Capsule().strokeBorder(Color.dividerLine.opacity(0.9), lineWidth: 0.7)
                        }
                }
                .buttonStyle(SoftPressStyle())

                Button {
                    Haptics.light()
                    exitManaging()
                } label: {
                    Text("完成")
                        .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 15)
                        .frame(height: 38)
                        .background(Color.actionInk, in: Capsule())
                }
                .buttonStyle(SoftPressStyle())
            } else {
                if !vm.recipes.isEmpty {
                    Button {
                        Haptics.light()
                        selectedRecipeIds.removeAll()
                        isManaging = true
                    } label: {
                        Image(systemName: "checklist")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.inkPrimary)
                            .frame(width: 44, height: 44)
                            .background(Color.cardBackground, in: Circle())
                    }
                    .buttonStyle(SoftPressStyle())
                    .accessibilityLabel("批量管理菜品")
                }

                Button {
                    Haptics.light()
                    categorySheetTarget = CategorySheetPresentation(initialEditing: nil)
                } label: {
                    Image(systemName: "tag")
                        .font(.system(size: 15.5, weight: .medium))
                        .foregroundStyle(Color.inkPrimary)
                        .frame(width: 44, height: 44)
                        .background(Color.cardBackground, in: Circle())
                }
                .buttonStyle(SoftPressStyle())
                .accessibilityLabel("管理菜谱分类")

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
        }
        .frame(minHeight: 54)
    }

    private var filterPanel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(
                    title: "全部",
                    isSelected: !vm.isUncategorizedSelected && vm.selectedCategoryId == nil && vm.quickFilter == .all
                ) {
                    Task { await vm.clearFilters() }
                }
                CategoryChip(title: MenuFilter.recent.label, isSelected: vm.quickFilter == .recent) {
                    Task { await vm.selectFilter(vm.quickFilter == .recent ? .all : .recent) }
                }
                ForEach(visibleCategories) { category in
                    let chipTitle = (category.icon?.isEmpty == false ? "\(category.icon!) " : "") + category.name
                    CategoryChip(title: chipTitle, isSelected: vm.selectedCategoryId == category.id) {
                        Task { await vm.selectCategory(vm.selectedCategoryId == category.id ? nil : category.id) }
                    }
                    .contextMenu {
                        Button {
                            categorySheetTarget = CategorySheetPresentation(initialEditing: category)
                        } label: {
                            Label("编辑分类", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            pendingDeleteCategory = category
                        } label: {
                            Label("删除分类", systemImage: "trash")
                        }
                    }
                }
                CategoryChip(title: "未分类", isSelected: vm.isUncategorizedSelected) {
                    Task { await vm.selectUncategorized() }
                }
                Button {
                    Haptics.light()
                    categorySheetTarget = CategorySheetPresentation(initialEditing: nil)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 11.5, weight: .semibold))
                        Text("管理分类")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .padding(.horizontal, 13)
                    .frame(height: 36)
                    .foregroundStyle(Color.inkSecondary)
                    .background(Color.cardBackground, in: Capsule())
                    .overlay {
                        Capsule().stroke(Color.dividerLine.opacity(0.9), lineWidth: 0.7)
                    }
                }
                .buttonStyle(SoftPressStyle())
            }
        }
    }

    /// 后端分类允许用户自定义；如果有人把“最近做过”之类的快捷筛选也建成分类，页面只展示一次。
    private var visibleCategories: [RecipeCategory] {
        let quickLabels = Set(MenuFilter.allCases.map(\.label)).union(["未分类"])
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
                        let isSelected = selectedRecipeIds.contains(recipe.id)
                        MenuRecipeCard(
                            recipe: recipe,
                            categories: vm.categories,
                            alreadyAdded: pinned != nil,
                            canToggle: pinned == nil || canRemovePinnedDish,
                            isManaging: isManaging,
                            isSelected: isSelected,
                            isMoreMenuOpen: activeCardMenuRecipeId == recipe.id,
                            onToggleMoreMenu: { anchorRect in
                                toggleCardMoreMenu(for: recipe.id, anchor: anchorRect)
                            },
                            onToggleSelect: {
                                toggleRecipeSelection(recipe.id)
                            },
                            onAdd: {
                                if let pinned {
                                    Task { await vm.removeDish(pinned) }
                                } else {
                                    Task { await vm.addDish(recipe) }
                                }
                            },
                            onEdit: {
                                editingRecipe = recipe
                            },
                            onEditPhotos: {
                                photoStudioRecipe = recipe
                            },
                            onMoveCategory: { catId, catName in
                                Task {
                                    _ = await vm.moveRecipesToCategory(
                                        ids: [recipe.id],
                                        categoryId: catId,
                                        categoryName: catName
                                    )
                                }
                            },
                            onStartBatch: {
                                Haptics.light()
                                isManaging = true
                                selectedRecipeIds = [recipe.id]
                            },
                            onDelete: {
                                pendingDeleteRecipe = recipe
                            }
                        )
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
            Text(vm.isUncategorizedSelected ? "没有未分类的菜谱" : "还没有菜谱 先去添加一道吧")
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
                                if let image = dish.recipeImage?.trimmingCharacters(in: .whitespacesAndNewlines),
                                   !image.isEmpty {
                                    Button {
                                        Haptics.light()
                                        previewGallery = PhotoGalleryPresentation(urls: [image], caption: dish.recipeName)
                                    } label: {
                                        DishThumb(name: dish.recipeName, image: dish.recipeImage)
                                    }
                                    .buttonStyle(SoftPressStyle())
                                    .accessibilityLabel("查看\(dish.recipeName)大图")
                                } else {
                                    DishThumb(name: dish.recipeName, image: dish.recipeImage)
                                }
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
        if isManaging {
            batchBottomBar
        } else if !vm.pinnedDishes.isEmpty {
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

    private var batchBottomBar: some View {
        let hasSelection = !selectedRecipeIds.isEmpty
        return HStack(spacing: 10) {
            Text(hasSelection ? "已选 \(selectedRecipeIds.count) 道" : "轻点卡片多选")
                .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(hasSelection ? Color.inkPrimary : Color.inkMuted)
                .padding(.leading, 6)

            Spacer(minLength: 4)

            Button {
                Haptics.light()
                showBatchCategorySheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "tag")
                        .font(.system(size: 11.5, weight: .semibold))
                    Text("移到分类")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(Color.actionInk.opacity(hasSelection ? 1 : 0.32), in: Capsule())
            }
            .buttonStyle(SoftPressStyle())
            .disabled(!hasSelection)

            Button {
                Haptics.light()
                confirmBatchDelete = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 11.5, weight: .semibold))
                    Text("删除")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(hasSelection ? Color.errorInk : Color.inkMuted)
                .padding(.horizontal, 13)
                .frame(height: 38)
                .background(
                    hasSelection ? Color.errorInk.opacity(0.12) : Color.cardBackground,
                    in: Capsule()
                )
            }
            .buttonStyle(SoftPressStyle())
            .disabled(!hasSelection)
        }
        .padding(.leading, 10)
        .padding(.trailing, 8)
        .frame(height: 52)
        .background {
            ZStack {
                Capsule().fill(.ultraThinMaterial)
                Capsule().fill(Color.white.opacity(0.90))
            }
        }
        .overlay {
            Capsule().strokeBorder(Color.black.opacity(0.09), lineWidth: 0.7)
        }
        .shadow(color: Color.black.opacity(0.11), radius: 16, y: 6)
        .padding(.horizontal, 18)
        .padding(.bottom, 76)
    }

    private func toggleRecipeSelection(_ id: UInt) {
        Haptics.light()
        if selectedRecipeIds.contains(id) {
            selectedRecipeIds.remove(id)
        } else {
            selectedRecipeIds.insert(id)
        }
    }

    private func exitManaging() {
        isManaging = false
        selectedRecipeIds.removeAll()
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

    private func toggleCardMoreMenu(for recipeId: UInt, anchor: CGRect) {
        if activeCardMenuRecipeId == recipeId {
            closeCardMoreMenu()
            return
        }
        activeCardMenuAnchor = anchor
        withAnimation(reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 0.82)) {
            activeCardMenuRecipeId = recipeId
        }
    }

    private func closeCardMoreMenu() {
        guard activeCardMenuRecipeId != nil else { return }
        withAnimation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.88)) {
            activeCardMenuRecipeId = nil
        }
    }

    private var cardMoreMenuOverlay: some View {
        let activeRecipe = activeCardMenuRecipeId.flatMap { id in
            vm.recipes.first(where: { $0.id == id })
        }
        let isPresentedBinding = Binding<Bool>(
            get: { activeRecipe != nil },
            set: { if !$0 { closeCardMoreMenu() } }
        )
        return AnchoredFloatingMenuOverlay(
            isPresented: isPresentedBinding,
            anchorRect: activeCardMenuAnchor,
            menuWidth: 238,
            topReserved: 12,
            bottomReserved: vm.pinnedDishes.isEmpty ? 92 : 146,
            estimatedMenuHeight: 256,
            scrimOpacity: 0.08
        ) { maxCardHeight in
            if let target = activeRecipe {
                RecipeFloatingMenuCard(
                    recipe: target,
                    categories: vm.categories,
                    maxCardHeight: maxCardHeight,
                    showsRecipeHeader: true,
                    showsBatchManage: true,
                    onEdit: {
                        editingRecipe = target
                    },
                    onEditPhotos: {
                        photoStudioRecipe = target
                    },
                    onSelectCategory: { catId, catName in
                        Task {
                            _ = await vm.moveRecipesToCategory(
                                ids: [target.id],
                                categoryId: catId,
                                categoryName: catName
                            )
                        }
                    },
                    onStartBatch: {
                        Haptics.light()
                        isManaging = true
                        selectedRecipeIds = [target.id]
                    },
                    onDelete: {
                        pendingDeleteRecipe = target
                    },
                    onClose: {
                        closeCardMoreMenu()
                    }
                )
                .id(target.id)
            }
        }
    }
}

// 批量移动分类选择弹层（支持直接新建分类并移入）
private struct BatchCategoryPickerSheet: View {
    let selectedCount: Int
    let categories: [RecipeCategory]
    var onSelect: (UInt?, String) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var localCategories: [RecipeCategory] = []
    @State private var newIcon: String = ""
    @State private var newName: String = ""
    @State private var isWorking: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("把选中的 \(selectedCount) 道菜放到对应分类下")
                        .font(AppFont.caption(13))
                        .foregroundStyle(Color.inkMuted)

                    // 快捷新建分类并直接归入
                    HStack(spacing: 8) {
                        TextField("🍲", text: $newIcon)
                            .multilineTextAlignment(.center)
                            .frame(width: 46, height: 40)
                            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        TextField("新建分类并移入，如：下酒菜", text: $newName)
                            .padding(.horizontal, 12)
                            .frame(height: 40)
                            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        Button {
                            Task { await createAndMove() }
                        } label: {
                            Text("创建并移入")
                                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .frame(height: 40)
                                .background(Color.actionInk, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        }
                        .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isWorking)
                        .opacity(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
                    }

                    Divider().overlay(Color.dividerLine.opacity(0.6))

                    VStack(spacing: AppSpacing.sm) {
                        targetRow(title: "未分类", subtitle: "从当前分类中移出", icon: "tray") {
                            await applySelection(id: nil, name: "未分类")
                        }
                        ForEach(localCategories) { cat in
                            targetRow(
                                title: cat.name,
                                subtitle: "\(cat.recipeCount ?? 0) 道菜",
                                emoji: cat.icon?.isEmpty == false ? cat.icon! : "🍽"
                            ) {
                                await applySelection(id: cat.id, name: cat.name)
                            }
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(AppFont.caption(12))
                            .foregroundStyle(Color.errorInk)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, 28)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("选择目标分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(Color.inkSecondary)
                        .disabled(isWorking)
                }
            }
            .onAppear {
                localCategories = categories
            }
            .task {
                if let latest = try? await CategoryService.shared.list() {
                    localCategories = latest
                }
            }
        }
    }

    private func targetRow(
        title: String,
        subtitle: String,
        icon: String? = nil,
        emoji: String? = nil,
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            Task { await action() }
        } label: {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    Color.appBackground
                    if let emoji {
                        Text(emoji).font(.system(size: 18))
                    } else if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
                .frame(width: 38, height: 38)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppFont.body(15))
                        .foregroundStyle(Color.inkPrimary)
                    Text(subtitle)
                        .font(AppFont.caption(11))
                        .foregroundStyle(Color.inkMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.inkMuted)
            }
            .padding(AppSpacing.md)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(Color.dividerLine.opacity(0.6), lineWidth: 0.7)
            }
        }
        .buttonStyle(SoftPressStyle())
        .disabled(isWorking)
    }

    private func applySelection(id: UInt?, name: String) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        if await onSelect(id, name) {
            dismiss()
        }
    }

    private func createAndMove() async {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let created = try await CategoryService.shared.create(
                CategoryInput(
                    name: trimmed,
                    icon: newIcon.isEmpty ? nil : newIcon,
                    color: nil,
                    sortOrder: localCategories.count
                )
            )
            AppNotifications.categoriesChanged()
            if await onSelect(created.id, created.name) {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
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
    let categories: [RecipeCategory]
    let alreadyAdded: Bool
    var canToggle: Bool = true
    var isManaging: Bool = false
    var isSelected: Bool = false
    var isMoreMenuOpen: Bool = false
    let onToggleMoreMenu: (CGRect) -> Void
    let onToggleSelect: () -> Void
    let onAdd: () -> Void
    let onEdit: () -> Void
    let onEditPhotos: () -> Void
    let onMoveCategory: (UInt?, String) -> Void
    let onStartBatch: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if isManaging {
                Button(action: onToggleSelect) {
                    VStack(alignment: .leading, spacing: 0) {
                        cover
                        information
                    }
                }
                .buttonStyle(.plain)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.actionInk : .white)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.white : Color.black.opacity(0.32))
                            .padding(2)
                    )
                    .padding(10)
                    .allowsHitTesting(false)
            } else {
                NavigationLink {
                    RecipeDetailView(recipeId: recipe.id)
                } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        cover
                        information
                    }
                }
                .buttonStyle(.plain)
                .contextMenu {
                    cardMenuItems
                }

                // 右上角单卡自定义操作按钮（编辑 / 主图抠图 / 移到分类 / 删除）
                AppMoreButton(
                    style: .photoBadge,
                    isOpen: isMoreMenuOpen,
                    coordinateSpaceName: "menuMoreSpace",
                    accessibilityTitle: "管理\(recipe.name)"
                ) { rect in
                    onToggleMoreMenu(rect)
                }
                .padding(.top, 2)
                .padding(.trailing, 2)

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
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    isManaging && isSelected ? Color.actionInk : Color.dividerLine.opacity(0.6),
                    lineWidth: isManaging && isSelected ? 2.0 : 0.7
                )
        }
    }

    @ViewBuilder
    private var cardMenuItems: some View {
        Button(action: onEdit) {
            Label("编辑菜谱", systemImage: "square.and.pencil")
        }
        Button(action: onEditPhotos) {
            Label("自定义主图与抠图", systemImage: "sparkles.rectangle.stack")
        }
        Menu {
            Button {
                onMoveCategory(nil, "未分类")
            } label: {
                if recipe.categoryId == nil {
                    Label("未分类", systemImage: "checkmark")
                } else {
                    Text("未分类")
                }
            }
            ForEach(categories) { cat in
                let label = (cat.icon?.isEmpty == false ? "\(cat.icon!) " : "") + cat.name
                Button {
                    onMoveCategory(cat.id, cat.name)
                } label: {
                    if recipe.categoryId == cat.id {
                        Label(label, systemImage: "checkmark")
                    } else {
                        Text(label)
                    }
                }
            }
        } label: {
            Label("移动到分类", systemImage: "tag")
        }
        Button(action: onStartBatch) {
            Label("多选批量管理", systemImage: "checklist")
        }
        Divider()
        Button(role: .destructive, action: onDelete) {
            Label("删除菜谱", systemImage: "trash")
        }
    }

    private var cover: some View {
        let displayURL = (recipe.coverImage?.isEmpty == false) ? recipe.coverImage : recipe.cutoutImage
        return GeometryReader { proxy in
            AsyncImageView(url: displayURL, name: recipe.name)
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

    private var resolvedCategoryName: String? {
        if let cid = recipe.categoryId,
           let matched = categories.first(where: { $0.id == cid }) {
            return matched.name
        }
        if let name = recipe.category?.name, !name.isEmpty, recipe.categoryId != nil {
            return name
        }
        return nil
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
                if let catName = resolvedCategoryName {
                    Text(catName)
                        .font(AppFont.caption(10.5))
                        .foregroundStyle(Color.inkSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.appBackground, in: Capsule())
                        .lineLimit(1)
                } else if let creator = recipe.creator {
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
