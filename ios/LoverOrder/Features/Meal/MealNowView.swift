import SwiftUI

// 首页"我们这顿"
struct MealNowView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm = MealNowViewModel()
    @State private var showAddDish: Bool = false
    @State private var showReview: Bool = false
    @State private var reviewMealId: UInt?
    @State private var showCreateRecipe: Bool = false
    @State private var showShoppingList: Bool = false
    @State private var showDiningHost: Bool = false
    @State private var showCancelMeal: Bool = false
    @State private var showInviteTicket: Bool = false
    @State private var ongoingDining: MealSession?
    @State private var resumeDining: MealSession?
    // 仅当本次 sheet 内真关过房才催「可以定下来了」
    @State private var diningHostDidCloseRoom: Bool = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            MealCanvasView(
                vm: vm,
                pendingReviewMealId: vm.pendingReviewMealId,
                onAddDish: { showAddDish = true },
                onReview: { id in
                    reviewMealId = id
                    showReview = true
                },
                onConfirm: {
                    if vm.dishCount == 0 && vm.meal?.status == .planning {
                        showAddDish = true
                    } else {
                        Task { await confirmAction() }
                    }
                },
                onShoppingList: { showShoppingList = true },
                onDining: { showDiningHost = true },
                onRetry: { await vm.load(scene: coupleScene, mood: appState.currentMood) }
            )
            .environmentObject(appState)
            .background(Color.appBackground.ignoresSafeArea())
            .task {
                // 首页只服务情侣日常我们这顿
                if appState.currentScene != .pair {
                    appState.currentScene = .pair
                }
                await vm.load(scene: coupleScene, mood: appState.currentMood)
            }
            .task {
                await checkDining()
            }
            .task {
                // 点菜协作不需要手动刷新:页面可见时每 4 秒静默同步另一台手机的改动
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(4))
                    guard scenePhase == .active else { continue }
                    await vm.syncMeal(
                        scene: coupleScene,
                        mood: appState.currentMood,
                        selfUserId: appState.currentUser?.id
                    )
                    await checkDining()
                }
            }
            // 改心情只走 applyMood 不并行 load 避免慢请求盖掉刚写的 mood
            .onReceive(NotificationCenter.default.publisher(for: .mealChanged)) { _ in
                Task {
                    await vm.refreshMeal(
                        scene: coupleScene,
                        mood: appState.currentMood,
                        selfUserId: appState.currentUser?.id
                    )
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .recipesChanged)) { _ in
                Task { await vm.load(scene: coupleScene, mood: appState.currentMood) }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddDish) {
                if let meal = vm.meal {
                    AddDishView(mealId: meal.id) {
                        Task { await vm.load(scene: coupleScene, mood: appState.currentMood) }
                    }
                    .environmentObject(appState)
                }
            }
            .sheet(isPresented: $showReview, onDismiss: {
                // 关掉评价不丢补评入口 收成轻量 banner（落盘）
                reviewMealId = nil
                if vm.pendingReviewMealId != nil {
                    vm.setReviewBannerCollapsed(true)
                }
                clearFinishedMeal()
                Task { await reloadCurrentMeal() }
            }) {
                if let mid = reviewMealId {
                    MealReviewView(mealId: mid) {
                        vm.clearPendingReview()
                        Task { await reloadCurrentMeal() }
                    }
                }
            }
            .sheet(isPresented: $showCreateRecipe) {
                RecipeEditView(mode: .create) { _ in
                    Task { await vm.load(scene: coupleScene, mood: appState.currentMood) }
                }
                .environmentObject(appState)
            }
            .sheet(isPresented: $showShoppingList) {
                if let mid = vm.meal?.id {
                    ShoppingListView(mealId: mid)
                }
            }
            .sheet(isPresented: $showInviteTicket) {
                if let h = appState.household {
                    InviteTicketView(
                        household: h,
                        inviterName: appState.currentUser?.displayName ?? "家人"
                    )
                } else {
                    // household 未就绪时别空 sheet；提示可点再试
                    VStack(spacing: AppSpacing.lg) {
                        Text("家信息还没拉到")
                            .font(AppFont.headline(17))
                            .foregroundStyle(Color.inkPrimary)
                        Text("点一下再试")
                            .font(AppFont.body())
                            .foregroundStyle(Color.inkMuted)
                        PrimaryButton(title: "再试一次") {
                            Task {
                                await appState.refreshHousehold()
                                if appState.household == nil {
                                    vm.errorMessage = "家信息还没拉到，点一下再试"
                                    showInviteTicket = false
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.xl)
                    }
                    .padding(AppSpacing.xxl)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.appBackground.ignoresSafeArea())
                }
            }
            .toast($vm.errorMessage)
            .tipToast($vm.tipMessage)
            .sheet(isPresented: $showDiningHost, onDismiss: {
                Task {
                    await vm.refreshMeal(
                        scene: coupleScene,
                        mood: appState.currentMood,
                        selfUserId: appState.currentUser?.id
                    )
                    // 只在本次 sheet 内真关过房时催一下；打开看一眼就关掉不打扰
                    if diningHostDidCloseRoom,
                       vm.meal?.status == .planning,
                       !vm.dishes.isEmpty {
                        vm.tipMessage = "人都点得差不多了 可以定下来了"
                    }
                    diningHostDidCloseRoom = false
                }
            }) {
                if let mid = vm.meal?.id {
                    DiningHostView(mealId: mid, didCloseRoom: $diningHostDidCloseRoom)
                }
            }
            .fullScreenCover(item: $resumeDining, onDismiss: {
                Task { await checkDining() }
            }) { m in
                DiningGuestView(meal: m)
                    .environmentObject(appState)
            }
            // 仅进行中的客人点菜才露胶囊续进；无进行中不占首页 chrome
            .overlay(alignment: .topTrailing) {
                if ongoingDining != nil {
                    diningResumeEntry
                }
            }
        }
    }

    // 客人路径续进：只有正在参与外客房间时才显示
    private var diningResumeEntry: some View {
        Button {
            if let d = ongoingDining {
                resumeDining = d
            }
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(Color.brandGreen)
                    .frame(width: 7, height: 7)
                Text("在点菜")
                    .font(AppFont.caption(12))
                    .foregroundStyle(Color.brandGreen)
            }
            .padding(.horizontal, AppSpacing.md)
            .frame(height: 36)
            .background(Color.cardBackground)
            .clipShape(Capsule())
            .appCardShadow()
        }
        .padding(.trailing, AppSpacing.lg)
        .padding(.top, AppSpacing.sm)
    }

    private func checkDining() async {
        ongoingDining = try? await DiningService.shared.current()
    }

    private var showEmptyHint: Bool {
        !vm.isLoading && vm.suggestions.isEmpty && vm.frequents.isEmpty && vm.dishes.isEmpty
    }

    // 首页只承载情侣日常「我们这顿」
    private var coupleScene: MealScene { .pair }

    private var addedRecipeIds: Set<UInt> {
        Set(vm.dishes.compactMap(\.recipeId))
    }

    private var header: some View {
        VStack(alignment: .center, spacing: AppSpacing.xs) {
            HStack(spacing: 6) {
                Text("我们这顿")
                    .font(AppFont.title(32))
                    .foregroundStyle(Color.inkPrimary)
                Image(systemName: "heart.fill")
                    .foregroundStyle(Color.brandGreen.opacity(0.75))
                    .font(.system(size: 16))
            }
            Text("两个人轻松决定吃什么")
                .font(AppFont.body(16))
                .foregroundStyle(Color.inkMuted)
            if appState.household != nil {
                HStack(spacing: 5) {
                    Image(systemName: appState.currentMood.icon)
                    Text("今天 · \(appState.currentMood.label)")
                }
                .font(AppFont.caption(11))
                .foregroundStyle(Color.inkMuted)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, 6)
                .background(Color.brandGreen.opacity(0.08))
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AppSpacing.md)
        .padding(.bottom, AppSpacing.xs)
    }

    // 聚会弱入口：默认可有可无的小字；开着房时才需要找回来
    @ViewBuilder
    private var diningQuietEntry: some View {
        if !vm.loadFailed, vm.meal?.status != .confirmed {
            if vm.hasActiveDiningRoom {
                Button {
                    showDiningHost = true
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.brandGreen)
                            .frame(width: 6, height: 6)
                        Text("客人还在点菜")
                            .font(AppFont.caption(12))
                            .foregroundStyle(Color.inkSecondary)
                        Spacer()
                        Text("看看")
                            .font(AppFont.caption(12))
                            .foregroundStyle(Color.brandGreen)
                    }
                    .padding(.vertical, AppSpacing.sm)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    guard vm.mealReady else {
                        vm.errorMessage = vm.loadFailed ? "没连上 下拉再试一次" : "再等一小会儿"
                        return
                    }
                    showDiningHost = true
                } label: {
                    Text("家里来人了？让大家一起点")
                        .font(AppFont.caption(12))
                        .foregroundStyle(Color.inkMuted.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.xs)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var unusedSuggestions: [Recipe] {
        vm.suggestions.filter { !addedRecipeIds.contains($0.id) }
    }

    private var unusedFrequents: [Recipe] {
        var hide = addedRecipeIds
        if let hid = heroDish?.id { hide.insert(hid) }
        unusedSuggestions.filter { $0.id != heroDish?.id }.prefix(3).forEach { hide.insert($0.id) }
        return vm.frequents.filter { !hide.contains($0.id) }
    }

    private var moodPicker: some View {
        HStack(spacing: AppSpacing.sm) {
            ForEach(Mood.allCases) { m in
                HomeMoodOption(mood: m, isSelected: appState.currentMood == m) {
                    Task {
                        appState.currentMood = m
                        await vm.applyMood(m, scene: coupleScene)
                    }
                }
            }
        }
        .padding(AppSpacing.sm)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous))
        .hairline(AppRadius.xl)
        .appCardShadow()
    }

    // 有图优先；已在桌上的不占大图
    private var heroDish: Recipe? {
        unusedSuggestions.first { ($0.coverImage ?? "").isEmpty == false } ?? unusedSuggestions.first
    }

    // 今日推荐大图卡 食物是首屏主角
    private func heroCard(_ recipe: Recipe) -> some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImageView(url: recipe.coverImage, name: recipe.name)
                .frame(height: 200)
                .frame(maxWidth: .infinity)
            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .center,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(recipe.name)
                    .font(AppFont.title(24))
                    .foregroundStyle(.white)
                if let desc = recipe.description, !desc.isEmpty {
                    Text(desc)
                        .font(AppFont.caption(12))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }
            }
            .padding(AppSpacing.lg)
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous))
        .overlay(alignment: .topLeading) {
            Text("要不这道")
                .font(AppFont.caption(11))
                .foregroundStyle(.white)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, 5)
                .background(Color.accentWarm)
                .clipShape(Capsule(style: .continuous))
                .padding(AppSpacing.md)
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                Task { await vm.addDish(recipe) }
            } label: {
                Image(systemName: alreadyAdded(recipe) ? "checkmark" : "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(alreadyAdded(recipe) ? Color.inkMuted : Color.accentWarm)
                    .clipShape(Circle())
            }
            .padding(AppSpacing.md)
        }
        .appCardShadow()
    }

    // 吃完后可反复打开；收起只变轻量条 不丢补评
    @ViewBuilder
    private func reviewPromptCard(_ mealId: UInt) -> some View {
        if vm.reviewBannerCollapsed {
            Button {
                reviewMealId = mealId
                showReview = true
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "leaf")
                        .foregroundStyle(Color.accentWarm)
                    Text("这顿还没写两句 想起来再补")
                        .font(AppFont.caption(13))
                        .foregroundStyle(Color.inkSecondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.inkMuted)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, 12)
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            }
            .buttonStyle(.plain)
        } else {
            SectionCard {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(Color.accentWarm)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("吃完了")
                            .font(AppFont.headline(15))
                            .foregroundStyle(Color.inkPrimary)
                        Text("有什么想说的 记两句就好")
                            .font(AppFont.caption(12))
                            .foregroundStyle(Color.inkMuted)
                    }
                    Spacer()
                    Button {
                        vm.setReviewBannerCollapsed(true)
                    } label: {
                        Text("先不了")
                            .font(AppFont.caption(12))
                            .foregroundStyle(Color.inkMuted)
                    }
                }
                PrimaryButton(title: "写两句", icon: "leaf") {
                    reviewMealId = mealId
                    showReview = true
                }
            }
        }
    }

    private var confirmedMealCard: some View {
        SectionCard {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                ZStack {
                    Color.brandGreen.opacity(0.12)
                    Image(systemName: "fork.knife")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.brandGreen)
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(confirmedTitle)
                        .font(AppFont.headline(17))
                        .foregroundStyle(Color.inkPrimary)
                    Text(confirmedSubtitle)
                        .font(AppFont.body(13))
                        .foregroundStyle(Color.inkMuted)
                }
                Spacer()
                Text("\(vm.dishCount) 道")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.inkMuted)
            }

            CookingProgressView()

            VStack(spacing: AppSpacing.sm) {
                ForEach(vm.dishes) { dish in
                    confirmedDishRow(dish)
                }
            }

            HStack(spacing: AppSpacing.sm) {
                SecondaryButton(title: "再加一道", icon: "plus") {
                    showAddDish = true
                }
                SecondaryButton(title: "买买买", icon: "cart") {
                    showShoppingList = true
                }
            }

            Button {
                showDiningHost = true
            } label: {
                Text(vm.hasActiveDiningRoom ? "客人还在点 · 去看看" : "家里来人了？让大家一起点")
                    .font(AppFont.caption(12))
                    .foregroundStyle(Color.inkMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
            }

            Button {
                showCancelMeal = true
            } label: {
                Text("算了 重选")
                    .font(AppFont.caption(12))
                    .foregroundStyle(Color.inkMuted)
                    .frame(maxWidth: .infinity)
            }
        }
        .confirmationDialog("这顿不要了？", isPresented: $showCancelMeal) {
            Button("清空重来", role: .destructive) {
                Task { await vm.cancelMeal(scene: coupleScene, mood: appState.currentMood) }
            }
            Button("手滑了", role: .cancel) {}
        } message: {
            Text(cancelMealMessage)
        }
    }

    private var cancelMealMessage: String {
        if vm.hasActiveDiningRoom {
            return "菜会清掉 客人那边也不能再点了"
        }
        return "刚选的都会清掉"
    }

    private var confirmedTitle: String {
        "就这些了"
    }

    private var confirmedSubtitle: String {
        "可以开工了 缺什么去买买买"
    }

    private func confirmedDishRow(_ dish: MealDish) -> some View {
        HStack(spacing: AppSpacing.md) {
            DishThumb(name: dish.recipeName, image: dish.recipeImage)
            VStack(alignment: .leading, spacing: 2) {
                Text(dish.recipeName)
                    .font(AppFont.body(15))
                    .foregroundStyle(Color.inkPrimary)
                if let note = dish.note, !note.isEmpty {
                    Text(note)
                        .font(AppFont.caption())
                        .foregroundStyle(Color.inkMuted)
                }
            }
            Spacer()
            if let adder = dish.adder {
                AvatarView(user: adder, size: 22)
            }
            if let recipeId = dish.recipeId {
                NavigationLink {
                    RecipeDetailView(recipeId: recipeId)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "list.number")
                        Text("做法")
                    }
                    .font(AppFont.caption(12))
                    .foregroundStyle(Color.brandGreen)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 6)
                    .background(Color.brandGreen.opacity(0.08))
                    .clipShape(Capsule())
                }
            }
            // confirmed 最后一道不能删 避免空 confirmed；要清光走「算了 重选」
            if vm.dishCount > 1 {
                Button {
                    Task { await vm.removeDish(dish) }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.inkMuted)
                }
            }
        }
    }

    private var currentMealCard: some View {
        SectionCard {
            HStack {
                Text(togetherDishTitle)
                    .font(AppFont.headline(15))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                Button {
                    showShoppingList = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "cart")
                        Text("买买买")
                    }
                    .font(AppFont.caption(12))
                    .foregroundStyle(Color.brandGreen)
                }
                Text("\(vm.dishCount) 道")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.inkMuted)
            }
            VStack(spacing: AppSpacing.sm) {
                ForEach(vm.dishes) { dish in
                    HStack(spacing: AppSpacing.md) {
                        DishThumb(name: dish.recipeName, image: dish.recipeImage)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dish.recipeName)
                                .font(AppFont.body(15))
                                .foregroundStyle(Color.inkPrimary)
                            if let note = dish.note, !note.isEmpty {
                                Text(note)
                                    .font(AppFont.caption())
                                    .foregroundStyle(Color.inkMuted)
                            }
                        }
                        Spacer()
                        if let adder = dish.adder {
                            AvatarView(user: adder, size: 22)
                        }
                        Button {
                            Task { await vm.removeDish(dish) }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.inkMuted)
                        }
                    }
                }
            }
            if participants.count > 1 {
                participantsRow
            }
        }
    }

    // 大图以外、还没点过的
    @ViewBuilder
    private var suggestionsSection: some View {
        let rest = unusedSuggestions.filter { $0.id != heroDish?.id }
        if unusedSuggestions.isEmpty && vm.dishes.isEmpty && !vm.isLoading {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("可能喜欢")
                    .font(AppFont.headline(17))
                    .foregroundStyle(Color.inkPrimary)
                emptyHint("菜单里多收几道，今天才有得挑")
            }
        } else if !rest.isEmpty {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    Text("可能喜欢")
                        .font(AppFont.headline(17))
                        .foregroundStyle(Color.inkPrimary)
                    Spacer()
                    if vm.isLoading {
                        ProgressView().tint(Color.brandGreen).controlSize(.small)
                    }
                }
                let columns = Array(repeating: GridItem(.flexible(), spacing: AppSpacing.md), count: 3)
                LazyVGrid(columns: columns, spacing: AppSpacing.md) {
                    ForEach(rest.prefix(3)) { recipe in
                        RecipeCircleCard(recipe: recipe, alreadyAdded: false) {
                            Task { await vm.addDish(recipe) }
                        }
                    }
                }
            }
        }
    }

    private var frequentsSection: some View {
        let pills = unusedFrequents
        return Group {
            if !pills.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("我们常吃")
                        .font(AppFont.headline(17))
                        .foregroundStyle(Color.inkPrimary)
                    FlowLayout(spacing: AppSpacing.sm) {
                        ForEach(pills) { recipe in
                            FrequentPill(recipe: recipe, alreadyAdded: false) {
                                Task { await vm.addDish(recipe) }
                            }
                        }
                    }
                }
            }
        }
    }

    private var bottomBar: some View {
        let hasDishes = vm.dishCount > 0
        return HStack(spacing: AppSpacing.md) {
            Button {
                guard vm.mealReady else {
                    vm.errorMessage = vm.loadFailed ? "没连上 下拉再试一次" : "再等一小会儿"
                    return
                }
                showAddDish = true
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "plus.circle")
                    Text("加菜").font(AppFont.caption())
                }
                .frame(width: 60, height: 52)
                .foregroundStyle(vm.mealReady ? Color.brandGreen : Color.inkMuted)
            }
            .disabled(vm.isActing)
            Button {
                guard vm.mealReady else {
                    vm.errorMessage = vm.loadFailed ? "没连上 下拉再试一次" : "再等一小会儿"
                    return
                }
                if vm.meal?.status == .confirmed {
                    showShoppingList = true
                } else {
                    Task { await randomPick() }
                }
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: vm.meal?.status == .confirmed ? "cart" : "shuffle")
                    Text(vm.meal?.status == .confirmed ? "买菜" : "随便").font(AppFont.caption())
                }
                .frame(width: 60, height: 52)
                .foregroundStyle(vm.mealReady ? Color.brandGreen : Color.inkMuted)
            }
            .disabled(vm.isActing)
            PrimaryButton(
                title: hasDishes || vm.meal?.status == .confirmed ? confirmTitle : "先挑一道",
                isLoading: vm.isActing
            ) {
                if hasDishes || vm.meal?.status == .confirmed {
                    Task { await confirmAction() }
                } else {
                    showAddDish = true
                }
            }
            .opacity(hasDishes || vm.meal?.status == .completed || vm.meal?.status == .cancelled ? 1 : 0.72)
            .disabled(!vm.mealReady && vm.meal?.status != .completed && vm.meal?.status != .cancelled)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
        .background(.ultraThinMaterial)
    }

    private var confirmTitle: String {
        guard let meal = vm.meal else { return "就这些" }
        switch meal.status {
        case .planning: return "就这些"
        case .confirmed: return "吃完了"
        case .completed: return "再来一顿"
        case .cancelled: return "重新选"
        }
    }

    private func emptyHint(_ text: String) -> some View {
        Text(text)
            .font(AppFont.caption())
            .foregroundStyle(Color.inkMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.lg)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
    }

    // 随便选一道 得说出来 不然像没点着（成功走 tip 通道 不当报错）
    private func randomPick() async {
        let pool = unusedSuggestions
        guard let any = pool.randomElement() else {
            vm.errorMessage = vm.suggestions.isEmpty ? "菜单还空着 先去加几道菜" : "能加的都在桌上了"
            return
        }
        await vm.addDish(any)
        if vm.errorMessage == nil {
            vm.tipMessage = "那就 \(any.name) 吧"
        }
    }

    private func reloadCurrentMeal() async {
        await vm.load(scene: coupleScene, mood: appState.currentMood)
    }

    private func clearFinishedMeal() {
        if vm.meal?.status == .completed || vm.meal?.status == .cancelled {
            vm.meal = nil
        }
    }

    private func confirmAction() async {
        guard let meal = vm.meal else {
            vm.errorMessage = vm.loadFailed ? "没连上 下拉再试一次" : "再等一小会儿"
            return
        }
        guard !vm.isActing else { return }
        switch meal.status {
        case .planning:
            if vm.dishes.isEmpty {
                vm.errorMessage = "还没点菜呢"
                return
            }
            await vm.confirm()
        case .confirmed:
            if vm.dishes.isEmpty {
                vm.errorMessage = "菜都没了 先留一道再收工"
                return
            }
            await vm.complete()
            if vm.meal?.status == .completed, let completedId = vm.meal?.id {
                vm.noteNeedsReview(completedId)
                reviewMealId = completedId
                clearFinishedMeal()
                showReview = true
            }
        case .completed, .cancelled:
            await vm.load(scene: coupleScene, mood: appState.currentMood)
        }
    }

    private func alreadyAdded(_ recipe: Recipe) -> Bool {
        vm.dishes.contains { $0.recipeId == recipe.id }
    }

    // 这一顿的参与者 按加菜人去重
    private var participants: [AppUser] {
        var seen = Set<UInt>()
        var result: [AppUser] = []
        for d in vm.dishes {
            if let a = d.adder, !seen.contains(a.id) {
                seen.insert(a.id)
                result.append(a)
            }
        }
        return result
    }

    // 桌上有没有「不是我点的」
    private var togetherDishTitle: String {
        let me = appState.currentUser?.id
        let mine = vm.dishes.contains { $0.addedBy == me }
        let others = vm.dishes.contains { dish in
            guard let by = dish.addedBy else { return false }
            return by != me
        }
        if mine && others { return "你们一起点的" }
        if others { return "Ta 也在点" }
        return "先点了这些"
    }

    private var participantsRow: some View {
        HStack(spacing: AppSpacing.sm) {
            HStack(spacing: -8) {
                ForEach(participants.prefix(5)) { u in
                    AvatarView(user: u, size: 24)
                        .overlay(Circle().strokeBorder(Color.cardBackground, lineWidth: 2))
                }
            }
            Text(participants.count >= 2
                 ? "两个人都在 · \(vm.dishCount) 道"
                 : "\(participants.count) 个人 · \(vm.dishCount) 道")
                .font(AppFont.caption(12))
                .foregroundStyle(Color.inkSecondary)
            Spacer()
        }
        .padding(.top, AppSpacing.xs)
    }
}

// 首页心情选择：四个等宽选项，保持一行，避免胶囊换行把主内容往下推。
private struct HomeMoodOption: View {
    let mood: Mood
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: mood.icon)
                    .font(.system(size: 20, weight: .medium))
                Text(mood.label)
                    .font(AppFont.caption(11))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 66)
            .foregroundStyle(isSelected ? Color.brandGreen : Color.inkSecondary)
            .background(isSelected ? Color.brandGreen.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.brandGreen.opacity(0.28) : Color.clear,
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

// 画布和点菜面板共用的透明菜品素材。没有对应抠图时才回退到用户上传的封面。
enum DishArtwork {
    static func assetName(for name: String) -> String? {
        let normalized = name.lowercased()
        if normalized.contains("虾") || normalized.contains("shrimp") { return "StickerShrimp" }
        if normalized.contains("牛排") || normalized.contains("steak") { return "StickerSteak" }
        if normalized.contains("三文鱼") || normalized.contains("寿司") || normalized.contains("丼") || normalized.contains("salmon") {
            return "StickerSalmonBowl"
        }
        if normalized.contains("吐司") || normalized.contains("面包") || normalized.contains("toast") { return "StickerToast" }
        if normalized.contains("意面") || normalized.contains("pasta") { return "StickerPasta" }
        if normalized.contains("披萨") || normalized.contains("pizza") { return "StickerPizza" }
        if normalized.contains("沙拉") || normalized.contains("拌饭") || normalized.contains("鸡蛋") { return "StickerSalad" }
        return nil
    }
}

// 圆角方形小图 用于点菜面板的推荐网格
struct RecipeCircleCard: View {
    let recipe: Recipe
    var alreadyAdded: Bool = false
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            ZStack(alignment: .bottomTrailing) {
                artwork
                Button(action: onAdd) {
                    Image(systemName: alreadyAdded ? "checkmark" : "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(alreadyAdded ? Color.inkMuted : Color.accentWarm)
                        .clipShape(Circle())
                }
                .padding(6)
            }
            .frame(maxWidth: .infinity)
            Text(recipe.name)
                .font(AppFont.body(13))
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(1)
            if let desc = recipe.description, !desc.isEmpty {
                Text(desc)
                    .font(AppFont.caption(11))
                    .foregroundStyle(Color.inkMuted)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var artwork: some View {
        ZStack {
            if let assetName = DishArtwork.assetName(for: recipe.name) {
                LinearGradient(
                    colors: [Color(red: 0.98, green: 0.96, blue: 0.88), Color(red: 0.90, green: 0.93, blue: 0.78)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
            } else {
                AsyncImageView(url: recipe.coverImage, name: recipe.name)
            }
        }
        .frame(height: 112)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
    }
}

// 常吃菜的小药丸 横向多个 单击直接加入
struct FrequentPill: View {
    let recipe: Recipe
    var alreadyAdded: Bool = false
    let onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
            HStack(spacing: 6) {
                Text(recipe.name)
                    .font(AppFont.body(13))
                Image(systemName: alreadyAdded ? "checkmark" : "plus")
                    .font(.system(size: 10, weight: .bold))
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 8)
            .foregroundStyle(alreadyAdded ? Color.inkMuted : Color.inkPrimary)
            .background(alreadyAdded ? Color.brandGreen.opacity(0.08) : Color.cardBackground)
            .overlay(
                Capsule().stroke(Color.brandGreen.opacity(alreadyAdded ? 0.35 : 0.18), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct CookingProgressView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(Color.brandGreen.opacity(0.75))
                        .frame(width: 5, height: 14)
                        .scaleEffect(y: isAnimating ? 1.35 : 0.7, anchor: .center)
                        .animation(
                            reduceMotion ? nil : .easeInOut(duration: 0.7)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.12),
                            value: isAnimating
                        )
                }
            }
            Text("开做了")
                .font(AppFont.headline(14))
                .foregroundStyle(Color.inkPrimary)
            Spacer()
            Text("吃完再记两句")
                .font(AppFont.caption(12))
                .foregroundStyle(Color.inkMuted)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 10)
        .background(Color.brandGreen.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        .onAppear {
            guard !reduceMotion else { return }
            isAnimating = true
        }
    }
}

// 小缩略图 没有图时显示菜名首字
struct DishThumb: View {
    let name: String
    let image: String?
    var size: CGFloat = 48
    var radius: CGFloat = AppRadius.sm

    var body: some View {
        Group {
            if let assetName = DishArtwork.assetName(for: name) {
                ZStack {
                    Color.appBackground
                    Image(assetName)
                        .resizable()
                        .scaledToFit()
                        .padding(5)
                }
            } else if let url = APIConfig.imageURL(image) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    private var placeholder: some View {
        ZStack {
            Color.appBackground
            Text(String(name.prefix(1)))
                .font(AppFont.headline(size * 0.36))
                .foregroundStyle(Color.brandGreen)
        }
    }
}

// 大尺寸异步图 用于双列网格 / 详情页
struct AsyncImageView: View {
    let url: String?
    let name: String

    var body: some View {
        Group {
            if let u = APIConfig.imageURL(url) {
                AsyncImage(url: u) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    case .empty:
                        Color.appBackground
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .background(Color.appBackground)
        .clipped()
    }

    private var placeholder: some View {
        ZStack {
            Color.appBackground
            VStack(spacing: 4) {
                Image(systemName: "leaf")
                    .foregroundStyle(Color.brandGreen.opacity(0.5))
                Text(name)
                    .font(AppFont.caption())
                    .foregroundStyle(Color.inkMuted)
            }
        }
    }
}
