import SwiftUI

// 访客端聚餐:临时在别人家的这一顿里点菜 离开就走 不影响自己的家
struct DiningGuestView: View {
    @EnvironmentObject private var appState: AppState
    @State var meal: MealSession
    @Environment(\.dismiss) private var dismiss
    @State private var showPicker = false
    @State private var ended = false
    @State private var errorMessage: String?

    private var dishes: [MealDish] { meal.dishes ?? [] }
    private var participants: [MealParticipant] { meal.participants ?? [] }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            if ended {
                endedView
            } else {
                VStack(spacing: 0) {
                    header
                    ScrollView {
                        VStack(spacing: AppSpacing.lg) {
                            dishesCard
                            Color.clear.frame(height: 80)
                        }
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.top, AppSpacing.md)
                    }
                }
                .safeAreaInset(edge: .bottom) { addBar }
            }
        }
        .toast($errorMessage)
        .task {
            await refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                await refresh()
                if ended { break }
            }
        }
        .sheet(isPresented: $showPicker, onDismiss: { Task { await refresh() } }) {
            DiningDishPicker(mealId: meal.id)
        }
    }

    private var endedView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            Image(systemName: "checkmark.seal")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(Color.brandGreen)
            Text("这顿聚餐散啦")
                .font(AppFont.title(24))
                .foregroundStyle(Color.inkPrimary)
            Text("主人结束了聚餐")
                .font(AppFont.body())
                .foregroundStyle(Color.inkMuted)
            Spacer()
            PrimaryButton(title: "返回") {
                dismiss()
            }
            .padding(.bottom, AppSpacing.xxl)
        }
        .padding(.horizontal, AppSpacing.xl)
    }

    private var header: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack {
                Button { Task { await leave() } } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                        Text("离开")
                    }
                    .font(AppFont.body(14))
                    .foregroundStyle(Color.inkSecondary)
                }
                Spacer()
            }
            Text("聚餐中")
                .font(AppFont.title(24))
                .foregroundStyle(Color.inkPrimary)
            Text("在 \(meal.creator?.displayName ?? "朋友") 家的这一顿")
                .font(AppFont.caption(12))
                .foregroundStyle(Color.inkMuted)
            HStack(spacing: -8) {
                ForEach(participants.prefix(6)) { p in
                    AvatarView(user: p.user, size: 26, ring: true)
                }
            }
            Text("\(participants.count) 人一起点 · 共 \(dishes.count) 道")
                .font(AppFont.caption(12))
                .foregroundStyle(Color.inkMuted)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
    }

    private var dishesCard: some View {
        SectionCard {
            if dishes.isEmpty {
                Text("还没点菜 打开下面菜单挑挑")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.inkMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.lg)
            } else {
                ForEach(dishes) { dish in
                    HStack(spacing: AppSpacing.md) {
                        DishThumb(name: dish.recipeName, image: dish.recipeImage)
                        Text(dish.recipeName)
                            .font(AppFont.body(15))
                            .foregroundStyle(Color.inkPrimary)
                        Spacer()
                        if let adder = dish.adder {
                            AvatarView(user: adder, size: 22)
                        }
                        if let myId = appState.currentUser?.id, dish.addedBy == myId {
                            Button {
                                Task { await removeDish(dish) }
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

    private var addBar: some View {
        PrimaryButton(title: "点菜 · 打开这桌菜单", icon: "fork.knife") {
            showPicker = true
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
        .background(.ultraThinMaterial)
    }

    private func refresh() async {
        do {
            if let m = try await DiningService.shared.current() {
                meal = m
            } else {
                ended = true
            }
        } catch {
            // 网络等临时错误 忽略 下次轮询再试
        }
    }

    private func removeDish(_ dish: MealDish) async {
        do {
            try await DiningService.shared.removeDish(mealId: meal.id, dishId: dish.id)
            await refresh()
            Haptics.light()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func leave() async {
        try? await DiningService.shared.leave(mealId: meal.id)
        dismiss()
    }
}
