import SwiftUI

// 首页"我们这顿"
struct MealNowView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm = MealNowViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    header
                    moodPicker
                    if !vm.dishes.isEmpty {
                        currentMealCard
                    }
                    suggestionsSection
                    frequentsSection
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
            .navigationBarHidden(true)
        }
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
            if let user = appState.currentUser {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 12))
                    Text("当前场景：\(user.displayName) 的 \(appState.currentScene.label)")
                        .font(AppFont.caption())
                }
                .foregroundStyle(Color.inkMuted)
                .padding(.top, AppSpacing.xs)
            }
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
                LazyVGrid(columns: [GridItem(.flexible(), spacing: AppSpacing.md), GridItem(.flexible())], spacing: AppSpacing.md) {
                    ForEach(vm.suggestions) { recipe in
                        RecipeSquareCard(recipe: recipe) {
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
                VStack(spacing: AppSpacing.sm) {
                    ForEach(vm.frequents) { recipe in
                        FrequentRow(recipe: recipe) {
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
        case .completed, .cancelled:
            await vm.load(scene: appState.currentScene, mood: appState.currentMood)
        }
    }
}

// 小尺寸正方形菜品卡
private struct RecipeSquareCard: View {
    let recipe: Recipe
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImageView(url: recipe.coverImage, name: recipe.name)
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.brandGreen)
                        .clipShape(Circle())
                }
                .padding(AppSpacing.sm)
            }
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
        }
    }
}

// 常吃菜的横向 row
private struct FrequentRow: View {
    let recipe: Recipe
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            DishThumb(name: recipe.name, image: recipe.coverImage)
            VStack(alignment: .leading, spacing: 2) {
                Text(recipe.name)
                    .font(AppFont.body(15))
                    .foregroundStyle(Color.inkPrimary)
                if let count = recipe.useCount, count > 0 {
                    Text("吃过 \(count) 次")
                        .font(AppFont.caption())
                        .foregroundStyle(Color.inkMuted)
                } else if let desc = recipe.description {
                    Text(desc)
                        .font(AppFont.caption())
                        .foregroundStyle(Color.inkMuted)
                        .lineLimit(1)
                }
            }
            Spacer()
            Button(action: onAdd) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.brandGreen)
            }
        }
        .padding(AppSpacing.md)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
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
