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
            Text("不能再点了")
                .font(AppFont.title(24))
                .foregroundStyle(Color.inkPrimary)
            Text("主人收摊了\n你点过的还在桌上")
                .multilineTextAlignment(.center)
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
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 13, weight: .semibold))
                        Text("离开")
                            .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(Color.inkPrimary)
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(Color.cardBackground, in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(Color.dividerLine.opacity(0.75), lineWidth: 0.7)
                    }
                }
                .buttonStyle(SoftPressStyle())
                Spacer()
            }
            Text("在点菜")
                .font(AppFont.title(24))
                .foregroundStyle(Color.inkPrimary)
            Text("跟 \(meal.creator?.displayName ?? "朋友") 一起")
                .font(AppFont.caption(12))
                .foregroundStyle(Color.inkMuted)
            HStack(spacing: -8) {
                ForEach(participants.prefix(6)) { p in
                    AvatarView(user: p.user, size: 26, ring: true)
                }
            }
            Text("\(participants.count) 个人 · \(dishes.count) 道")
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.inkSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.cardBackground, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(Color.dividerLine.opacity(0.65), lineWidth: 0.6)
                }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
    }

    private var dishesCard: some View {
        SectionCard {
            if dishes.isEmpty {
                Text("还没点 下面挑")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.inkMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.lg)
            } else {
                ForEach(Array(dishes.enumerated()), id: \.element.id) { idx, dish in
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
                    if idx < dishes.count - 1 {
                        Divider().background(Color.dividerLine.opacity(0.5))
                    }
                }
            }
        }
    }

    private var addBar: some View {
        PrimaryButton(title: "我要点菜", icon: "fork.knife") {
            showPicker = true
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
        .background(Color.appBackground)
        .overlay(alignment: .top) {
            Divider().overlay(Color.dividerLine.opacity(0.6))
        }
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
