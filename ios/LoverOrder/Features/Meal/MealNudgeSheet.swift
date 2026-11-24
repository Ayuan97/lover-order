import SwiftUI
import UIKit

enum MealNudgeStage: Equatable {
    case emptyPlanning
    case discussingDishes
    case confirmedMeal
    case pendingReview

    static func resolve(meal: MealSession?, hasCanvasAdditions: Bool = false, hasPendingReview: Bool = false) -> MealNudgeStage {
        if let meal {
            if meal.status == .confirmed {
                return .confirmedMeal
            }
            let dishCount = meal.dishes?.count ?? 0
            if dishCount > 0 || hasCanvasAdditions {
                return .discussingDishes
            }
        }
        if hasPendingReview {
            return .pendingReview
        }
        return .emptyPlanning
    }
}

struct MealNudgePresetItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let stickerCode: String
    let isBellSound: Bool

    var stickerAssetName: String { "StickerEmoji_\(stickerCode)" }

    static let all: [MealNudgePresetItem] = [
        .init(
            id: "hungry",
            title: "饿啦，吃啥？",
            subtitle: "喊 Ta 上画布一起挑菜",
            stickerCode: "mood_drool",
            isBellSound: false
        ),
        .init(
            id: "check_canvas",
            title: "快看画布",
            subtitle: "桌上有新贴纸或便签",
            stickerCode: "mood_wink",
            isBellSound: false
        ),
        .init(
            id: "dinner_ready",
            title: "摇铃开饭啦",
            subtitle: "叮铃铃喊 Ta 洗手端碗",
            stickerCode: "food_cheers",
            isBellSound: true
        ),
        .init(
            id: "confirm_menu",
            title: "来拍板定下",
            subtitle: "问问这几道菜够不够吃",
            stickerCode: "food_ramen",
            isBellSound: false
        ),
        .init(
            id: "inspiration",
            title: "求点菜灵感",
            subtitle: "想吃啥尽管往桌上抛",
            stickerCode: "vibe_sparkles",
            isBellSound: false
        ),
        .init(
            id: "shopping_list",
            title: "买菜清单好啦",
            subtitle: "点通知直达勾选食材",
            stickerCode: "food_croissant",
            isBellSound: false
        ),
        .init(
            id: "cooking",
            title: "系围裙开火咯",
            subtitle: "厨房飘香预告大厨上线",
            stickerCode: "food_fried_egg",
            isBellSound: false
        ),
        .init(
            id: "write_review",
            title: "来留张纪念照",
            subtitle: "邀 Ta 晒图写两句回味",
            stickerCode: "vibe_camera",
            isBellSound: false
        )
    ]

    static func ordered(for stage: MealNudgeStage) -> [MealNudgePresetItem] {
        let priorityIDs: [String]
        switch stage {
        case .emptyPlanning:
            priorityIDs = ["hungry", "inspiration", "check_canvas", "dinner_ready", "shopping_list", "cooking", "confirm_menu", "write_review"]
        case .discussingDishes:
            priorityIDs = ["check_canvas", "confirm_menu", "shopping_list", "hungry", "dinner_ready", "cooking", "inspiration", "write_review"]
        case .confirmedMeal:
            priorityIDs = ["dinner_ready", "cooking", "shopping_list", "check_canvas", "write_review", "hungry", "confirm_menu", "inspiration"]
        case .pendingReview:
            priorityIDs = ["write_review", "hungry", "inspiration", "check_canvas", "dinner_ready", "shopping_list", "cooking", "confirm_menu"]
        }
        let dict = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        return priorityIDs.compactMap { dict[$0] }
    }
}

private struct NudgeStickerChoice: Identifiable, Equatable {
    let code: String
    let label: String
    var id: String { code }
    var assetName: String { "StickerEmoji_\(code)" }

    static let curated: [NudgeStickerChoice] = [
        .init(code: "mood_drool", label: "馋了"),
        .init(code: "food_cheers", label: "开饭"),
        .init(code: "mood_wink", label: "快看"),
        .init(code: "mood_hug_heart", label: "贴贴"),
        .init(code: "mood_finger_heart", label: "比心"),
        .init(code: "food_ramen", label: "热面"),
        .init(code: "food_fried_egg", label: "开火"),
        .init(code: "food_croissant", label: "采购"),
        .init(code: "mood_star_eyes", label: "超期待"),
        .init(code: "vibe_sparkles", label: "灵感"),
        .init(code: "vibe_puppy", label: "飞奔"),
        .init(code: "vibe_cat", label: "喵喵"),
        .init(code: "food_cake", label: "加餐"),
        .init(code: "vibe_camera", label: "留影")
    ]
}

/// 家庭日常成员间的阶段化趣味提醒面板（「喊 Ta 一下」）
struct MealNudgeSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var meal: MealSession?
    var onlineUserIDs: Set<UInt> = []
    var hasCanvasAdditions: Bool = false
    var hasPendingReview: Bool = false
    var initialTargetUserID: UInt? = nil
    var onInvitePartner: (() -> Void)? = nil
    var onSent: ((String) -> Void)? = nil

    @State private var selectedPresetID: String = "hungry"
    @State private var selectedStickerCode: String = "mood_drool"
    @State private var customMessage: String = ""
    @State private var selectedTargetUserID: UInt? = nil
    @State private var fallbackLoadedMeal: MealSession? = nil
    @State private var isSending: Bool = false
    @State private var errorMessage: String?
    @State private var didInitialize: Bool = false
    @State private var userChangedPreset: Bool = false
    @FocusState private var messageFocused: Bool

    private var effectiveMeal: MealSession? {
        meal ?? fallbackLoadedMeal
    }

    private var stage: MealNudgeStage {
        MealNudgeStage.resolve(
            meal: effectiveMeal,
            hasCanvasAdditions: hasCanvasAdditions,
            hasPendingReview: hasPendingReview || PendingReviewStore.load() != nil
        )
    }

    private var orderedPresets: [MealNudgePresetItem] {
        MealNudgePresetItem.ordered(for: stage)
    }

    private var otherMembers: [AppUser] {
        let myID = appState.currentUser?.id ?? 0
        return (appState.household?.members ?? []).filter { $0.id != 0 && $0.id != myID }
    }

    private var recipientSummaryName: String {
        if let targetID = selectedTargetUserID,
           let found = otherMembers.first(where: { $0.id == targetID }) {
            return found.displayName
        }
        if otherMembers.count == 1 {
            return otherMembers[0].displayName
        }
        return "家里人"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if otherMembers.isEmpty {
                        emptyHouseholdCard
                    } else {
                        recipientBar
                        presetGrid
                        stickerStrip
                        customNoteCard
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.appBackground.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                if !otherMembers.isEmpty {
                    sendBottomBar
                }
            }
            .navigationTitle("喊 Ta 一下")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            .onAppear {
                guard !didInitialize else { return }
                didInitialize = true
                if let first = orderedPresets.first {
                    selectedPresetID = first.id
                    selectedStickerCode = first.stickerCode
                }
                if let initialTargetUserID, otherMembers.contains(where: { $0.id == initialTargetUserID }) {
                    selectedTargetUserID = initialTargetUserID
                } else if otherMembers.count == 1 {
                    selectedTargetUserID = otherMembers[0].id
                }
            }
            .task {
                guard appState.currentUser?.hasHousehold == true || appState.household != nil else { return }
                if otherMembers.isEmpty {
                    await appState.refreshHousehold()
                    if selectedTargetUserID == nil, otherMembers.count == 1 {
                        selectedTargetUserID = otherMembers[0].id
                    }
                } else {
                    Task {
                        await appState.refreshHousehold()
                        if selectedTargetUserID == nil, otherMembers.count == 1 {
                            selectedTargetUserID = otherMembers[0].id
                        }
                    }
                }
                guard meal == nil else { return }
                if let fetched = try? await MealService.shared.current(scene: .household, mood: appState.currentMood) {
                    fallbackLoadedMeal = fetched
                    if !userChangedPreset, let first = orderedPresets.first {
                        selectedPresetID = first.id
                        selectedStickerCode = first.stickerCode
                    }
                }
            }
            .toast($errorMessage)
        }
    }

    private var emptyHouseholdCard: some View {
        SectionCard {
            VStack(spacing: 14) {
                Image("StickerEmoji_mood_hug_heart")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 68, height: 68)
                Text("家里现在还只有你一个人哦")
                    .font(AppFont.headline(17))
                    .foregroundStyle(Color.inkPrimary)
                Text("把入伙餐券发给 Ta，进家后就能随时摇铃喊开饭、催挑菜、互发表情传呼啦")
                    .font(AppFont.body(13.5))
                    .foregroundStyle(Color.inkMuted)
                    .multilineTextAlignment(.center)

                if let onInvitePartner {
                    PrimaryButton(title: "叫 Ta 进来", icon: "ticket.fill") {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
                            onInvitePartner()
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.lg)
        }
    }

    @ViewBuilder
    private var recipientBar: some View {
        HStack(spacing: 10) {
            if otherMembers.count == 1, let partner = otherMembers.first {
                let isOnline = onlineUserIDs.contains(partner.id)
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(user: partner, size: 38)
                    if isOnline {
                        Circle()
                            .fill(Color(red: 0.18, green: 0.72, blue: 0.40))
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.appBackground, lineWidth: 1.8))
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("传呼给 \(partner.displayName)")
                            .font(AppFont.headline(15))
                            .foregroundStyle(Color.inkPrimary)
                        if isOnline {
                            Text("正在画布上")
                                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color(red: 0.14, green: 0.56, blue: 0.31))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color(red: 0.18, green: 0.72, blue: 0.40).opacity(0.14), in: Capsule())
                        }
                    }
                    Text(isOnline ? "发出后 Ta 的画布会立刻飘出桌面特效与声音" : "发出后将通过通知横幅与专属提示音提醒 Ta")
                        .font(AppFont.caption(11.5))
                        .foregroundStyle(Color.inkMuted)
                }
                Spacer(minLength: 0)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        recipientChip(title: "全部家人", user: nil, isSelected: selectedTargetUserID == nil) {
                            Haptics.selection()
                            selectedTargetUserID = nil
                        }
                        ForEach(otherMembers) { member in
                            recipientChip(
                                title: member.displayName,
                                user: member,
                                isSelected: selectedTargetUserID == member.id
                            ) {
                                Haptics.selection()
                                selectedTargetUserID = member.id
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func recipientChip(title: String, user: AppUser?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let user {
                    AvatarView(user: user, size: 20)
                } else {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? .white : Color.inkPrimary)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(isSelected ? Color.actionInk : Color.appBackground, in: Capsule())
            .overlay {
                if !isSelected {
                    Capsule().strokeBorder(Color.dividerLine.opacity(0.8), lineWidth: 0.8)
                }
            }
        }
        .buttonStyle(SoftPressStyle())
    }

    private var presetGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("选个餐桌暗号")
                    .font(AppFont.headline(14.5))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                Text(stageHintLabel)
                    .font(AppFont.caption(11.5))
                    .foregroundStyle(Color.inkMuted)
            }

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                ForEach(orderedPresets) { item in
                    let isSelected = (selectedPresetID == item.id)
                    Button {
                        Haptics.selection()
                        if item.isBellSound {
                            CanvasSoundEngine.shared.playDinnerBell()
                        } else {
                            CanvasSoundEngine.shared.playDishPick()
                        }
                        selectedPresetID = item.id
                        selectedStickerCode = item.stickerCode
                        userChangedPreset = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(item.stickerAssetName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 36, height: 36)
                                .scaleEffect(isSelected ? 1.08 : 1.0)
                                .animation(.spring(response: 0.26, dampingFraction: 0.68), value: isSelected)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                                    .foregroundStyle(isSelected ? .white : Color.inkPrimary)
                                    .lineLimit(1)
                                Text(item.subtitle)
                                    .font(.system(size: 11, weight: .regular, design: .rounded))
                                    .foregroundStyle(isSelected ? Color.white.opacity(0.76) : Color.inkMuted)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 10)
                        .background(
                            isSelected ? Color.actionInk : Color.cardBackground,
                            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .strokeBorder(
                                    isSelected ? Color.actionInk : Color.dividerLine.opacity(0.65),
                                    lineWidth: 0.8
                                )
                        }
                    }
                    .buttonStyle(SoftPressStyle())
                }
            }
        }
    }

    private var stickerStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("配一枚手绘表情贴纸")
                .font(AppFont.headline(14.5))
                .foregroundStyle(Color.inkPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(NudgeStickerChoice.curated) { item in
                        let isSelected = (selectedStickerCode == item.code)
                        Button {
                            Haptics.soft()
                            CanvasSoundEngine.shared.playEmojiPop()
                            selectedStickerCode = item.code
                        } label: {
                            VStack(spacing: 3) {
                                Image(item.assetName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 34, height: 34)
                                Text(item.label)
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(isSelected ? .white : Color.inkSecondary)
                            }
                            .frame(width: 56, height: 60)
                            .background(
                                isSelected ? Color.actionInk : Color.cardBackground,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                        }
                        .buttonStyle(SoftPressStyle())
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var customNoteCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("顺便捎句话（可选）")
                    .font(AppFont.headline(14.5))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                Text("\(customMessage.count)/36")
                    .font(AppFont.caption(11))
                    .monospacedDigit()
                    .foregroundStyle(Color.inkMuted)
            }

            HStack(spacing: 8) {
                TextField("比如：回来路上顺便带瓶冰可乐～", text: $customMessage)
                    .font(AppFont.body(14))
                    .foregroundStyle(Color.inkPrimary)
                    .focused($messageFocused)
                    .submitLabel(.done)
                    .onChange(of: customMessage) { _, next in
                        if next.count > 36 {
                            customMessage = String(next.prefix(36))
                        }
                    }

                if !customMessage.isEmpty {
                    Button {
                        customMessage = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.inkMuted)
                    }
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
    }

    private var sendBottomBar: some View {
        VStack(spacing: 0) {
            Divider().overlay(Color.dividerLine.opacity(0.6))
            PrimaryButton(
                title: "喊 \(recipientSummaryName) · 立刻送达",
                icon: selectedPresetID == "dinner_ready" ? "bell.and.waves.left.and.right.fill" : "paperplane.fill",
                isLoading: isSending
            ) {
                Task { await sendNudgeNow() }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, 10)
            .background(Color.appBackground)
        }
    }

    private var stageHintLabel: String {
        switch stage {
        case .emptyPlanning: return "已按挑菜阶段置顶推荐"
        case .discussingDishes: return "已按商量阶段置顶推荐"
        case .confirmedMeal: return "已定菜单 · 可摇铃开饭"
        case .pendingReview: return "刚吃完 · 可邀 Ta 留影"
        }
    }

    private func sendNudgeNow() async {
        guard !isSending else { return }
        messageFocused = false
        isSending = true
        defer { isSending = false }

        let trimmed = customMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            _ = try await NotificationService.shared.sendNudge(
                preset: selectedPresetID,
                message: trimmed.isEmpty ? nil : trimmed,
                stickerCode: selectedStickerCode,
                mealId: effectiveMeal?.id,
                targetUserId: selectedTargetUserID
            )
            if selectedPresetID == "dinner_ready" {
                CanvasSoundEngine.shared.playDinnerBell()
            } else {
                CanvasSoundEngine.shared.playNudgePing()
            }
            Haptics.success()
            let toastText = selectedPresetID == "dinner_ready"
                ? "开饭铃摇响啦，已通知 \(recipientSummaryName)"
                : "暗号已飞向 \(recipientSummaryName)"
            dismiss()
            onSent?(toastText)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// 画布顶部实时传呼浮条（同伴在线发来「喊 Ta」或「回戳」时浮现，支持一键回戳）
struct CanvasNudgeBanner: View {
    let message: CanvasNudgeRealtimeMessage
    let isLightSurface: Bool
    let onReply: (String) -> Void
    let onOpenLink: ((AppDeepLink) -> Void)?
    let onDismiss: () -> Void

    @State private var replied: Bool = false
    @State private var stickerBounce: Bool = false

    private var primaryInk: Color {
        isLightSurface ? Color(red: 0.08, green: 0.08, blue: 0.10) : .white
    }

    private var secondaryInk: Color {
        isLightSurface ? Color(red: 0.32, green: 0.32, blue: 0.36) : Color.white.opacity(0.80)
    }

    private var canReply: Bool {
        message.kind == "meal_nudge"
    }

    private var replyCode: String {
        message.presetKey == "dinner_ready" ? "washing_hands" : "wave_back"
    }

    private var replyLabel: String {
        message.presetKey == "dinner_ready" ? "马上到" : "收到 👋"
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(user: message.actor.asAppUser, size: 36)
                    .overlay(Circle().stroke(Color.white.opacity(0.75), lineWidth: 1.2))
                if let assetName = message.stickerAssetName, UIImage(named: assetName) != nil {
                    Image(assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .scaleEffect(stickerBounce ? 1.16 : 0.92)
                        .offset(x: 5, y: 4)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(message.title)
                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(primaryInk)
                    .lineLimit(1)
                Text(message.body)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(secondaryInk)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                if let raw = message.deepLink,
                   let parsed = AppDeepLink.parse(string: raw),
                   case .shopping = parsed {
                    onOpenLink?(parsed)
                }
            }

            if canReply {
                Button {
                    guard !replied else { return }
                    replied = true
                    Haptics.popSequence()
                    CanvasSoundEngine.shared.playNudgeHeartReply()
                    onReply(replyCode)
                } label: {
                    Text(replied ? "已回戳 ✓" : replyLabel)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(isLightSurface ? .white : Color(red: 0.08, green: 0.08, blue: 0.10))
                        .padding(.horizontal, 11)
                        .frame(height: 30)
                        .background(
                            isLightSurface ? Color.actionInk : Color.white,
                            in: Capsule()
                        )
                }
                .buttonStyle(SoftPressStyle())
                .disabled(replied)
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(secondaryInk)
                    .frame(width: 24, height: 24)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("收起提醒")
        }
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(isLightSurface ? Color.white.opacity(0.82) : Color.black.opacity(0.46))
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        isLightSurface ? Color.black.opacity(0.08) : Color.white.opacity(0.24),
                        lineWidth: 0.8
                    )
            }
            .shadow(color: Color.black.opacity(isLightSurface ? 0.12 : 0.30), radius: 16, y: 6)
        }
        .onAppear {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.55).repeatCount(2, autoreverses: true)) {
                stickerBounce = true
            }
        }
    }
}
