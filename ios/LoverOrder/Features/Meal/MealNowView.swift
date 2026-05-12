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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    header
                    moodPicker
                    if !vm.dishes.isEmpty {
                        currentMealCard
                    }
                    if showEmptyHint {
                        EmptyMealHint(
                            onCreateRecipe: { showCreateRecipe = true },
                            onInvite: { copyInviteCode() }
                        )
                    } else {
                        suggestionsSection
                        frequentsSection
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
            .task {
                await vm.load(scene: appState.currentScene, mood: appState.currentMood)
            }
            .onChange(of: appState.currentScene) { _, _ in
                Task { await vm.load(scene: appState.currentScene, mood: appState.currentMood) }
            }
            .onChange(of: appState.currentMood) { _, _ in
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
            .sheet(isPresented: $showReview) {
                if let mid = reviewMealId {
                    MealReviewView(mealId: mid) {
                        Task { await vm.load(scene: appState.currentScene, mood: appState.currentMood) }
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
        }
    }

    private var showEmptyHint: Bool {
        !vm.isLoading && vm.suggestions.isEmpty && vm.frequents.isEmpty && vm.dishes.isEmpty
    }

    private func copyInviteCode() {
        guard let code = appState.household?.inviteCode else { return }
        UIPasteboard.general.string = code
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text("我们这顿")
                    .font(AppFont.title(30))
                    .foregroundStyle(Color.inkPrimary)
                Image(systemName: "leaf.fill")
                    .foregroundStyle(Color.brandGreen)
                    .font(.system(size: 18))
                Spacer()
            }
            Text(appState.currentScene.hint)
                .font(AppFont.body())
                .foregroundStyle(Color.inkMuted)
            CurrentSceneBadge(scene: appState.currentScene)
                .padding(.top, AppSpacing.xs)
        }
        .padding(.vertical, AppSpacing.sm)
    }

    private var moodPicker: some View {
        SectionCard(padding: AppSpacing.lg) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(Mood.allCases) { m in
                    MoodChip(mood: m, isSelected: appState.currentMood == m) {
                        Task {
                            appState.currentMood = m
                            await vm.changeMood(to: m)
                        }
                    }
                }
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
                        Button {
                            Task { await vm.removeDish(dish) }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.inkMuted)
                        }
                    }
                }
            }
        }
    }

    private var suggestionsSection: some View {
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
            if vm.suggestions.isEmpty && !vm.isLoading {
                emptyHint("先去菜单里收一些菜谱，这里会推荐")
            } else {
                let columns = Array(repeating: GridItem(.flexible(), spacing: AppSpacing.md), count: 3)
                LazyVGrid(columns: columns, spacing: AppSpacing.md) {
                    ForEach(vm.suggestions.prefix(3)) { recipe in
                        RecipeCircleCard(recipe: recipe) {
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
                        FrequentPill(recipe: recipe) {
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
                Task { await randomPick() }
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "shuffle")
                    Text("随便").font(AppFont.caption())
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
        case .confirmed: return "做好啦"
        case .completed: return "再来一顿"
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

    private func randomPick() async {
        guard !vm.suggestions.isEmpty, let any = vm.suggestions.randomElement() else { return }
        await vm.addDish(any)
    }

    private func confirmAction() async {
        guard let meal = vm.meal else { return }
        switch meal.status {
        case .planning:
            await vm.confirm()
        case .confirmed:
            await vm.complete()
            if let completedId = vm.meal?.id {
                reviewMealId = completedId
                showReview = true
            }
        case .completed, .cancelled:
            await vm.load(scene: appState.currentScene, mood: appState.currentMood)
        }
    }
}

// 圆形小图 用于首页"可能喜欢" 3 列推荐
struct RecipeCircleCard: View {
    let recipe: Recipe
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImageView(url: recipe.coverImage, name: recipe.name)
                    .aspectRatio(1, contentMode: .fill)
                    .clipShape(Circle())
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Color.brandGreen)
                        .clipShape(Circle())
                }
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
    let onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
            HStack(spacing: 6) {
                Text(recipe.name)
                    .font(AppFont.body(13))
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 8)
            .foregroundStyle(Color.inkPrimary)
            .background(Color.cardBackground)
            .overlay(
                Capsule().stroke(Color.brandGreen.opacity(0.18), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// 小缩略图 没有图时显示菜名首字
struct DishThumb: View {
    let name: String
    let image: String?

    var body: some View {
        Group {
            if let urlString = image, !urlString.isEmpty, let url = URL(string: urlString) {
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
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
    }

    private var placeholder: some View {
        ZStack {
            Color.appBackground
            Text(String(name.prefix(1)))
                .font(AppFont.headline(18))
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
            if let urlString = url, !urlString.isEmpty, let u = URL(string: urlString) {
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
