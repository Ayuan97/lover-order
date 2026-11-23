import SwiftUI

// 访客端聚餐：直接进入同一张自由画布实时协同，保留收起与退出，不含主人流程控制
struct DiningGuestView: View {
    @EnvironmentObject private var appState: AppState
    @State var meal: MealSession
    @Environment(\.dismiss) private var dismiss

    @StateObject private var canvasVM = MealNowViewModel()
    @State private var showPicker = false
    @State private var showLeaveConfirm = false
    @State private var removingDishIDs: Set<UInt> = []
    @State private var ended = false
    @State private var canvasIsLightSurface = false
    @State private var errorMessage: String?
    @State private var tipMessage: String?

    private var dishes: [MealDish] { meal.dishes ?? [] }
    private var participants: [MealParticipant] { meal.participants ?? [] }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            if ended {
                endedView
            } else {
                MealCanvasView(
                    vm: canvasVM,
                    pendingReviewMealId: nil,
                    onAddDish: { showPicker = true },
                    onReview: { _ in },
                    onConfirm: {},
                    onShoppingList: {},
                    onDining: {},
                    onRetry: { await refresh() },
                    isGuestMode: true,
                    guestHostName: meal.creator?.displayName,
                    guestParticipants: participants,
                    onGuestCollapse: { dismiss() },
                    onGuestLeave: { showLeaveConfirm = true },
                    onDeleteDish: { dish in
                        await removeDishFromCanvas(dish)
                    },
                    onRemoteMealSync: {
                        Task { await refresh() }
                    },
                    onGuestLightSurfaceChange: { isLight in
                        canvasIsLightSurface = isLight
                    }
                )
            }
        }
        .preferredColorScheme((ended || canvasIsLightSurface) ? .light : .dark)
        .onAppear {
            canvasVM.meal = meal
        }
        .toast($errorMessage)
        .toast($canvasVM.errorMessage)
        .tipToast($tipMessage)
        .tipToast($canvasVM.tipMessage)
        .confirmationDialog("退出这个点菜房？", isPresented: $showLeaveConfirm) {
            Button("退出房间", role: .destructive) {
                Task { await leave() }
            }
            Button("再待会儿", role: .cancel) {}
        } message: {
            Text("退出后需要重新扫码或输房间号，你点过的菜仍会留在桌上")
        }
        .task {
            await refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                await refresh()
                if ended { break }
            }
        }
        .sheet(isPresented: $showPicker, onDismiss: { Task { await refresh() } }) {
            DiningDishPicker(
                mealId: meal.id,
                initialDishes: dishes,
                currentUserId: appState.currentUser?.id,
                hostName: meal.creator?.displayName
            ) {
                Task { await refresh() }
            }
            .preferredColorScheme(.light)
        }
    }

    // MARK: - 主人已收摊态

    private var endedView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            Image("StickerEmoji_mood_full_cat")
                .resizable()
                .scaledToFit()
                .frame(width: 82, height: 82)
                .shadow(color: Color.black.opacity(0.10), radius: 10, y: 4)
            Text("点菜已经收摊啦")
                .font(AppFont.title(24))
                .foregroundStyle(Color.inkPrimary)
            Text("主人关掉了房间，你点过的菜都留在桌上啦")
                .multilineTextAlignment(.center)
                .font(AppFont.body())
                .foregroundStyle(Color.inkMuted)
            if !dishes.isEmpty {
                Text("本桌共点了 \(dishes.count) 道菜")
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.inkSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.cardBackground, in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(Color.dividerLine.opacity(0.7), lineWidth: 0.7)
                    }
            }
            Spacer()
            PrimaryButton(title: "返回") {
                dismiss()
            }
            .padding(.bottom, AppSpacing.xxl)
        }
        .padding(.horizontal, AppSpacing.xl)
    }

    private func refresh() async {
        do {
            if let m = try await DiningService.shared.current() {
                meal = m
                canvasVM.meal = m
            } else {
                showPicker = false
                showLeaveConfirm = false
                ended = true
            }
        } catch {
            // 网络等临时错误 忽略 下次轮询再试
        }
    }

    private func removeDishFromCanvas(_ dish: MealDish) async -> Bool {
        guard !removingDishIDs.contains(dish.id) else { return false }
        removingDishIDs.insert(dish.id)
        defer { removingDishIDs.remove(dish.id) }
        do {
            try await DiningService.shared.removeDish(mealId: meal.id, dishId: dish.id)
            var updated = meal
            updated.dishes = (updated.dishes ?? []).filter { $0.id != dish.id }
            meal = updated
            canvasVM.meal = updated
            Haptics.light()
            tipMessage = "已移出「\(dish.recipeName)」"
            await refresh()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func leave() async {
        try? await DiningService.shared.leave(mealId: meal.id)
        dismiss()
    }
}
