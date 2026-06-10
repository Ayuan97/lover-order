import SwiftUI
import UIKit

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
    @State private var showDiningJoin: Bool = false
    @State private var showCancelMeal: Bool = false
    @State private var ongoingDining: MealSession?
    @State private var resumeDining: MealSession?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    header
                    if let promptId = vm.completedPromptMealId {
                        reviewPromptCard(promptId)
                    }
                    if vm.meal?.status != .confirmed, !vm.loadFailed, let hero = heroDish {
                        heroCard(hero)
                    }
                    if vm.meal?.status != .confirmed {
                        moodPicker
                    }
                    if showFriendOrderingCard {
                        friendOrderingCard
                    }
                    if vm.meal?.status == .confirmed {
                        confirmedMealCard
                    } else if !vm.dishes.isEmpty {
                        currentMealCard
                    }
                    if vm.meal?.status != .confirmed {
                        if showEmptyHint {
                            if vm.loadFailed {
                                LoadFailedView { await vm.load(scene: appState.currentScene, mood: appState.currentMood) }
                            } else {
                                EmptyMealHint(
                                    onCreateRecipe: { showCreateRecipe = true },
                                    onInvite: { copyInviteCode() }
                                )
                            }
                        } else {
                            suggestionsSection
                            frequentsSection
                        }
                    }
                    Color.clear.frame(height: 80)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .refreshable {
                await vm.load(scene: appState.currentScene, mood: appState.currentMood)
                await checkDining()
            }
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
            .task {
                await vm.load(scene: appState.currentScene, mood: appState.currentMood)
            }
            .task {
                await checkDining()
            }
            .task {
                // 点菜协作不需要手动刷新:页面可见时每 4 秒静默同步另一台手机的改动
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(4))
                    guard scenePhase == .active else { continue }
                    await vm.syncMeal(scene: appState.currentScene, mood: appState.currentMood)
                    await checkDining()
                }
            }
            .onChange(of: appState.currentScene) { _, _ in
                Task { await vm.load(scene: appState.currentScene, mood: appState.currentMood) }
            }
            .onChange(of: appState.currentMood) { _, _ in
                Task { await vm.load(scene: appState.currentScene, mood: appState.currentMood) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .mealChanged)) { _ in
                Task { await vm.refreshMeal(scene: appState.currentScene, mood: appState.currentMood) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .recipesChanged)) { _ in
                Task { await vm.load(scene: appState.currentScene, mood: appState.currentMood) }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddDish) {
                if let meal = vm.meal {
                    AddDishView(mealId: meal.id) {
                        Task { await vm.load(scene: appState.currentScene, mood: appState.currentMood) }
                    }
                    .environmentObject(appState)
                }
            }
            .sheet(isPresented: $showReview, onDismiss: {
                reviewMealId = nil
                clearFinishedMeal()
                Task { await reloadCurrentMeal() }
            }) {
                if let mid = reviewMealId {
                    MealReviewView(mealId: mid) {
                        Task { await reloadCurrentMeal() }
                    }
                }
            }
            .sheet(isPresented: $showCreateRecipe) {
                RecipeEditView(mode: .create) { _ in
                    Task { await vm.load(scene: appState.currentScene, mood: appState.currentMood) }
                }
                .environmentObject(appState)
            }
            .sheet(isPresented: $showShoppingList) {
                if let mid = vm.meal?.id {
                    ShoppingListView(mealId: mid)
                }
            }
            .toast($vm.errorMessage)
            .sheet(isPresented: $showDiningHost) {
                if let mid = vm.meal?.id {
                    DiningHostView(mealId: mid)
                }
            }
            .sheet(isPresented: $showDiningJoin, onDismiss: {
                Task { await checkDining() }
            }) {
                DiningJoinView()
                    .environmentObject(appState)
            }
            .fullScreenCover(item: $resumeDining, onDismiss: {
                Task { await checkDining() }
            }) { m in
                DiningGuestView(meal: m)
                    .environmentObject(appState)
            }
            .overlay(alignment: .topTrailing) {
                diningJoinEntry
            }
        }
    }

    // 右上角常驻:没聚餐时是"扫码加入" 检测到正在参与的聚餐就变成"聚餐中·一键返回"
    private var diningJoinEntry: some View {
        Button {
            if let d = ongoingDining {
                resumeDining = d
            } else {
                showDiningJoin = true
            }
        } label: {
            if ongoingDining != nil {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.brandGreen)
                        .frame(width: 7, height: 7)
                    Text("聚餐中")
                        .font(AppFont.caption(12))
                        .foregroundStyle(Color.brandGreen)
                }
                .padding(.horizontal, AppSpacing.md)
                .frame(height: 36)
                .background(Color.cardBackground)
                .clipShape(Capsule())
                .appCardShadow()
            } else {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.brandGreen)
                    .frame(width: 40, height: 40)
                    .background(Color.cardBackground)
                    .clipShape(Circle())
                    .appCardShadow()
            }
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

    private var showFriendOrderingCard: Bool {
        appState.currentScene == .family && vm.meal?.status != .confirmed && !vm.loadFailed
    }

    private func copyInviteCode() {
        guard let code = appState.household?.inviteCode else { return }
        UIPasteboard.general.string = code
    }

    private var header: some View {
        VStack(spacing: AppSpacing.xs) {
            HStack(spacing: 6) {
                Text("我们这顿")
                    .font(AppFont.title(30))
                    .foregroundStyle(Color.inkPrimary)
                Image(systemName: "heart.fill")
                    .foregroundStyle(Color.accentWarm)
                    .font(.system(size: 14))
            }
            Text(appState.currentScene.hint)
                .font(AppFont.body())
                .foregroundStyle(Color.inkMuted)
            CurrentSceneBadge(scene: appState.currentScene)
                .padding(.top, AppSpacing.xs)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
    }

    private var moodPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                Text("想怎么吃")
                    .font(AppFont.caption(12))
                    .foregroundStyle(Color.inkMuted)
                ForEach(Mood.allCases) { m in
                    MoodChip(mood: m, isSelected: appState.currentMood == m) {
                        Task {
                            appState.currentMood = m
                            await vm.changeMood(to: m)
                        }
                    }
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollClipDisabled()
    }

    // 有图的优先 保证首屏一定是有食欲的大图
    private var heroDish: Recipe? {
        vm.suggestions.first { ($0.coverImage ?? "").isEmpty == false } ?? vm.suggestions.first
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
            Text("今日推荐")
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

    // 对方标记"做好了"后 这台手机收到的留评提醒
    private func reviewPromptCard(_ mealId: UInt) -> some View {
        SectionCard {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(Color.accentWarm)
                VStack(alignment: .leading, spacing: 2) {
                    Text("这顿吃完啦")
                        .font(AppFont.headline(15))
                        .foregroundStyle(Color.inkPrimary)
                    Text("Ta 标记做好了 你也留一份感受吧")
                        .font(AppFont.caption(12))
                        .foregroundStyle(Color.inkMuted)
                }
                Spacer()
                Button {
                    vm.completedPromptMealId = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.inkMuted)
                }
            }
            PrimaryButton(title: "去留感受", icon: "leaf") {
                reviewMealId = mealId
                vm.completedPromptMealId = nil
                showReview = true
            }
        }
    }

    private var confirmedMealCard: some View {
        SectionCard {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                ZStack {
                    Color.brandGreen.opacity(0.12)
                    Image(systemName: appState.currentScene == .family ? "house.fill" : "fork.knife")
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
                SecondaryButton(title: "继续加菜", icon: "plus") {
                    showAddDish = true
                }
                SecondaryButton(title: "购物清单", icon: "cart") {
                    showShoppingList = true
                }
            }

            // 常见时序是"先定下自家的菜 客人到了再开聚餐" 定下后入口不能断
            if appState.currentScene == .family {
                Button {
                    showDiningHost = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "qrcode")
                        Text("开聚餐 · 客人扫码一起加菜")
                    }
                    .font(AppFont.body(14))
                    .foregroundStyle(Color.brandGreen)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
            }

            Button {
                showCancelMeal = true
            } label: {
                Text("改主意了 · 重新选这顿")
                    .font(AppFont.caption(12))
                    .foregroundStyle(Color.inkMuted)
                    .frame(maxWidth: .infinity)
            }
        }
        .confirmationDialog("重新选这顿？", isPresented: $showCancelMeal) {
            Button("清空重选", role: .destructive) {
                Task { await vm.cancelMeal(scene: appState.currentScene, mood: appState.currentMood) }
            }
            Button("再想想", role: .cancel) {}
        } message: {
            Text("已选的菜会清空 这顿回到挑菜状态")
        }
    }

    private var confirmedTitle: String {
        appState.currentScene == .family ? "家里这顿定好了" : "今天就吃这些"
    }

    private var confirmedSubtitle: String {
        appState.currentScene == .family ? "先照着这份菜单准备 临时想起还能加菜" : "菜单已经定下 现在可以照着做了"
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
            Button {
                Task { await vm.removeDish(dish) }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.inkMuted)
            }
        }
    }

    private var friendOrderingCard: some View {
        SectionCard {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                ZStack {
                    Color.brandGreen.opacity(0.1)
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.brandGreen)
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("朋友点菜")
                        .font(AppFont.headline(17))
                        .foregroundStyle(Color.inkPrimary)
                    Text("把手机递给朋友 从你家的菜单里直接挑想吃的")
                        .font(AppFont.body(13))
                        .foregroundStyle(Color.inkMuted)
                }
                Spacer()
                if vm.dishCount > 0 {
                    Text("\(vm.dishCount) 道")
                        .font(AppFont.caption(12))
                        .foregroundStyle(Color.brandGreen)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, 6)
                        .background(Color.brandGreen.opacity(0.08))
                        .clipShape(Capsule())
                }
            }

            PrimaryButton(title: "打开家里菜单", icon: "fork.knife") {
                showAddDish = true
            }
            Button {
                if vm.meal != nil {
                    showDiningHost = true
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "qrcode")
                    Text("开聚餐 · 让大家扫码")
                }
                .font(AppFont.body(14))
                .foregroundStyle(Color.brandGreen)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
        }
    }

    private var currentMealCard: some View {
        SectionCard {
            HStack {
                Text("已加入这一顿")
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

    // 大图卡已占用第一个推荐 这里只展示其余的
    @ViewBuilder
    private var suggestionsSection: some View {
        let rest = vm.suggestions.filter { $0.id != heroDish?.id }
        if vm.suggestions.isEmpty && !vm.isLoading {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("可能喜欢")
                    .font(AppFont.headline(17))
                    .foregroundStyle(Color.inkPrimary)
                emptyHint("先去菜单里收一些菜谱，这里会推荐")
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
                        RecipeCircleCard(recipe: recipe, alreadyAdded: alreadyAdded(recipe)) {
                            Task { await vm.addDish(recipe) }
                        }
                    }
                }
            }
        }
    }

    private var frequentsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("我们常吃")
                .font(AppFont.headline(17))
                .foregroundStyle(Color.inkPrimary)
            if vm.frequents.isEmpty && !vm.isLoading {
                emptyHint("还没吃过几顿 慢慢攒")
            } else {
                FlowLayout(spacing: AppSpacing.sm) {
                    ForEach(vm.frequents) { recipe in
                        FrequentPill(recipe: recipe, alreadyAdded: alreadyAdded(recipe)) {
                            Task { await vm.addDish(recipe) }
                        }
                    }
                }
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: AppSpacing.md) {
            Button {
                showAddDish = true
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "plus.circle")
                    Text("加菜").font(AppFont.caption())
                }
                .frame(width: 60, height: 52)
                .foregroundStyle(Color.brandGreen)
            }
            Button {
                if vm.meal?.status == .confirmed {
                    showShoppingList = true
                } else {
                    Task { await randomPick() }
                }
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: vm.meal?.status == .confirmed ? "cart" : "shuffle")
                    Text(vm.meal?.status == .confirmed ? "清单" : "随便").font(AppFont.caption())
                }
                .frame(width: 60, height: 52)
                .foregroundStyle(Color.brandGreen)
            }
            PrimaryButton(title: confirmTitle) {
                Task { await confirmAction() }
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
        .background(.ultraThinMaterial)
    }

    private var confirmTitle: String {
        guard let meal = vm.meal else { return "一起选好了" }
        switch meal.status {
        case .planning: return "一起选好了"
        case .confirmed: return "做好了"
        case .completed: return "再开一顿"
        case .cancelled: return "重新开始"
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

    // 点"随便"得让人知道天意选了啥 不能悄无声息
    private func randomPick() async {
        let pool = vm.suggestions.filter { !alreadyAdded($0) }
        guard let any = pool.randomElement() else {
            vm.errorMessage = vm.suggestions.isEmpty ? "暂时没有可推荐的菜 去菜单里挑一道吧" : "推荐的都点上啦 今天很丰盛"
            return
        }
        vm.errorMessage = nil
        await vm.addDish(any)
        if vm.errorMessage == nil {
            vm.errorMessage = "天意:就吃「\(any.name)」吧"
        }
    }

    private func reloadCurrentMeal() async {
        await vm.load(scene: appState.currentScene, mood: appState.currentMood)
    }

    private func clearFinishedMeal() {
        if vm.meal?.status == .completed || vm.meal?.status == .cancelled {
            vm.meal = nil
        }
    }

    private func confirmAction() async {
        guard let meal = vm.meal else { return }
        switch meal.status {
        case .planning:
            if vm.dishes.isEmpty {
                vm.errorMessage = "先选一道菜再定下"
                return
            }
            await vm.confirm()
        case .confirmed:
            await vm.complete()
            if vm.meal?.status == .completed, let completedId = vm.meal?.id {
                reviewMealId = completedId
                clearFinishedMeal()
                showReview = true
            }
        case .completed, .cancelled:
            await vm.load(scene: appState.currentScene, mood: appState.currentMood)
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

    private var participantsRow: some View {
        HStack(spacing: AppSpacing.sm) {
            HStack(spacing: -8) {
                ForEach(participants.prefix(5)) { u in
                    AvatarView(user: u, size: 24)
                        .overlay(Circle().strokeBorder(Color.cardBackground, lineWidth: 2))
                }
            }
            Text("\(participants.count) 人一起选了 \(vm.dishCount) 道")
                .font(AppFont.caption(12))
                .foregroundStyle(Color.inkSecondary)
            Spacer()
        }
        .padding(.top, AppSpacing.xs)
    }
}

// 圆角方形小图 用于首页"可能喜欢" 3 列推荐
struct RecipeCircleCard: View {
    let recipe: Recipe
    var alreadyAdded: Bool = false
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImageView(url: recipe.coverImage, name: recipe.name)
                    .aspectRatio(1, contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
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
            Text("做饭中")
                .font(AppFont.headline(14))
                .foregroundStyle(Color.inkPrimary)
            Spacer()
            Text("做好后再评价")
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
            if let url = APIConfig.imageURL(image) {
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
