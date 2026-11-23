import SwiftUI
import PhotosUI
import Photos
import UIKit

/// 这一顿的自由画布，支持菜品、文字、表情和涂鸦。
struct MealCanvasView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var vm: MealNowViewModel
    let pendingReviewMealId: UInt?
    let onAddDish: () -> Void
    let onReview: (UInt) -> Void
    let onConfirm: () -> Void
    let onShoppingList: () -> Void
    let onDining: () -> Void
    let onRetry: () async -> Void
    var isLaunchStudio: Bool = false
    var onCloseLaunchStudio: (() -> Void)? = nil
    var onLaunchLightSurfaceChange: ((Bool) -> Void)? = nil
    var onShareMeal: (() -> Void)? = nil
    var isGuestMode: Bool = false
    var guestHostName: String? = nil
    var guestParticipants: [MealParticipant] = []
    var onGuestCollapse: (() -> Void)? = nil
    var onGuestLeave: (() -> Void)? = nil
    var onDeleteDish: ((MealDish) async -> Bool)? = nil
    var onRemoteMealSync: (() -> Void)? = nil
    var onGuestLightSurfaceChange: ((Bool) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var realtime = CanvasRealtimeSession()
    @State private var background: CanvasBackground = .meadow
    @State private var blur: Double = 0.0
    @State private var moodFilter: CanvasMoodFilter = .none
    @State private var customBackgroundData: Data?
    @State private var customBackgroundURL: String?
    @State private var isApplyingRemoteUpdate = false
    @State private var hasReceivedWelcome = false
    @State private var stickers: [CanvasSticker] = []
    @State private var notes: [CanvasNote] = []
    @State private var strokes: [CanvasStroke] = []
    @State private var activeStroke: [CGPoint] = []
    @State private var brushColor: CanvasBrushColor = .white
    @State private var customBrushColor: Color = CanvasBrushColor.white.color
    @State private var usesCustomBrushColor = false
    @State private var brushStyle: CanvasBrushStyle = .solid
    @State private var brushWidth: CGFloat = 4
    @State private var selectedStickerID: UUID?
    @State private var selectedNoteID: UUID?
    @State private var isSelecting = false
    @State private var selectedElements: Set<CanvasSelection> = []
    @State private var drawingEnabled = false
    @State private var restoredMealID: UInt?
    @State private var isRemovingDish = false
    @State private var canvasFrame: CGRect = .zero
    @State private var isExporting = false
    @State private var isEditing = false
    @State private var isCanvasInteracting = false
    @State private var alignmentGuides = CanvasAlignmentGuides()
    @State private var undoStack: [CanvasHistorySnapshot] = []
    @State private var redoStack: [CanvasHistorySnapshot] = []
    @State private var transformEditorHasChanges = false
    @State private var activeEditor: CanvasEditorPanel?
    @State private var insertMode: CanvasInsertItem?
    @State private var draftText = ""
    @State private var draftFont: CanvasTextFont = .rounded
    @State private var draftColor: CanvasTextColor = .white
    @State private var draftScale: CGFloat = 1.0
    @State private var draftTextStyle: CanvasTextStyle = .plain
    @State private var draftTextEffect: CanvasTextEffect = .float
    @State private var emojiCategory: CanvasEmojiCategory = .featured
    @State private var stickerSource: CanvasStickerSource = .doodles
    @State private var doodleColor: CanvasTextColor = .white
    @State private var stickerFavorites: [StickerFavorite] = []
    @State private var isLoadingStickerFavorites = false
    @State private var stickerFavoritesError: String?
    @State private var deletingStickerFavorites: Set<UInt> = []
    @Namespace private var emojiCategoryHighlight
    @State private var backgroundPhotoItem: PhotosPickerItem?
    @State private var stickerPhotoItem: PhotosPickerItem?
    @State private var isCreatingAlbumSticker = false
    @State private var strokeRedoStack: [CanvasStroke] = []
    @State private var layoutPresetIndex = 0
    @State private var showPhotoSticker = false
    @State private var toolsExpanded = false
    @State private var liveMotionEnabled = true
    @State private var liveExportProgress: Double?
    @State private var studioTipMessage: String?
    @State private var launchConfig: LaunchCurtainConfig = LaunchCurtainStore.load()
    @State private var showLaunchOptionsSheet = false
    @State private var showLaunchLivePreview = false
    @State private var hasLoadedStudio = false
    @FocusState private var textEditorFocused: Bool

    private static let todayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEE"
        return formatter
    }()

    private static func starterDateText(for date: Date = Date()) -> String {
        let md = DateFormatter()
        md.locale = Locale(identifier: "en_US_POSIX")
        md.dateFormat = "M.dd"
        let wd = DateFormatter()
        wd.locale = Locale(identifier: "en_US_POSIX")
        wd.dateFormat = "EEEE"
        return "\(md.string(from: date))\n\(wd.string(from: date))"
    }

    private var headerInk: Color {
        background.isLightSurface ? CanvasPalette.ink : .white
    }

    private var headerMutedInk: Color {
        background.isLightSurface ? CanvasPalette.muted : Color.white.opacity(0.76)
    }

    @ViewBuilder
    private func adaptiveGlass<S: InsettableShape>(_ shape: S) -> some View {
        let isLight = background.isLightSurface
        shape
            .fill(.ultraThinMaterial)
            .overlay {
                shape.fill(isLight ? Color.white.opacity(0.76) : Color.black.opacity(0.20))
            }
            .overlay {
                shape.strokeBorder(
                    isLight ? Color.black.opacity(0.08) : Color.white.opacity(0.38),
                    lineWidth: isLight ? 0.6 : 0.85
                )
            }
            .shadow(color: Color.black.opacity(isLight ? 0.08 : 0.22), radius: isLight ? 10 : 12, y: isLight ? 3 : 4)
    }

    private var topHeaderOverlay: some View {
        VStack(spacing: 8) {
            if isLaunchStudio {
                launchStudioHeader
                    .padding(.horizontal, 18)
                    .padding(.top, 4)

                if let studioTipMessage {
                    Text(studioTipMessage)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.black.opacity(0.72), in: Capsule())
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            } else {
                header
                    .padding(.horizontal, 18)
                    .padding(.top, 4)

                if vm.loadFailed && vm.meal == nil {
                    retryStrip
                        .padding(.horizontal, 18)
                }
            }
        }
        .opacity(isExporting ? 0 : 1)
    }

    @ViewBuilder
    private var launchPreviewOverlay: some View {
        if isLaunchStudio && showLaunchLivePreview {
            LaunchCurtainView(
                config: launchConfig,
                previewPayload: LaunchCanvasDocumentPayload(document: currentDocumentSnapshot()),
                canDismiss: true,
                allowTapToSkip: true,
                holdMilliseconds: max(launchConfig.holdSpeed.milliseconds, 2400)
            ) {
                withAnimation(.easeOut(duration: 0.22)) {
                    showLaunchLivePreview = false
                }
            }
            .zIndex(200)
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var liveExportOverlay: some View {
        if let progress = liveExportProgress {
            ZStack {
                Color.black.opacity(0.22).ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(.white)
                        .frame(width: 170)
                    Text("正在合成实况照片 \(Int((progress * 100).rounded()))%")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.black.opacity(0.45))
                        }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.28), lineWidth: 0.8)
                }
                .shadow(color: Color.black.opacity(0.28), radius: 18, y: 8)
            }
            .transition(.opacity)
        }
    }

    private var canvasStageView: some View {
        canvas
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                ZStack {
                    CanvasMediaBackground(
                        source: background,
                        blur: blur,
                        customData: customBackgroundData,
                        customURL: customBackgroundURL
                    )
                    .id(background)
                    .transition(.opacity)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: background)

                    CanvasMoodFilterOverlay(filter: moodFilter)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: moodFilter)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
            .overlay(alignment: .top) {
                if !isExporting && !background.isLightSurface {
                    LinearGradient(
                        colors: [Color.black.opacity(0.26), Color.black.opacity(0.08), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 136)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .top) { topHeaderOverlay }
            .overlay(alignment: .bottom) {
                liveControls
                    .padding(.horizontal, 16)
                    .padding(.bottom, (isLaunchStudio || isGuestMode) ? 16 : 78)
                    .opacity(isExporting ? 0 : 1)
            }
            .overlay { launchPreviewOverlay }
            .overlay { liveExportOverlay }
    }

    var body: some View {
        stageWithMediaModifiers
            .sheet(isPresented: $isEditing, onDismiss: {
                activeEditor = nil
                textEditorFocused = false
            }) {
                inlineEditorSheetContent
            }
            .background { launchOptionsSheetHost }
    }

    @ViewBuilder
    private var inlineEditorSheetContent: some View {
        if activeEditor != nil {
            inlineEditorPanel
                .preferredColorScheme(.light)
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .presentationDetents(editorDetents)
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .presentationBackground(Color.white)
                .presentationBackgroundInteraction(.enabled)
                .fullScreenCover(isPresented: $showPhotoSticker) {
                    PhotoStickerSheet { saved in
                        rememberStickerFavorite(saved)
                        stickerSource = .favorites
                    }
                    .preferredColorScheme(.light)
                }
        }
    }

    private var launchOptionsSheetHost: some View {
        Color.clear
            .sheet(isPresented: $showLaunchOptionsSheet) {
                LaunchStudioOptionsSheet(
                    config: $launchConfig,
                    onSelectTemplate: { template in
                        applyLaunchTemplate(template)
                    },
                    onPreview: {
                        showLaunchOptionsSheet = false
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(250))
                            finishEditing()
                            withAnimation(.easeOut(duration: 0.2)) {
                                showLaunchLivePreview = true
                            }
                        }
                    },
                    onResetDefault: {
                        resetLaunchStudioToDefault()
                    }
                )
                .preferredColorScheme(.light)
                .presentationDetents([.height(540), .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
            }
    }

    private var stageWithMealModifiers: some View {
        canvasStageView
            .onAppear {
                if isLaunchStudio {
                    restoreLaunchStudioIfNeeded()
                } else {
                    reportLightSurface(background.isLightSurface)
                    restoreDocumentIfNeeded()
                    setupRealtimeHandlers()
                    if let mealID = vm.meal?.id {
                        realtime.connect(mealId: mealID)
                    }
                }
            }
            .onDisappear {
                if !isLaunchStudio {
                    realtime.disconnect()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                guard !isLaunchStudio else { return }
                if phase == .active, let mealID = vm.meal?.id {
                    realtime.ensureConnected(mealId: mealID)
                }
            }
            .onChange(of: vm.meal?.id) { _, newMealID in
                guard !isLaunchStudio else { return }
                hasReceivedWelcome = false
                selectedStickerID = nil
                selectedNoteID = nil
                finishSelecting()
                activeStroke.removeAll()
                strokeRedoStack.removeAll()
                stickerPhotoItem = nil
                isCreatingAlbumSticker = false
                drawingEnabled = false
                isEditing = false
                activeEditor = nil
                insertMode = nil
                textEditorFocused = false
                undoStack.removeAll()
                redoStack.removeAll()
                restoreDocumentIfNeeded()
                if let newMealID {
                    realtime.connect(mealId: newMealID)
                } else {
                    realtime.disconnect()
                }
            }
            .onChange(of: vm.meal?.status) { _, status in
                guard !isLaunchStudio else { return }
                if status == .confirmed || status == .completed {
                    finishEditing()
                }
            }
            .onChange(of: vm.dishes.map(\.id)) { _, _ in
                guard !isLaunchStudio else { return }
                let myUserId = appState.currentUser?.id
                let addedDishID = restoredMealID == vm.meal?.id
                    ? vm.dishes.first(where: { dish in
                        !stickers.contains(where: { $0.mealDishID == dish.id })
                            && (myUserId == nil || dish.addedBy == nil || dish.addedBy == myUserId)
                    })?.id
                    : nil
                syncStickers(broadcast: !isApplyingRemoteUpdate && hasReceivedWelcome)
                selectedElements.formIntersection(Set(layerEntries.map(\.selection)))
                if !isCanvasInteracting, !drawingEnabled, !isEditing,
                   let addedDishID, let added = stickers.first(where: { $0.mealDishID == addedDishID }) {
                    finishSelecting()
                    selectedStickerID = added.id
                    selectedNoteID = nil
                }
            }
    }

    private var stageWithMediaModifiers: some View {
        stageWithMealModifiers
            .onChange(of: selectedNoteID) { _, _ in
                if activeEditor == .insert {
                    draftText = selectedTextNote?.text ?? ""
                }
            }
            .onChange(of: selectedCanvasElement) { _, _ in transformEditorHasChanges = false }
            .onChange(of: notes.map(\.id)) { _, _ in
                selectedElements.formIntersection(Set(layerEntries.map(\.selection)))
            }
            .onChange(of: background) { oldValue, newValue in
                reportLightSurface(newValue.isLightSurface)
                if !usesCustomBrushColor, oldValue.isLightSurface != newValue.isLightSurface,
                   brushColor == .white || brushColor == .ink {
                    brushColor = newValue.defaultBrushColor
                    customBrushColor = brushColor.color
                }
                saveDocument()
            }
            .onChange(of: blur) { _, _ in saveDocument() }
            .onChange(of: moodFilter) { _, _ in
                saveDocument()
            }
            .onChange(of: customBackgroundData) { _, _ in saveDocument() }
            .onChange(of: backgroundPhotoItem) { _, item in
                guard let item else { return }
                Task {
                    guard let data = try? await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data),
                          let preview = image.canvasPreviewData else {
                        backgroundPhotoItem = nil
                        showCanvasTip("无法读取照片，请重新选择")
                        return
                    }
                    await MainActor.run {
                        recordUndoSnapshot()
                        customBackgroundData = preview
                        customBackgroundURL = nil
                        background = .custom
                        backgroundPhotoItem = nil
                    }
                    guard !isLaunchStudio else { return }
                    do {
                        let uploaded = try await UploadService.shared.uploadImage(preview, filename: "canvas_bg.jpg", mime: "image/jpeg")
                        await MainActor.run {
                            guard customBackgroundData == preview else { return }
                            customBackgroundURL = uploaded.path
                            saveDocument()
                            broadcastBackgroundUpdate()
                        }
                    } catch {
                        await MainActor.run {
                            showCanvasTip("背景图上传失败，仅本机可见")
                        }
                    }
                }
            }
            .onChange(of: stickerPhotoItem) { _, item in
                guard let item else { return }
                Task { await createStickerFromAlbumPhoto(item) }
            }
    }

    private var editorDetents: Set<PresentationDetent> {
        switch activeEditor {
        case .transform: return [.height(360)]
        case .emoji: return [.height(540), .large]
        case .brush: return [.height(470), .large]
        case .effects: return [.height(420), .large]
        case .insert: return [.height(620), .large]
        case .background: return [.height(336)]
        case nil: return [.height(430)]
        }
    }

    private var statusBadgeText: String {
        if vm.meal?.status == .confirmed {
            return "已定下 · \(vm.dishCount) 道"
        }
        if vm.dishCount > 0 {
            return "商量中 · \(vm.dishCount) 道"
        }
        return "挑菜中"
    }

    private var headerParticipants: [AppUser] {
        var seen: Set<UInt> = []
        var result: [AppUser] = []
        for actor in realtime.onlineUsers {
            guard seen.insert(actor.id).inserted else { continue }
            result.append(actor.asAppUser)
            if result.count >= 4 { return result }
        }
        for participant in guestParticipants {
            guard let user = participant.user, seen.insert(user.id).inserted else { continue }
            result.append(user)
            if result.count >= 4 { return result }
        }
        for dish in vm.dishes {
            guard let adder = dish.adder, seen.insert(adder.id).inserted else { continue }
            result.append(adder)
            if result.count >= 4 { return result }
        }
        return result
    }

    private var livePillMenu: some View {
        Menu {
            Button {
                Haptics.light()
                saveCanvasAsLivePhoto()
            } label: {
                Label("保存为实况照片", systemImage: "livephoto")
            }
            .disabled(isExporting || liveExportProgress != nil)

            Button {
                Haptics.light()
                withAnimation(.easeInOut(duration: 0.22)) {
                    liveMotionEnabled.toggle()
                }
            } label: {
                Label(
                    liveMotionEnabled ? "暂停实况动效" : "开启实况动效",
                    systemImage: liveMotionEnabled ? "pause.circle" : "play.circle"
                )
            }

            Button {
                Haptics.light()
                activateAllLiveMotion()
            } label: {
                Label("全部轻盈动起来", systemImage: "sparkles")
            }

            Button {
                Haptics.light()
                applyNextSmartLayout()
            } label: {
                Label("一键换排版", systemImage: "rectangle.3.group")
            }
            .disabled(stickers.isEmpty)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: liveMotionEnabled ? "livephoto" : "livephoto.slash")
                    .font(.system(size: 11, weight: .semibold))
                    .symbolEffect(.pulse, options: .repeating, isActive: liveMotionEnabled && !reduceMotion && !isExporting)
                Text("LIVE")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.4)
                    .lineLimit(1)
            }
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(headerInk)
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background { adaptiveGlass(Capsule()) }
            .frame(minHeight: 34)
            .contentShape(Capsule())
        }
        .disabled(isCanvasInteracting || liveExportProgress != nil)
        .accessibilityLabel("实况画布选项")
    }

    @ViewBuilder
    private var undoRedoCapsule: some View {
        let isLight = background.isLightSurface
        if canUndoCanvas || canRedoCanvas {
            HStack(spacing: 0) {
                if canUndoCanvas {
                    Button(action: undoLastAction) {
                        ProductIcon(kind: .undo, size: 14, weight: .medium)
                            .foregroundStyle(headerInk)
                            .frame(width: 34, height: 34)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(CanvasPressStyle())
                    .accessibilityLabel("撤销上一步")
                }

                if canUndoCanvas && canRedoCanvas {
                    Rectangle()
                        .fill(headerInk.opacity(isLight ? 0.14 : 0.24))
                        .frame(width: 0.7, height: 15)
                }

                if canRedoCanvas {
                    Button(action: redoLastAction) {
                        ProductIcon(kind: .redo, size: 14, weight: .medium)
                            .foregroundStyle(headerInk)
                            .frame(width: 34, height: 34)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(CanvasPressStyle())
                    .accessibilityLabel("重做")
                }
            }
            .background { adaptiveGlass(Capsule()) }
            .frame(minHeight: 44)
            .transition(.scale(scale: 0.85).combined(with: .opacity))
        }
    }

    private var launchStudioHeader: some View {
        let isLight = background.isLightSurface
        let saveFill = isLight ? CanvasPalette.obsidianInk : Color.white
        let saveInk = isLight ? Color.white : CanvasPalette.obsidianInk
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 6) {
                Button {
                    Haptics.light()
                    finishEditing()
                    onCloseLaunchStudio?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(headerInk)
                        .frame(width: 34, height: 34)
                        .background { adaptiveGlass(Circle()) }
                        .frame(minWidth: 36, minHeight: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(CanvasPressStyle())
                .accessibilityLabel("关闭开屏创作")

                Button {
                    Haptics.light()
                    finishEditing()
                    showLaunchOptionsSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: launchConfig.motion.icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(launchConfig.motion.title)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .opacity(0.72)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundStyle(headerInk)
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .background { adaptiveGlass(Capsule()) }
                    .frame(minHeight: 44)
                    .contentShape(Capsule())
                }
                .buttonStyle(CanvasPressStyle())
                .accessibilityLabel("选择开屏动效与模板")

                Spacer(minLength: 4)

                undoRedoCapsule

                Button {
                    Haptics.light()
                    finishEditing()
                    withAnimation(.easeOut(duration: 0.2)) {
                        showLaunchLivePreview = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10.5, weight: .semibold))
                        Text("试看")
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundStyle(headerInk)
                    .padding(.horizontal, 11)
                    .frame(height: 34)
                    .background { adaptiveGlass(Capsule()) }
                    .frame(minHeight: 44)
                    .contentShape(Capsule())
                }
                .buttonStyle(SoftPressStyle())
                .disabled(isCanvasInteracting)
                .accessibilityLabel("全屏试看开屏动画")

                Button {
                    saveLaunchStudioAndDismiss()
                } label: {
                    Text("保存")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(saveInk)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(saveFill, in: Capsule())
                        .shadow(color: Color.black.opacity(isLight ? 0.12 : 0.24), radius: 10, y: 4)
                        .frame(minHeight: 44)
                        .contentShape(Capsule())
                }
                .buttonStyle(SoftPressStyle())
                .disabled(isCanvasInteracting)
                .accessibilityLabel("保存开屏设置")
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: canUndoCanvas)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: canRedoCanvas)

            HStack(spacing: 6) {
                Button {
                    Haptics.light()
                    launchConfig.enabled.toggle()
                } label: {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(launchConfig.enabled ? (isLight ? CanvasPalette.obsidianInk : Color(red: 0.56, green: 0.88, blue: 0.58)) : headerMutedInk.opacity(0.6))
                            .frame(width: 6, height: 6)
                        Text(launchConfig.enabled ? "开屏已开启" : "开屏已关闭")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .lineLimit(1)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundStyle(launchConfig.enabled ? headerInk : headerMutedInk)
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .background { adaptiveGlass(Capsule()) }
                    .frame(minHeight: 30)
                    .contentShape(Capsule())
                }
                .buttonStyle(CanvasPressStyle(scale: 0.96))

                Button {
                    Haptics.light()
                    finishEditing()
                    showLaunchOptionsSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 10, weight: .semibold))
                        Text("模板与节奏 · \(launchConfig.holdSpeed.title)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .lineLimit(1)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundStyle(headerInk)
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .background { adaptiveGlass(Capsule()) }
                    .frame(minHeight: 30)
                    .contentShape(Capsule())
                }
                .buttonStyle(CanvasPressStyle(scale: 0.96))

                Menu {
                    Button("保存为实况照片", systemImage: "livephoto") {
                        saveCanvasAsLivePhoto()
                    }
                    .disabled(isExporting || liveExportProgress != nil)
                    Button("保存静态图片", systemImage: "square.and.arrow.down") {
                        saveCanvasToPhotos()
                    }
                    Button("全部轻盈动起来", systemImage: "sparkles") {
                        activateAllLiveMotion()
                    }
                    Button("恢复默认开屏", systemImage: "arrow.counterclockwise") {
                        resetLaunchStudioToDefault()
                    }
                    Button("清空画布元素", systemImage: "trash", role: .destructive) {
                        clearLaunchCanvasAdditions()
                    }
                    .disabled(stickers.isEmpty && notes.isEmpty && strokes.isEmpty)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(headerInk)
                        .frame(width: 24, height: 24)
                        .background { adaptiveGlass(Circle()) }
                        .frame(minWidth: 30, minHeight: 30)
                        .contentShape(Circle())
                }
                .disabled(isCanvasInteracting)
                .accessibilityLabel("更多开屏创作选项")
            }
        }
    }

    private var header: some View {
        let isLight = background.isLightSurface
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 6) {
                if isGuestMode {
                    Button {
                        Haptics.light()
                        onGuestCollapse?()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11.5, weight: .semibold))
                            Text("收起")
                                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(headerInk)
                        .padding(.horizontal, 11)
                        .frame(height: 32)
                        .background { adaptiveGlass(Capsule()) }
                        .frame(minHeight: 44)
                        .contentShape(Capsule())
                    }
                    .buttonStyle(CanvasPressStyle(scale: 0.96))
                    .accessibilityLabel("收起点菜房")
                } else {
                    Text("这一顿")
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(headerInk)
                        .shadow(color: isLight ? Color.clear : Color.black.opacity(0.20), radius: 6, y: 1)
                }

                livePillMenu

                Spacer(minLength: 4)

                undoRedoCapsule

                if !isGuestMode && vm.dishCount > 0 {
                    Button {
                        Haptics.light()
                        actionBarConfirm()
                    } label: {
                        HStack(spacing: 4) {
                            if vm.isActing {
                                ProgressView().tint(Color.white).controlSize(.small)
                            } else {
                                Image(systemName: confirmIcon).font(.system(size: 12, weight: .semibold))
                                Text(confirmPillTitle)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .lineLimit(1)
                            }
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background {
                            if isLight {
                                Capsule().fill(CanvasPalette.ink)
                                    .shadow(color: Color.black.opacity(0.12), radius: 10, y: 4)
                            } else {
                                adaptiveGlass(Capsule())
                            }
                        }
                        .frame(minHeight: 44)
                        .contentShape(Capsule())
                    }
                    .buttonStyle(SoftPressStyle())
                    .disabled(vm.isActing || isRemovingDish || isCanvasInteracting)
                    .accessibilityLabel(confirmTitle)
                }

                Menu {
                    Button("更换背景", systemImage: "photo") {
                        openEditor(.background)
                    }
                    Button("保存为实况照片", systemImage: "livephoto") {
                        saveCanvasAsLivePhoto()
                    }
                    .disabled(isExporting || liveExportProgress != nil)
                    Button("保存静态图片", systemImage: "square.and.arrow.down") {
                        saveCanvasToPhotos()
                    }
                    if vm.meal?.status == .planning || vm.meal?.status == .confirmed {
                        Button("从菜谱加菜", systemImage: "plus") {
                            onAddDish()
                        }
                        .disabled(vm.isActing || isRemovingDish)
                    }
                    if !isGuestMode {
                        if vm.dishCount > 0 || (vm.meal?.status != nil && vm.meal?.status != .planning) {
                            Button(confirmTitle, systemImage: confirmIcon) {
                                Haptics.light()
                                actionBarConfirm()
                            }
                            .disabled(vm.isActing || isRemovingDish)
                        }
                        Button("买菜清单", systemImage: "cart") { onShoppingList() }
                        Button(vm.hasActiveDiningRoom ? "聚餐点菜房（进行中）" : "邀请一起点", systemImage: "person.2") { onDining() }
                        if onShareMeal != nil, vm.meal != nil {
                            Button("分享这一顿", systemImage: "square.and.arrow.up") {
                                saveDocument()
                                Haptics.light()
                                onShareMeal?()
                            }
                        }
                        if let pendingReviewMealId {
                            Button("补写记录", systemImage: "square.and.arrow.pencil") {
                                onReview(pendingReviewMealId)
                            }
                        }
                    }
                    Button("撤销最后一笔", systemImage: "arrow.uturn.backward") {
                        undoStroke()
                    }
                    .disabled(strokes.isEmpty)
                    Button("清除文字和涂鸦", systemImage: "trash", role: .destructive) {
                        clearCanvasAdditions()
                    }
                    .disabled(!hasCanvasAdditions)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(headerInk)
                        .frame(width: 34, height: 34)
                        .background { adaptiveGlass(Circle()) }
                        .frame(width: 36, height: 44)
                        .contentShape(Circle())
                }
                .disabled(isCanvasInteracting)
                .accessibilityLabel("这一顿的更多操作")

                if isGuestMode {
                    Button {
                        Haptics.light()
                        onGuestLeave?()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 11, weight: .semibold))
                            Text("退出")
                                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(headerInk)
                        .padding(.horizontal, 11)
                        .frame(height: 32)
                        .background { adaptiveGlass(Capsule()) }
                        .frame(minHeight: 44)
                        .contentShape(Capsule())
                    }
                    .buttonStyle(CanvasPressStyle(scale: 0.96))
                    .accessibilityLabel("退出点菜房")
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: canUndoCanvas)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: canRedoCanvas)

            HStack(spacing: 8) {
                Button {
                    Haptics.light()
                    onAddDish()
                } label: {
                    HStack(spacing: 5) {
                        if isGuestMode {
                            Circle()
                                .fill(realtime.isConnected
                                    ? (isLight ? Color(red: 0.16, green: 0.62, blue: 0.34) : Color(red: 0.44, green: 0.88, blue: 0.56))
                                    : headerMutedInk)
                                .frame(width: 6, height: 6)
                            let hostDisplay = (guestHostName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                                ? guestHostName!
                                : "朋友"
                            Text(vm.dishCount > 0 ? "\(hostDisplay) 家的这一顿 · \(vm.dishCount) 道" : "\(hostDisplay) 家的这一顿 · 挑菜中")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .contentTransition(.numericText())
                                .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: vm.dishCount)
                        } else {
                            if vm.meal?.status == .confirmed {
                                Circle()
                                    .fill(headerInk)
                                    .frame(width: 5, height: 5)
                            }
                            Text("\(Self.todayDateFormatter.string(from: Date())) · \(statusBadgeText)")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .contentTransition(.numericText())
                                .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: vm.dishCount)
                        }
                    }
                    .foregroundStyle((isGuestMode || vm.dishCount > 0 || vm.meal?.status == .confirmed) ? headerInk : headerMutedInk)
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .background { adaptiveGlass(Capsule()) }
                }
                .buttonStyle(CanvasPressStyle(scale: 0.96))
                .frame(minHeight: 30)
                .disabled(vm.meal == nil || vm.isActing || isRemovingDish)
                .accessibilityLabel(statusBadgeText)

                if !isGuestMode && vm.hasActiveDiningRoom {
                    let guestCount = max(vm.meal?.participants?.count ?? 0, realtime.onlineUsers.filter { $0.role == "guest" }.count)
                    Button {
                        Haptics.light()
                        onDining()
                    } label: {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(isLight ? Color(red: 0.16, green: 0.62, blue: 0.34) : Color(red: 0.44, green: 0.88, blue: 0.56))
                                .frame(width: 6, height: 6)
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 10, weight: .semibold))
                            Text(guestCount > 0 ? "聚餐中 · \(guestCount) 人" : "聚餐中")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                        }
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(headerInk)
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background { adaptiveGlass(Capsule()) }
                    }
                    .buttonStyle(CanvasPressStyle(scale: 0.96))
                    .frame(minHeight: 30)
                    .disabled(isCanvasInteracting)
                    .accessibilityLabel("聚餐点菜房进行中")
                }

                if !headerParticipants.isEmpty {
                    HStack(spacing: -6) {
                        ForEach(headerParticipants) { user in
                            AvatarView(user: user, size: 20)
                                .overlay(Circle().stroke(isLight ? Color.white : Color.white.opacity(0.65), lineWidth: 1.2))
                        }
                    }
                    .accessibilityHidden(true)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var canvas: some View {
        GeometryReader { proxy in
            let orderedLayers = layerEntries.sorted { $0.layer > $1.layer }
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                            selectedStickerID = nil
                            selectedNoteID = nil
                            textEditorFocused = false
                            toolsExpanded = false
                        }
                    }
                    .allowsHitTesting(!drawingEnabled && !isCanvasInteracting)
                    .zIndex(-999_999)

                if stickers.isEmpty && notes.isEmpty && strokes.isEmpty && !isExporting {
                    Button {
                        Haptics.light()
                        if isLaunchStudio {
                            openEditor(.emoji)
                        } else {
                            onAddDish()
                        }
                    } label: {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .frame(width: 60, height: 60)
                                    .background { adaptiveGlass(Circle()) }
                                ProductIcon(kind: isLaunchStudio ? .effects : .meal, size: 24, weight: .regular)
                                    .foregroundStyle(headerInk)
                            }
                            VStack(spacing: 5) {
                                Text(isLaunchStudio ? "自由创作你的开屏画面" : "今天想吃点什么？")
                                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                                    .foregroundStyle(headerInk)
                                Text(isLaunchStudio ? "点下方文字、贴纸、画笔或背景开始" : "点下方加菜，把想吃的摆上桌")
                                    .font(.system(size: 13, weight: .regular, design: .rounded))
                                    .foregroundStyle(headerMutedInk)
                            }
                        }
                        .padding(.horizontal, 28)
                        .padding(.vertical, 20)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(SoftPressStyle())
                    .disabled(!isLaunchStudio && (vm.meal == nil || vm.isActing))
                    .opacity((!isLaunchStudio && (vm.meal == nil || vm.isActing)) ? 0.45 : 1)
                    .padding(.bottom, 40)
                    .accessibilityLabel(isLaunchStudio ? "添加开屏贴纸与文字" : "从菜谱添加第一道菜")
                }

                if !isExporting && liveMotionEnabled && !reduceMotion && !isSelecting {
                    TimelineView(.animation(minimumInterval: 1.0 / 16.0, paused: isCanvasInteracting)) { context in
                        LiveAmbientSparklesView(
                            time: context.date.timeIntervalSinceReferenceDate,
                            isLightSurface: background.isLightSurface,
                            isActive: true
                        )
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .zIndex(-500_000)
                }

                ForEach($stickers) { $sticker in
                    let stickerID = sticker.id
                    let preview = isExporting ? nil : remotePreview(for: "sticker", id: stickerID)
                    CanvasStickerView(
                        sticker: $sticker,
                        canvasSize: proxy.size,
                        isSelected: !isExporting && !isEditing && !isSelecting && stickerID == selectedStickerID,
                        reduceMotion: reduceMotion || isSelecting || !liveMotionEnabled,
                        reportsBounds: isSelecting,
                        isLightSurface: background.isLightSurface,
                        canMoveForward: orderedLayers.first?.selection != .sticker(stickerID),
                        canMoveBackward: orderedLayers.last?.selection != .sticker(stickerID),
                        alignmentTargets: alignmentTargets(excluding: .sticker(stickerID)),
                        remotePreview: preview,
                        onTransformStart: { rememberTransform(for: .sticker(stickerID)) },
                        onSelect: {
                            if selectedStickerID != stickerID { Haptics.light() }
                            withAnimation(.spring(response: 0.30, dampingFraction: 0.76)) {
                                selectedStickerID = stickerID
                                selectedNoteID = nil
                            }
                        },
                        onTransform: {
                            selectedStickerID = stickerID
                            selectedNoteID = nil
                            openEditor(.transform)
                        },
                        onLayerMove: { move in
                            moveLayer(move, for: .sticker(stickerID))
                        },
                        onDelete: {
                            deleteElement(.sticker(stickerID))
                        },
                        onFavorite: sticker.mealDishID == nil ? {
                            guard let image = stickers.first(where: { $0.id == stickerID })?.image else { return }
                            Task { await saveCanvasStickerFavorite(image) }
                        } : nil,
                        onDuplicate: sticker.mealDishID == nil ? {
                            duplicateElement(.sticker(stickerID))
                        } : nil,
                        onLiveChange: {
                            guard !isLaunchStudio,
                                  let current = stickers.first(where: { $0.id == stickerID }) else { return }
                            realtime.sendLivePreview(
                                targetKind: "sticker",
                                targetId: stickerID.uuidString,
                                position: current.position,
                                scale: current.scale,
                                rotationDegrees: current.rotationDegrees
                            )
                        },
                        onChange: {
                            if !isLaunchStudio {
                                realtime.sendLivePreview(targetKind: "clear", targetId: stickerID.uuidString)
                            }
                            saveDocument()
                            broadcastStickerUpsert(id: stickerID)
                        }
                    )
                    .transition(.opacity)
                    .zIndex(Double(sticker.layer))
                    .accessibilityHidden(isSelecting)
                    .allowsHitTesting(!drawingEnabled && !isSelecting && (!isCanvasInteracting || selectedStickerID == stickerID))
                }

                ForEach($notes) { $note in
                    let noteID = note.id
                    let preview = isExporting ? nil : remotePreview(for: "note", id: noteID)
                    CanvasNoteView(
                        note: $note,
                        canvasSize: proxy.size,
                        isSelected: !isExporting && !isEditing && !isSelecting && noteID == selectedNoteID,
                        freezesMotion: isSelecting || !liveMotionEnabled,
                        reportsBounds: isSelecting,
                        isLightSurface: background.isLightSurface,
                        canMoveForward: orderedLayers.first?.selection != .note(noteID),
                        canMoveBackward: orderedLayers.last?.selection != .note(noteID),
                        alignmentTargets: alignmentTargets(excluding: .note(noteID)),
                        remotePreview: preview,
                        onTransformStart: { rememberTransform(for: .note(noteID)) },
                        onSelect: {
                            if selectedNoteID != noteID { Haptics.light() }
                            withAnimation(.spring(response: 0.30, dampingFraction: 0.76)) {
                                selectedStickerID = nil
                                selectedNoteID = noteID
                            }
                        },
                        onEdit: {
                            selectedStickerID = nil
                            selectedNoteID = noteID
                            openEditor(.insert)
                        },
                        onTransform: {
                            selectedStickerID = nil
                            selectedNoteID = noteID
                            openEditor(.transform)
                        },
                        onLayerMove: { move in
                            moveLayer(move, for: .note(noteID))
                        },
                        onDelete: {
                            deleteElement(.note(noteID))
                        },
                        onDuplicate: {
                            duplicateElement(.note(noteID))
                        },
                        onLiveChange: {
                            guard !isLaunchStudio,
                                  let current = notes.first(where: { $0.id == noteID }) else { return }
                            realtime.sendLivePreview(
                                targetKind: "note",
                                targetId: noteID.uuidString,
                                position: current.position,
                                scale: current.scale,
                                rotationDegrees: current.rotationDegrees
                            )
                        },
                        onChange: {
                            if !isLaunchStudio {
                                realtime.sendLivePreview(targetKind: "clear", targetId: noteID.uuidString)
                            }
                            saveDocument()
                            broadcastNoteUpsert(id: noteID)
                        }
                    )
                    .transition(.opacity)
                    .zIndex(Double(note.layer))
                    .accessibilityHidden(isSelecting)
                    .allowsHitTesting(!drawingEnabled && !isSelecting && (!isCanvasInteracting || selectedNoteID == noteID))
                }

                CanvasDrawingView(
                    strokes: $strokes,
                    activeStroke: $activeStroke,
                    remoteActiveStrokes: isExporting ? [] : remoteActiveStrokes,
                    isEnabled: drawingEnabled,
                    brush: brushColor,
                    paintColor: customBrushColor,
                    style: brushStyle,
                    width: brushWidth,
                    onStart: { recordUndoSnapshot() },
                    onLiveStroke: { normalizedPoints in
                        guard !isLaunchStudio else { return }
                        let live = CanvasStroke(
                            points: normalizedPoints,
                            color: brushColor,
                            customColor: CanvasRGBA(color: customBrushColor),
                            style: brushStyle,
                            width: brushWidth,
                            isNormalized: true
                        )
                        realtime.sendLivePreview(targetKind: "stroke", targetId: "stroke", activeStroke: live)
                    },
                    onEnd: {
                        strokeRedoStack.removeAll()
                        if !isLaunchStudio {
                            realtime.sendLivePreview(targetKind: "clear", targetId: "stroke")
                        }
                        saveDocument()
                        if let last = strokes.last {
                            broadcastOp("add_stroke", payload: .addStroke(last))
                        }
                    }
                )
                .frame(width: proxy.size.width, height: proxy.size.height)

                if !isExporting {
                    Path { path in
                        if let x = alignmentGuides.vertical {
                            path.move(to: CGPoint(x: proxy.size.width * x, y: 12))
                            path.addLine(to: CGPoint(x: proxy.size.width * x, y: proxy.size.height - 12))
                        }
                        if let y = alignmentGuides.horizontal {
                            path.move(to: CGPoint(x: 12, y: proxy.size.height * y))
                            path.addLine(to: CGPoint(x: proxy.size.width - 12, y: proxy.size.height * y))
                        }
                    }
                    .stroke(background.isLightSurface ? CanvasPalette.accent.opacity(0.85) : Color.white.opacity(0.95), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .shadow(color: background.isLightSurface ? Color.clear : Color.black.opacity(0.25), radius: 1)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .zIndex(999)
                }

            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .overlayPreferenceValue(CanvasTransformOverlayKey.self) { overlay in
                if let overlay {
                    ZStack {
                        overlay.controls
                            .frame(width: overlay.size.width, height: overlay.size.height)
                            .position(overlay.center)
                            .id(overlay.selection)
                            .transaction {
                                $0.animation = nil
                                $0.disablesAnimations = true
                            }

                        Group {
                            if !isExporting, !isEditing, !isCanvasInteracting {
                                CanvasElementActionBar(
                                    title: selectedElementTitle,
                                    canEditText: selectedTextNote != nil,
                                    canDuplicate: canDuplicateSelectedElement,
                                    isDeleting: isRemovingDish,
                                    layers: orderedLayers,
                                    selection: overlay.selection,
                                    onSelect: selectElement,
                                    onEditText: { openEditor(.insert) },
                                    onEdit: { openEditor(.effects) },
                                    onDuplicate: { duplicateElement(overlay.selection) },
                                    onLayerMove: { moveLayer($0, for: overlay.selection) },
                                    onDelete: { deleteElement(overlay.selection) }
                                )
                                .position(elementMenuPosition(for: overlay, in: proxy.size))
                                .id(overlay.selection)
                                .transition(reduceMotion ? .opacity : .scale(scale: 0.94, anchor: .bottom).combined(with: .opacity))
                                .zIndex(1)
                            }
                        }
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isCanvasInteracting)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: selectedCanvasElement)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
            .overlayPreferenceValue(CanvasElementBoundsKey.self) { bounds in
                if isSelecting, !isExporting {
                    CanvasMarqueeSelection(
                        canvasSize: proxy.size,
                        bounds: bounds,
                        layers: orderedLayers.map(\.selection),
                        selection: $selectedElements,
                        transforms: selectedElements.compactMap { currentTransform(for: $0) },
                        isLightSurface: background.isLightSurface,
                        onMoveStart: { _ in
                            recordUndoSnapshot()
                        },
                        onMove: moveElements,
                        onChange: {
                            saveDocument()
                            broadcastBatchStickersNotes()
                        }
                    )
                }
            }
            .onAppear { canvasFrame = proxy.frame(in: .global) }
            .onChange(of: proxy.frame(in: .global)) { _, frame in
                guard frame.width > 0, frame.height > 0 else { return }
                canvasFrame = frame
                if restoredMealID == vm.meal?.id { saveDocument() }
            }
            .coordinateSpace(name: "mealCanvas")
        }
        .overlay(alignment: .top) {
            if !isExporting, isRemovingDish || drawingEnabled || isSelecting {
                Text(isRemovingDish ? "正在移除…" : drawingEnabled ? "正在画画 · 直接涂鸦"
                    : (selectedElements.isEmpty ? "拖出范围框选内容" : "已选 \(selectedElements.count) 项 · 拖动一起移动"))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(headerInk)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background { adaptiveGlass(Capsule()) }
                    .padding(.top, 82)
                    .allowsHitTesting(false)
            }
        }
        .onPreferenceChange(CanvasElementInteractionKey.self) { isCanvasInteracting = $0 }
        .onPreferenceChange(CanvasAlignmentGuidesKey.self) { alignmentGuides = $0 }
    }

    /// 编辑工具以紧凑双胶囊或单排图标条浮于画布底端。
    private var liveControls: some View {
        let isLight = background.isLightSurface
        let ctaFill = isLight ? CanvasPalette.obsidianInk : Color.white
        let ctaInk = isLight ? Color.white : CanvasPalette.obsidianInk
        return Group {
            if isSelecting {
                HStack(spacing: 2) {
                    LiveControlButton(title: "全选内容", icon: "selection.all",
                        isLightSurface: isLight,
                        isActive: selectedElements.count == layerEntries.count,
                        isDisabled: layerEntries.isEmpty) {
                        selectedElements = Set(layerEntries.map(\.selection))
                    }
                    LiveControlButton(title: "清除选择", icon: "xmark",
                        isLightSurface: isLight,
                        isDisabled: selectedElements.isEmpty) {
                        selectedElements.removeAll()
                    }
                    Button {
                        Haptics.light()
                        finishSelecting()
                    } label: {
                        HStack(spacing: 4) {
                            ProductIcon(kind: .check, size: 13, weight: .semibold)
                            Text("完成")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(ctaInk)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(ctaFill, in: Capsule())
                        .frame(minHeight: 40)
                        .contentShape(Capsule())
                    }
                    .buttonStyle(CanvasPressStyle(scale: 0.92))
                    .accessibilityLabel("完成框选")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background { adaptiveGlass(Capsule()) }
            } else if drawingEnabled {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(CanvasBrushColor.allCases) { item in
                            let selected = !usesCustomBrushColor && item == brushColor
                            Button {
                                Haptics.light()
                                brushColor = item
                                customBrushColor = item.color
                                usesCustomBrushColor = false
                            } label: {
                                ZStack {
                                    if selected {
                                        Circle()
                                            .stroke(isLight ? CanvasPalette.obsidianInk : Color.white, lineWidth: 1.8)
                                            .frame(width: 24, height: 24)
                                    }
                                    Circle()
                                        .fill(item.color)
                                        .frame(width: 18, height: 18)
                                        .overlay(Circle().strokeBorder(Color.black.opacity(0.16), lineWidth: 0.6))
                                }
                                .frame(width: 28, height: 28)
                                .contentShape(Circle())
                            }
                            .buttonStyle(CanvasPressStyle(scale: 0.88))
                            .accessibilityLabel(item.title)
                        }

                        Divider()
                            .frame(height: 16)
                            .overlay(headerInk.opacity(0.18))

                        Button {
                            Haptics.light()
                            openEditor(.brush)
                        } label: {
                            Text("\(brushStyle.title) · \(Int(brushWidth))")
                                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(headerInk)
                                .padding(.horizontal, 10)
                                .frame(height: 28)
                                .background(headerInk.opacity(isLight ? 0.08 : 0.16), in: Capsule())
                        }
                        .buttonStyle(CanvasPressStyle(scale: 0.94))
                        .accessibilityLabel("切换笔触和粗细")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background { adaptiveGlass(Capsule()) }

                    HStack(spacing: 2) {
                        Button {
                            Haptics.light()
                            openEditor(.brush)
                        } label: {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(customBrushColor)
                                    .frame(width: 13, height: 13)
                                    .overlay(Circle().strokeBorder(headerInk.opacity(0.28), lineWidth: 0.8))
                                Text("笔触")
                                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                                    .foregroundStyle(headerInk)
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 38)
                            .contentShape(Capsule())
                        }
                        .buttonStyle(CanvasPressStyle(scale: 0.92))
                        .accessibilityLabel("画笔设置")

                        LiveControlButton(title: "撤销", icon: "arrow.uturn.backward", isLightSurface: isLight, isDisabled: strokes.isEmpty) {
                            undoStroke()
                        }

                        LiveControlButton(title: "重做", icon: "arrow.uturn.forward", isLightSurface: isLight, isDisabled: strokeRedoStack.isEmpty) {
                            redoStroke()
                        }

                        LiveControlButton(title: "清空涂鸦", icon: "trash", isLightSurface: isLight, isDisabled: strokes.isEmpty) {
                            clearStrokes()
                        }

                        Button {
                            Haptics.light()
                            drawingEnabled = false
                        } label: {
                            HStack(spacing: 4) {
                                ProductIcon(kind: .check, size: 13, weight: .semibold)
                                Text("完成")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(ctaInk)
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                            .background(ctaFill, in: Capsule())
                            .frame(minHeight: 40)
                            .contentShape(Capsule())
                        }
                        .buttonStyle(CanvasPressStyle(scale: 0.92))
                        .accessibilityLabel("完成")
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background { adaptiveGlass(Capsule()) }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if toolsExpanded {
                HStack(spacing: 1) {
                    LiveControlButton(title: "文字", shortLabel: "文字", icon: "textformat", isLightSurface: isLight, isActive: activeEditor == .insert) {
                        addText()
                    }
                    LiveControlButton(title: "贴纸", shortLabel: "贴纸", icon: "face.smiling", isLightSurface: isLight, isActive: activeEditor == .emoji) {
                        openEditor(.emoji)
                    }
                    LiveControlButton(title: "画笔", shortLabel: "画笔", icon: "pencil", isLightSurface: isLight, isActive: drawingEnabled || activeEditor == .brush) {
                        startDrawing()
                    }
                    LiveControlButton(title: "背景", shortLabel: "背景", icon: "photo", isLightSurface: isLight, isActive: activeEditor == .background) {
                        openEditor(.background)
                    }
                    LiveControlButton(title: isLaunchStudio && stickers.isEmpty ? "模板与排版" : "一键排版", shortLabel: "排版", icon: "rectangle.3.group", isLightSurface: isLight, isDisabled: isLaunchStudio ? false : (stickers.isEmpty || isRemovingDish)) {
                        if isLaunchStudio && stickers.isEmpty {
                            finishEditing()
                            showLaunchOptionsSheet = true
                        } else {
                            applyNextSmartLayout()
                        }
                    }
                    LiveControlButton(title: "框选内容", shortLabel: "框选", icon: "selection", isLightSurface: isLight, isDisabled: layerEntries.isEmpty || isRemovingDish) {
                        selectedStickerID = nil
                        selectedNoteID = nil
                        textEditorFocused = false
                        toolsExpanded = false
                        isSelecting = true
                    }

                    Divider()
                        .frame(height: 22)
                        .overlay(headerInk.opacity(0.18))
                        .padding(.horizontal, 2)

                    Button {
                        Haptics.light()
                        withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.84)) {
                            toolsExpanded = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(headerMutedInk)
                            .frame(width: 32, height: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(CanvasPressStyle(scale: 0.90))
                    .accessibilityLabel("收起画布工具")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .frame(height: 52)
                .background { adaptiveGlass(Capsule()) }
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            } else {
                let addFill = isLight ? CanvasPalette.obsidianInk : Color.white
                let addInk = isLight ? Color.white : CanvasPalette.obsidianInk
                HStack(spacing: 10) {
                    Button {
                        Haptics.light()
                        if isLaunchStudio {
                            finishEditing()
                            showLaunchOptionsSheet = true
                        } else {
                            onAddDish()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if isLaunchStudio {
                                Image(systemName: "sparkles.tv")
                                    .font(.system(size: 14, weight: .semibold))
                            } else {
                                ProductIcon(kind: .add, size: 15, weight: .semibold)
                            }
                            Text(isLaunchStudio ? "动效模板" : "加菜")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .foregroundStyle(addInk)
                        .padding(.horizontal, 18)
                        .frame(height: 44)
                        .background(addFill, in: Capsule())
                        .shadow(color: Color.black.opacity(isLight ? 0.14 : 0.24), radius: 14, y: 5)
                    }
                    .buttonStyle(CanvasPressStyle(scale: 0.92))
                    .disabled(!isLaunchStudio && (vm.meal == nil || vm.isActing || isRemovingDish))
                    .opacity((!isLaunchStudio && (vm.meal == nil || vm.isActing || isRemovingDish)) ? 0.45 : 1)
                    .accessibilityLabel(isLaunchStudio ? "选择开屏动效与模板" : "加菜")

                    Button {
                        Haptics.light()
                        withAnimation(reduceMotion ? nil : .spring(response: 0.30, dampingFraction: 0.82)) {
                            toolsExpanded = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            ProductIcon(kind: .effects, size: 15, weight: .medium)
                            Text("创作")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .foregroundStyle(headerInk)
                        .padding(.horizontal, 16)
                        .frame(height: 44)
                        .background { adaptiveGlass(Capsule()) }
                    }
                    .buttonStyle(CanvasPressStyle(scale: 0.92))
                    .accessibilityLabel("展开画布工具")

                    Button {
                        Haptics.light()
                        openEditor(.background)
                    } label: {
                        ProductIcon(kind: .background, size: 16, weight: .medium)
                            .foregroundStyle(headerInk)
                            .frame(width: 44, height: 44)
                            .background { adaptiveGlass(Circle()) }
                    }
                    .buttonStyle(CanvasPressStyle(scale: 0.92))
                    .accessibilityLabel("更换背景")
                }
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.84), value: toolsExpanded)
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.86), value: drawingEnabled)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isSelecting)
        .opacity(isCanvasInteracting ? 0.35 : 1)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isCanvasInteracting)
        .allowsHitTesting(!isCanvasInteracting)
    }

    @ViewBuilder
    private var inlineEditorPanel: some View {
        if let activeEditor {
            VStack(alignment: .leading, spacing: 0) {
                editorSheetHeader(activeEditor)
                Group {
                    switch activeEditor {
                    case .transform: transformEditorContent
                    case .insert: textEditorContent
                    case .emoji: emojiEditorContent
                    case .effects: effectsEditorContent
                    case .brush: brushEditorContent
                    case .background: inlineBackgroundPanel
                    }
                }
                .id(activeEditor)
                .padding(.top, 16)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.spring(response: 0.34, dampingFraction: 0.80), value: activeEditor)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.white)
        }
    }

    private func editorSheetHeader(_ panel: CanvasEditorPanel) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(panel == .insert ? (selectedTextNote == nil ? "写一句" : "编辑文字") : panel == .transform ? "大小与角度" : panel == .emoji ? "贴纸" : panel == .effects ? "特效" : panel == .brush ? "画笔" : "画布背景")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(CanvasPalette.ink)

            }
            Spacer(minLength: 8)
            Button { closeEditor() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(CanvasPalette.ink)
                    .frame(width: 44, height: 44)
                    .background(CanvasPalette.surface, in: Circle())
                    .overlay {
                        Circle().strokeBorder(CanvasPalette.line, lineWidth: 0.8)
                    }
            }
            .buttonStyle(CanvasPressStyle(scale: 0.90))
            .accessibilityLabel("关闭编辑器")
        }
    }

    private static let textInspirationPhrases: [String] = [
        "今晚吃点好的", "微辣刚刚好", "在家吃顿好的 ✨", "今日菜单", "干杯 🥂", "光盘行动", "周末加餐"
    ]

    private var textEditorContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $draftText)
                    .focused($textEditorFocused)
                    .accessibilityLabel("画布文字")
                    .font(draftFont.font(size: 19, weight: .semibold))
                    .foregroundStyle(draftColor.color)
                    .frame(minHeight: 52, maxHeight: 62)
                    .scrollContentBackground(.hidden)
                if draftText.isEmpty {
                    Text("例如：今晚吃点好的")
                        .font(draftFont.font(size: 19, weight: .semibold))
                        .foregroundStyle((draftColor == .white || draftColor == .butter) ? .white.opacity(0.55) : CanvasPalette.muted.opacity(0.7))
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background((draftColor == .white || draftColor == .butter) ? CanvasPalette.obsidianInk.opacity(0.88) : CanvasPalette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(CanvasPalette.line, lineWidth: 0.8)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Self.textInspirationPhrases, id: \.self) { phrase in
                        Button {
                            Haptics.light()
                            draftText = phrase
                            if let selectedNoteID,
                               let index = notes.firstIndex(where: { $0.id == selectedNoteID }),
                               notes[index].isPlainText {
                                if notes[index].text != phrase { recordUndoSnapshot() }
                                notes[index].text = phrase
                                saveDocument()
                                broadcastNoteUpsert(id: selectedNoteID)
                            }
                        } label: {
                            Text(phrase)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(CanvasPalette.obsidianInk)
                                .padding(.horizontal, 11)
                                .frame(height: 30)
                                .background(CanvasPalette.surface, in: Capsule())
                                .overlay {
                                    Capsule().strokeBorder(CanvasPalette.line, lineWidth: 0.7)
                                }
                        }
                        .buttonStyle(CanvasPressStyle(scale: 0.94))
                    }
                }
                .padding(.horizontal, 1)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("样式")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CanvasPalette.muted)
                HStack(spacing: 6) {
                    ForEach(CanvasTextStyle.allCases) { style in
                        let selected = (selectedTextNote?.textStyle ?? draftTextStyle) == style
                        Button {
                            Haptics.light()
                            draftTextStyle = style
                            setSelectedNoteStyle(style)
                        } label: {
                            Text(style.title)
                                .font(.system(size: 12.5, weight: selected ? .semibold : .medium, design: .rounded))
                                .foregroundStyle(selected ? .white : CanvasPalette.muted)
                                .frame(maxWidth: .infinity)
                                .frame(height: 34)
                                .background(selected ? CanvasPalette.obsidianInk : CanvasPalette.surface, in: Capsule())
                                .overlay {
                                    if !selected {
                                        Capsule().strokeBorder(CanvasPalette.line, lineWidth: 0.8)
                                    }
                                }
                        }
                        .buttonStyle(CanvasPressStyle(scale: 0.94))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("字体")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CanvasPalette.muted)
                HStack(spacing: 8) {
                    ForEach(CanvasTextFont.allCases) { font in
                        let selected = (selectedTextNote?.font ?? draftFont) == font
                        Button {
                            Haptics.light()
                            draftFont = font
                            setSelectedNoteFont(font)
                        } label: {
                            Text(font.title)
                                .font(font.font(size: 13.5, weight: .semibold))
                                .foregroundStyle(selected ? .white : CanvasPalette.muted)
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .background(selected ? CanvasPalette.obsidianInk : CanvasPalette.surface, in: Capsule())
                                .overlay {
                                    if !selected {
                                        Capsule().strokeBorder(CanvasPalette.line, lineWidth: 0.8)
                                    }
                                }
                        }
                        .buttonStyle(CanvasPressStyle(scale: 0.94))
                    }
                }
                HStack(spacing: 0) {
                    Text("颜色")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CanvasPalette.muted)
                    ForEach(CanvasTextColor.allCases) { color in
                        let selected = (selectedTextNote?.color ?? draftColor) == color
                        Button {
                            Haptics.light()
                            draftColor = color
                            setSelectedNoteColor(color)
                        } label: {
                            ZStack {
                                if selected {
                                    Circle()
                                        .stroke(CanvasPalette.obsidianInk, lineWidth: 2)
                                        .frame(width: 31, height: 31)
                                }
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 22, height: 22)
                                    .overlay(Circle().stroke(CanvasPalette.line, lineWidth: 1))
                            }
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(CanvasPressStyle(scale: 0.92))
                        .accessibilityLabel("文字颜色 \(color.title)")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                    Spacer()
                }
            }
            HStack(spacing: 8) {
                Text("大小")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CanvasPalette.muted)
                ForEach([(0.82, "小"), (1.0, "中"), (1.22, "大"), (1.46, "特大")], id: \.0) { preset in
                    let currentScale = selectedTextNote?.scale ?? draftScale
                    let selected = abs(currentScale - CGFloat(preset.0)) < 0.02
                    Button {
                        Haptics.light()
                        draftScale = CGFloat(preset.0)
                        setSelectedNoteScale(CGFloat(preset.0))
                    } label: {
                        Text(preset.1)
                            .font(.system(size: 12.5, weight: selected ? .semibold : .medium))
                            .foregroundStyle(selected ? .white : CanvasPalette.muted)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(selected ? CanvasPalette.obsidianInk : CanvasPalette.surface, in: Capsule())
                            .overlay {
                                if !selected {
                                    Capsule().strokeBorder(CanvasPalette.line, lineWidth: 0.8)
                                }
                            }
                    }
                    .buttonStyle(CanvasPressStyle(scale: 0.94))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("实况动效")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CanvasPalette.muted)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(CanvasTextEffect.allCases) { effect in
                            let selected = (selectedTextNote?.textEffect ?? draftTextEffect) == effect
                            Button {
                                Haptics.light()
                                draftTextEffect = effect
                                setSelectedNoteEffect(effect)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: effect.icon)
                                        .font(.system(size: 11, weight: .semibold))
                                    Text(effect.title)
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                }
                                .foregroundStyle(selected ? .white : CanvasPalette.obsidianInk)
                                .padding(.horizontal, 12)
                                .frame(height: 34)
                                .background(selected ? CanvasPalette.obsidianInk : CanvasPalette.surface, in: Capsule())
                                .overlay {
                                    if !selected {
                                        Capsule().strokeBorder(CanvasPalette.line, lineWidth: 0.7)
                                    }
                                }
                            }
                            .buttonStyle(CanvasPressStyle(scale: 0.94))
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
        .padding(.bottom, 4)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            let isEmptyText = draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            VStack(spacing: 0) {
                Divider().overlay(CanvasPalette.line.opacity(0.8))
                Button {
                    Haptics.light()
                    commitDraftText()
                } label: {
                    Text(selectedTextNote == nil ? "放到画布" : "更新文字")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(isEmptyText ? CanvasPalette.obsidianInk.opacity(0.30) : CanvasPalette.obsidianInk, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(SoftPressStyle())
                .disabled(isEmptyText)
                .padding(.top, 10)
            }
            .background(Color.white)
        }
    }

    private var emojiEditorContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 4) {
                ForEach(CanvasStickerSource.allCases) { source in
                    Button {
                        Haptics.light()
                        stickerSource = source
                    } label: {
                        Text(source.rawValue)
                            .font(.system(size: 14, weight: stickerSource == source ? .semibold : .medium, design: .rounded))
                            .foregroundStyle(stickerSource == source ? CanvasPalette.ink : CanvasPalette.muted)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background {
                                if stickerSource == source {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.white)
                                        .shadow(color: CanvasPalette.ink.opacity(0.06), radius: 3, y: 1)
                                        .matchedGeometryEffect(id: "stickerSource", in: emojiCategoryHighlight)
                                }
                            }
                    }
                    .buttonStyle(SoftPressStyle())
                    .accessibilityAddTraits(stickerSource == source ? .isSelected : [])
                }
            }
            .padding(4)
            .background(CanvasPalette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(CanvasPalette.line, lineWidth: 0.8)
            }
            if stickerSource == .doodles {
                doodleStickerContent
            } else if stickerSource == .favorites {
                favoriteStickerContent
            } else {
                systemStickerContent
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: stickerSource)
        .task { await loadStickerFavorites() }
    }

    private var doodleStickerContent: some View {
        let darkCard = doodleColor == .white || doodleColor == .butter
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("配色")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CanvasPalette.muted)
                ForEach([CanvasTextColor.white, .ink, .butter, .coral], id: \.self) { color in
                    let selected = doodleColor == color
                    Button {
                        Haptics.light()
                        doodleColor = color
                    } label: {
                        ZStack {
                            if selected {
                                Circle()
                                    .stroke(CanvasPalette.accent, lineWidth: 2)
                                    .frame(width: 28, height: 28)
                            }
                            Circle()
                                .fill(color.color)
                                .frame(width: 20, height: 20)
                                .overlay(Circle().stroke(CanvasPalette.line, lineWidth: 0.9))
                        }
                        .frame(width: 30, height: 30)
                        .contentShape(Circle())
                    }
                    .buttonStyle(CanvasPressStyle(scale: 0.90))
                    .accessibilityLabel("手绘配色 \(color.title)")
                }

                Spacer()

                Button {
                    Haptics.light()
                    clearDoodleStickers()
                } label: {
                    HStack(spacing: 4) {
                        ProductIcon(kind: .trash, size: 13)
                        Text("清空手绘")
                            .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(CanvasPalette.muted)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(CanvasPalette.surface, in: Capsule())
                }
                .buttonStyle(SoftPressStyle())
                .disabled(!notes.contains(where: { $0.isDoodle }))
                .opacity(notes.contains(where: { $0.isDoodle }) ? 1 : 0.38)
            }

            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(CanvasDoodleKind.allCases) { kind in
                        Button {
                            Haptics.light()
                            insertDoodle(kind)
                        } label: {
                            VStack(spacing: 6) {
                                CanvasDoodleView(
                                    kind: kind,
                                    tint: doodleColor.color,
                                    isLightSurface: !darkCard,
                                    compact: true
                                )
                                .frame(maxWidth: .infinity)
                                .frame(height: 58)

                                Text(kind.title)
                                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                                    .foregroundStyle(darkCard ? Color.white.opacity(0.76) : CanvasPalette.muted)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .background(
                                darkCard ? Color(red: 0.165, green: 0.17, blue: 0.19) : CanvasPalette.surface,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(darkCard ? Color.white.opacity(0.08) : CanvasPalette.line.opacity(0.7), lineWidth: 0.7)
                            }
                        }
                        .buttonStyle(CanvasPressStyle(scale: 0.94))
                        .accessibilityLabel("添加手绘贴纸 \(kind.title)")
                    }
                }
                .padding(.bottom, 6)
            }
        }
    }

    private var favoriteStickerContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                PhotosPicker(selection: $stickerPhotoItem, matching: .images, photoLibrary: .shared()) {
                    Label("相册抠图", systemImage: "photo.badge.plus")
                        .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(CanvasPalette.obsidianInk, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(SoftPressStyle())
                .disabled(isCreatingAlbumSticker)

                Button {
                    showPhotoSticker = true
                } label: {
                    Label("拍照做贴图", systemImage: "camera")
                        .font(.system(size: 13.5, weight: .medium, design: .rounded))
                        .foregroundStyle(CanvasPalette.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(CanvasPalette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(CanvasPalette.line, lineWidth: 0.8)
                        }
                }
                .buttonStyle(SoftPressStyle())
                .disabled(isCreatingAlbumSticker)
            }

            if isCreatingAlbumSticker {
                HStack(spacing: 8) {
                    ProgressView().tint(CanvasPalette.obsidianInk).controlSize(.small)
                    Text("正在智能抠图并保存到贴纸库…")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(CanvasPalette.ink)
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
                .background(Color.paperGreen, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if let stickerFavoritesError {
                HStack {
                    Text(stickerFavoritesError)
                        .font(AppFont.caption())
                        .foregroundStyle(Color.errorInk)
                    Spacer(minLength: 8)
                    Button("重试") { Task { await loadStickerFavorites() } }
                        .foregroundStyle(CanvasPalette.accent)
                        .frame(minHeight: 44)
                        .disabled(isLoadingStickerFavorites)
                }
            }
            if isLoadingStickerFavorites && stickerFavorites.isEmpty {
                ProgressView().tint(CanvasPalette.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if stickerFavorites.isEmpty && stickerFavoritesError == nil {
                VStack(spacing: 10) {
                    Image(systemName: "star")
                        .font(.system(size: 28))
                        .foregroundStyle(CanvasPalette.muted)
                    Text("还没有收藏的贴图")
                        .font(AppFont.body(15))
                        .foregroundStyle(CanvasPalette.ink)
                    Text("从相册选图或拍照抠图后存到这里，点一下就能贴上画布。")
                        .font(AppFont.caption())
                        .foregroundStyle(CanvasPalette.muted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("点贴图添加到画布，长按可取消收藏")
                    .font(AppFont.caption())
                    .foregroundStyle(CanvasPalette.muted)
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                        ForEach(stickerFavorites) { favorite in
                            Button {
                                insertPhotoSticker(favorite.image, name: favorite.image.lowercased().hasSuffix(".png") ? "相册贴图" : "照片贴图")
                            } label: {
                                CachedStickerThumbView(imagePath: favorite.image)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 84)
                                    .padding(8)
                                    .background(CanvasPalette.surface, in: RoundedRectangle(cornerRadius: 14))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14)
                                            .strokeBorder(CanvasPalette.line.opacity(0.7), lineWidth: 0.6)
                                    }
                            }
                            .buttonStyle(CanvasPressStyle(scale: 0.94))
                            .disabled((!isLaunchStudio && vm.meal == nil) || deletingStickerFavorites.contains(favorite.id))
                            .opacity(((!isLaunchStudio && vm.meal == nil) || deletingStickerFavorites.contains(favorite.id)) ? 0.4 : 1)
                            .accessibilityLabel("添加收藏贴图到画布")
                            .contextMenu {
                                Button("取消收藏", systemImage: "star.slash", role: .destructive) {
                                    Task { await deleteStickerFavorite(favorite) }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 6)
                }
                .refreshable { await loadStickerFavorites() }
            }
        }
    }

    private var systemStickerContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                ForEach(CanvasEmojiCategory.allCases) { item in
                    Button {
                        Haptics.light()
                        emojiCategory = item
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: item.icon)
                                .font(.system(size: 12, weight: .semibold))
                            Text(item.title)
                                .font(.system(size: 12.5, weight: emojiCategory == item ? .semibold : .medium, design: .rounded))
                                .lineLimit(1)
                        }
                        .foregroundStyle(emojiCategory == item ? CanvasPalette.ink : CanvasPalette.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background {
                            if emojiCategory == item {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white)
                                    .shadow(color: CanvasPalette.ink.opacity(0.06), radius: 3, y: 1)
                                    .matchedGeometryEffect(id: "emojiCategory", in: emojiCategoryHighlight)
                            }
                        }
                    }
                    .buttonStyle(SoftPressStyle())
                    .accessibilityLabel(item.title)
                    .accessibilityAddTraits(emojiCategory == item ? .isSelected : [])
                }
                Divider().frame(height: 18).padding(.horizontal, 2)
                Button {
                    Haptics.light()
                    clearEmojiStickers()
                } label: {
                    ProductIcon(kind: .trash, size: 15)
                        .frame(width: 38, height: 36)
                }
                .foregroundStyle(CanvasPalette.muted)
                .buttonStyle(SoftPressStyle())
                .disabled(!notes.contains(where: { $0.isEmoji }))
                .opacity(notes.contains(where: { $0.isEmoji }) ? 1 : 0.35)
                .accessibilityLabel("清空表情贴纸")
            }
            .padding(4)
            .background(CanvasPalette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(CanvasPalette.line, lineWidth: 0.8)
            }
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.86), value: emojiCategory)
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                    ForEach(emojiCategory.items) { item in
                        Button {
                            Haptics.light()
                            insertEmoji(item)
                        } label: {
                            VStack(spacing: 3) {
                                Image(item.assetName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 50, height: 50)
                                    .shadow(color: Color.black.opacity(0.14), radius: 3, y: 1.5)
                                Text(item.title)
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(CanvasPalette.muted)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 76)
                            .background(CanvasPalette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(CanvasPalette.line.opacity(0.6), lineWidth: 0.7)
                            }
                        }
                        .buttonStyle(CanvasPressStyle(scale: 0.90))
                        .accessibilityLabel("添加贴纸 \(item.title)")
                    }
                }
                .padding(.bottom, 6)
            }
            .id(emojiCategory)
            .transition(.opacity)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: emojiCategory)
    }

    private var transformEditorContent: some View {
        VStack(spacing: 14) {
            HStack {
                Text("大小")
                Spacer()
                Text("\(Int((selectedElementScale * 100).rounded()))%")
                    .monospacedDigit()
            }
            Slider(value: Binding(
                get: { Double(selectedElementScale) },
                set: { updateSelectedTransform(scale: CGFloat($0)) }
            ), in: 0.3...3, onEditingChanged: { editing in
                if !editing {
                    commitTransformEditorSync()
                }
            })
            .frame(height: 44)
            .accessibilityLabel("元素大小")
            HStack {
                Text("角度")
                Spacer()
                Text("\(Int(selectedElementRotation.rounded()))°")
                    .monospacedDigit()
            }
            Slider(value: Binding(
                get: { selectedElementRotation },
                set: { updateSelectedTransform(rotation: $0) }
            ), in: -180...180, onEditingChanged: { editing in
                if !editing {
                    commitTransformEditorSync()
                }
            })
            .frame(height: 44)
            .accessibilityLabel("元素角度")
            HStack {
                Text("直接拖动画布上的内容来移动")
                    .font(.system(size: 12))
                    .foregroundStyle(CanvasPalette.muted)
                Spacer()
                Button {
                    Haptics.light()
                    updateSelectedTransform(scale: 1, rotation: 0)
                    commitTransformEditorSync()
                } label: {
                    ProductIcon(kind: .undo)
                        .foregroundStyle(CanvasPalette.ink)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(CanvasPressStyle())
                .accessibilityLabel("恢复大小和角度")
            }
        }
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(CanvasPalette.ink)
        .tint(CanvasPalette.accent)
        .disabled(selectedCanvasElement == nil)
    }

    @ViewBuilder
    private var effectsEditorContent: some View {
        if selectedCanvasElement == nil {
            VStack(spacing: 8) {
                Image(systemName: "cursorarrow.click.2")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(CanvasPalette.accent)
                Text("先点选画布里的菜品、贴纸或文字")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(CanvasPalette.ink)
                Text("选中后这里会显示适合它的特效")
                    .font(.system(size: 12))
                    .foregroundStyle(CanvasPalette.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    if let sticker = stickers.first(where: { $0.id == selectedStickerID }) {
                        HStack(spacing: 6) {
                            ForEach(CanvasStickerStyle.allCases) { item in
                                let isChosen = sticker.style == item
                                Button {
                                    Haptics.light()
                                    applyStickerStyle(item)
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: item.icon)
                                            .font(.system(size: 12, weight: .semibold))
                                        Text(item.title)
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    }
                                    .foregroundStyle(isChosen ? Color.white : CanvasPalette.ink)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 36)
                                    .background(
                                        isChosen ? CanvasPalette.ink : CanvasPalette.surface,
                                        in: Capsule()
                                    )
                                    .overlay {
                                        if !isChosen {
                                            Capsule().stroke(CanvasPalette.line, lineWidth: 0.7)
                                        }
                                    }
                                }
                                .buttonStyle(CanvasPressStyle(scale: 0.96))
                                .accessibilityAddTraits(isChosen ? .isSelected : [])
                            }
                        }
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                        if let sticker = stickers.first(where: { $0.id == selectedStickerID }) {
                            ForEach(CanvasEffect.allCases) { effect in
                                CanvasInlineEditorCard(icon: effect.icon, title: effect.title, previewKind: .sticker(effect, sticker), isSelected: selectedStickerEffect == effect) { applyEffect(effect) }
                            }
                        } else if let note = notes.first(where: { $0.id == selectedNoteID }) {
                            let effects = (note.isDoodle || (note.isEmoji && note.emojiAsset != nil))
                                ? CanvasTextEffect.allCases.filter { $0 != .typewriter }
                                : CanvasTextEffect.allCases
                            ForEach(effects) { effect in
                                CanvasInlineEditorCard(icon: effect.icon, title: effect.title, previewKind: .text(effect, note), isSelected: selectedTextEffect == effect) { applyTextEffect(effect) }
                            }
                        }
                    }
                    .padding(.bottom, 2)
                }
            }
        }
    }

    private var brushEditorContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("颜色")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(CanvasPalette.muted)
                    Spacer()
                    Text(usesCustomBrushColor ? "自定义" : brushColor.title)
                        .font(.system(size: 12))
                        .foregroundStyle(CanvasPalette.ink)
                }
                HStack(spacing: 4) {
                    ForEach(CanvasBrushColor.allCases) { item in
                        let selected = !usesCustomBrushColor && item == brushColor
                        Button {
                            Haptics.light()
                            brushColor = item
                            customBrushColor = item.color
                            usesCustomBrushColor = false
                        } label: {
                            Circle()
                                .fill(item.color)
                                .frame(width: 28, height: 28)
                                .overlay(Circle().stroke(selected ? CanvasPalette.ink : Color.dividerLine, lineWidth: selected ? 2 : 1))
                                .overlay {
                                    if selected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(item == .ink ? Color.white : CanvasPalette.ink)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(SoftPressStyle())
                        .accessibilityLabel(item.title)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                    ColorPicker("自定义颜色", selection: Binding(
                        get: { customBrushColor },
                        set: { customBrushColor = $0; usesCustomBrushColor = true }
                    ), supportsOpacity: true)
                    .labelsHidden()
                    .frame(width: 44, height: 44)
                    .background(usesCustomBrushColor ? Color.paperGreen : Color.clear, in: RoundedRectangle(cornerRadius: 12))
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("笔触")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(CanvasPalette.muted)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(CanvasBrushStyle.allCases) { item in
                            Button {
                                Haptics.light()
                                brushStyle = item
                            } label: {
                                VStack(spacing: 7) {
                                    CanvasBrushPreview(style: item, color: item == .neon ? (usesCustomBrushColor ? customBrushColor : (brushColor == .white ? CanvasBrushColor.coral.color : brushColor.color)) : CanvasPalette.ink)
                                        .frame(height: 22)
                                        .padding(.horizontal, 8)
                                        .background(item == .neon ? CanvasPalette.obsidianInk.opacity(0.88) : Color.clear, in: Capsule())
                                    Text(item.title)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(item == brushStyle ? CanvasPalette.ink : CanvasPalette.muted)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(item == brushStyle ? Color.paperGreen : CanvasPalette.surface, in: RoundedRectangle(cornerRadius: 14))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(item == brushStyle ? CanvasPalette.accent : CanvasPalette.line.opacity(0.8), lineWidth: 1)
                                }
                            }
                            .buttonStyle(SoftPressStyle())
                            .accessibilityAddTraits(item == brushStyle ? .isSelected : [])
                        }
                    }
                }
                HStack(spacing: 10) {
                    Text("粗细")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(CanvasPalette.muted)
                    Slider(value: $brushWidth, in: 2...14, step: 1)
                        .tint(CanvasPalette.accent)
                        .accessibilityLabel("画笔粗细")
                    Circle()
                        .fill(CanvasPalette.ink)
                        .frame(width: brushWidth, height: brushWidth)
                        .frame(width: 32, height: 44)
                        .accessibilityHidden(true)
                }
                Button { startDrawing() } label: {
                    Text("开始画画")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(CanvasPalette.ink, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(SoftPressStyle())
                .accessibilityLabel("开始在画布上绘制")
            }
        }
    }

    private func elementMenuPosition(for overlay: CanvasTransformOverlay, in size: CGSize) -> CGPoint {
        let radians = overlay.controls.rotationDegrees * .pi / 180
        let ring = overlay.controls.selectionSize
        let halfElementHeight = hypot(ring.width * sin(radians), ring.height * cos(radians)) / 2 + 19
        let halfWidth: CGFloat = (selectedTextNote == nil ? 214 : 254) / 2 + 8
        let top = overlay.center.y - halfElementHeight
        let bottom = overlay.center.y + halfElementHeight
        let upperLimit = min(104, size.height / 2)
        let lowerLimit = max(upperLimit, size.height - 156)
        let above = min(max(top - 49, upperLimit), lowerLimit)
        let below = min(max(bottom + 49, upperLimit), lowerLimit)
        let overlapAbove = max(0, min(above + 26, bottom) - max(above - 26, top))
        let overlapBelow = max(0, min(below + 26, bottom) - max(below - 26, top))
        return CGPoint(
            x: min(max(overlay.center.x, halfWidth), max(halfWidth, size.width - halfWidth)),
            y: overlapAbove <= overlapBelow ? above : below
        )
    }

    private var inlineBackgroundPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    PhotosPicker(selection: $backgroundPhotoItem, matching: .images, photoLibrary: .shared()) {
                        VStack(spacing: 5) {
                            VStack(spacing: 6) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 20, weight: .medium))
                                Text("从相册选")
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                            }
                            .foregroundStyle(CanvasPalette.obsidianInk)
                            .frame(width: 66, height: 84)
                            .background(CanvasPalette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(CanvasPalette.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            }
                            Text("相册")
                                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                                .foregroundStyle(CanvasPalette.muted)
                        }
                    }
                    .buttonStyle(CanvasPressStyle(scale: 0.96))
                    .accessibilityLabel("从相册选择背景")

                    if customBackgroundData != nil || customBackgroundURL != nil {
                        backgroundThumbnail(.custom)
                    }

                    ForEach(isLaunchStudio
                        ? [CanvasBackground.morningTable, .meadow, .gingham, .linen, .blushPaper, .warmWood, .seaside, .sunset, .night]
                        : [CanvasBackground.meadow, .morningTable, .gingham, .linen, .blushPaper, .warmWood, .seaside, .sunset, .night]
                    ) { item in
                        backgroundThumbnail(item)
                    }
                }
                .padding(.horizontal, 1)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("氛围滤镜")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CanvasPalette.muted)
                HStack(spacing: 6) {
                    ForEach(CanvasMoodFilter.allCases) { item in
                        let selected = moodFilter == item
                        Button {
                            Haptics.light()
                            if moodFilter != item {
                                recordUndoSnapshot()
                                moodFilter = item
                                broadcastBackgroundUpdate()
                            }
                        } label: {
                            Text(item.title)
                                .font(.system(size: 12, weight: selected ? .semibold : .medium, design: .rounded))
                                .foregroundStyle(selected ? .white : CanvasPalette.obsidianInk)
                                .frame(maxWidth: .infinity)
                                .frame(height: 32)
                                .background(selected ? CanvasPalette.obsidianInk : CanvasPalette.surface, in: Capsule())
                                .overlay {
                                    if !selected {
                                        Capsule().strokeBorder(CanvasPalette.line, lineWidth: 0.7)
                                    }
                                }
                        }
                        .buttonStyle(CanvasPressStyle(scale: 0.94))
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }

            HStack(spacing: 8) {
                Text("背景虚化")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CanvasPalette.muted)
                Slider(value: $blur, in: 0...10) { editing in
                    if editing {
                        recordUndoSnapshot()
                    } else {
                        broadcastBackgroundUpdate()
                    }
                }
                .tint(CanvasPalette.obsidianInk)
                Text(blur < 0.5 ? "关" : "\(Int(blur.rounded()))")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(CanvasPalette.obsidianInk)
                    .frame(width: 22)
            }
        }
    }

    private func backgroundThumbnail(_ item: CanvasBackground) -> some View {
        let isChosen = background == item
        return Button {
            if item != .custom || customBackgroundData != nil || customBackgroundURL != nil {
                Haptics.light()
                if background != item {
                    recordUndoSnapshot()
                    background = item
                    broadcastBackgroundUpdate()
                }
            }
        } label: {
            VStack(spacing: 5) {
                CanvasMediaBackground(
                    source: item,
                    blur: 0,
                    customData: customBackgroundData,
                    customURL: customBackgroundURL
                )
                    .frame(width: 66, height: 84)
                    .clipped()
                    .overlay(alignment: .topTrailing) {
                        if isChosen {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(5)
                                .background(CanvasPalette.obsidianInk, in: Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.85), lineWidth: 0.8))
                                .padding(5)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isChosen ? CanvasPalette.obsidianInk : CanvasPalette.line, lineWidth: isChosen ? 2 : 0.8)
                    }
                Text(item == .custom ? "自选图" : item.title)
                    .font(.system(size: 10.5, weight: isChosen ? .semibold : .medium, design: .rounded))
                    .foregroundStyle(isChosen ? CanvasPalette.obsidianInk : CanvasPalette.muted)
                    .lineLimit(1)
            }
        }
        .buttonStyle(CanvasPressStyle(scale: 0.96))
        .animation(.spring(response: 0.24, dampingFraction: 0.80), value: background)
        .accessibilityLabel(item == .custom ? "自选背景图" : item.title)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }

    private var selectedCanvasElement: CanvasSelection? {
        if let selectedStickerID { return .sticker(selectedStickerID) }
        if let selectedNoteID { return .note(selectedNoteID) }
        return nil
    }

    private var selectedTextNote: CanvasNote? {
        guard let selectedNoteID else { return nil }
        return notes.first { $0.id == selectedNoteID && $0.isPlainText }
    }

    private var canDuplicateSelectedElement: Bool {
        switch selectedCanvasElement {
        case .note: return true
        case .sticker(let id):
            return stickers.first(where: { $0.id == id })?.mealDishID == nil
        case nil: return false
        }
    }

    private var selectedElementTitle: String {
        switch selectedCanvasElement {
        case .sticker(let id):
            return stickers.first(where: { $0.id == id })?.name ?? "贴纸"
        case .note(let id):
            guard let note = notes.first(where: { $0.id == id }) else { return "文字" }
            if let doodle = note.doodle { return doodle.title }
            if note.isEmoji { return note.text }
            let clean = note.text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            return clean.isEmpty ? "文字" : String(clean.prefix(10))
        case nil:
            return ""
        }
    }

    private var selectedTextEffect: CanvasTextEffect? {
        guard case .note(let id) = selectedCanvasElement else { return nil }
        return notes.first(where: { $0.id == id })?.textEffect
    }

    private var selectedStickerEffect: CanvasEffect? {
        guard case .sticker(let id) = selectedCanvasElement else { return nil }
        return stickers.first(where: { $0.id == id })?.effect
    }

    private var selectedElementScale: CGFloat {
        switch selectedCanvasElement {
        case .sticker(let id): return stickers.first(where: { $0.id == id })?.scale ?? 1
        case .note(let id): return notes.first(where: { $0.id == id })?.scale ?? 1
        case nil: return 1
        }
    }

    private var selectedElementRotation: Double {
        let degrees: Double
        switch selectedCanvasElement {
        case .sticker(let id): degrees = stickers.first(where: { $0.id == id })?.rotationDegrees ?? 0
        case .note(let id): degrees = notes.first(where: { $0.id == id })?.rotationDegrees ?? 0
        case nil: degrees = 0
        }
        let angle = degrees.truncatingRemainder(dividingBy: 360)
        return angle > 180 ? angle - 360 : angle < -180 ? angle + 360 : angle
    }

    private func updateSelectedTransform(scale: CGFloat? = nil, rotation: Double? = nil) {
        guard scale.map({ min(max($0, 0.3), 3) != selectedElementScale }) == true
            || rotation.map({ $0 != selectedElementRotation }) == true else { return }
        if !transformEditorHasChanges, let selection = selectedCanvasElement {
            rememberTransform(for: selection)
            transformEditorHasChanges = true
        }
        switch selectedCanvasElement {
        case .sticker(let id):
            guard let index = stickers.firstIndex(where: { $0.id == id }) else { return }
            if let scale { stickers[index].scale = min(max(scale, 0.3), 3) }
            if let rotation { stickers[index].rotationDegrees = rotation }
        case .note(let id):
            guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
            if let scale { notes[index].scale = min(max(scale, 0.3), 3) }
            if let rotation { notes[index].rotationDegrees = rotation }
        case nil: return
        }
        saveDocument()
        broadcastTransformLivePreview()
    }

    private func broadcastTransformLivePreview() {
        guard !isLaunchStudio else { return }
        switch selectedCanvasElement {
        case .sticker(let id):
            guard let item = stickers.first(where: { $0.id == id }) else { return }
            realtime.sendLivePreview(
                targetKind: "sticker",
                targetId: id.uuidString,
                position: item.position,
                scale: item.scale,
                rotationDegrees: item.rotationDegrees
            )
        case .note(let id):
            guard let item = notes.first(where: { $0.id == id }) else { return }
            realtime.sendLivePreview(
                targetKind: "note",
                targetId: id.uuidString,
                position: item.position,
                scale: item.scale,
                rotationDegrees: item.rotationDegrees
            )
        case nil:
            break
        }
    }

    private func commitTransformEditorSync() {
        guard !isLaunchStudio else { return }
        switch selectedCanvasElement {
        case .sticker(let id):
            realtime.sendLivePreview(targetKind: "clear", targetId: id.uuidString)
            broadcastStickerUpsert(id: id)
        case .note(let id):
            realtime.sendLivePreview(targetKind: "clear", targetId: id.uuidString)
            broadcastNoteUpsert(id: id)
        case nil:
            break
        }
    }

    private func currentTransform(for selection: CanvasSelection) -> CanvasTransformUndo? {
        switch selection {
        case .sticker(let id):
            guard let item = stickers.first(where: { $0.id == id }) else { return nil }
            return CanvasTransformUndo(selection: selection, position: item.position, scale: item.scale, rotationDegrees: item.rotationDegrees)
        case .note(let id):
            guard let item = notes.first(where: { $0.id == id }) else { return nil }
            return CanvasTransformUndo(selection: selection, position: item.position, scale: item.scale, rotationDegrees: item.rotationDegrees)
        }
    }

    private var canUndoCanvas: Bool {
        guard !isCanvasInteracting, !isEditing, !drawingEnabled, !isRemovingDish else { return false }
        return !undoStack.isEmpty
    }

    private var canRedoCanvas: Bool {
        guard !isCanvasInteracting, !isEditing, !drawingEnabled, !isRemovingDish else { return false }
        return !redoStack.isEmpty
    }

    private func currentCanvasSnapshot() -> CanvasHistorySnapshot {
        CanvasHistorySnapshot(
            stickers: stickers,
            notes: notes,
            strokes: strokes,
            background: background,
            moodFilter: moodFilter,
            blur: blur,
            customBackgroundData: customBackgroundData,
            customBackgroundURL: customBackgroundURL
        )
    }

    private func recordUndoSnapshot() {
        let snap = currentCanvasSnapshot()
        if undoStack.last != snap {
            undoStack.append(snap)
            if undoStack.count > 20 {
                undoStack.removeFirst(undoStack.count - 20)
            }
            redoStack.removeAll()
        }
    }

    private func rememberTransform(for selection: CanvasSelection) {
        _ = selection
        transformEditorHasChanges = false
        recordUndoSnapshot()
    }

    private func undoLastAction() {
        guard canUndoCanvas, let target = undoStack.popLast() else { return }
        redoStack.append(currentCanvasSnapshot())
        if redoStack.count > 20 {
            redoStack.removeFirst(redoStack.count - 20)
        }
        applyHistorySnapshot(target)
    }

    private func redoLastAction() {
        guard canRedoCanvas, let target = redoStack.popLast() else { return }
        undoStack.append(currentCanvasSnapshot())
        if undoStack.count > 20 {
            undoStack.removeFirst(undoStack.count - 20)
        }
        applyHistorySnapshot(target)
    }

    private func applyHistorySnapshot(_ target: CanvasHistorySnapshot) {
        let currentDishes = stickers.filter { $0.mealDishID != nil }
        let snapshotStickersByID = Dictionary(uniqueKeysWithValues: target.stickers.map { ($0.id, $0) })
        let restoredDishes: [CanvasSticker] = currentDishes.map { current in
            guard let prev = snapshotStickersByID[current.id] else { return current }
            var updated = current
            updated.position = prev.position
            updated.scale = prev.scale
            updated.rotationDegrees = prev.rotationDegrees
            updated.layer = prev.layer
            updated.effect = prev.effect
            updated.style = prev.style
            return updated
        }
        let restoredCustomStickers = target.stickers.filter { $0.mealDishID == nil }

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            stickers = restoredDishes + restoredCustomStickers
            notes = target.notes
            strokes = target.strokes
            background = target.background
            moodFilter = target.moodFilter
            blur = target.blur
            customBackgroundData = target.customBackgroundData
            customBackgroundURL = target.customBackgroundURL
            reportLightSurface(background.isLightSurface)
            selectedStickerID = selectedStickerID.flatMap { id in stickers.contains(where: { $0.id == id }) ? id : nil }
            selectedNoteID = selectedNoteID.flatMap { id in notes.contains(where: { $0.id == id }) ? id : nil }
            selectedElements.formIntersection(Set(layerEntries.map(\.selection)))
        }
        saveDocument()
        broadcastOp("replace_document", payload: .replaceDocument(currentDocumentSnapshot()))
        Haptics.light()
    }

    private func moveElements(_ transforms: [CanvasTransformUndo], by offset: CGSize) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            for item in transforms {
                let position = CanvasPoint(x: item.position.x + offset.width, y: item.position.y + offset.height)
                switch item.selection {
                case .sticker(let id):
                    if let index = stickers.firstIndex(where: { $0.id == id }) { stickers[index].position = position }
                case .note(let id):
                    if let index = notes.firstIndex(where: { $0.id == id }) { notes[index].position = position }
                }
            }
        }
    }

    private func finishSelecting() {
        isSelecting = false
        selectedElements.removeAll()
    }

    private var layerEntries: [CanvasLayerEntry] {
        stickers.map { CanvasLayerEntry(selection: .sticker($0.id), layer: $0.layer, title: $0.name, icon: $0.mealDishID == nil ? "photo" : "fork.knife") }
            + notes.map {
                CanvasLayerEntry(selection: .note($0.id), layer: $0.layer,
                    title: $0.doodle?.title ?? ($0.isEmoji ? "\($0.text) 贴纸" : String($0.text.replacingOccurrences(of: "\n", with: " ").prefix(16))),
                    icon: $0.doodle != nil ? "seal" : ($0.isEmoji ? "face.smiling" : "pencil"))
            }
    }

    private func selectElement(_ selection: CanvasSelection) {
        guard selection != selectedCanvasElement, currentTransform(for: selection) != nil else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.14)) {
            switch selection {
            case .sticker(let id): selectedStickerID = id; selectedNoteID = nil
            case .note(let id): selectedStickerID = nil; selectedNoteID = id
            }
        }
        Haptics.light()
    }

    private func moveLayer(_ move: CanvasLayerMove, for selected: CanvasSelection) {
        let ordered = layerEntries.sorted { $0.layer < $1.layer }
        guard let currentIndex = ordered.firstIndex(where: { $0.selection == selected }) else { return }

        switch move {
        case .front:
            guard currentIndex < ordered.count - 1 else { return }
            recordUndoSnapshot()
            setLayer((ordered.last?.layer ?? 0) + 1, for: selected)
        case .back:
            guard currentIndex > 0 else { return }
            recordUndoSnapshot()
            setLayer((ordered.first?.layer ?? 0) - 1, for: selected)
        case .forward, .backward:
            let targetIndex = move == .forward ? currentIndex + 1 : currentIndex - 1
            guard ordered.indices.contains(targetIndex) else { return }
            recordUndoSnapshot()
            let other = ordered[targetIndex]
            setLayer(other.layer, for: selected)
            setLayer(ordered[currentIndex].layer, for: other.selection)
        }
        saveDocument()
        broadcastBatchStickersNotes()
    }

    private func setLayer(_ layer: Int, for selection: CanvasSelection) {
        switch selection {
        case .sticker(let id):
            guard let index = stickers.firstIndex(where: { $0.id == id }) else { return }
            stickers[index].layer = layer
        case .note(let id):
            guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
            notes[index].layer = layer
        }
    }

    private func deleteElement(_ selected: CanvasSelection) {
        switch selected {
        case .sticker(let id):
            guard let sticker = stickers.first(where: { $0.id == id }) else { return }
            if sticker.mealDishID == nil {
                recordUndoSnapshot()
                stickers.removeAll { $0.id == id }
                selectedStickerID = nil
                closeEditor()
                saveDocument()
                broadcastOp("delete_sticker", payload: .deleteSticker(id: id))
                return
            }
            guard !isRemovingDish,
                  let dish = vm.dishes.first(where: { $0.id == sticker.mealDishID }) else { return }
            isRemovingDish = true
            Task {
                defer { isRemovingDish = false }
                let deleted: Bool
                if let onDeleteDish {
                    deleted = await onDeleteDish(dish)
                } else {
                    await vm.removeDish(dish)
                    deleted = !vm.dishes.contains(where: { $0.id == dish.id })
                }
                if deleted {
                    syncStickers(broadcast: false)
                    broadcastOp("delete_sticker", payload: .deleteSticker(id: id, mealDishID: dish.id))
                }
            }
        case .note(let id):
            guard notes.contains(where: { $0.id == id }) else { return }
            recordUndoSnapshot()
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                notes.removeAll { $0.id == id }
                selectedNoteID = nil
            }
            closeEditor()
            saveDocument()
            broadcastOp("delete_note", payload: .deleteNote(id: id))
        }
    }

    private func duplicateElement(_ selected: CanvasSelection) {
        switch selected {
        case .sticker(let id):
            guard let source = stickers.first(where: { $0.id == id }), source.mealDishID == nil else { return }
            recordUndoSnapshot()
            let copy = CanvasSticker(
                mealDishID: nil,
                name: source.name,
                image: source.image,
                isCutout: source.isCutout,
                assetName: source.assetName,
                position: CanvasPoint(
                    x: min(max(source.position.x + 0.045, 0.10), 0.90),
                    y: min(max(source.position.y + 0.045, 0.14), 0.84)
                ),
                scale: source.scale,
                rotationDegrees: source.rotationDegrees,
                effect: source.effect,
                style: source.style,
                shapeIndex: source.shapeIndex,
                layer: nextLayerIndex
            )
            stickers.append(copy)
            selectedStickerID = copy.id
            selectedNoteID = nil
            saveDocument()
            broadcastStickerUpsert(id: copy.id)
            Haptics.light()
        case .note(let id):
            guard let source = notes.first(where: { $0.id == id }) else { return }
            recordUndoSnapshot()
            let copy = CanvasNote(
                text: source.text,
                isEmoji: source.isEmoji,
                position: CanvasPoint(
                    x: min(max(source.position.x + 0.045, 0.10), 0.90),
                    y: min(max(source.position.y + 0.045, 0.14), 0.84)
                ),
                scale: source.scale,
                rotationDegrees: source.rotationDegrees,
                layer: nextLayerIndex,
                textEffect: source.textEffect,
                font: source.font,
                color: source.color,
                textStyle: source.textStyle,
                doodle: source.doodle,
                emojiAsset: source.emojiAsset
            )
            notes.append(copy)
            selectedStickerID = nil
            selectedNoteID = copy.id
            saveDocument()
            broadcastNoteUpsert(id: copy.id)
            Haptics.light()
        }
    }

    private func addText() {
        selectedStickerID = nil
        selectedNoteID = nil
        draftText = ""
        draftFont = .rounded
        draftColor = background.isLightSurface ? .ink : .white
        draftScale = 1.0
        draftTextStyle = .plain
        draftTextEffect = .float
        openEditor(.insert)
    }

    private func openEditor(_ panel: CanvasEditorPanel) {
        finishSelecting()
        if panel == .emoji {
            stickerSource = .doodles
            doodleColor = background.isLightSurface ? .ink : .white
        }
        transformEditorHasChanges = false
        withAnimation(.spring(response: 0.28, dampingFraction: 0.80)) {
            activeEditor = panel
            isEditing = true
            drawingEnabled = false
            if panel == .insert, let selectedNoteID, let note = notes.first(where: { $0.id == selectedNoteID }), note.isPlainText {
                draftText = note.text
                draftFont = note.font
                draftColor = note.color
                draftScale = note.scale
                draftTextStyle = note.textStyle
                draftTextEffect = note.textEffect
            }
            if panel != .insert {
                insertMode = nil
                textEditorFocused = false
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                    guard isEditing, activeEditor == .insert else { return }
                    textEditorFocused = true
                }
            }
        }
    }

    private func closeEditor() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            isEditing = false
            insertMode = nil
            textEditorFocused = false
        }
    }

    private func startDrawing() {
        finishSelecting()
        Haptics.light()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.80)) {
            isEditing = false
            toolsExpanded = false
            selectedStickerID = nil
            selectedNoteID = nil
            drawingEnabled = true
        }
    }

    private func finishEditing() {
        finishSelecting()
        closeEditor()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            drawingEnabled = false
            selectedStickerID = nil
            selectedNoteID = nil
        }
    }

    private func actionBarConfirm() {
        guard !vm.isActing, !isRemovingDish else { return }
        finishEditing()
        onConfirm()
    }

    private var hasCanvasAdditions: Bool {
        !notes.isEmpty || !strokes.isEmpty || !activeStroke.isEmpty
    }

    private var nextLayerIndex: Int {
        let highest = (stickers.map(\.layer) + notes.map(\.layer)).max() ?? -1
        return highest + 1
    }

    private func alignmentTargets(excluding selection: CanvasSelection) -> [CanvasPoint] {
        stickers.filter { .sticker($0.id) != selection }.map(\.position)
            + notes.filter { .note($0.id) != selection }.map(\.position)
    }

    private func insertionPosition(isEmoji: Bool) -> CanvasPoint {
        let width = max(canvasFrame.width, 1)
        let height = max(canvasFrame.height, 1)
        let preferred = CanvasPoint(x: isEmoji ? 0.78 : 0.5, y: isEmoji ? 0.68 : 0.16)
        let baseSize = max(110, min(width, height) * 0.37)
        let occupied = stickers.map {
            (point: $0.position, radius: baseSize * 0.56 * min(max($0.scale, 0.3), 3))
        } + notes.map {
            (point: $0.position, radius: ($0.isEmoji ? 42.0 : 80.0) * min(max($0.scale, 0.3), 3))
        }
        let columns: [CGFloat] = isEmoji ? [0.22, 0.5, 0.78] : [0.5]
        let candidates = [preferred] + [CGFloat(0.16), 0.32, 0.48, 0.64, 0.78].flatMap { y in
            columns.map { CanvasPoint(x: $0, y: y) }
        }
        func score(_ point: CanvasPoint) -> CGFloat {
            let clearance = occupied.map {
                hypot((point.x - $0.point.x) * width, (point.y - $0.point.y) * height) - $0.radius
            }.min() ?? 0
            let distance = hypot((point.x - preferred.x) * width, (point.y - preferred.y) * height)
            return clearance - distance * 0.15
        }
        return candidates.max { score($0) < score($1) } ?? preferred
    }

    private func clearCanvasAdditions() {
        guard !notes.isEmpty || !strokes.isEmpty else { return }
        recordUndoSnapshot()
        notes.removeAll()
        strokes.removeAll()
        strokeRedoStack.removeAll()
        activeStroke.removeAll()
        selectedNoteID = nil
        saveDocument()
        broadcastOp("clear_additions", payload: CanvasOpPayload())
    }

    private func undoStroke() {
        guard let last = strokes.popLast() else { return }
        strokeRedoStack.append(last)
        saveDocument()
        broadcastOp("delete_stroke", payload: .deleteStroke(id: last.id))
        Haptics.light()
    }

    private func redoStroke() {
        guard let restored = strokeRedoStack.popLast() else { return }
        strokes.append(restored)
        saveDocument()
        broadcastOp("add_stroke", payload: .addStroke(restored))
        Haptics.light()
    }

    private func clearStrokes() {
        guard !strokes.isEmpty else { return }
        recordUndoSnapshot()
        strokes.removeAll()
        strokeRedoStack.removeAll()
        activeStroke.removeAll()
        saveDocument()
        broadcastOp("clear_strokes", payload: CanvasOpPayload())
        Haptics.light()
    }

    private func applyNextSmartLayout() {
        guard !stickers.isEmpty else { return }
        recordUndoSnapshot()
        let preset = CanvasLayoutPreset.allCases[layoutPresetIndex % CanvasLayoutPreset.allCases.count]
        layoutPresetIndex += 1
        let orderedIndices = stickers.indices.sorted { lhs, rhs in
            let lIsDish = stickers[lhs].mealDishID != nil
            let rIsDish = stickers[rhs].mealDishID != nil
            if lIsDish != rIsDish { return lIsDish }
            return stickers[lhs].layer < stickers[rhs].layer
        }
        let placements = preset.placements(count: orderedIndices.count)
        withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.78)) {
            for (rank, index) in orderedIndices.enumerated() where rank < placements.count {
                let placement = placements[rank]
                stickers[index].position = placement.position
                stickers[index].scale = placement.scale
                stickers[index].rotationDegrees = placement.rotation
            }
        }
        saveDocument()
        broadcastBatchStickersNotes(includeStickers: true, includeNotes: false)
        Haptics.light()
        showCanvasTip("已切换排版：\(preset.title)")
    }

    private var confirmIcon: String {
        switch vm.meal?.status {
        case .confirmed: return "fork.knife"
        case .completed, .cancelled: return "arrow.clockwise"
        default: return "checkmark"
        }
    }

    private var confirmTitle: String {
        switch vm.meal?.status {
        case .confirmed: return "记录吃完"
        case .completed, .cancelled: return "重新开始"
        default: return vm.dishCount == 0 ? "先加菜" : "定下这一顿"
        }
    }

    private var confirmPillTitle: String {
        switch vm.meal?.status {
        case .confirmed: return "吃完了"
        case .completed, .cancelled: return "新一顿"
        default: return "定下"
        }
    }

    private var retryStrip: some View {
        Button {
            Task { await onRetry() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "wifi.exclamationmark")
                Text("画布还没连上，点这里重试")
                Spacer()
                Image(systemName: "arrow.clockwise")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(CanvasPalette.ink)
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(CanvasPalette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func insertText(_ text: String) {
        recordUndoSnapshot()
        let note = CanvasNote(
            text: text,
            isEmoji: false,
            position: insertionPosition(isEmoji: false),
            scale: draftScale,
            layer: nextLayerIndex,
            textEffect: draftTextEffect,
            font: draftFont,
            color: draftColor,
            textStyle: draftTextStyle
        )
        notes.append(note)
        selectedStickerID = nil
        selectedNoteID = note.id
        saveDocument()
        broadcastNoteUpsert(id: note.id)
    }

    private func setSelectedNoteScale(_ scale: CGFloat) {
        guard let selectedNoteID, let index = notes.firstIndex(where: { $0.id == selectedNoteID }), notes[index].isPlainText else { return }
        guard notes[index].scale != scale else { return }
        rememberTransform(for: .note(selectedNoteID))
        withAnimation(.spring(response: 0.30, dampingFraction: 0.76)) {
            notes[index].scale = scale
        }
        saveDocument()
        broadcastNoteUpsert(id: selectedNoteID)
    }

    private func setSelectedNoteFont(_ font: CanvasTextFont) {
        guard let selectedNoteID, let index = notes.firstIndex(where: { $0.id == selectedNoteID }), notes[index].isPlainText else { return }
        guard notes[index].font != font else { return }
        recordUndoSnapshot()
        notes[index].font = font
        saveDocument()
        broadcastNoteUpsert(id: selectedNoteID)
    }

    private func setSelectedNoteColor(_ color: CanvasTextColor) {
        guard let selectedNoteID, let index = notes.firstIndex(where: { $0.id == selectedNoteID }), notes[index].isPlainText else { return }
        guard notes[index].color != color else { return }
        recordUndoSnapshot()
        notes[index].color = color
        saveDocument()
        broadcastNoteUpsert(id: selectedNoteID)
    }

    private func setSelectedNoteStyle(_ style: CanvasTextStyle) {
        guard let selectedNoteID, let index = notes.firstIndex(where: { $0.id == selectedNoteID }), notes[index].isPlainText else { return }
        guard notes[index].textStyle != style else { return }
        recordUndoSnapshot()
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
            notes[index].textStyle = style
        }
        saveDocument()
        broadcastNoteUpsert(id: selectedNoteID)
    }

    private func setSelectedNoteEffect(_ effect: CanvasTextEffect) {
        guard let selectedNoteID, let index = notes.firstIndex(where: { $0.id == selectedNoteID }), notes[index].isPlainText else { return }
        guard notes[index].textEffect != effect else { return }
        recordUndoSnapshot()
        withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.76)) {
            notes[index].textEffect = effect
        }
        saveDocument()
        broadcastNoteUpsert(id: selectedNoteID)
    }

    private func commitDraftText() {
        let value = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        if let selectedNoteID, let index = notes.firstIndex(where: { $0.id == selectedNoteID }), notes[index].isPlainText {
            recordUndoSnapshot()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.76)) {
                notes[index].text = value
                notes[index].font = draftFont
                notes[index].color = draftColor
                notes[index].textStyle = draftTextStyle
                notes[index].textEffect = draftTextEffect
            }
            saveDocument()
            broadcastNoteUpsert(id: selectedNoteID)
        } else {
            insertText(value)
        }
        insertMode = nil
        closeEditor()
    }

    private func clearEmojiStickers() {
        guard notes.contains(where: { $0.isEmoji }) else { return }
        recordUndoSnapshot()
        notes.removeAll { $0.isEmoji }
        if let selectedNoteID, !notes.contains(where: { $0.id == selectedNoteID }) {
            self.selectedNoteID = nil
        }
        saveDocument()
        broadcastBatchStickersNotes(includeStickers: false, includeNotes: true)
    }

    private func clearDoodleStickers() {
        guard notes.contains(where: { $0.isDoodle }) else { return }
        recordUndoSnapshot()
        notes.removeAll { $0.isDoodle }
        if let selectedNoteID, !notes.contains(where: { $0.id == selectedNoteID }) {
            self.selectedNoteID = nil
        }
        saveDocument()
        broadcastBatchStickersNotes(includeStickers: false, includeNotes: true)
    }

    private func insertDoodle(_ kind: CanvasDoodleKind) {
        recordUndoSnapshot()
        let note = CanvasNote(
            text: kind.title,
            isEmoji: false,
            position: insertionPosition(isEmoji: true),
            scale: 1.0,
            rotationDegrees: kind == .washiTape ? -12 : 0,
            layer: nextLayerIndex,
            textEffect: .float,
            font: .rounded,
            color: doodleColor,
            textStyle: .plain,
            doodle: kind
        )
        notes.append(note)
        selectedStickerID = nil
        selectedNoteID = note.id
        saveDocument()
        broadcastNoteUpsert(id: note.id)
    }

    private func insertEmoji(_ item: CanvasCustomEmoji) {
        recordUndoSnapshot()
        let note = CanvasNote(
            text: item.title,
            isEmoji: true,
            position: insertionPosition(isEmoji: true),
            layer: nextLayerIndex,
            emojiAsset: item.assetName
        )
        notes.append(note)
        selectedStickerID = nil
        selectedNoteID = note.id
        saveDocument()
        broadcastNoteUpsert(id: note.id)
    }

    private func insertPhotoSticker(_ path: String, name: String = "拍照贴图") {
        recordUndoSnapshot()
        let isPNG = path.lowercased().hasSuffix(".png")
        let sticker = CanvasSticker(
            name: name, image: path, isCutout: isPNG,
            position: insertionPosition(isEmoji: true), layer: nextLayerIndex
        )
        stickers.append(sticker)
        finishSelecting()
        selectedStickerID = sticker.id
        selectedNoteID = nil
        saveDocument()
        broadcastStickerUpsert(id: sticker.id)
        Haptics.light()
    }

    @MainActor
    private func createStickerFromAlbumPhoto(_ item: PhotosPickerItem) async {
        guard !isCreatingAlbumSticker else { return }
        isCreatingAlbumSticker = true
        defer {
            isCreatingAlbumSticker = false
            stickerPhotoItem = nil
        }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            showCanvasTip("无法读取选中的照片")
            return
        }
        do {
            let uploaded: UploadedImage
            let usedCutout: Bool
            if let png = try? await ImageCutoutService.shared.makePNG(from: image) {
                uploaded = try await UploadService.shared.uploadImage(png, filename: "sticker.png", mime: "image/png")
                usedCutout = true
            } else if let previewData = image.canvasPreviewData {
                uploaded = try await UploadService.shared.uploadImage(previewData, filename: "sticker.jpg", mime: "image/jpeg")
                usedCutout = false
            } else {
                showCanvasTip("图片格式暂不支持，请换一张重试")
                return
            }
            let saved = try await StickerFavoriteService.shared.save(image: uploaded.path)
            rememberStickerFavorite(saved)
            insertPhotoSticker(saved.image, name: usedCutout ? "相册贴图" : "照片贴图")
            showCanvasTip(usedCutout ? "抠图完成，已贴上画布并收藏" : "已按照片做成贴纸并收藏")
        } catch {
            showCanvasTip(error.localizedDescription)
        }
    }

    @MainActor
    private func loadStickerFavorites() async {
        guard !isLoadingStickerFavorites else { return }
        isLoadingStickerFavorites = true
        stickerFavoritesError = nil
        defer { isLoadingStickerFavorites = false }
        do {
            let items = try await StickerFavoriteService.shared.list()
            guard !Task.isCancelled else { return }
            stickerFavorites = items
        } catch {
            if !Task.isCancelled { stickerFavoritesError = error.localizedDescription }
        }
    }

    private func rememberStickerFavorite(_ favorite: StickerFavorite) {
        stickerFavorites.removeAll { $0.id == favorite.id }
        stickerFavorites.insert(favorite, at: 0)
        stickerFavoritesError = nil
    }

    @MainActor
    private func saveCanvasStickerFavorite(_ image: String) async {
        do {
            let saved = try await StickerFavoriteService.shared.save(image: image)
            rememberStickerFavorite(saved)
            showCanvasTip("贴图已存到收藏")
        } catch {
            if isLaunchStudio {
                showCanvasTip(error.localizedDescription)
            } else {
                vm.errorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    private func deleteStickerFavorite(_ favorite: StickerFavorite) async {
        guard deletingStickerFavorites.insert(favorite.id).inserted else { return }
        defer { deletingStickerFavorites.remove(favorite.id) }
        do {
            try await StickerFavoriteService.shared.delete(id: favorite.id)
            stickerFavorites.removeAll { $0.id == favorite.id }
        } catch { stickerFavoritesError = error.localizedDescription }
    }

    private func nextDishPosition(index: Int, occupiedStickers: [CanvasSticker]) -> CanvasPoint {
        let width = max(canvasFrame.width, 320)
        let height = max(canvasFrame.height, 480)
        let baseSize = max(110, min(width, height) * 0.37)
        let candidates: [CanvasPoint] = [
            CanvasPoint(x: 0.30, y: 0.32),
            CanvasPoint(x: 0.74, y: 0.42),
            CanvasPoint(x: 0.26, y: 0.59),
            CanvasPoint(x: 0.74, y: 0.63),
            CanvasPoint(x: 0.50, y: 0.47),
            CanvasPoint(x: 0.28, y: 0.28),
            CanvasPoint(x: 0.74, y: 0.29),
            CanvasPoint(x: 0.50, y: 0.65)
        ]
        let preferred = candidates[index % candidates.count]
        let occupied = occupiedStickers.map {
            (point: $0.position, radius: baseSize * 0.52 * min(max($0.scale, 0.3), 3))
        } + notes.map {
            (point: $0.position, radius: ($0.isEmoji ? 32.0 : 76.0) * min(max($0.scale, 0.3), 3))
        }
        guard !occupied.isEmpty else { return preferred }
        func score(_ point: CanvasPoint) -> CGFloat {
            let clearance = occupied.map {
                hypot((point.x - $0.point.x) * width, (point.y - $0.point.y) * height) - $0.radius
            }.min() ?? 0
            let distance = hypot((point.x - preferred.x) * width, (point.y - preferred.y) * height)
            return clearance - distance * 0.12
        }
        return candidates.max { score($0) < score($1) } ?? preferred
    }

    private func syncStickers(broadcast: Bool = false, preserveUnknownRemoteDishes: Bool = false) {
        let customStickers = stickers.filter { $0.mealDishID == nil }
        let existing = Dictionary(uniqueKeysWithValues: stickers.compactMap { sticker in
            sticker.mealDishID.map { ($0, sticker) }
        })
        let currentDishIDs = Set(vm.dishes.map(\.id))
        let removedDishStickers = stickers.filter { sticker in
            guard let dishID = sticker.mealDishID else { return false }
            return !currentDishIDs.contains(dishID)
        }
        var newLayer = nextLayerIndex
        var occupiedStickers = customStickers + existing.values
        var resultStickers = customStickers
        if preserveUnknownRemoteDishes {
            resultStickers.append(contentsOf: removedDishStickers)
        }
        var newlyCreated: [(sticker: CanvasSticker, addedBy: UInt?)] = []
        for (index, dish) in vm.dishes.enumerated() {
            let cutout = dish.recipeCutoutImage.flatMap { $0.isEmpty ? nil : $0 }
            if var old = existing[dish.id] {
                old.image = cutout ?? dish.recipeImage
                old.isCutout = cutout != nil
                if old.assetName == nil {
                    old.assetName = stickerAsset(for: dish.recipeName, index: index)
                }
                resultStickers.append(old)
            } else {
                let layer = newLayer
                newLayer += 1
                let heroScales: [CGFloat] = [1.18, 0.90, 0.92, 1.02, 0.96, 0.94]
                let heroAngles: [Double] = [-4.5, 5.0, -3.5, 4.0, -2.5, 3.0]
                let created = CanvasSticker(
                    mealDishID: dish.id,
                    name: dish.recipeName,
                    image: cutout ?? dish.recipeImage,
                    isCutout: cutout != nil,
                    assetName: stickerAsset(for: dish.recipeName, index: index),
                    position: nextDishPosition(index: index, occupiedStickers: occupiedStickers),
                    scale: heroScales[index % heroScales.count],
                    rotationDegrees: heroAngles[index % heroAngles.count],
                    effect: .float,
                    style: .dieCut,
                    shapeIndex: index % 5,
                    layer: layer
                )
                occupiedStickers.append(created)
                resultStickers.append(created)
                newlyCreated.append((sticker: created, addedBy: dish.addedBy))
            }
        }
        stickers = resultStickers
        if let selectedStickerID, !stickers.contains(where: { $0.id == selectedStickerID }) {
            self.selectedStickerID = nil
        }
        saveDocument()

        if preserveUnknownRemoteDishes && !removedDishStickers.isEmpty {
            onRemoteMealSync?()
        }

        if broadcast && !isLaunchStudio && !isApplyingRemoteUpdate && hasReceivedWelcome {
            let myUserID = appState.currentUser?.id
            for item in newlyCreated where item.addedBy == nil || myUserID == nil || item.addedBy == myUserID {
                broadcastOp("upsert_sticker", payload: .upsertSticker(item.sticker))
            }
            for removed in removedDishStickers {
                broadcastOp("delete_sticker", payload: .deleteSticker(id: removed.id, mealDishID: removed.mealDishID))
            }
        }
    }

    private func stickerAsset(for name: String, index: Int) -> String? {
        _ = index
        return DishArtwork.assetName(for: name)
    }

    private func applyEffect(_ effect: CanvasEffect) {
        guard let selectedStickerID,
              let index = stickers.firstIndex(where: { $0.id == selectedStickerID }),
              stickers[index].effect != effect else { return }
        recordUndoSnapshot()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
            stickers[index].effect = effect
        }
        saveDocument()
        broadcastStickerUpsert(id: selectedStickerID)
    }

    private func applyStickerStyle(_ style: CanvasStickerStyle) {
        guard let selectedStickerID,
              let index = stickers.firstIndex(where: { $0.id == selectedStickerID }),
              stickers[index].style != style else { return }
        recordUndoSnapshot()
        withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) {
            stickers[index].style = style
        }
        saveDocument()
        broadcastStickerUpsert(id: selectedStickerID)
    }

    private func applyTextEffect(_ effect: CanvasTextEffect) {
        guard let selectedNoteID,
              let index = notes.firstIndex(where: { $0.id == selectedNoteID }),
              notes[index].textEffect != effect else { return }
        recordUndoSnapshot()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
            notes[index].textEffect = effect
        }
        saveDocument()
        broadcastNoteUpsert(id: selectedNoteID)
    }

    private func activateAllLiveMotion() {
        recordUndoSnapshot()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
            liveMotionEnabled = true
            for index in stickers.indices where !stickers[index].effect.isAnimated {
                stickers[index].effect = .float
            }
            for index in notes.indices where notes[index].textEffect == .plain {
                notes[index].textEffect = .float
            }
        }
        saveDocument()
        broadcastBatchStickersNotes()
        showCanvasTip("画布已进入实况微动模式")
    }

    private func makeStarterDateNote(layer: Int) -> CanvasNote {
        CanvasNote(
            text: Self.starterDateText(for: Date()),
            isEmoji: false,
            position: CanvasPoint(x: 0.75, y: 0.24),
            scale: 1.04,
            rotationDegrees: -4,
            layer: layer,
            textEffect: .float,
            font: .handwritten,
            color: .white
        )
    }

    private func restoreDocumentIfNeeded() {
        guard let mealID = vm.meal?.id, restoredMealID != mealID else {
            if vm.meal != nil { syncStickers() }
            return
        }
        restoredMealID = mealID
        if let document = CanvasDocumentStore.load(mealID: mealID) {
            let isUntouchedLegacyDraft = document.schemaVersion < 2
                && document.background == CanvasBackground.linen.rawValue
                && document.notes.isEmpty
                && document.strokes.isEmpty
                && document.customBackgroundData == nil
            if isUntouchedLegacyDraft {
                background = .meadow
                blur = 0.0
                moodFilter = .none
                customBackgroundData = nil
                customBackgroundURL = nil
                stickers = []
                notes = [makeStarterDateNote(layer: 0)]
                strokes = []
                activeStroke = []
                brushColor = .white
                customBrushColor = CanvasBrushColor.white.color
                usesCustomBrushColor = false
                selectedStickerID = nil
                selectedNoteID = nil
            } else {
                background = CanvasBackground(rawValue: document.background) ?? .meadow
                blur = document.blur
                moodFilter = document.moodFilter
                customBackgroundData = document.customBackgroundData
                customBackgroundURL = document.customBackgroundURL
                stickers = document.stickers
                notes = document.notes
                strokes = document.strokes
                activeStroke = []
                let todayText = Self.starterDateText(for: Date())
                if notes.count == 1,
                   notes[0].font == .handwritten,
                   let createdAt = vm.meal?.createdAt,
                   notes[0].text == Self.starterDateText(for: createdAt),
                   notes[0].text != todayText {
                    notes[0].text = todayText
                }
                if !usesCustomBrushColor && strokes.isEmpty {
                    brushColor = background.defaultBrushColor
                    customBrushColor = brushColor.color
                }
                migrateLegacyLayerOrderIfNeeded()
                repairOverlappingNoteLayout(mealID: mealID)
            }
        } else {
            background = .meadow
            blur = 0.0
            moodFilter = .none
            customBackgroundData = nil
            customBackgroundURL = nil
            stickers = []
            notes = [makeStarterDateNote(layer: 0)]
            strokes = []
            activeStroke = []
            brushColor = .white
            customBrushColor = CanvasBrushColor.white.color
            usesCustomBrushColor = false
            selectedStickerID = nil
            selectedNoteID = nil
        }
        reportLightSurface(background.isLightSurface)
        syncStickers()
    }

    /// Older canvas drafts placed the first emoji directly under the first
    /// caption. Their hit rectangles overlap, which makes the emoji feel
    /// impossible to select. Repair that legacy demo layout once, while
    /// leaving any later intentional user placement untouched.
    private func repairOverlappingNoteLayout(mealID: UInt) {
        let key = "meal.canvas.layout.repaired.v1.\(mealID)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        var changed = false
        for emojiIndex in notes.indices where notes[emojiIndex].isEmoji {
            let emoji = notes[emojiIndex].position
            let overlapsCaption = notes.contains { note in
                guard !note.isEmoji else { return false }
                let dx = emoji.x - note.position.x
                let dy = emoji.y - note.position.y
                return (dx * dx + dy * dy).squareRoot() < 0.14
            }
            guard overlapsCaption else { continue }
            notes[emojiIndex].position = CanvasPoint(x: 0.78, y: 0.73)
            changed = true
        }

        UserDefaults.standard.set(true, forKey: key)
        if changed { saveDocument() }
    }

    private func migrateLegacyLayerOrderIfNeeded() {
        let layers = stickers.map(\.layer) + notes.map(\.layer)
        guard layers.count > 1, Set(layers).count == 1 else { return }
        var nextLayer = 0
        for index in stickers.indices {
            stickers[index].layer = nextLayer
            nextLayer += 1
        }
        for index in notes.indices {
            notes[index].layer = nextLayer
            nextLayer += 1
        }
    }

    private func showCanvasTip(_ message: String) {
        if isLaunchStudio {
            withAnimation(.easeOut(duration: 0.2)) {
                studioTipMessage = message
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.2))
                if studioTipMessage == message {
                    withAnimation(.easeOut(duration: 0.2)) {
                        studioTipMessage = nil
                    }
                }
            }
        } else {
            vm.tipMessage = message
        }
    }

    private func restoreLaunchStudioIfNeeded() {
        guard isLaunchStudio, !hasLoadedStudio else { return }
        hasLoadedStudio = true
        launchConfig = LaunchCurtainStore.load()
        applyLaunchCanvasPayload(LaunchCanvasStore.loadOrDefaultPayload(), recordUndo: false)
        toolsExpanded = true
        undoStack.removeAll()
        redoStack.removeAll()
    }

    private func applyLaunchCanvasPayload(_ payload: LaunchCanvasDocumentPayload, recordUndo: Bool) {
        if recordUndo {
            recordUndoSnapshot()
        }
        let doc = payload.document
        background = CanvasBackground(rawValue: doc.background) ?? .morningTable
        blur = doc.blur
        moodFilter = doc.moodFilter
        customBackgroundData = doc.customBackgroundData
        stickers = doc.stickers
        notes = doc.notes
        strokes = doc.strokes
        activeStroke.removeAll()
        selectedStickerID = nil
        selectedNoteID = nil
        finishSelecting()
        if !usesCustomBrushColor && strokes.isEmpty {
            brushColor = background.defaultBrushColor
            customBrushColor = brushColor.color
        }
        onLaunchLightSurfaceChange?(background.isLightSurface)
    }

    private func applyLaunchTemplate(_ template: LaunchCanvasTemplate) {
        let payload = LaunchCanvasStore.makeTemplatePayload(template)
        applyLaunchCanvasPayload(payload, recordUndo: true)
        Haptics.light()
        showCanvasTip("已套用「\(template.title)」模板")
    }

    private func resetLaunchStudioToDefault() {
        let payload = LaunchCanvasStore.makeTemplatePayload(.morningTable)
        applyLaunchCanvasPayload(payload, recordUndo: true)
        launchConfig.motion = .fadeZoom
        launchConfig.holdSpeed = .standard
        Haptics.light()
        showCanvasTip("已恢复默认开屏画布")
    }

    private func clearLaunchCanvasAdditions() {
        guard !stickers.isEmpty || !notes.isEmpty || !strokes.isEmpty else { return }
        recordUndoSnapshot()
        stickers.removeAll()
        notes.removeAll()
        strokes.removeAll()
        strokeRedoStack.removeAll()
        activeStroke.removeAll()
        selectedStickerID = nil
        selectedNoteID = nil
        finishSelecting()
        Haptics.light()
    }

    private func saveLaunchStudioAndDismiss() {
        finishEditing()
        LaunchCanvasStore.save(LaunchCanvasDocumentPayload(document: currentDocumentSnapshot()))
        LaunchCurtainStore.save(launchConfig)
        Haptics.success()
        onCloseLaunchStudio?()
    }

    private func saveDocument() {
        guard !isLaunchStudio else { return }
        guard let mealID = vm.meal?.id else { return }
        CanvasDocumentStore.save(currentDocumentSnapshot(), mealID: mealID)
    }

    private func currentDocumentSnapshot() -> CanvasDocument {
        CanvasDocument(
            schemaVersion: 3,
            background: background.rawValue,
            blur: blur,
            moodFilter: moodFilter,
            customBackgroundData: customBackgroundData,
            customBackgroundURL: customBackgroundURL,
            stickers: stickers,
            notes: notes,
            strokes: strokes,
            size: canvasFrame.size.width > 0 ? canvasFrame.size : nil
        )
    }

    // MARK: - 实时多人协同同步

    private func reportLightSurface(_ isLight: Bool) {
        if isLaunchStudio {
            onLaunchLightSurfaceChange?(isLight)
        } else if isGuestMode {
            onGuestLightSurfaceChange?(isLight)
        } else {
            appState.canvasIsLightSurface = isLight
        }
    }

    private func applyRemoteState(_ body: () -> Void) {
        isApplyingRemoteUpdate = true
        defer { isApplyingRemoteUpdate = false }
        body()
    }

    private func applyRemoteDocument(_ doc: CanvasDocument) {
        applyRemoteState {
            let urlChanged = doc.customBackgroundURL != customBackgroundURL
            background = CanvasBackground(rawValue: doc.background) ?? .meadow
            blur = doc.blur
            moodFilter = doc.moodFilter
            customBackgroundURL = doc.customBackgroundURL
            if urlChanged && doc.customBackgroundURL != nil {
                customBackgroundData = nil
            } else if background != .custom {
                customBackgroundData = nil
            }
            stickers = doc.stickers
            notes = doc.notes
            strokes = doc.strokes
            reportLightSurface(background.isLightSurface)
            selectedStickerID = selectedStickerID.flatMap { id in stickers.contains(where: { $0.id == id }) ? id : nil }
            selectedNoteID = selectedNoteID.flatMap { id in notes.contains(where: { $0.id == id }) ? id : nil }
            selectedElements.formIntersection(Set(layerEntries.map(\.selection)))
        }
    }

    private func applyCanvasOpLocally(kind: String, payload: CanvasOpPayload) {
        switch kind {
        case "upsert_sticker":
            guard let incoming = payload.sticker else { return }
            if let idx = stickers.firstIndex(where: {
                $0.id == incoming.id
                    || (incoming.mealDishID != nil && $0.mealDishID == incoming.mealDishID)
            }) {
                let oldID = stickers[idx].id
                stickers[idx] = incoming
                if selectedStickerID == oldID {
                    selectedStickerID = incoming.id
                }
            } else {
                stickers.append(incoming)
            }
        case "delete_sticker":
            let targetID = payload.uuidValue
            let targetDishID = payload.mealDishId
            stickers.removeAll { sticker in
                let matchID = targetID != nil && sticker.id == targetID
                let matchDish = targetDishID != nil && sticker.mealDishID == targetDishID
                return matchID || matchDish
            }
            if let selectedStickerID, !stickers.contains(where: { $0.id == selectedStickerID }) {
                self.selectedStickerID = nil
            }
        case "upsert_note":
            guard let incoming = payload.note else { return }
            if let idx = notes.firstIndex(where: { $0.id == incoming.id }) {
                notes[idx] = incoming
            } else {
                notes.append(incoming)
            }
        case "delete_note":
            if let targetID = payload.uuidValue {
                notes.removeAll { $0.id == targetID }
                if selectedNoteID == targetID {
                    selectedNoteID = nil
                }
            }
        case "add_stroke":
            guard let incoming = payload.stroke else { return }
            if let idx = strokes.firstIndex(where: { $0.id == incoming.id }) {
                strokes[idx] = incoming
            } else {
                strokes.append(incoming)
            }
        case "delete_stroke":
            if let targetID = payload.uuidValue {
                strokes.removeAll { $0.id == targetID }
            } else if !strokes.isEmpty {
                strokes.removeLast()
            }
        case "clear_strokes":
            strokes.removeAll()
            strokeRedoStack.removeAll()
        case "clear_additions":
            notes.removeAll()
            strokes.removeAll()
            strokeRedoStack.removeAll()
            selectedNoteID = nil
        case "update_background":
            if let bgRaw = payload.background, let bg = CanvasBackground(rawValue: bgRaw) {
                background = bg
                reportLightSurface(bg.isLightSurface)
            }
            if let newBlur = payload.blur {
                blur = newBlur
            }
            if let filterRaw = payload.moodFilter, let filter = CanvasMoodFilter(rawValue: filterRaw) {
                moodFilter = filter
            }
            if payload.clearCustomBackgroundURL == true {
                customBackgroundURL = nil
                customBackgroundData = nil
            } else if let url = payload.customBackgroundURL {
                if url != customBackgroundURL {
                    customBackgroundData = nil
                }
                customBackgroundURL = url.isEmpty ? nil : url
            }
        case "batch_stickers_notes":
            if let incomingStickers = payload.stickers {
                stickers = incomingStickers
            }
            if let incomingNotes = payload.notes {
                notes = incomingNotes
            }
            if let selectedStickerID, !stickers.contains(where: { $0.id == selectedStickerID }) {
                self.selectedStickerID = nil
            }
            if let selectedNoteID, !notes.contains(where: { $0.id == selectedNoteID }) {
                self.selectedNoteID = nil
            }
        case "replace_document":
            if let doc = payload.document {
                let urlChanged = doc.customBackgroundURL != customBackgroundURL
                background = CanvasBackground(rawValue: doc.background) ?? .meadow
                blur = doc.blur
                moodFilter = doc.moodFilter
                customBackgroundURL = doc.customBackgroundURL
                if urlChanged && doc.customBackgroundURL != nil {
                    customBackgroundData = nil
                } else if background != .custom {
                    customBackgroundData = nil
                }
                stickers = doc.stickers
                notes = doc.notes
                strokes = doc.strokes
                reportLightSurface(background.isLightSurface)
                selectedStickerID = selectedStickerID.flatMap { id in stickers.contains(where: { $0.id == id }) ? id : nil }
                selectedNoteID = selectedNoteID.flatMap { id in notes.contains(where: { $0.id == id }) ? id : nil }
            }
        default:
            break
        }
        selectedElements.formIntersection(Set(layerEntries.map(\.selection)))
    }

    private func setupRealtimeHandlers() {
        realtime.onWelcome = { msg in
            guard msg.mealId == vm.meal?.id else { return }
            hasReceivedWelcome = true
            if msg.revision > 0, let remoteDoc = msg.document {
                applyRemoteDocument(remoteDoc)
                syncStickers(broadcast: false, preserveUnknownRemoteDishes: true)
                let queued = realtime.drainPendingOps()
                if !queued.isEmpty {
                    applyRemoteState {
                        for item in queued {
                            applyCanvasOpLocally(kind: item.kind, payload: item.payload)
                        }
                    }
                    for item in queued {
                        realtime.sendOp(kind: item.kind, payload: item.payload)
                    }
                }
                saveDocument()
            } else {
                _ = realtime.drainPendingOps()
                realtime.sendOp(
                    kind: "replace_document",
                    payload: .replaceDocument(currentDocumentSnapshot(), onlyIfEmpty: true)
                )
            }
        }

        realtime.onSnapshot = { msg in
            guard msg.mealId == vm.meal?.id, msg.clientId != realtime.clientID else { return }
            if let remoteDoc = msg.document {
                applyRemoteDocument(remoteDoc)
                syncStickers(broadcast: false, preserveUnknownRemoteDishes: true)
                saveDocument()
            }
        }

        realtime.onOpApplied = { msg in
            guard msg.mealId == vm.meal?.id, msg.clientId != realtime.clientID else { return }
            realtime.remotePreviews.removeValue(forKey: msg.clientId)
            applyRemoteState {
                applyCanvasOpLocally(kind: msg.kind, payload: msg.payload)
            }
            saveDocument()
        }

        realtime.onMealSync = { msg in
            guard msg.mealId == vm.meal?.id else { return }
            onRemoteMealSync?()
        }

        realtime.onError = { message in
            showCanvasTip(message)
        }
    }

    private func remotePreview(for kind: String, id: UUID) -> CanvasRemoteLivePreview? {
        realtime.remotePreviews.values
            .filter { $0.targetKind == kind && $0.targetId.caseInsensitiveCompare(id.uuidString) == .orderedSame }
            .max(by: { $0.receivedAt < $1.receivedAt })
    }

    private var remoteActiveStrokes: [CanvasStroke] {
        realtime.remotePreviews.values
            .filter { $0.targetKind == "stroke" }
            .compactMap(\.activeStroke)
    }

    private func broadcastOp(_ kind: String, payload: CanvasOpPayload) {
        guard !isLaunchStudio, !isApplyingRemoteUpdate, vm.meal != nil else { return }
        if !hasReceivedWelcome && kind == "replace_document" && payload.onlyIfEmpty == true {
            return
        }
        realtime.sendOp(kind: kind, payload: payload)
    }

    private func broadcastStickerUpsert(id: UUID) {
        guard let sticker = stickers.first(where: { $0.id == id }) else { return }
        broadcastOp("upsert_sticker", payload: .upsertSticker(sticker))
    }

    private func broadcastNoteUpsert(id: UUID) {
        guard let note = notes.first(where: { $0.id == id }) else { return }
        broadcastOp("upsert_note", payload: .upsertNote(note))
    }

    private func broadcastBatchStickersNotes(includeStickers: Bool = true, includeNotes: Bool = true) {
        broadcastOp(
            "batch_stickers_notes",
            payload: .batch(
                stickers: includeStickers ? stickers : nil,
                notes: includeNotes ? notes : nil
            )
        )
    }

    private func broadcastBackgroundUpdate() {
        broadcastOp(
            "update_background",
            payload: .updateBackground(
                background: background.rawValue,
                blur: blur,
                moodFilter: moodFilter.rawValue,
                customBackgroundURL: customBackgroundURL,
                clearCustomBackgroundURL: background != .custom && customBackgroundURL == nil
            )
        )
    }

    /// 将当前画布合成为真正的 Apple Live Photo（静态封面 + 3 秒配对实况视频）写入系统相册。
    private func saveCanvasAsLivePhoto() {
        guard !isExporting, liveExportProgress == nil, canvasFrame.width > 0 else { return }
        let snapshot = currentDocumentSnapshot()
        let fallbackSize = canvasFrame.size
        Task { @MainActor in
            liveExportProgress = 0.02
            defer { liveExportProgress = nil }
            do {
                try await LiveCanvasExporterHelper.export(
                    document: snapshot,
                    fallbackSize: fallbackSize
                ) { progress in
                    liveExportProgress = progress
                }
                Haptics.light()
                showCanvasTip("实况照片已保存到相册")
            } catch {
                showCanvasTip(error.localizedDescription)
            }
        }
    }

    /// 导出画布静态图片，隐藏编辑控件，并以相册实际写入结果反馈。
    private func saveCanvasToPhotos() {
        guard !isExporting, canvasFrame.width > 0 else { return }
        Task { @MainActor in
            let authorization = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard authorization == .authorized || authorization == .limited else {
                showCanvasTip("请在设置中允许添加照片后再保存")
                return
            }
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
                  let window = scene.windows.first(where: { $0.isKeyWindow }) else { return }
            isExporting = true
            defer { isExporting = false }
            try? await Task.sleep(for: .milliseconds(120))
            let frame = canvasFrame
            let renderer = UIGraphicsImageRenderer(size: frame.size)
            let image = renderer.image { _ in
                window.drawHierarchy(in: window.bounds.offsetBy(dx: -frame.minX, dy: -frame.minY), afterScreenUpdates: true)
            }
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
                showCanvasTip("画布已保存到相册")
            } catch {
                showCanvasTip("保存失败，请重试")
            }
        }
    }
}

/// 以保存时的尺寸还原画布；在详情页可开启动态 Live 播放与实况照片重导出。
struct MealCanvasSnapshotView: View {
    private let mealID: UInt
    private let allowLivePlayback: Bool
    private let fillsContainer: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var document: CanvasDocument?
    @State private var isPlayingLive = true
    @State private var exportProgress: Double?
    @State private var feedbackMessage: String?

    init(mealID: UInt, allowLivePlayback: Bool = false, fillsContainer: Bool = false) {
        self.mealID = mealID
        self.allowLivePlayback = allowLivePlayback
        self.fillsContainer = fillsContainer
        _document = State(initialValue: CanvasDocumentStore.load(mealID: mealID))
    }

    var body: some View {
        Group {
            if let document {
                snapshotContent(document: document)
            }
        }
        .task(id: mealID) {
            let synced = await syncRemoteMealCanvasIfNeeded(mealID: mealID, forceRefresh: allowLivePlayback)
            if synced || document == nil {
                document = CanvasDocumentStore.load(mealID: mealID)
            }
        }
    }

    @ViewBuilder
    private func snapshotContent(document: CanvasDocument) -> some View {
            let size = document.size ?? CGSize(width: 390, height: 680)
            let isLight = (CanvasBackground(rawValue: document.background) ?? .meadow).isLightSurface
            let content = ZStack {
                if allowLivePlayback && isPlayingLive && !reduceMotion && scenePhase == .active {
                    TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
                        scaledArtwork(
                            document: document,
                            size: size,
                            time: context.date.timeIntervalSinceReferenceDate,
                            isLiveActive: true
                        )
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                } else {
                    scaledArtwork(
                        document: document,
                        size: size,
                        time: 0.5,
                        isLiveActive: false
                    )
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }

                if allowLivePlayback {
                    let fgColor: Color = isLight ? CanvasPalette.obsidianInk : .white
                    let bgTint: Color = isLight ? Color.white.opacity(0.76) : Color.black.opacity(0.38)
                    let strokeTint: Color = isLight ? Color.black.opacity(0.10) : Color.white.opacity(0.36)
                    VStack {
                        HStack {
                            Button {
                                Haptics.light()
                                isPlayingLive.toggle()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: isPlayingLive ? "livephoto" : "livephoto.slash")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text("LIVE")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                                .foregroundStyle(fgColor)
                                .padding(.horizontal, 10)
                                .frame(height: 28)
                                .background {
                                    ZStack {
                                        Capsule().fill(.ultraThinMaterial)
                                        Capsule().fill(bgTint)
                                    }
                                }
                                .overlay { Capsule().strokeBorder(strokeTint, lineWidth: 0.7) }
                                .shadow(color: Color.black.opacity(isLight ? 0.08 : 0.24), radius: 6, y: 2)
                            }
                            .buttonStyle(SoftPressStyle())

                            Spacer()

                            Button {
                                exportHistoryLivePhoto(document: document, size: size)
                            } label: {
                                HStack(spacing: 4) {
                                    if let exportProgress {
                                        ProgressView(value: exportProgress)
                                            .progressViewStyle(.circular)
                                            .tint(fgColor)
                                            .controlSize(.mini)
                                        Text("\(Int((exportProgress * 100).rounded()))%")
                                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                                            .monospacedDigit()
                                            .lineLimit(1)
                                            .fixedSize(horizontal: true, vertical: false)
                                    } else {
                                        Image(systemName: "square.and.arrow.down")
                                            .font(.system(size: 11, weight: .semibold))
                                        Text("存实况")
                                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                                            .lineLimit(1)
                                            .fixedSize(horizontal: true, vertical: false)
                                    }
                                }
                                .foregroundStyle(fgColor)
                                .padding(.horizontal, 11)
                                .frame(height: 28)
                                .background {
                                    ZStack {
                                        Capsule().fill(.ultraThinMaterial)
                                        Capsule().fill(bgTint)
                                    }
                                }
                                .overlay { Capsule().strokeBorder(strokeTint, lineWidth: 0.7) }
                                .shadow(color: Color.black.opacity(isLight ? 0.08 : 0.24), radius: 6, y: 2)
                            }
                            .buttonStyle(SoftPressStyle())
                            .disabled(exportProgress != nil)
                        }
                        .padding(12)

                        Spacer()

                        if let feedbackMessage {
                            Text(feedbackMessage)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.68), in: Capsule())
                                .padding(.bottom, 12)
                                .transition(.opacity)
                        }
                    }
                } else {
                    VStack {
                        HStack {
                            HStack(spacing: 3) {
                                Image(systemName: "livephoto")
                                    .font(.system(size: 9, weight: .bold))
                                Text("LIVE")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3.5)
                            .background(Color.black.opacity(0.46), in: Capsule())
                            .overlay {
                                Capsule().strokeBorder(Color.white.opacity(0.32), lineWidth: 0.6)
                            }
                            .padding(8)
                            Spacer()
                        }
                        Spacer()
                    }
                    .allowsHitTesting(false)
                }
            }

            Group {
                if fillsContainer {
                    content.clipped()
                } else {
                    content
                        .aspectRatio(size.width / size.height, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
            }
            .allowsHitTesting(allowLivePlayback)
            .accessibilityElement(children: allowLivePlayback ? .contain : .ignore)
            .accessibilityLabel("这一顿保存的实况画布")
    }

    private func scaledArtwork(document: CanvasDocument, size: CGSize, time: TimeInterval, isLiveActive: Bool) -> some View {
        GeometryReader { proxy in
            if fillsContainer {
                let scale = max(proxy.size.width / max(size.width, 1), proxy.size.height / max(size.height, 1))
                CanvasDocumentArtwork(document: document, size: size, time: time, isLiveActive: isLiveActive)
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(scale)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            } else {
                CanvasDocumentArtwork(document: document, size: size, time: time, isLiveActive: isLiveActive)
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(proxy.size.width / max(size.width, 1), anchor: .topLeading)
            }
        }
    }

    private func exportHistoryLivePhoto(document: CanvasDocument, size: CGSize) {
        guard exportProgress == nil else { return }
        Task { @MainActor in
            exportProgress = 0.02
            defer { exportProgress = nil }
            do {
                try await LiveCanvasExporterHelper.export(document: document, fallbackSize: size) { progress in
                    exportProgress = progress
                }
                Haptics.light()
                withAnimation(.easeOut(duration: 0.2)) { feedbackMessage = "实况照片已保存到相册" }
            } catch {
                withAnimation(.easeOut(duration: 0.2)) { feedbackMessage = error.localizedDescription }
            }
            try? await Task.sleep(for: .seconds(2.2))
            withAnimation(.easeOut(duration: 0.2)) { feedbackMessage = nil }
        }
    }
}

private struct CanvasDocumentArtwork: View {
    let document: CanvasDocument
    let size: CGSize
    var time: TimeInterval = 0.5
    var isLiveActive: Bool = false

    var body: some View {
        let bgSource = CanvasBackground(rawValue: document.background) ?? .meadow
        ZStack {
            CanvasMediaBackground(
                source: bgSource,
                blur: document.blur,
                customData: document.customBackgroundData,
                customURL: document.customBackgroundURL
            )
            .frame(width: size.width, height: size.height)
            .zIndex(-1_000_000)

            CanvasMoodFilterOverlay(filter: document.moodFilter)
                .frame(width: size.width, height: size.height)
                .zIndex(-900_000)

            if isLiveActive {
                LiveAmbientSparklesView(
                    time: time,
                    isLightSurface: bgSource.isLightSurface,
                    isActive: true
                )
                .frame(width: size.width, height: size.height)
                .zIndex(-500_000)
            }

            ForEach(document.stickers) { sticker in
                CanvasStickerView(
                    sticker: .constant(sticker), canvasSize: size, isSelected: false,
                    reduceMotion: !isLiveActive, isLightSurface: bgSource.isLightSurface,
                    onSelect: {}, onTransform: {}, onLayerMove: { _ in },
                    onDelete: {}, onChange: {}
                )
                .zIndex(Double(sticker.layer))
            }
            ForEach(document.notes) { note in
                CanvasNoteView(
                    note: .constant(note), canvasSize: size, isSelected: false, freezesMotion: !isLiveActive,
                    isLightSurface: bgSource.isLightSurface,
                    onSelect: {}, onEdit: {}, onTransform: {}, onLayerMove: { _ in }, onDelete: {}, onChange: {}
                )
                .zIndex(Double(note.layer))
            }
            CanvasStrokeDrawingLayer(
                strokes: document.strokes,
                activeStroke: [],
                paintColor: .white,
                style: .solid,
                width: 4
            )
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
}

@MainActor
private enum LiveCanvasExporterHelper {
    private struct PreparedRenderAssets {
        let canvasSize: CGSize
        let bgImage: UIImage?
        let orderedStickers: [CanvasSticker]
        let orderedNotes: [CanvasNote]
        let stickerMedia: [UUID: (image: UIImage, isCutout: Bool)]
    }

    private static func prepareAssets(
        document: CanvasDocument,
        fallbackSize: CGSize
    ) async -> PreparedRenderAssets {
        let rawSize = document.size ?? fallbackSize
        let width = max(rawSize.width, 320)
        let height = max(rawSize.height, 480)
        let canvasSize = CGSize(width: width, height: height)

        let bgSource = CanvasBackground(rawValue: document.background) ?? .meadow
        var bgImage: UIImage?
        if bgSource == .custom, let customData = document.customBackgroundData {
            bgImage = UIImage(data: customData)
        } else if bgSource == .custom, let customURL = APIConfig.imageURL(document.customBackgroundURL) {
            if let cachedBG = RemoteImageCache.shared.cachedImage(for: customURL) {
                bgImage = cachedBG
            } else {
                bgImage = await RemoteImageCache.shared.load(url: customURL)
            }
        } else if bgSource == .morningTable {
            bgImage = UIImage(named: "ProfileHeroCover")
        } else if bgSource == .meadow {
            bgImage = UIImage(named: "CanvasMeadow")
        } else if bgSource == .gingham {
            bgImage = UIImage(named: "CanvasWarmCafe")
        } else if bgSource == .linen {
            bgImage = UIImage(named: "CanvasGallerySun")
        } else if let remoteURL = bgSource.url {
            if let cachedBG = RemoteImageCache.shared.cachedImage(for: remoteURL) {
                bgImage = cachedBG
            } else {
                bgImage = await RemoteImageCache.shared.load(url: remoteURL)
            }
        }

        var stickerMedia: [UUID: (image: UIImage, isCutout: Bool)] = [:]
        for sticker in document.stickers {
            if let url = APIConfig.imageURL(sticker.image) {
                let raw: UIImage?
                if let cachedRaw = RemoteImageCache.shared.cachedImage(for: url) {
                    raw = cachedRaw
                } else {
                    raw = await RemoteImageCache.shared.load(url: url)
                }
                let subject: UIImage?
                if sticker.isCutout {
                    subject = raw
                } else if let cachedCut = DishCutoutCache.shared.cachedCutout(for: url) {
                    subject = cachedCut
                } else if let raw {
                    subject = await DishCutoutCache.shared.cutout(for: url, sourceImage: raw)
                } else {
                    subject = nil
                }

                if let subject {
                    if sticker.style == .dieCut {
                        let rendered = await StickerBorderRenderer.shared.makeDieCutSticker(
                            from: subject,
                            cacheKey: url.absoluteString
                        )
                        stickerMedia[sticker.id] = (rendered, true)
                    } else {
                        stickerMedia[sticker.id] = (subject, true)
                    }
                } else if let raw {
                    stickerMedia[sticker.id] = (raw, false)
                }
            } else if let assetName = sticker.assetName, let assetImg = UIImage(named: assetName) {
                stickerMedia[sticker.id] = (assetImg, true)
            }
        }

        return PreparedRenderAssets(
            canvasSize: canvasSize,
            bgImage: bgImage,
            orderedStickers: document.stickers.sorted { $0.layer < $1.layer },
            orderedNotes: document.notes.sorted { $0.layer < $1.layer },
            stickerMedia: stickerMedia
        )
    }

    static func renderStillImage(
        document: CanvasDocument,
        fallbackSize: CGSize = CGSize(width: 390, height: 680),
        renderScale: CGFloat = 2.0
    ) async -> UIImage? {
        let prepared = await prepareAssets(document: document, fallbackSize: fallbackSize)
        let view = LiveCanvasExportFrame(
            document: document,
            size: prepared.canvasSize,
            time: 0.5,
            bgImage: prepared.bgImage,
            orderedStickers: prepared.orderedStickers,
            orderedNotes: prepared.orderedNotes,
            stickerMedia: prepared.stickerMedia
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = renderScale
        renderer.proposedSize = ProposedViewSize(prepared.canvasSize)
        return renderer.uiImage
    }

    static func export(
        document: CanvasDocument,
        fallbackSize: CGSize,
        onProgress: @escaping @MainActor (Double) -> Void
    ) async throws {
        let prepared = await prepareAssets(document: document, fallbackSize: fallbackSize)
        let renderScale: CGFloat = 2.0
        let pixelSize = CGSize(
            width: prepared.canvasSize.width * renderScale,
            height: prepared.canvasSize.height * renderScale
        )

        try await LivePhotoExporter.exportAndSave(
            pixelSize: pixelSize,
            frameCount: 72,
            fps: 24,
            keyframeIndex: 12,
            onProgress: onProgress
        ) { frameIndex in
            let frameTime = Double(frameIndex) / 24.0
            let view = LiveCanvasExportFrame(
                document: document,
                size: prepared.canvasSize,
                time: frameTime,
                bgImage: prepared.bgImage,
                orderedStickers: prepared.orderedStickers,
                orderedNotes: prepared.orderedNotes,
                stickerMedia: prepared.stickerMedia
            )
            let renderer = ImageRenderer(content: view)
            renderer.scale = renderScale
            renderer.proposedSize = ProposedViewSize(prepared.canvasSize)
            return renderer.cgImage
        }
    }
}

private struct LiveCanvasExportFrame: View {
    let document: CanvasDocument
    let size: CGSize
    let time: TimeInterval
    let bgImage: UIImage?
    let orderedStickers: [CanvasSticker]
    let orderedNotes: [CanvasNote]
    let stickerMedia: [UUID: (image: UIImage, isCutout: Bool)]

    private var baseSize: CGFloat {
        max(110, min(size.width, size.height) * 0.37)
    }

    var body: some View {
        let bgSource = CanvasBackground(rawValue: document.background) ?? .meadow
        let isLight = bgSource.isLightSurface
        ZStack {
            CanvasMediaBackground(
                source: bgSource,
                blur: document.blur,
                customData: document.customBackgroundData,
                customURL: document.customBackgroundURL,
                preloadedImage: bgImage
            )
            .frame(width: size.width, height: size.height)

            CanvasMoodFilterOverlay(filter: document.moodFilter)
                .frame(width: size.width, height: size.height)

            LiveAmbientSparklesView(time: time, isLightSurface: isLight, isActive: true)
                .frame(width: size.width, height: size.height)

            ForEach(orderedStickers) { sticker in
                stickerNode(sticker, isLight: isLight)
                    .zIndex(Double(sticker.layer))
            }

            ForEach(orderedNotes) { note in
                noteNode(note, isLight: isLight)
                    .zIndex(Double(note.layer))
            }

            CanvasStrokeDrawingLayer(
                strokes: document.strokes,
                activeStroke: [],
                paintColor: .white,
                style: .solid,
                width: 4
            )
            .frame(width: size.width, height: size.height)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    @ViewBuilder
    private func stickerNode(_ sticker: CanvasSticker, isLight: Bool) -> some View {
        let boxSide = baseSize * (sticker.isCutout ? 1.24 : 1.12)
        let phase = sticker.id.motionPhaseOffset
        let media = stickerMedia[sticker.id]

        Group {
            if sticker.style == .polaroid {
                PolaroidStickerCard(
                    image: media?.image,
                    isCutout: media?.isCutout ?? sticker.isCutout,
                    name: sticker.name,
                    compact: false,
                    isLightSurface: isLight
                )
            } else if let media {
                if media.isCutout {
                    Image(uiImage: media.image)
                        .resizable()
                        .scaledToFit()
                        .padding(4)
                        .shadow(color: Color.black.opacity(isLight ? 0.16 : 0.32), radius: 14, y: 8)
                        .shadow(color: Color.black.opacity(isLight ? 0.08 : 0.16), radius: 3, y: 2)
                } else {
                    GeometryReader { proxy in
                        Image(uiImage: media.image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(
                                        sticker.style == .dieCut ? Color.white : (isLight ? Color.black.opacity(0.06) : Color.white.opacity(0.18)),
                                        lineWidth: sticker.style == .dieCut ? 3.5 : 0.7
                                    )
                            }
                            .shadow(color: Color.black.opacity(isLight ? 0.14 : 0.34), radius: 12, y: 7)
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isLight ? Color(red: 0.96, green: 0.96, blue: 0.97) : Color(red: 0.16, green: 0.16, blue: 0.18))
                    .overlay {
                        Text(sticker.name)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(isLight ? CanvasPalette.ink : .white)
                            .multilineTextAlignment(.center)
                            .padding(12)
                    }
            }
        }
        .frame(width: boxSide, height: boxSide)
        .overlay {
            if sticker.effect == .outline {
                StickerBlobShape(index: sticker.shapeIndex)
                    .stroke(
                        isLight ? CanvasPalette.accent.opacity(0.85) : .white.opacity(0.94),
                        style: StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [5, 4])
                    )
            }
        }
        .shadow(
            color: Color.white.opacity(sticker.effect.glowOpacity(time: time, phase: phase, reduceMotion: false)),
            radius: sticker.effect.glowRadius
        )
        .scaleEffect(sticker.effect.scale(time: time, phase: phase, reduceMotion: false))
        .rotationEffect(.degrees(sticker.effect.rotation(time: time, phase: phase, reduceMotion: false)))
        .offset(sticker.effect.offset(time: time, phase: phase, reduceMotion: false))
        .scaleEffect(min(max(sticker.scale, 0.3), 3))
        .rotationEffect(.degrees(sticker.rotationDegrees))
        .position(x: size.width * sticker.position.x, y: size.height * sticker.position.y)
    }

    @ViewBuilder
    private func noteNode(_ note: CanvasNote, isLight: Bool) -> some View {
        let count = note.text.count
        let fontSize: CGFloat = count > 18 ? 16 : count > 11 ? 18 : 21
        let phase = note.id.motionPhaseOffset
        let visible = note.textEffect.visibleText(note.text, time: time, reduceMotion: false)

        Group {
            if let doodle = note.doodle {
                CanvasDoodleView(
                    kind: doodle,
                    tint: note.color.color,
                    isLightSurface: isLight,
                    compact: false
                )
            } else if note.isEmoji {
                if let asset = note.emojiAsset {
                    Image(asset)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 78, height: 78)
                        .shadow(color: Color.black.opacity(isLight ? 0.14 : 0.30), radius: 9, y: 4)
                        .shadow(color: Color.black.opacity(isLight ? 0.06 : 0.16), radius: 2, y: 1)
                } else {
                    Text(visible)
                        .font(.system(size: 38))
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .foregroundStyle(.white)
                        .shadow(color: Color.black.opacity(isLight ? 0.18 : 0.30), radius: 8, y: 3)
                }
            } else {
                CanvasStyledTextContent(
                    text: note.text,
                    visibleText: visible,
                    font: note.font,
                    fontSize: fontSize,
                    color: note.color,
                    textStyle: note.textStyle,
                    isLightSurface: isLight
                )
            }
        }
        .opacity(note.textEffect.opacity(time: time, reduceMotion: false))
        .offset(note.textEffect.offset(time: time, phase: phase, reduceMotion: false))
        .scaleEffect(x: note.textEffect.scaleX(time: time, reduceMotion: false), y: note.textEffect.scaleY(time: time, reduceMotion: false))
        .rotationEffect(.degrees(note.textEffect.rotation(time: time, reduceMotion: false)))
        .scaleEffect(min(max(note.scale, 0.3), 3))
        .rotationEffect(.degrees(note.rotationDegrees))
        .position(x: size.width * note.position.x, y: size.height * note.position.y)
    }
}

private struct LiveAmbientSparklesView: View {
    let time: TimeInterval
    let isLightSurface: Bool
    let isActive: Bool

    var body: some View {
        Canvas { context, size in
            guard isActive else { return }
            let tint = isLightSurface ? Color.black.opacity(0.16) : Color.white.opacity(0.90)
            let sparkles: [(x: CGFloat, y: CGFloat, radius: CGFloat, speed: Double, phase: Double)] = [
                (0.11, 0.24, 9.0, 1.9, 0.2),
                (0.88, 0.31, 10.5, 1.6, 1.4),
                (0.51, 0.29, 6.5, 2.3, 0.9),
                (0.13, 0.70, 7.5, 2.2, 2.5),
                (0.86, 0.71, 9.0, 1.8, 3.7)
            ]

            for item in sparkles {
                let pulse = 0.42 + 0.58 * (sin(time * item.speed + item.phase) + 1) * 0.5
                let r = item.radius * (0.70 + 0.34 * pulse)
                let cx = size.width * item.x
                let cy = size.height * item.y
                var star = Path()
                star.move(to: CGPoint(x: cx, y: cy - r))
                star.addQuadCurve(to: CGPoint(x: cx + r, y: cy), control: CGPoint(x: cx + r * 0.16, y: cy - r * 0.16))
                star.addQuadCurve(to: CGPoint(x: cx, y: cy + r), control: CGPoint(x: cx + r * 0.16, y: cy + r * 0.16))
                star.addQuadCurve(to: CGPoint(x: cx - r, y: cy), control: CGPoint(x: cx - r * 0.16, y: cy + r * 0.16))
                star.addQuadCurve(to: CGPoint(x: cx, y: cy - r), control: CGPoint(x: cx - r * 0.16, y: cy - r * 0.16))
                star.closeSubpath()
                context.fill(star, with: .color(tint.opacity(pulse)))
            }

            let dots: [(x: CGFloat, y: CGFloat, radius: CGFloat, speed: Double, phase: Double)] = [
                (0.18, 0.38, 2.2, 1.4, 0.7),
                (0.82, 0.50, 2.5, 1.7, 2.1),
                (0.49, 0.69, 2.1, 1.5, 3.2)
            ]
            for dot in dots {
                let glow = 0.28 + 0.55 * (sin(time * dot.speed + dot.phase) + 1) * 0.5
                let rect = CGRect(
                    x: size.width * dot.x - dot.radius,
                    y: size.height * dot.y - dot.radius,
                    width: dot.radius * 2,
                    height: dot.radius * 2
                )
                context.fill(Path(ellipseIn: rect), with: .color(tint.opacity(glow)))
            }
        }
        .allowsHitTesting(false)
    }
}

private enum CanvasPalette {
    static let page = CanvasTheme.page
    static let surface = CanvasTheme.surface
    static let ink = CanvasTheme.ink
    static let obsidianInk = Color(red: 0.067, green: 0.067, blue: 0.075)
    static let muted = CanvasTheme.secondary
    static let accent = CanvasTheme.accent
    static let line = CanvasTheme.line
    static let live = Color.dopamineYellow
    static let coral = Color.dopaminePink
}

struct CanvasPoint: Codable, Hashable {
    var x: CGFloat
    var y: CGFloat
}

private struct CanvasElementInteractionKey: PreferenceKey {
    static var defaultValue: Bool { false }
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

private struct CanvasAlignmentGuides: Equatable {
    var vertical: CGFloat?
    var horizontal: CGFloat?
}

private struct CanvasAlignmentGuidesKey: PreferenceKey {
    static var defaultValue: CanvasAlignmentGuides { .init() }
    static func reduce(value: inout CanvasAlignmentGuides, nextValue: () -> CanvasAlignmentGuides) {
        let next = nextValue()
        value.vertical = next.vertical ?? value.vertical
        value.horizontal = next.horizontal ?? value.horizontal
    }
}

private struct CanvasDragPlacement {
    let position: CanvasPoint
    let guides: CanvasAlignmentGuides

    init(position: CanvasPoint, translation: CGSize, canvasSize: CGSize, isDragging: Bool,
         alignmentTargets: [CanvasPoint],
         previousGuides: CanvasAlignmentGuides = .init()) {
        let width = max(canvasSize.width, 1)
        let height = max(canvasSize.height, 1)
        let x = position.x + translation.width / width
        let y = position.y + translation.height / height
        func target(_ value: CGFloat, length: CGFloat, previous: CGFloat?, candidates: [CGFloat]) -> CGFloat? {
            guard isDragging else { return nil }
            if let previous, abs(value - previous) * length <= 10 { return previous }
            guard let nearest = ([CGFloat(0.5)] + candidates).min(by: { abs(value - $0) < abs(value - $1) }),
                  abs(value - nearest) * length <= 6 else { return nil }
            return nearest
        }
        guides = CanvasAlignmentGuides(
            vertical: target(x, length: width, previous: previousGuides.vertical, candidates: alignmentTargets.map(\.x)),
            horizontal: target(y, length: height, previous: previousGuides.horizontal, candidates: alignmentTargets.map(\.y)))
        self.position = CanvasPoint(x: guides.vertical ?? min(max(x, 0.02), 0.98),
                                    y: guides.horizontal ?? min(max(y, 0.02), 0.98))
    }
}

private struct CanvasRotationPlacement {
    let degrees: Double
    let snappedAngle: Double?

    init(degrees: Double, previousSnap: Double?) {
        let nearest = (degrees / 90).rounded() * 90
        let delta = degrees - nearest
        let distance = abs(delta)
        snappedAngle = distance <= (previousSnap == nearest ? 6 : 3) ? nearest : nil
        let progress = min(max((distance - 3) / 3, 0), 1)
        let blend = progress * progress * (3 - 2 * progress)
        self.degrees = nearest + delta * blend
    }
}

private struct CanvasManipulation: ViewModifier {
    @Binding var position: CanvasPoint
    @Binding var scale: CGFloat
    @Binding var rotationDegrees: Double
    @Binding var isGestureActive: Bool
    let canvasSize: CGSize
    let alignmentTargets: [CanvasPoint]
    let isSelected: Bool
    let isHandleActive: Bool
    let onTransformStart: () -> Void
    let onSelect: () -> Void
    var onLiveChange: (() -> Void)? = nil
    let onChange: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @GestureState(resetTransaction: Transaction(animation: nil)) private var isDragging = false
    @GestureState(resetTransaction: Transaction(animation: nil)) private var isTransforming = false
    @State private var dragStart: DragStart?
    @State private var transformStart: TransformStart?
    @State private var guides = CanvasAlignmentGuides()
    @State private var snappedAngle: Double?
    @State private var didChange = false

    private struct DragStart {
        var position: CanvasPoint
        var translation: CGSize
    }

    private struct TransformStart {
        var scale: CGFloat
        let rotationDegrees: Double
        var hasRotated = false
    }

    private var isManipulating: Bool { isDragging || isTransforming || isHandleActive }

    func body(content: Content) -> some View {
        content
            .transaction {
                if isManipulating {
                    $0.animation = nil
                    $0.disablesAnimations = true
                }
            }
            .highPriorityGesture(dragGesture, including: isHandleActive ? .none : .all)
            .simultaneousGesture(transformGesture, including: isHandleActive ? .none : .all)
            .preference(key: CanvasElementInteractionKey.self, value: isManipulating)
            .preference(key: CanvasAlignmentGuidesKey.self, value: guides)
            .onChange(of: isDragging || isTransforming) { _, active in isGestureActive = active }
            .onChange(of: isDragging) { _, active in
                if !active { dragStart = nil; guides = .init() }
            }
            .onChange(of: isTransforming) { _, active in
                if !active { transformStart = nil; snappedAngle = nil }
            }
            .onChange(of: isHandleActive) { _, active in
                if active { didChange = true }
            }
            .onChange(of: isManipulating) { previous, active in
                if previous && !active { finishManipulation() }
            }
            .onDisappear {
                isGestureActive = false
                if didChange { didChange = false; onChange() }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .named("mealCanvas"))
            .updating($isDragging) { _, active, transaction in
                active = true
                transaction.animation = nil
            }
            .onChanged { updateDrag($0) }
    }

    private func updateDrag(_ value: DragGesture.Value) {
        guard !isTransforming, !isHandleActive else { return }
        if !isSelected { onSelect() }
        if dragStart == nil {
            dragStart = DragStart(position: position, translation: value.translation)
        }
        guard let start = dragStart else { return }
        let delta = CGSize(width: value.translation.width - start.translation.width,
                           height: value.translation.height - start.translation.height)
        let placement = CanvasDragPlacement(position: start.position, translation: delta,
            canvasSize: canvasSize, isDragging: true, alignmentTargets: alignmentTargets, previousGuides: guides)
        if (placement.guides.vertical != nil && placement.guides.vertical != guides.vertical)
            || (placement.guides.horizontal != nil && placement.guides.horizontal != guides.horizontal) {
            Haptics.light()
        }
        guides = placement.guides
        if position != placement.position {
            if !didChange { onTransformStart() }
            didChange = true
            withTransaction(Transaction(animation: nil)) { position = placement.position }
            onLiveChange?()
        }
        let requestedX = start.position.x + delta.width / max(canvasSize.width, 1)
        let requestedY = start.position.y + delta.height / max(canvasSize.height, 1)
        if requestedX < 0.02 || requestedX > 0.98 {
            dragStart?.position.x = placement.position.x
            dragStart?.translation.width = value.translation.width
        }
        if requestedY < 0.02 || requestedY > 0.98 {
            dragStart?.position.y = placement.position.y
            dragStart?.translation.height = value.translation.height
        }
    }

    private var transformGesture: some Gesture {
        MagnifyGesture().simultaneously(with: RotateGesture())
            .updating($isTransforming) { _, active, transaction in
                active = true
                transaction.animation = nil
            }
            .onChanged { updateTransform($0) }
    }

    private func updateTransform(_ value: SimultaneousGesture<MagnifyGesture, RotateGesture>.Value) {
        guard !isHandleActive else { return }
        if !isSelected { onSelect() }
        if transformStart == nil {
            transformStart = TransformStart(scale: scale, rotationDegrees: rotationDegrees)
            let nearest = (rotationDegrees / 90).rounded() * 90
            snappedAngle = abs(rotationDegrees - nearest) <= 3 ? nearest : nil
            dragStart = nil
            guides = .init()
        }
        guard let start = transformStart else { return }
        let nextScale = value.first.map { min(max(start.scale * $0.magnification, 0.3), 3) } ?? scale
        if let zoom = value.first, zoom.magnification > 0,
           start.scale * zoom.magnification != nextScale {
            // 到达大小边界后重新定标，反向捏合立即生效。
            transformStart?.scale = nextScale / zoom.magnification
        }
        var nextRotation = rotationDegrees
        if let rotation = value.second?.rotation.degrees, rotation != 0 || start.hasRotated {
            transformStart?.hasRotated = true
            let placement = CanvasRotationPlacement(degrees: start.rotationDegrees + rotation, previousSnap: snappedAngle)
            if let target = placement.snappedAngle, target != snappedAngle { Haptics.light() }
            snappedAngle = placement.snappedAngle
            nextRotation = placement.degrees
        }
        if nextScale != scale || nextRotation != rotationDegrees {
            if !didChange { onTransformStart() }
            didChange = true
            withTransaction(Transaction(animation: nil)) {
                scale = nextScale
                rotationDegrees = nextRotation
            }
            onLiveChange?()
        }
    }

    // 大小、角度和位置已在操作中更新，结束时只保存，不再次叠加手势增量。
    private func finishManipulation() {
        guard didChange else { return }
        didChange = false
        onChange()
        if scenePhase == .active { Haptics.light() }
    }
}

private enum CanvasTransformHandle: CaseIterable, Hashable {
    case rotate, resize

    var icon: ProductIcon.Kind { self == .rotate ? .rotate : .resize }
    var title: String { self == .rotate ? "旋转" : "缩放" }
}

private struct CanvasTransformOverlay {
    let selection: CanvasSelection
    let controls: CanvasTransformControls
    let size: CGSize
    var center: CGPoint { controls.center }
}

private struct CanvasTransformOverlayKey: PreferenceKey {
    static var defaultValue: CanvasTransformOverlay? { nil }
    static func reduce(value: inout CanvasTransformOverlay?, nextValue: () -> CanvasTransformOverlay?) {
        if let next = nextValue() { value = next }
    }
}

private struct CanvasTransformControls: View {
    let size: CGSize
    let canvasSize: CGSize
    @Binding var rotationDegrees: Double
    @Binding var position: CanvasPoint
    @Binding var scale: CGFloat
    @Binding var isHandleActive: Bool
    var isLightSurface: Bool = false
    var isRectangular: Bool = false
    var contentRatio: CGFloat = 1.0
    let onTransformStart: () -> Void
    var onLiveChange: (() -> Void)? = nil
    let onChange: () -> Void

    @GestureState(resetTransaction: Transaction(animation: nil)) private var activeHandle: CanvasTransformHandle? = nil
    @State private var start: HandleStart?

    private struct HandleStart {
        let center: CGPoint
        let grabOffset: CGSize
        var scale: CGFloat
        var distance: CGFloat
        var angle: Double
        var rotationDegrees: Double
        var snappedAngle: Double?
        var hasMoved = false
        var hasChanged = false
    }

    var selectionSize: CGSize {
        if isRectangular {
            return CGSize(width: (size.width * contentRatio + 10) * displayScale,
                          height: (size.height * contentRatio + 10) * displayScale)
        }
        return CGSize(width: (size.width + 8) * displayScale,
                      height: (size.height + 8) * displayScale)
    }

    var center: CGPoint {
        CGPoint(x: position.x * canvasSize.width, y: position.y * canvasSize.height)
    }

    private var displayScale: CGFloat { min(max(scale, 0.3), 3) }
    private var handleScale: CGFloat { min(max(displayScale, 0.65), 1.2) }

    var body: some View {
        ZStack {
            Group {
                if isRectangular {
                    RoundedRectangle(cornerRadius: 18 * min(max(displayScale, 0.7), 1.3), style: .continuous)
                        .stroke(isLightSurface ? CanvasPalette.accent.opacity(0.88) : Color.white.opacity(0.88),
                                lineWidth: isLightSurface ? 1.5 : 1.1)
                } else {
                    Ellipse()
                        .stroke(isLightSurface ? CanvasPalette.accent.opacity(0.8) : .white.opacity(0.75),
                                lineWidth: isLightSurface ? 1.1 : 0.75)
                }
            }
            .frame(width: selectionSize.width, height: selectionSize.height)
            .rotationEffect(.degrees(rotationDegrees))
            .shadow(color: isLightSurface ? Color.clear : Color.black.opacity(0.3), radius: 1)
            .position(x: size.width / 2, y: size.height / 2)
            .allowsHitTesting(false)
            ForEach(CanvasTransformHandle.allCases, id: \.self) { handle in
                ProductIcon(kind: handle.icon)
                    .foregroundStyle(isLightSurface ? CanvasPalette.accent : .white)
                    .scaleEffect(0.625 * handleScale)
                    .rotationEffect(.degrees(handle == .resize ? rotationDegrees : 0))
                    .frame(width: 26 * handleScale, height: 26 * handleScale)
                    .background {
                        if isLightSurface {
                            Circle().fill(.white.opacity(0.96))
                        } else {
                            Circle().fill(.black.opacity(0.28))
                        }
                    }
                    .overlay(Circle().stroke(isLightSurface ? CanvasPalette.accent.opacity(0.85) : .white.opacity(0.9), lineWidth: 0.9))
                    .shadow(color: CanvasPalette.ink.opacity(isLightSurface ? 0.14 : 0.30), radius: 2, y: 1)
                    .opacity(activeHandle == nil || activeHandle == handle ? 1 : 0.5)
                    .frame(width: 44, height: 44)
                    .contentShape(handleHitArea(handle))
                    .highPriorityGesture(handleGesture(handle))
                    .allowsHitTesting(activeHandle == nil || activeHandle == handle)
                    .position(handlePosition(handle))
                    .accessibilityElement()
                    .accessibilityLabel(handle.title)
                    .accessibilityValue(handle == .resize
                        ? "\(Int((scale * 100).rounded()))%"
                        : "\(Int(rotationDegrees.rounded()))度")
                    .accessibilityAdjustableAction { direction in
                        let increment: Double
                        switch direction {
                        case .increment: increment = 1
                        case .decrement: increment = -1
                        @unknown default: return
                        }
                        if handle == .resize {
                            let nextScale = min(max(scale + increment * 0.1, 0.3), 3)
                            guard nextScale != scale else { return }
                            onTransformStart()
                            scale = nextScale
                        } else {
                            onTransformStart()
                            rotationDegrees += increment * 15
                        }
                        onChange()
                    }
            }
        }
        .onChange(of: activeHandle != nil) { _, active in
            isHandleActive = active
            if !active { start = nil }
        }
        .onDisappear { isHandleActive = false }
    }

    private func handlePosition(_ handle: CanvasTransformHandle) -> CGPoint {
        let direction: CGFloat = handle == .rotate ? -1 : 1
        let divisor: CGFloat = isRectangular ? 2 : (2 * sqrt(2))
        let x = selectionSize.width / divisor * direction
        let y = selectionSize.height / divisor * direction
        let angle = rotationDegrees * .pi / 180
        let point = CGPoint(x: center.x + x * cos(angle) - y * sin(angle),
                            y: center.y + x * sin(angle) + y * cos(angle))
        // 手柄靠近画布边缘时仍保留完整触摸范围，并避开顶部栏和底部工具与导航栏。
        let visibleX = min(max(point.x, 22), max(22, canvasSize.width - 22))
        let visibleY = min(max(point.y, 84), max(84, canvasSize.height - 138))
        return CGPoint(x: size.width / 2 + visibleX - center.x,
                       y: size.height / 2 + visibleY - center.y)
    }

    private func handleHitArea(_ handle: CanvasTransformHandle) -> Path {
        let point = handlePosition(handle)
        let other = handlePosition(handle == .rotate ? .resize : .rotate)
        let distance = hypot(other.x - point.x, other.y - point.y)
        guard distance < 44 else { return Path(ellipseIn: CGRect(x: 0, y: 0, width: 44, height: 44)) }
        // 用中垂线分开重叠的触摸范围，两个手柄中心都能准确命中。
        let angle = atan2(Double(other.y - point.y), Double(other.x - point.x))
        let spread = acos(Double(distance / 44))
        var path = Path()
        path.addArc(center: CGPoint(x: 22, y: 22), radius: 22,
                    startAngle: .radians(angle + spread), endAngle: .radians(angle + 2 * .pi - spread), clockwise: false)
        path.closeSubpath()
        return path
    }

    private func handleGesture(_ handle: CanvasTransformHandle) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("mealCanvas"))
            .updating($activeHandle) { _, active, transaction in
                if active == nil || active == handle { active = handle }
                transaction.animation = nil
            }
            .onChanged { value in
                guard activeHandle == nil || activeHandle == handle else { return }
                if start == nil {
                    let point = handlePosition(handle)
                    let vector = CGPoint(x: point.x - size.width / 2, y: point.y - size.height / 2)
                    let grabOffset = CGSize(width: value.startLocation.x - center.x - vector.x,
                                            height: value.startLocation.y - center.y - vector.y)
                    let nearest = (rotationDegrees / 90).rounded() * 90
                    start = HandleStart(center: center, grabOffset: grabOffset,
                        scale: scale, distance: max(hypot(vector.x, vector.y), 8),
                        angle: atan2(vector.y, vector.x), rotationDegrees: rotationDegrees,
                        snappedAngle: abs(rotationDegrees - nearest) <= 3 ? nearest : nil)
                    Haptics.light()
                }
                guard var start else { return }
                guard start.hasMoved || value.translation != .zero else { return }
                start.hasMoved = true
                let vector = CGPoint(x: value.location.x - start.grabOffset.width - start.center.x,
                                     y: value.location.y - start.grabOffset.height - start.center.y)
                withTransaction(Transaction(animation: nil)) {
                    if handle == .resize {
                        let distance = max(hypot(vector.x, vector.y), 8)
                        let requested = start.scale * distance / start.distance
                        let nextScale = min(max(requested, 0.3), 3)
                        if nextScale != scale, !start.hasChanged {
                            onTransformStart()
                            start.hasChanged = true
                        }
                        scale = nextScale
                        if requested != scale {
                            start.scale = scale
                            start.distance = distance
                        }
                    } else if hypot(vector.x, vector.y) >= 8 {
                        let angle = atan2(vector.y, vector.x)
                        let delta = atan2(sin(angle - start.angle), cos(angle - start.angle))
                        start.rotationDegrees += delta * 180 / .pi
                        start.angle = angle
                        let placement = CanvasRotationPlacement(degrees: start.rotationDegrees, previousSnap: start.snappedAngle)
                        if let target = placement.snappedAngle, target != start.snappedAngle { Haptics.light() }
                        start.snappedAngle = placement.snappedAngle
                        if placement.degrees != rotationDegrees, !start.hasChanged {
                            onTransformStart()
                            start.hasChanged = true
                        }
                        rotationDegrees = placement.degrees
                    }
                }
                self.start = start
                if start.hasChanged {
                    onLiveChange?()
                }
            }
    }
}

private enum CanvasSelection: Hashable {
    case sticker(UUID)
    case note(UUID)
}

private struct CanvasTransformUndo: Equatable {
    let selection: CanvasSelection
    let position: CanvasPoint
    let scale: CGFloat
    let rotationDegrees: Double
}

private struct CanvasHistorySnapshot: Equatable {
    let stickers: [CanvasSticker]
    let notes: [CanvasNote]
    let strokes: [CanvasStroke]
    let background: CanvasBackground
    let moodFilter: CanvasMoodFilter
    let blur: CGFloat
    let customBackgroundData: Data?
    let customBackgroundURL: String?
}

private struct CanvasElementBoundsKey: PreferenceKey {
    static var defaultValue: [CanvasSelection: CGRect] { [:] }
    static func reduce(value: inout [CanvasSelection: CGRect], nextValue: () -> [CanvasSelection: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

private struct CanvasElementBoundsReporter: ViewModifier {
    let selection: CanvasSelection
    let canvasSize: CGSize
    let position: CanvasPoint
    let scale: CGFloat
    let rotation: Double
    let isEnabled: Bool
    var contentRatio: CGFloat = 1

    func body(content: Content) -> some View {
        content.overlay {
            if isEnabled {
                GeometryReader { proxy in
                    let angle = rotation * .pi / 180
                    let width = proxy.size.width * min(max(scale, 0.3), 3) * contentRatio
                    let height = proxy.size.height * min(max(scale, 0.3), 3) * contentRatio
                    let rotatedWidth = abs(cos(angle)) * width + abs(sin(angle)) * height
                    let rotatedHeight = abs(sin(angle)) * width + abs(cos(angle)) * height
                    Color.clear
                        .allowsHitTesting(false)
                        .preference(key: CanvasElementBoundsKey.self, value: [selection: CGRect(
                            x: position.x * canvasSize.width - rotatedWidth / 2,
                            y: position.y * canvasSize.height - rotatedHeight / 2,
                            width: rotatedWidth, height: rotatedHeight)])
                }
            }
        }
    }
}

private struct CanvasMarqueeSelection: View {
    let canvasSize: CGSize
    let bounds: [CanvasSelection: CGRect]
    let layers: [CanvasSelection]
    @Binding var selection: Set<CanvasSelection>
    let transforms: [CanvasTransformUndo]
    var isLightSurface: Bool = false
    let onMoveStart: ([CanvasTransformUndo]) -> Void
    let onMove: ([CanvasTransformUndo], CGSize) -> Void
    let onChange: () -> Void

    @GestureState(resetTransaction: Transaction(animation: nil)) private var isDragging = false
    @State private var drag: SelectionDrag?

    private struct SelectionDrag {
        let origin: CGPoint
        var rectangle: CGRect?
        var movement: GroupMovement?
    }

    private struct GroupMovement {
        let transforms: [CanvasTransformUndo]
        var translation: CGSize = .zero
        var offset: CGSize = .zero
        var appliedOffset: CGSize = .zero
        var didChange = false
    }

    private var groupBounds: CGRect? {
        let rect = selection.compactMap { bounds[$0] }.reduce(CGRect.null) { $0.union($1) }
        guard !rect.isNull else { return nil }
        return rect.insetBy(dx: -8, dy: -8)
            .intersection(CGRect(origin: .zero, size: canvasSize).insetBy(dx: 4, dy: 4))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            ForEach(layers.filter { selection.contains($0) }, id: \.self) { item in
                if let rect = bounds[item] {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isLightSurface ? CanvasPalette.accent.opacity(0.8) : .white.opacity(0.65), lineWidth: 0.9)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                }
            }
            if let rect = drag?.rectangle ?? groupBounds {
                RoundedRectangle(cornerRadius: drag?.rectangle == nil ? 8 : 2)
                    .fill(isLightSurface ? CanvasPalette.accent.opacity(0.08) : .clear)
                    .overlay {
                        RoundedRectangle(cornerRadius: drag?.rectangle == nil ? 8 : 2)
                            .stroke(isLightSurface ? CanvasPalette.accent : .white, style: StrokeStyle(lineWidth: 1.1, dash: [5, 4]))
                    }
                    .shadow(color: isLightSurface ? Color.clear : Color.black.opacity(0.25), radius: 1)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .contentShape(Rectangle())
        .gesture(selectionGesture)
        .transaction { $0.animation = nil; $0.disablesAnimations = true }
        .preference(key: CanvasElementInteractionKey.self, value: isDragging)
        .onChange(of: isDragging) { _, active in
            guard !active, let drag else { return }
            if drag.movement?.didChange == true { onChange() }
            if drag.movement?.didChange == true || (drag.movement == nil && !selection.isEmpty) { Haptics.light() }
            self.drag = nil
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("框选画布内容")
        .accessibilityValue("已选 \(selection.count) 项")
        .accessibilityHint("拖出范围选中内容，拖动选区整体移动；点按内容可补选或取消")
    }

    private var selectionGesture: some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .named("mealCanvas"))
            .updating($isDragging) { _, active, _ in active = true }
            .onChanged { value in
                guard canvasSize.width > 0, canvasSize.height > 0 else { return }
                var drag = self.drag ?? SelectionDrag(origin: value.startLocation,
                    movement: groupBounds?.contains(value.startLocation) == true && !transforms.isEmpty
                        ? GroupMovement(transforms: transforms) : nil)
                if var movement = drag.movement {
                    let requested = CGSize(
                        width: movement.offset.width + (value.translation.width - movement.translation.width) / canvasSize.width,
                        height: movement.offset.height + (value.translation.height - movement.translation.height) / canvasSize.height)
                    let xs = movement.transforms.map(\.position.x)
                    let ys = movement.transforms.map(\.position.y)
                    let offset = CGSize(
                        width: min(max(requested.width, min(0, 0.02 - (xs.min() ?? 0))), max(0, 0.98 - (xs.max() ?? 1))),
                        height: min(max(requested.height, min(0, 0.02 - (ys.min() ?? 0))), max(0, 0.98 - (ys.max() ?? 1))))
                    if offset != movement.appliedOffset {
                        if !movement.didChange { onMoveStart(movement.transforms) }
                        onMove(movement.transforms, offset)
                        movement.appliedOffset = offset
                        movement.didChange = true
                    }
                    if requested.width != offset.width {
                        movement.offset.width = offset.width
                        movement.translation.width = value.translation.width
                    }
                    if requested.height != offset.height {
                        movement.offset.height = offset.height
                        movement.translation.height = value.translation.height
                    }
                    drag.movement = movement
                } else {
                    let end = CGPoint(x: min(max(value.location.x, 0), canvasSize.width),
                        y: min(max(value.location.y, 0), canvasSize.height))
                    let rect = CGRect(x: min(drag.origin.x, end.x), y: min(drag.origin.y, end.y),
                        width: abs(end.x - drag.origin.x), height: abs(end.y - drag.origin.y))
                    drag.rectangle = rect
                    selection = Set(bounds.compactMap { rect.intersects($0.value) ? $0.key : nil })
                }
                self.drag = drag
            }
            .exclusively(before: SpatialTapGesture(coordinateSpace: .named("mealCanvas"))
                .onEnded { value in
                    if let item = layers.first(where: { bounds[$0]?.contains(value.location) == true }) {
                        if selection.contains(item) { selection.remove(item) } else { selection.insert(item) }
                        Haptics.light()
                    } else {
                        selection.removeAll()
                    }
                })
    }
}

private enum CanvasEditorPanel: String, CaseIterable, Identifiable {
    case transform
    case insert
    case emoji
    case effects
    case brush
    case background

    var id: String { rawValue }

    var title: String {
        switch self {
        case .transform: return "大小与角度"
        case .insert: return "文字"
        case .emoji: return "贴纸"
        case .effects: return "特效"
        case .brush: return "画笔"
        case .background: return "背景"
        }
    }

    var icon: String {
        switch self {
        case .transform: return "arrow.up.left.and.arrow.down.right"
        case .insert: return "plus"
        case .emoji: return "face.smiling"
        case .effects: return "sparkles"
        case .brush: return "pencil.tip"
        case .background: return "photo"
        }
    }
}

private enum CanvasStickerSource: String, CaseIterable, Identifiable {
    case doodles = "手绘贴纸"
    case favorites = "我的贴图"
    case system = "表情"

    var id: String { rawValue }
}

private struct CanvasCustomEmoji: Identifiable, Hashable {
    let id: String
    let title: String
    var assetName: String { "StickerEmoji_\(id)" }
}

private enum CanvasEmojiCatalog {
    static let moods: [CanvasCustomEmoji] = [
        .init(id: "mood_bun_smile", title: "开心"),
        .init(id: "mood_star_eyes", title: "超爱"),
        .init(id: "mood_drool", title: "馋了"),
        .init(id: "mood_finger_heart", title: "比心"),
        .init(id: "mood_bear_love", title: "甜甜"),
        .init(id: "mood_peace", title: "耶"),
        .init(id: "mood_full_cat", title: "吃撑"),
        .init(id: "mood_spicy", title: "微辣"),
        .init(id: "mood_wow", title: "哇塞"),
        .init(id: "mood_hug_heart", title: "贴贴"),
        .init(id: "mood_wink", title: "调皮"),
        .init(id: "mood_thumbs_up", title: "超赞")
    ]

    static let foods: [CanvasCustomEmoji] = [
        .init(id: "food_ramen", title: "拉面"),
        .init(id: "food_strawberry", title: "草莓"),
        .init(id: "food_matcha", title: "冰饮"),
        .init(id: "food_croissant", title: "可颂"),
        .init(id: "food_fried_egg", title: "荷包蛋"),
        .init(id: "food_dumpling", title: "小笼包"),
        .init(id: "food_cheers", title: "干杯"),
        .init(id: "food_cake", title: "小蛋糕"),
        .init(id: "food_pudding", title: "布丁"),
        .init(id: "food_chili", title: "辣椒"),
        .init(id: "food_cherry", title: "樱桃"),
        .init(id: "food_tea", title: "热茶")
    ]

    static let vibes: [CanvasCustomEmoji] = [
        .init(id: "vibe_heart", title: "爱心"),
        .init(id: "vibe_daisy", title: "小雏菊"),
        .init(id: "vibe_sparkles", title: "闪闪"),
        .init(id: "vibe_sun", title: "晴天"),
        .init(id: "vibe_moon", title: "晚安"),
        .init(id: "vibe_rainbow", title: "彩虹"),
        .init(id: "vibe_bow", title: "蝴蝶结"),
        .init(id: "vibe_clover", title: "幸运草"),
        .init(id: "vibe_cat", title: "小猫"),
        .init(id: "vibe_puppy", title: "小狗"),
        .init(id: "vibe_camera", title: "拍立得"),
        .init(id: "vibe_crown", title: "今日C位")
    ]

    static let featured: [CanvasCustomEmoji] = {
        let all = moods + foods + vibes
        let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        let pickIDs = [
            "mood_star_eyes", "mood_drool", "mood_finger_heart", "mood_full_cat",
            "mood_spicy", "mood_hug_heart", "food_cheers", "food_cake",
            "food_pudding", "vibe_heart", "vibe_sparkles", "vibe_cat"
        ]
        return pickIDs.compactMap { byID[$0] }
    }()
}

private enum CanvasEmojiCategory: String, CaseIterable, Identifiable, Hashable {
    case featured
    case mood
    case food
    case vibe

    var id: String { rawValue }

    var title: String {
        switch self {
        case .featured: return "精选"
        case .mood: return "情绪"
        case .food: return "食光"
        case .vibe: return "氛围"
        }
    }

    var icon: String {
        switch self {
        case .featured: return "sparkles"
        case .mood: return "face.smiling"
        case .food: return "fork.knife"
        case .vibe: return "heart"
        }
    }

    var items: [CanvasCustomEmoji] {
        switch self {
        case .featured: return CanvasEmojiCatalog.featured
        case .mood: return CanvasEmojiCatalog.moods
        case .food: return CanvasEmojiCatalog.foods
        case .vibe: return CanvasEmojiCatalog.vibes
        }
    }
}

/// 画布里的按钮都用同一套轻触反馈：缩小、变淡、回弹，避免 SwiftUI 默认的“点了没反应”。
private struct CanvasPressStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.20, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

private enum CanvasEffectPreviewKind {
    case sticker(CanvasEffect, CanvasSticker)
    case text(CanvasTextEffect, CanvasNote)
}

private struct CanvasEffectPreview: View {
    let kind: CanvasEffectPreviewKind
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var isAnimated: Bool {
        switch kind {
        case .sticker(let effect, _): return effect.isAnimated
        case .text(let effect, _): return effect != .plain
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion || scenePhase != .active || !isAnimated)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            switch kind {
            case .text(let effect, let note):
                let visible = effect.visibleText(note.text, time: time, reduceMotion: reduceMotion)
                Group {
                    if let doodle = note.doodle {
                        CanvasDoodleView(
                            kind: doodle,
                            tint: note.color == .white ? CanvasPalette.ink : note.color.color,
                            isLightSurface: true,
                            compact: true
                        )
                    } else if note.isEmoji {
                        if let asset = note.emojiAsset {
                            Image(asset)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 46, height: 46)
                                .shadow(color: Color.black.opacity(0.14), radius: 3, y: 1.5)
                        } else {
                            Text(visible.isEmpty ? "…" : visible)
                                .font(.system(size: 31))
                        }
                    } else {
                        CanvasStyledTextContent(
                            text: note.text,
                            visibleText: visible.isEmpty ? "…" : visible,
                            font: note.font,
                            fontSize: 13,
                            color: note.color == .white && note.textStyle == .plain ? .ink : note.color,
                            textStyle: note.textStyle,
                            isLightSurface: true,
                            compact: true
                        )
                    }
                }
                .opacity(effect.opacity(time: time, reduceMotion: reduceMotion))
                .offset(effect.offset(time: time, reduceMotion: reduceMotion))
                .scaleEffect(x: effect.scaleX(time: time, reduceMotion: reduceMotion), y: effect.scaleY(time: time, reduceMotion: reduceMotion))
                .rotationEffect(.degrees(effect.rotation(time: time, reduceMotion: reduceMotion)))
            case .sticker(let effect, let sticker):
                StickerImageView(assetName: sticker.assetName, image: sticker.image, name: sticker.name, isCutout: sticker.isCutout, style: sticker.style, compact: true)
                    .frame(width: 44, height: 44)
                    .scaleEffect(effect.scale(time: time, reduceMotion: reduceMotion))
                    .rotationEffect(.degrees(effect.rotation(time: time, reduceMotion: reduceMotion)))
                    .offset(effect.offset(time: time, reduceMotion: reduceMotion))
                    .shadow(
                        color: effect == .none ? .clear : CanvasPalette.accent.opacity(effect == .glow ? 0.78 : (effect == .breathe ? 0.55 : 0)),
                        radius: effect == .glow ? 10 : (effect == .breathe ? 8 : 0)
                    )
                    .overlay {
                        if effect == .outline {
                            StickerBlobShape(index: sticker.shapeIndex)
                                .stroke(CanvasPalette.accent, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                                .frame(width: 48, height: 48)
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

private struct CanvasInlineEditorCard: View {
    let icon: String
    let title: String
    var previewKind: CanvasEffectPreviewKind?
    var subtitle: String?
    var isSelected = false
    let action: () -> Void

    init(icon: String, title: String, previewKind: CanvasEffectPreviewKind? = nil, subtitle: String? = nil, isSelected: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.previewKind = previewKind
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            VStack(spacing: 7) {
                if let previewKind {
                    CanvasEffectPreview(kind: previewKind)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isSelected ? CanvasPalette.ink : CanvasPalette.muted)
                        .frame(width: 32, height: 32)
                        .background(isSelected ? CanvasPalette.accent.opacity(0.24) : CanvasPalette.page, in: Circle())
                }
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? CanvasPalette.ink : CanvasPalette.muted)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(CanvasPalette.muted)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: subtitle == nil ? 76 : 88)
            .background(isSelected ? Color.paperGreen : Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? CanvasPalette.accent : CanvasPalette.ink.opacity(0.08), lineWidth: isSelected ? 1.2 : 0.8)
            }
        }
        .buttonStyle(CanvasPressStyle(scale: 0.95))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(.spring(response: 0.24, dampingFraction: 0.80), value: isSelected)
    }
}

private enum CanvasLayerMove: Equatable {
    case front, forward, backward, back
}

private struct CanvasLayerEntry {
    let selection: CanvasSelection
    let layer: Int
    let title: String
    let icon: String
}

enum CanvasBrushColor: String, CaseIterable, Identifiable, Codable {
    case white, butter, coral, sky, mint, ink

    var id: String { rawValue }

    var title: String {
        switch self {
        case .white: return "奶油白"
        case .butter: return "黄油黄"
        case .coral: return "番茄红"
        case .sky: return "海盐蓝"
        case .mint: return "薄荷绿"
        case .ink: return "墨黑"
        }
    }

    var color: Color {
        switch self {
        case .white: return .white
        case .butter: return Color(red: 0.89, green: 0.76, blue: 0.43)
        case .coral: return Color(red: 0.81, green: 0.49, blue: 0.43)
        case .sky: return Color(red: 0.53, green: 0.66, blue: 0.73)
        case .mint: return Color(red: 0.60, green: 0.72, blue: 0.53)
        case .ink: return Color(red: 0.22, green: 0.22, blue: 0.21)
        }
    }
}

enum CanvasBrushStyle: String, CaseIterable, Identifiable, Codable {
    case solid, dotted, dashed, marker, crayon, neon

    var id: String { rawValue }

    var title: String {
        switch self {
        case .solid: return "实线"
        case .dotted: return "点点"
        case .dashed: return "虚线"
        case .marker: return "荧光"
        case .crayon: return "蜡笔"
        case .neon: return "霓虹"
        }
    }

    var lineWidthMultiplier: CGFloat {
        switch self {
        case .marker: return 2.2
        case .crayon: return 1.35
        case .neon: return 1.15
        default: return 1
        }
    }

    var opacity: Double {
        switch self {
        case .marker: return 0.34
        case .crayon: return 0.76
        default: return 1
        }
    }
}

private struct CanvasBrushPreview: View {
    let style: CanvasBrushStyle
    let color: Color

    var body: some View {
        Canvas { context, size in
            let y = size.height / 2
            if style == .dotted {
                for x in stride(from: 3, through: size.width - 3, by: 7) {
                    context.fill(Path(ellipseIn: CGRect(x: x - 1.8, y: y - 1.8, width: 3.6, height: 3.6)), with: .color(color))
                }
            } else if style == .neon {
                var path = Path()
                path.move(to: CGPoint(x: 4, y: y))
                path.addLine(to: CGPoint(x: size.width - 4, y: y))
                context.stroke(path, with: .color(color.opacity(0.32)), style: StrokeStyle(lineWidth: 8.5, lineCap: .round))
                context.stroke(path, with: .color(color.opacity(0.65)), style: StrokeStyle(lineWidth: 5.0, lineCap: .round))
                context.stroke(path, with: .color(Color.white.opacity(0.95)), style: StrokeStyle(lineWidth: 2.0, lineCap: .round))
            } else {
                var path = Path()
                path.move(to: CGPoint(x: 2, y: y))
                path.addLine(to: CGPoint(x: size.width - 2, y: y))
                context.stroke(path, with: .color(color.opacity(style.opacity)), style: StrokeStyle(lineWidth: style == .marker ? 7 : 3, lineCap: .round, dash: style == .dashed ? [6, 5] : []))
            }
        }
    }
}

struct CanvasStroke: Identifiable, Codable, Hashable {
    var id: UUID
    var points: [CGPoint]
    var color: CanvasBrushColor
    var customColor: CanvasRGBA?
    var style: CanvasBrushStyle
    var width: CGFloat
    var isNormalized: Bool

    init(
        id: UUID = UUID(),
        points: [CGPoint],
        color: CanvasBrushColor = .white,
        customColor: CanvasRGBA? = nil,
        style: CanvasBrushStyle = .solid,
        width: CGFloat = 4,
        isNormalized: Bool = false
    ) {
        self.id = id
        self.points = points
        self.color = color
        self.customColor = customColor
        self.style = style
        self.width = width
        self.isNormalized = isNormalized
    }

    private enum CodingKeys: String, CodingKey { case id, points, color, customColor, style, width, isNormalized }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        points = try container.decode([CGPoint].self, forKey: .points)
        color = try container.decode(CanvasBrushColor.self, forKey: .color)
        customColor = try container.decodeIfPresent(CanvasRGBA.self, forKey: .customColor)
        style = try container.decodeIfPresent(CanvasBrushStyle.self, forKey: .style) ?? .solid
        width = try container.decodeIfPresent(CGFloat.self, forKey: .width) ?? 4
        isNormalized = try container.decodeIfPresent(Bool.self, forKey: .isNormalized) ?? false
    }
}

struct CanvasRGBA: Codable, Hashable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    init(color: Color) {
        let uiColor = UIColor(color)
        var red: CGFloat = 1, green: CGFloat = 1, blue: CGFloat = 1, alpha: CGFloat = 1
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        self.red = Double(red)
        self.green = Double(green)
        self.blue = Double(blue)
        self.alpha = Double(alpha)
    }

    var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha) }
}

enum CanvasBackground: String, CaseIterable, Identifiable {
    case linen, gingham, warmWood, blushPaper, meadow, morningTable, seaside, sunset, night, custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .linen: return "斜阳画纸"
        case .gingham: return "暖光咖啡"
        case .warmWood: return "纯白画室"
        case .blushPaper: return "曜石暗台"
        case .meadow: return "暖阳野餐"
        case .morningTable: return "晨光餐桌"
        case .seaside: return "海边"
        case .sunset: return "黄昏"
        case .night: return "夜色"
        case .custom: return "自定义"
        }
    }

    var isLightSurface: Bool {
        switch self {
        case .linen, .warmWood:
            return true
        case .gingham, .blushPaper, .meadow, .morningTable, .seaside, .sunset, .night, .custom:
            return false
        }
    }

    var defaultBrushColor: CanvasBrushColor {
        isLightSurface ? .ink : .white
    }

    var url: URL? {
        switch self {
        case .seaside:
            return URL(string: "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=85")
        case .sunset:
            return URL(string: "https://images.unsplash.com/photo-1470252649378-9c29740c9fa8?auto=format&fit=crop&w=1200&q=85")
        case .night:
            return URL(string: "https://images.unsplash.com/photo-1519681393784-d120267933ba?auto=format&fit=crop&w=1200&q=85")
        case .linen, .gingham, .warmWood, .blushPaper, .meadow, .morningTable, .custom:
            return nil
        }
    }
}

enum CanvasMoodFilter: String, CaseIterable, Identifiable, Codable, Hashable {
    case none, warmFilm, creamy, cinema, crisp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "原图"
        case .warmFilm: return "暖阳"
        case .creamy: return "奶油"
        case .cinema: return "电影"
        case .crisp: return "清透"
        }
    }
}

private struct CanvasMoodFilterOverlay: View {
    let filter: CanvasMoodFilter

    var body: some View {
        switch filter {
        case .none:
            Color.clear
        case .warmFilm:
            ZStack {
                Color(red: 1.0, green: 0.72, blue: 0.36).opacity(0.13)
                    .blendMode(.softLight)
                RadialGradient(
                    colors: [.clear, Color(red: 0.24, green: 0.13, blue: 0.04).opacity(0.20)],
                    center: .center,
                    startRadius: 130,
                    endRadius: 480
                )
            }
            .allowsHitTesting(false)
        case .creamy:
            ZStack {
                Color(red: 0.99, green: 0.96, blue: 0.91).opacity(0.14)
                LinearGradient(
                    colors: [Color(red: 1.0, green: 0.95, blue: 0.88).opacity(0.12), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .allowsHitTesting(false)
        case .cinema:
            ZStack {
                Color(red: 0.08, green: 0.14, blue: 0.18).opacity(0.12)
                RadialGradient(
                    colors: [.clear, Color.black.opacity(0.32)],
                    center: UnitPoint(x: 0.5, y: 0.44),
                    startRadius: 110,
                    endRadius: 460
                )
            }
            .allowsHitTesting(false)
        case .crisp:
            LinearGradient(
                colors: [Color.white.opacity(0.12), .clear, Color.black.opacity(0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
    }
}

struct CanvasDocument: Codable {
    var schemaVersion: Int
    var background: String
    var blur: Double
    var moodFilter: CanvasMoodFilter
    var customBackgroundData: Data?
    var customBackgroundURL: String?
    var stickers: [CanvasSticker]
    var notes: [CanvasNote]
    var strokes: [CanvasStroke]
    var size: CGSize?

    init(
        schemaVersion: Int = 3,
        background: String,
        blur: Double,
        moodFilter: CanvasMoodFilter = .none,
        customBackgroundData: Data? = nil,
        customBackgroundURL: String? = nil,
        stickers: [CanvasSticker],
        notes: [CanvasNote],
        strokes: [CanvasStroke] = [],
        size: CGSize? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.background = background
        self.blur = blur
        self.moodFilter = moodFilter
        self.customBackgroundData = customBackgroundData
        self.customBackgroundURL = customBackgroundURL
        self.stickers = stickers
        self.notes = notes
        self.strokes = strokes
        self.size = size
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, background, blur, moodFilter, customBackgroundData, customBackgroundURL, stickers, notes, strokes, size
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        background = try container.decode(String.self, forKey: .background)
        blur = try container.decode(Double.self, forKey: .blur)
        moodFilter = try container.decodeIfPresent(CanvasMoodFilter.self, forKey: .moodFilter) ?? .none
        customBackgroundData = try container.decodeIfPresent(Data.self, forKey: .customBackgroundData)
        customBackgroundURL = try container.decodeIfPresent(String.self, forKey: .customBackgroundURL)
        stickers = try container.decode([CanvasSticker].self, forKey: .stickers)
        notes = try container.decode([CanvasNote].self, forKey: .notes)
        strokes = try container.decodeIfPresent([CanvasStroke].self, forKey: .strokes) ?? []
        size = try container.decodeIfPresent(CGSize.self, forKey: .size)
    }

    func networkSanitized() -> CanvasDocument {
        var copy = self
        copy.customBackgroundData = nil
        return copy
    }
}

private enum CanvasDocumentStore {
    private static let prefix = "meal.canvas.document.v5."

    static func load(mealID: UInt) -> CanvasDocument? {
        guard let data = UserDefaults.standard.data(forKey: prefix + String(mealID)) else { return nil }
        return try? JSONDecoder().decode(CanvasDocument.self, from: data)
    }

    static func save(_ document: CanvasDocument, mealID: UInt) {
        guard let data = try? JSONEncoder().encode(document) else { return }
        UserDefaults.standard.set(data, forKey: prefix + String(mealID))
    }
}

// 记录详情页用它判断是否需要显示画布卡片，没保存过就整块省掉。
func mealCanvasDocumentExists(mealID: UInt) -> Bool {
    CanvasDocumentStore.load(mealID: mealID) != nil
}

/// 若本地没有画布缓存或需要与云端对齐，从后端拉取并写入本地缓存。
@MainActor
@discardableResult
func syncRemoteMealCanvasIfNeeded(mealID: UInt, forceRefresh: Bool = false) async -> Bool {
    let existing = CanvasDocumentStore.load(mealID: mealID)
    if !forceRefresh && existing != nil {
        return true
    }
    guard let resp = try? await MealService.shared.fetchCanvas(mealId: mealID),
          resp.revision > 0,
          var doc = resp.document else {
        return existing != nil
    }
    if doc.customBackgroundData == nil,
       let existing,
       existing.customBackgroundURL == doc.customBackgroundURL {
        doc.customBackgroundData = existing.customBackgroundData
    }
    CanvasDocumentStore.save(doc, mealID: mealID)
    return true
}

/// 异步把指定餐次已保存的画布合成为高清静态图，供「分享这顿饭」海报工坊同步渲染。
@MainActor
func renderMealCanvasStillImage(mealID: UInt) async -> UIImage? {
    if CanvasDocumentStore.load(mealID: mealID) == nil {
        _ = await syncRemoteMealCanvasIfNeeded(mealID: mealID)
    }
    guard let doc = CanvasDocumentStore.load(mealID: mealID) else { return nil }
    let fallbackSize = doc.size ?? CGSize(width: 390, height: 680)
    return await LiveCanvasExporterHelper.renderStillImage(document: doc, fallbackSize: fallbackSize, renderScale: 2.0)
}

/// 异步把指定餐次已保存的画布导出为系统相册实况照片。
@MainActor
func exportMealCanvasLivePhoto(
    mealID: UInt,
    onProgress: @escaping @MainActor (Double) -> Void
) async throws {
    if CanvasDocumentStore.load(mealID: mealID) == nil {
        _ = await syncRemoteMealCanvasIfNeeded(mealID: mealID)
    }
    guard let doc = CanvasDocumentStore.load(mealID: mealID) else { return }
    let fallbackSize = doc.size ?? CGSize(width: 390, height: 680)
    try await LiveCanvasExporterHelper.export(document: doc, fallbackSize: fallbackSize, onProgress: onProgress)
}

private struct CanvasMediaBackground: View {
    let source: CanvasBackground
    let blur: Double
    let customData: Data?
    var customURL: String? = nil
    var preloadedImage: UIImage? = nil
    @State private var remoteImage: UIImage?

    private var effectiveRemoteURL: URL? {
        source == .custom ? APIConfig.imageURL(customURL) : source.url
    }

    var body: some View {
        ZStack {
            Group {
                if let preloadedImage {
                    Image(uiImage: preloadedImage)
                        .resizable()
                        .scaledToFill()
                } else if source == .custom, let customData, let image = UIImage(data: customData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if source == .meadow {
                    Image("CanvasMeadow")
                        .resizable()
                        .scaledToFill()
                } else if source == .morningTable {
                    Image("ProfileHeroCover")
                        .resizable()
                        .scaledToFill()
                } else if source == .gingham {
                    Image("CanvasWarmCafe")
                        .resizable()
                        .scaledToFill()
                } else if source == .linen {
                    Image("CanvasGallerySun")
                        .resizable()
                        .scaledToFill()
                } else if source == .warmWood {
                    linenPaper
                } else if source == .blushPaper {
                    blushNotePaper
                } else if let url = effectiveRemoteURL {
                    let cached = RemoteImageCache.shared.cachedImage(for: url)
                    if let uiImage = remoteImage ?? cached {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        fallback
                    }
                } else {
                    fallback
                }
            }
            .blur(radius: blur > 0 ? blur * 1.6 : 0, opaque: true)

            // 轻柔雾化罩，保证虚化时高光柔和、前景色不刺眼。
            if blur > 0 {
                Color(source.isLightSurface ? .white : .black)
                    .opacity(min(0.18, blur / 60))
            }
        }
        .clipped()
        .task(id: effectiveRemoteURL) {
            remoteImage = nil
            guard preloadedImage == nil, let url = effectiveRemoteURL else { return }
            if let cached = RemoteImageCache.shared.cachedImage(for: url) {
                remoteImage = cached
                return
            }
            remoteImage = await RemoteImageCache.shared.load(url: url)
        }
    }

    private var linenPaper: some View {
        ZStack {
            Color.white
            RadialGradient(
                colors: [
                    Color.white,
                    Color(red: 0.949, green: 0.949, blue: 0.961)
                ],
                center: UnitPoint(x: 0.5, y: 0.40),
                startRadius: 90,
                endRadius: 520
            )
        }
    }

    private var ginghamCloth: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.973, green: 0.976, blue: 0.984),
                    Color(red: 0.910, green: 0.918, blue: 0.933)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color.white.opacity(0.92), Color.clear],
                center: UnitPoint(x: 0.25, y: 0.18),
                startRadius: 10,
                endRadius: 340
            )
        }
    }

    private var warmWoodTable: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.957, green: 0.953, blue: 0.945),
                    Color(red: 0.902, green: 0.898, blue: 0.886)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [Color.white.opacity(0.55), Color.clear],
                center: UnitPoint(x: 0.5, y: 0.38),
                startRadius: 40,
                endRadius: 420
            )
        }
    }

    private var blushNotePaper: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.094, green: 0.094, blue: 0.106),
                    Color(red: 0.043, green: 0.043, blue: 0.051)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [Color.white.opacity(0.11), Color.white.opacity(0.03), Color.clear],
                center: UnitPoint(x: 0.5, y: 0.42),
                startRadius: 20,
                endRadius: 360
            )
        }
    }

    private var fallback: some View {
        ZStack {
            LinearGradient(
                colors: source == .night
                    ? [Color(red: 0.07, green: 0.08, blue: 0.15), Color(red: 0.18, green: 0.12, blue: 0.24)]
                        : source == .sunset
                            ? [Color(red: 0.88, green: 0.55, blue: 0.36), Color(red: 0.48, green: 0.27, blue: 0.34)]
                        : source == .meadow
                            ? [Color(red: 0.39, green: 0.54, blue: 0.55), Color(red: 0.33, green: 0.37, blue: 0.22)]
                            : source == .custom
                                ? [Color(red: 0.46, green: 0.52, blue: 0.54), Color(red: 0.20, green: 0.25, blue: 0.26)]
                        : [Color(red: 0.16, green: 0.57, blue: 0.70), Color(red: 0.08, green: 0.22, blue: 0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private extension UIImage {
    /// Keep a selected photo small enough for the local canvas document while
    /// preserving a crisp portrait preview.
    var canvasPreviewData: Data? {
        let preview = preparingThumbnail(of: CGSize(width: 1600, height: 1600)) ?? self
        return preview.jpegData(compressionQuality: 0.84)
    }
}

private extension UUID {
    var motionPhaseOffset: Double {
        let bytes = withUnsafeBytes(of: uuid) { Array($0) }
        let seed = bytes.prefix(4).reduce(0) { ($0 << 8) | Int($1) }
        return Double(seed % 360) * .pi / 180.0
    }
}

enum CanvasStickerStyle: String, CaseIterable, Identifiable, Codable, Hashable {
    case dieCut
    case floating
    case polaroid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dieCut: return "白边贴纸"
        case .floating: return "纯净悬浮"
        case .polaroid: return "拍立得"
        }
    }

    var icon: String {
        switch self {
        case .dieCut: return "square.on.circle"
        case .floating: return "circle.dashed"
        case .polaroid: return "photo.artframe"
        }
    }
}

struct CanvasSticker: Identifiable, Codable, Hashable {
    let id: UUID
    let mealDishID: UInt?
    let name: String
    var image: String?
    var isCutout: Bool
    var assetName: String?
    var position: CanvasPoint
    var scale: CGFloat
    var rotationDegrees: Double
    var effect: CanvasEffect = .float
    var style: CanvasStickerStyle = .dieCut
    var shapeIndex: Int = 0
    var layer: Int = 0

    init(
        id: UUID = UUID(),
        mealDishID: UInt? = nil,
        name: String,
        image: String?,
        isCutout: Bool = false,
        assetName: String? = nil,
        position: CanvasPoint,
        scale: CGFloat = 1,
        rotationDegrees: Double = 0,
        effect: CanvasEffect = .float,
        style: CanvasStickerStyle = .dieCut,
        shapeIndex: Int = 0,
        layer: Int = 0
    ) {
        self.id = id
        self.mealDishID = mealDishID
        self.name = name
        self.image = image
        self.isCutout = isCutout
        self.assetName = assetName
        self.position = position
        self.scale = scale
        self.rotationDegrees = rotationDegrees
        self.effect = effect
        self.style = style
        self.shapeIndex = shapeIndex
        self.layer = layer
    }

    private enum CodingKeys: String, CodingKey {
        case id, mealDishID, name, image, isCutout, assetName, position, scale, rotationDegrees, effect, style, shapeIndex, layer
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        mealDishID = try container.decodeIfPresent(UInt.self, forKey: .mealDishID)
        name = try container.decode(String.self, forKey: .name)
        image = try container.decodeIfPresent(String.self, forKey: .image)
        isCutout = try container.decodeIfPresent(Bool.self, forKey: .isCutout) ?? false
        assetName = try container.decodeIfPresent(String.self, forKey: .assetName)
        position = try container.decode(CanvasPoint.self, forKey: .position)
        scale = try container.decodeIfPresent(CGFloat.self, forKey: .scale) ?? 1
        rotationDegrees = try container.decodeIfPresent(Double.self, forKey: .rotationDegrees) ?? 0
        effect = try container.decodeIfPresent(CanvasEffect.self, forKey: .effect) ?? .none
        style = try container.decodeIfPresent(CanvasStickerStyle.self, forKey: .style) ?? .dieCut
        shapeIndex = try container.decodeIfPresent(Int.self, forKey: .shapeIndex) ?? 0
        layer = try container.decodeIfPresent(Int.self, forKey: .layer) ?? 0
    }
}

enum CanvasEffect: String, CaseIterable, Identifiable, Codable {
    case none
    case outline
    case glow
    case breathe
    case shake
    case bounce
    case float

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "无"
        case .outline: return "描边"
        case .glow: return "柔光"
        case .breathe: return "呼吸"
        case .shake: return "抖动"
        case .bounce: return "弹跳"
        case .float: return "漂浮"
        }
    }

    var icon: String {
        switch self {
        case .none: return "circle.slash"
        case .outline: return "scribble.variable"
        case .glow: return "sparkles"
        case .breathe: return "aqi.medium"
        case .shake: return "waveform.path.ecg"
        case .bounce: return "arrow.up.and.down"
        case .float: return "wind"
        }
    }

    var isAnimated: Bool { self == .shake || self == .bounce || self == .float || self == .breathe }

    func offset(time: TimeInterval, phase: Double = 0, reduceMotion: Bool) -> CGSize {
        guard !reduceMotion else { return .zero }
        let t = time + phase
        switch self {
        case .float: return CGSize(width: sin(t * 0.95) * 2.2, height: sin(t * 1.45) * 5.5)
        case .bounce: return CGSize(width: 0, height: -abs(sin(t * 2.1)) * 5)
        default: return .zero
        }
    }

    func rotation(time: TimeInterval, phase: Double = 0, reduceMotion: Bool) -> Double {
        guard !reduceMotion else { return 0 }
        let t = time + phase
        switch self {
        case .shake: return sin(t * 9) * 3
        case .float: return sin(t * 1.15) * 1.3
        default: return 0
        }
    }

    func scale(time: TimeInterval, phase: Double = 0, reduceMotion: Bool) -> CGFloat {
        guard !reduceMotion else { return 1 }
        let t = time + phase
        switch self {
        case .bounce: return 1 + abs(sin(t * 2.1)) * 0.04
        case .breathe: return 1 + CGFloat(sin(t * 1.85) * 0.048)
        default: return 1
        }
    }

    func glowOpacity(time: TimeInterval, phase: Double = 0, reduceMotion: Bool) -> Double {
        switch self {
        case .glow: return 0.85
        case .breathe:
            guard !reduceMotion else { return 0.35 }
            let wave = (sin((time + phase) * 1.85) + 1) * 0.5
            return 0.28 + 0.34 * wave
        default: return 0
        }
    }

    var glowRadius: CGFloat {
        switch self {
        case .glow: return 20
        case .breathe: return 15
        default: return 0
        }
    }
}

enum CanvasTextEffect: String, CaseIterable, Identifiable, Codable {
    case plain
    case typewriter
    case float
    case distort
    case fade
    case bounce

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plain: return "普通"
        case .typewriter: return "打字"
        case .float: return "漂浮"
        case .distort: return "扭曲"
        case .fade: return "浮现"
        case .bounce: return "跳动"
        }
    }

    var icon: String {
        switch self {
        case .plain: return "minus.circle"
        case .typewriter: return "keyboard"
        case .float: return "arrow.up.and.down"
        case .distort: return "scribble.variable"
        case .fade: return "circle.lefthalf.filled"
        case .bounce: return "arrow.up.and.down.circle"
        }
    }

    func visibleText(_ text: String, time: TimeInterval, reduceMotion: Bool) -> String {
        guard self == .typewriter, !reduceMotion else { return text }
        let characters = Array(text)
        guard !characters.isEmpty else { return text }
        let cycle = 4.8
        let elapsed = positiveRemainder(time, cycle: cycle)
        let reveal = min(max((elapsed - 0.25) / 2.9, 0), 1)
        let count = Int((Double(characters.count) * reveal).rounded(.down))
        return String(characters.prefix(count))
    }

    func opacity(time: TimeInterval, reduceMotion: Bool) -> Double {
        guard self == .fade, !reduceMotion else { return 1 }
        let wave = (sin(time * 1.55 - .pi / 2) + 1) * 0.5
        return 0.30 + wave * 0.70
    }

    func offset(time: TimeInterval, phase: Double = 0, reduceMotion: Bool) -> CGSize {
        guard !reduceMotion else { return .zero }
        let t = time + phase
        switch self {
        case .float:
            return CGSize(width: 0, height: sin(t * 1.25) * 5)
        case .bounce:
            return CGSize(width: 0, height: -abs(sin(t * 2.1)) * 5)
        default:
            return .zero
        }
    }

    func scaleX(time: TimeInterval, reduceMotion: Bool) -> CGFloat {
        guard self == .distort, !reduceMotion else { return 1 }
        return CGFloat(1 + sin(time * 1.8) * 0.09)
    }

    func scaleY(time: TimeInterval, reduceMotion: Bool) -> CGFloat {
        guard self == .distort, !reduceMotion else { return 1 }
        return CGFloat(1 - sin(time * 1.8) * 0.06)
    }

    func rotation(time: TimeInterval, reduceMotion: Bool) -> Double {
        guard self == .distort, !reduceMotion else { return 0 }
        return sin(time * 1.8) * 4
    }

    private func positiveRemainder(_ value: TimeInterval, cycle: TimeInterval) -> TimeInterval {
        let remainder = value.truncatingRemainder(dividingBy: cycle)
        return remainder >= 0 ? remainder : remainder + cycle
    }
}

private struct CanvasStickerView: View {
    @Binding var sticker: CanvasSticker
    let canvasSize: CGSize
    let isSelected: Bool
    let reduceMotion: Bool
    var reportsBounds = false
    var isLightSurface: Bool = false
    var canMoveForward: Bool = true
    var canMoveBackward: Bool = true
    var alignmentTargets: [CanvasPoint] = []
    var remotePreview: CanvasRemoteLivePreview? = nil
    var onTransformStart: () -> Void = {}
    let onSelect: () -> Void
    let onTransform: () -> Void
    let onLayerMove: (CanvasLayerMove) -> Void
    let onDelete: () -> Void
    var onFavorite: (() -> Void)? = nil
    var onDuplicate: (() -> Void)? = nil
    var onLiveChange: (() -> Void)? = nil
    let onChange: () -> Void

    @State private var isGestureActive = false
    @State private var hasAppeared = false
    @State private var isHandleActive = false
    @Environment(\.scenePhase) private var scenePhase

    private var isManipulating: Bool { isGestureActive || isHandleActive }

    private var baseSize: CGFloat {
        max(110, min(canvasSize.width, canvasSize.height) * 0.37)
    }

    var body: some View {
        let activePreview = isManipulating ? nil : remotePreview
        let displayPosition = activePreview?.position ?? sticker.position
        let displayScale = activePreview?.scale ?? sticker.scale
        let displayRotation = activePreview?.rotationDegrees ?? sticker.rotationDegrees
        let x = canvasSize.width * displayPosition.x
        let y = canvasSize.height * displayPosition.y

        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion || scenePhase != .active || isSelected || isManipulating || activePreview != nil || !sticker.effect.isAnimated)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let effectsPaused = reduceMotion || isSelected || isManipulating || activePreview != nil
            let phase = sticker.id.motionPhaseOffset
            ZStack(alignment: .topTrailing) {
                StickerImageView(
                    assetName: sticker.assetName,
                    image: sticker.image,
                    name: sticker.name,
                    isCutout: sticker.isCutout,
                    style: sticker.style,
                    isLightSurface: isLightSurface
                )
                    .frame(width: baseSize * (sticker.isCutout ? 1.24 : 1.12), height: baseSize * (sticker.isCutout ? 1.24 : 1.12))
                    .overlay {
                        if sticker.effect == .outline {
                            StickerBlobShape(index: sticker.shapeIndex)
                                .stroke(
                                    isLightSurface ? CanvasPalette.accent.opacity(0.85) : .white.opacity(0.94),
                                    style: StrokeStyle(
                                        lineWidth: 1.6,
                                        lineCap: .round,
                                        dash: [5, 4]
                                    )
                                )
                        }
                    }
                    .shadow(
                        color: Color.white.opacity(sticker.effect.glowOpacity(time: time, phase: phase, reduceMotion: effectsPaused)),
                        radius: sticker.effect.glowRadius,
                        y: 0
                    )
                    .scaleEffect(sticker.effect.scale(time: time, phase: phase, reduceMotion: effectsPaused))
                    .rotationEffect(.degrees(sticker.effect.rotation(time: time, phase: phase, reduceMotion: effectsPaused)))
                    .offset(sticker.effect.offset(time: time, phase: phase, reduceMotion: effectsPaused))

            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isSelected)
        }
        .frame(width: baseSize * 1.34, height: baseSize * 1.34)
        .contentShape(Rectangle())
        .scaleEffect(min(max(displayScale, 0.3), 3) * (hasAppeared || reduceMotion ? 1 : 0.86))
        .rotationEffect(.degrees(displayRotation))
        .overlay(alignment: .top) {
            if let activePreview {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(red: 0.44, green: 0.88, blue: 0.56))
                        .frame(width: 5.5, height: 5.5)
                    Text(activePreview.actor.nickname)
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(CanvasPalette.obsidianInk.opacity(0.88), in: Capsule())
                .overlay {
                    Capsule().strokeBorder(Color.white.opacity(0.24), lineWidth: 0.6)
                }
                .shadow(color: Color.black.opacity(0.20), radius: 5, y: 2)
                .offset(y: -14)
                .allowsHitTesting(false)
            }
        }
        .opacity(hasAppeared || reduceMotion ? 1 : 0)
        .animation(reduceMotion || isManipulating ? nil : .easeOut(duration: 0.08), value: activePreview)
        .onTapGesture(perform: onSelect)
        .animation(.spring(response: 0.34, dampingFraction: 0.74), value: sticker.effect)
        .contextMenu {
            elementContextMenu
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(sticker.name)
        .accessibilityValue("\(Int((sticker.scale * 100).rounded()))%，\(sticker.effect.title)")
        .accessibilityHint("拖动内容移动，选中后拖动旋转或缩放手柄；双指可缩放或旋转")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { onSelect() }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.72)) {
                hasAppeared = true
            }
        }
        .overlay {
            if isSelected {
                GeometryReader { proxy in
                    Color.clear
                        .allowsHitTesting(false)
                        .preference(key: CanvasTransformOverlayKey.self, value: CanvasTransformOverlay(
                            selection: .sticker(sticker.id),
                            controls: CanvasTransformControls(size: proxy.size, canvasSize: canvasSize,
                                rotationDegrees: $sticker.rotationDegrees,
                                position: $sticker.position,
                                scale: $sticker.scale, isHandleActive: $isHandleActive,
                                isLightSurface: isLightSurface,
                                isRectangular: sticker.style == .polaroid,
                                contentRatio: sticker.style == .polaroid ? 0.92 : 1.0,
                                onTransformStart: onTransformStart,
                                onLiveChange: onLiveChange,
                                onChange: onChange),
                            size: proxy.size))
                }
            }
        }
        .modifier(CanvasElementBoundsReporter(selection: .sticker(sticker.id), canvasSize: canvasSize,
            position: sticker.position, scale: sticker.scale, rotation: sticker.rotationDegrees,
            isEnabled: reportsBounds, contentRatio: 1.12 / 1.34))
        .modifier(CanvasManipulation(position: $sticker.position, scale: $sticker.scale,
            rotationDegrees: $sticker.rotationDegrees, isGestureActive: $isGestureActive,
            canvasSize: canvasSize, alignmentTargets: alignmentTargets, isSelected: isSelected, isHandleActive: isHandleActive,
            onTransformStart: onTransformStart,
            onSelect: onSelect, onLiveChange: onLiveChange, onChange: onChange))
        .position(x: x, y: y)
    }

    @ViewBuilder
    private var elementContextMenu: some View {
        Button("精细调整", systemImage: "arrow.up.left.and.arrow.down.right", action: onTransform)
        if let onDuplicate {
            Button("复制一份", systemImage: "doc.on.doc", action: onDuplicate)
        }
        if let onFavorite {
            Button("收藏贴图", systemImage: "star", action: onFavorite)
        }
        Section("层级") {
            Button("置顶", systemImage: "arrow.up.to.line") {
                onLayerMove(.front)
            }
            .disabled(!canMoveForward)
            Button("上移一层", systemImage: "chevron.up") {
                onLayerMove(.forward)
            }
            .disabled(!canMoveForward)
            Button("下移一层", systemImage: "chevron.down") {
                onLayerMove(.backward)
            }
            .disabled(!canMoveBackward)
            Button("置底", systemImage: "arrow.down.to.line") {
                onLayerMove(.back)
            }
            .disabled(!canMoveBackward)
        }
        Button("删除", systemImage: "trash", role: .destructive, action: onDelete)
    }

}

/// 真实菜品自动抠图主体（白边模切贴纸或纯净悬浮）与无图兜底卡。
private struct StickerImageView: View {
    let assetName: String?
    let image: String?
    let name: String
    var isCutout = false
    var style: CanvasStickerStyle = .dieCut
    var compact = false
    var isLightSurface = true
    @State private var loadedPhoto: UIImage?
    @State private var cutoutPhoto: UIImage?
    @State private var dieCutPhoto: UIImage?
    @State private var finishedLoading = false

    private var resolvedURL: URL? { APIConfig.imageURL(image) }

    var body: some View {
        let cachedRaw = resolvedURL.flatMap { RemoteImageCache.shared.cachedImage(for: $0) }
        let cachedExtracted = isCutout ? nil : resolvedURL.flatMap { DishCutoutCache.shared.cachedCutout(for: $0) }
        let subjectImage: UIImage? = isCutout ? (loadedPhoto ?? cachedRaw) : (cutoutPhoto ?? cachedExtracted)
        let cachedRim = (style == .dieCut) ? resolvedURL.flatMap { StickerBorderRenderer.shared.cached(forKey: $0.absoluteString) } : nil
        let displayCutout: UIImage? = (style == .dieCut) ? (dieCutPhoto ?? cachedRim ?? subjectImage) : subjectImage
        let rawImage: UIImage? = loadedPhoto ?? cachedRaw

        Group {
            if style == .polaroid && !compact && (subjectImage != nil || rawImage != nil || finishedLoading || resolvedURL == nil) {
                PolaroidStickerCard(
                    image: subjectImage ?? rawImage,
                    assetName: assetName,
                    isCutout: subjectImage != nil,
                    name: name,
                    compact: compact,
                    isLightSurface: isLightSurface
                )
            } else if resolvedURL != nil {
                if let displayCutout {
                    Image(uiImage: displayCutout)
                        .resizable()
                        .scaledToFit()
                        .padding(compact ? 2 : 4)
                        .shadow(
                            color: Color.black.opacity(isLightSurface ? 0.16 : 0.34),
                            radius: compact ? 4 : 14,
                            y: compact ? 2 : 8
                        )
                        .shadow(
                            color: Color.black.opacity(isLightSurface ? 0.08 : 0.16),
                            radius: 3,
                            y: 2
                        )
                        .transition(.opacity)
                } else if let rawImage {
                    if compact {
                        GeometryReader { proxy in
                            Image(uiImage: rawImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    } else {
                        GeometryReader { proxy in
                            Image(uiImage: rawImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .overlay {
                                    if style == .dieCut {
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .strokeBorder(Color.white, lineWidth: 3.5)
                                    } else {
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .strokeBorder(
                                                isLightSurface ? Color.black.opacity(0.06) : Color.white.opacity(0.18),
                                                lineWidth: 0.7
                                            )
                                    }
                                }
                                .shadow(
                                    color: Color.black.opacity(isLightSurface ? 0.14 : 0.36),
                                    radius: 12,
                                    y: 7
                                )
                        }
                    }
                } else if finishedLoading {
                    fallback
                } else {
                    ProgressView().tint(isLightSurface ? CanvasPalette.ink : .white)
                }
            } else {
                fallback
            }
        }
        .animation(.easeOut(duration: 0.22), value: displayCutout != nil)
        .task(id: resolvedURL) {
            finishedLoading = false
            cutoutPhoto = nil
            dieCutPhoto = nil
            guard let url = resolvedURL else {
                loadedPhoto = nil
                return
            }
            if isCutout {
                let target: UIImage?
                if let cached = RemoteImageCache.shared.cachedImage(for: url) {
                    target = cached
                } else {
                    target = await RemoteImageCache.shared.load(url: url)
                }
                guard !Task.isCancelled else { return }
                loadedPhoto = target
                finishedLoading = true
                if let target {
                    let rimmed = await StickerBorderRenderer.shared.makeDieCutSticker(from: target, cacheKey: url.absoluteString)
                    if !Task.isCancelled {
                        dieCutPhoto = rimmed
                    }
                }
                return
            }
            if let cachedCut = DishCutoutCache.shared.cachedCutout(for: url) {
                cutoutPhoto = cachedCut
                finishedLoading = true
                let rimmed = await StickerBorderRenderer.shared.makeDieCutSticker(from: cachedCut, cacheKey: url.absoluteString)
                if !Task.isCancelled {
                    dieCutPhoto = rimmed
                }
                return
            }
            let raw: UIImage?
            if let cached = RemoteImageCache.shared.cachedImage(for: url) {
                raw = cached
            } else {
                raw = await RemoteImageCache.shared.load(url: url)
            }
            guard !Task.isCancelled else { return }
            loadedPhoto = raw
            finishedLoading = true
            if let raw {
                let extracted = await DishCutoutCache.shared.cutout(for: url, sourceImage: raw)
                if !Task.isCancelled, let extracted {
                    cutoutPhoto = extracted
                    let rimmed = await StickerBorderRenderer.shared.makeDieCutSticker(from: extracted, cacheKey: url.absoluteString)
                    if !Task.isCancelled {
                        dieCutPhoto = rimmed
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var fallback: some View {
        if let assetName {
            Image(assetName).resizable().scaledToFit()
                .shadow(color: Color.black.opacity(isLightSurface ? 0.16 : 0.45), radius: 10, y: 6)
        } else if compact {
            Text(name)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(CanvasPalette.ink)
                .lineLimit(2)
                .padding(6)
                .background(CanvasPalette.surface, in: RoundedRectangle(cornerRadius: 10))
        } else {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isLightSurface ? Color(red: 0.96, green: 0.96, blue: 0.97) : Color(red: 0.16, green: 0.16, blue: 0.18))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            isLightSurface ? Color.black.opacity(0.08) : Color.white.opacity(0.18),
                            lineWidth: 0.8
                        )
                }
                .overlay {
                    Text(name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(isLightSurface ? CanvasPalette.ink : .white)
                        .lineLimit(3)
                        .minimumScaleFactor(0.78)
                        .padding(14)
                }
                .shadow(color: Color.black.opacity(isLightSurface ? 0.08 : 0.30), radius: 10, y: 5)
        }
    }
}

private struct PolaroidStickerCard: View {
    let image: UIImage?
    var assetName: String? = nil
    let isCutout: Bool
    let name: String
    var compact: Bool = false
    var isLightSurface: Bool = false

    var body: some View {
        let sideInset: CGFloat = compact ? 3 : 8
        let bottomInset: CGFloat = compact ? 10 : 28
        let outerRadius: CGFloat = compact ? 5 : 10
        let innerRadius: CGFloat = compact ? 3 : 5

        VStack(spacing: 0) {
            GeometryReader { proxy in
                ZStack {
                    Color(red: 0.962, green: 0.950, blue: 0.928)
                    if let image {
                        if isCutout {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .padding(compact ? 3 : 8)
                        } else {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: proxy.size.width, height: proxy.size.height)
                        }
                    } else if let assetName, !assetName.isEmpty {
                        Image(assetName)
                            .resizable()
                            .scaledToFit()
                            .padding(compact ? 4 : 10)
                    } else {
                        Text(name)
                            .font(.system(size: compact ? 9 : 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(CanvasPalette.obsidianInk)
                            .multilineTextAlignment(.center)
                            .padding(6)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipShape(RoundedRectangle(cornerRadius: innerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: innerRadius, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.6)
                }
            }
            .padding(.top, sideInset)
            .padding(.horizontal, sideInset)

            Text(name)
                .font(.custom("Noteworthy-Bold", size: compact ? 8.5 : 13.5))
                .foregroundStyle(CanvasPalette.obsidianInk)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .frame(height: bottomInset)
                .padding(.horizontal, sideInset)
        }
        .background(Color(red: 0.992, green: 0.986, blue: 0.972), in: RoundedRectangle(cornerRadius: outerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                .strokeBorder(Color.black.opacity(0.07), lineWidth: 0.6)
        }
        .shadow(color: Color.black.opacity(isLightSurface ? 0.14 : 0.34), radius: compact ? 4 : 12, y: compact ? 2 : 6)
    }
}

private struct CachedStickerThumbView: View {
    let imagePath: String
    @State private var uiImage: UIImage?
    @State private var finished = false

    private var url: URL? { APIConfig.imageURL(imagePath) }

    var body: some View {
        let cached = url.flatMap { RemoteImageCache.shared.cachedImage(for: $0) }
        Group {
            if let display = uiImage ?? cached {
                Image(uiImage: display)
                    .resizable()
                    .scaledToFit()
            } else if finished {
                Image(systemName: "photo.badge.exclamationmark")
                    .foregroundStyle(CanvasPalette.muted)
            } else {
                ProgressView().tint(CanvasPalette.accent)
            }
        }
        .task(id: url) {
            finished = false
            uiImage = nil
            guard let url else {
                finished = true
                return
            }
            if let hit = RemoteImageCache.shared.cachedImage(for: url) {
                uiImage = hit
                finished = true
                return
            }
            uiImage = await RemoteImageCache.shared.load(url: url)
            finished = true
        }
    }
}

private struct StickerBlobShape: Shape {
    let index: Int

    func path(in rect: CGRect) -> Path {
        let presets: [[CGPoint]] = [
            [CGPoint(x: 0.50, y: 0.02), CGPoint(x: 0.80, y: 0.10), CGPoint(x: 0.98, y: 0.42), CGPoint(x: 0.87, y: 0.82), CGPoint(x: 0.54, y: 0.98), CGPoint(x: 0.17, y: 0.88), CGPoint(x: 0.02, y: 0.55), CGPoint(x: 0.16, y: 0.17)],
            [CGPoint(x: 0.40, y: 0.02), CGPoint(x: 0.86, y: 0.15), CGPoint(x: 0.96, y: 0.60), CGPoint(x: 0.74, y: 0.95), CGPoint(x: 0.28, y: 0.91), CGPoint(x: 0.03, y: 0.60), CGPoint(x: 0.12, y: 0.19)],
            [CGPoint(x: 0.52, y: 0.01), CGPoint(x: 0.92, y: 0.22), CGPoint(x: 0.90, y: 0.74), CGPoint(x: 0.60, y: 0.99), CGPoint(x: 0.13, y: 0.84), CGPoint(x: 0.04, y: 0.40), CGPoint(x: 0.28, y: 0.11)],
            [CGPoint(x: 0.28, y: 0.04), CGPoint(x: 0.76, y: 0.08), CGPoint(x: 0.99, y: 0.46), CGPoint(x: 0.78, y: 0.91), CGPoint(x: 0.42, y: 0.99), CGPoint(x: 0.07, y: 0.72), CGPoint(x: 0.02, y: 0.28)],
            [CGPoint(x: 0.50, y: 0.03), CGPoint(x: 0.88, y: 0.18), CGPoint(x: 0.94, y: 0.52), CGPoint(x: 0.72, y: 0.96), CGPoint(x: 0.30, y: 0.96), CGPoint(x: 0.05, y: 0.61), CGPoint(x: 0.17, y: 0.18)]
        ]
        let points = presets[index % presets.count].map {
            CGPoint(x: rect.minX + rect.width * $0.x, y: rect.minY + rect.height * $0.y)
        }
        guard !points.isEmpty else { return Path() }
        // 用二次曲线把控制点连成柔和的不规则轮廓，避免贴纸像硬切出来的八边形。
        func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: (a.x + b.x) * 0.5, y: (a.y + b.y) * 0.5)
        }
        var path = Path()
        let start = midpoint(points[0], points[1 % points.count])
        path.move(to: start)
        for index in points.indices {
            let control = points[index]
            let next = points[(index + 1) % points.count]
            path.addQuadCurve(to: midpoint(control, next), control: control)
        }
        path.closeSubpath()
        return path
    }
}

enum CanvasTextFont: String, CaseIterable, Identifiable, Codable, Hashable {
    case rounded, serif, mono, handwritten

    var id: String { rawValue }
    var title: String {
        switch self {
        case .rounded: return "圆体"
        case .serif: return "衬线"
        case .mono: return "等宽"
        case .handwritten: return "手写"
        }
    }
    func font(size: CGFloat, weight: Font.Weight) -> Font {
        switch self {
        case .rounded: return .system(size: size, weight: weight, design: .rounded)
        case .serif: return .system(size: size, weight: weight, design: .serif)
        case .mono: return .system(size: size, weight: weight, design: .monospaced)
        case .handwritten: return .custom("Noteworthy-Bold", size: size + 2)
        }
    }
}

enum CanvasTextColor: String, CaseIterable, Identifiable, Codable, Hashable {
    case white, butter, coral, mint, sky, ink

    var id: String { rawValue }
    var title: String {
        switch self {
        case .white: return "奶油白"
        case .butter: return "黄油黄"
        case .coral: return "番茄红"
        case .mint: return "薄荷绿"
        case .sky: return "海盐蓝"
        case .ink: return "墨黑"
        }
    }
    var color: Color {
        switch self {
        case .white: return .white
        case .butter: return Color(red: 0.95, green: 0.78, blue: 0.38)
        case .coral: return Color(red: 0.95, green: 0.48, blue: 0.46)
        case .mint: return Color(red: 0.65, green: 0.82, blue: 0.56)
        case .sky: return Color(red: 0.58, green: 0.78, blue: 0.92)
        case .ink: return Color(red: 0.18, green: 0.17, blue: 0.16)
        }
    }
}

enum CanvasTextStyle: String, CaseIterable, Identifiable, Codable, Hashable {
    case plain, glass, pill, paper, highlight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plain: return "无底"
        case .glass: return "磨砂"
        case .pill: return "标签"
        case .paper: return "纸贴"
        case .highlight: return "高光"
        }
    }
}

enum CanvasDoodleKind: String, CaseIterable, Identifiable, Codable, Hashable {
    case yummy
    case tonight
    case homemade
    case perfect
    case cheers
    case spicy
    case cleanPlate
    case speechBubble
    case bonAppetit
    case filmDate
    case starCluster
    case curvedArrow
    case heartDoodle
    case wavyLine
    case crown
    case washiTape

    var id: String { rawValue }

    var title: String {
        switch self {
        case .yummy: return "YUM!"
        case .tonight: return "今日份"
        case .homemade: return "厨房印章"
        case .perfect: return "100%"
        case .cheers: return "干杯"
        case .spicy: return "微辣刚好"
        case .cleanPlate: return "光盘"
        case .speechBubble: return "真香"
        case .bonAppetit: return "Bon Appetit"
        case .filmDate: return "胶片日期"
        case .starCluster: return "星光"
        case .curvedArrow: return "小箭头"
        case .heartDoodle: return "手绘心"
        case .wavyLine: return "波浪线"
        case .crown: return "小皇冠"
        case .washiTape: return "和纸胶带"
        }
    }
}

private enum CanvasLayoutPreset: String, CaseIterable {
    case collage
    case hero
    case magazine
    case grid

    var title: String {
        switch self {
        case .collage: return "错落拼贴"
        case .hero: return "主菜居中"
        case .magazine: return "杂志对角"
        case .grid: return "整齐画册"
        }
    }

    struct Placement {
        let position: CanvasPoint
        let scale: CGFloat
        let rotation: Double
    }

    func placements(count: Int) -> [Placement] {
        guard count > 0 else { return [] }
        if count == 1 {
            switch self {
            case .collage: return [Placement(position: CanvasPoint(x: 0.48, y: 0.46), scale: 1.24, rotation: -4)]
            case .hero: return [Placement(position: CanvasPoint(x: 0.50, y: 0.45), scale: 1.32, rotation: 0)]
            case .magazine: return [Placement(position: CanvasPoint(x: 0.54, y: 0.47), scale: 1.22, rotation: 5)]
            case .grid: return [Placement(position: CanvasPoint(x: 0.50, y: 0.46), scale: 1.18, rotation: 0)]
            }
        }
        switch self {
        case .collage:
            let base: [Placement] = [
                Placement(position: CanvasPoint(x: 0.30, y: 0.33), scale: 1.16, rotation: -5.5),
                Placement(position: CanvasPoint(x: 0.72, y: 0.43), scale: 0.94, rotation: 5.5),
                Placement(position: CanvasPoint(x: 0.27, y: 0.60), scale: 0.94, rotation: -3.5),
                Placement(position: CanvasPoint(x: 0.72, y: 0.64), scale: 1.02, rotation: 4.0),
                Placement(position: CanvasPoint(x: 0.50, y: 0.48), scale: 0.96, rotation: -2.5),
                Placement(position: CanvasPoint(x: 0.68, y: 0.29), scale: 0.88, rotation: 6.0)
            ]
            return (0..<count).map { base[$0 % base.count] }
        case .hero:
            var items: [Placement] = [
                Placement(position: CanvasPoint(x: 0.50, y: 0.44), scale: 1.24, rotation: -2.0)
            ]
            let satellites: [Placement] = [
                Placement(position: CanvasPoint(x: 0.24, y: 0.65), scale: 0.84, rotation: -6.0),
                Placement(position: CanvasPoint(x: 0.76, y: 0.63), scale: 0.84, rotation: 5.5),
                Placement(position: CanvasPoint(x: 0.25, y: 0.29), scale: 0.80, rotation: 4.5),
                Placement(position: CanvasPoint(x: 0.75, y: 0.30), scale: 0.80, rotation: -4.5),
                Placement(position: CanvasPoint(x: 0.50, y: 0.69), scale: 0.82, rotation: 2.0)
            ]
            for idx in 1..<count {
                items.append(satellites[(idx - 1) % satellites.count])
            }
            return items
        case .magazine:
            let base: [Placement] = [
                Placement(position: CanvasPoint(x: 0.34, y: 0.32), scale: 1.12, rotation: -3.5),
                Placement(position: CanvasPoint(x: 0.68, y: 0.52), scale: 1.10, rotation: 4.0),
                Placement(position: CanvasPoint(x: 0.32, y: 0.66), scale: 0.92, rotation: -2.5),
                Placement(position: CanvasPoint(x: 0.72, y: 0.31), scale: 0.88, rotation: 5.0),
                Placement(position: CanvasPoint(x: 0.52, y: 0.48), scale: 0.92, rotation: -4.0),
                Placement(position: CanvasPoint(x: 0.74, y: 0.68), scale: 0.86, rotation: 3.0)
            ]
            return (0..<count).map { base[$0 % base.count] }
        case .grid:
            let columns = 2
            let rows = max(1, (count + 1) / 2)
            let yStart: CGFloat = rows == 1 ? 0.47 : (rows == 2 ? 0.36 : 0.30)
            let yEnd: CGFloat = rows == 1 ? 0.47 : (rows == 2 ? 0.61 : 0.67)
            return (0..<count).map { idx in
                let col = idx % columns
                let row = idx / columns
                let x: CGFloat = (idx == count - 1 && count % 2 == 1) ? 0.50 : (col == 0 ? 0.30 : 0.70)
                let y: CGFloat = rows == 1 ? 0.47 : yStart + CGFloat(row) / CGFloat(max(rows - 1, 1)) * (yEnd - yStart)
                let rot = (col == 0 ? -2.0 : 2.0)
                return Placement(position: CanvasPoint(x: x, y: y), scale: count > 4 ? 0.84 : 0.96, rotation: rot)
            }
        }
    }
}

struct CanvasNote: Identifiable, Codable, Hashable {
    let id: UUID
    var text: String
    var isEmoji: Bool
    var position: CanvasPoint
    var scale: CGFloat
    var rotationDegrees: Double
    var layer: Int
    var textEffect: CanvasTextEffect
    var font: CanvasTextFont
    var color: CanvasTextColor
    var textStyle: CanvasTextStyle
    var doodle: CanvasDoodleKind?
    var emojiAsset: String?

    var isDoodle: Bool { doodle != nil }
    var isPlainText: Bool { !isEmoji && doodle == nil }

    init(
        id: UUID = UUID(),
        text: String,
        isEmoji: Bool,
        position: CanvasPoint,
        scale: CGFloat = 1,
        rotationDegrees: Double = 0,
        layer: Int = 0,
        textEffect: CanvasTextEffect = .plain,
        font: CanvasTextFont = .rounded,
        color: CanvasTextColor = .white,
        textStyle: CanvasTextStyle = .plain,
        doodle: CanvasDoodleKind? = nil,
        emojiAsset: String? = nil
    ) {
        self.id = id
        self.text = text
        self.isEmoji = isEmoji
        self.position = position
        self.scale = scale
        self.rotationDegrees = rotationDegrees
        self.layer = layer
        self.textEffect = textEffect
        self.font = font
        self.color = color
        self.textStyle = textStyle
        self.doodle = doodle
        self.emojiAsset = emojiAsset
    }

    private enum CodingKeys: String, CodingKey {
        case id, text, isEmoji, position, scale, rotationDegrees, layer, textEffect, font, color, textStyle, doodle, emojiAsset
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        isEmoji = try container.decode(Bool.self, forKey: .isEmoji)
        position = try container.decode(CanvasPoint.self, forKey: .position)
        scale = try container.decodeIfPresent(CGFloat.self, forKey: .scale) ?? 1
        rotationDegrees = try container.decodeIfPresent(Double.self, forKey: .rotationDegrees) ?? 0
        layer = try container.decodeIfPresent(Int.self, forKey: .layer) ?? 0
        textEffect = try container.decodeIfPresent(CanvasTextEffect.self, forKey: .textEffect) ?? .plain
        font = try container.decodeIfPresent(CanvasTextFont.self, forKey: .font) ?? .rounded
        color = try container.decodeIfPresent(CanvasTextColor.self, forKey: .color) ?? .white
        textStyle = try container.decodeIfPresent(CanvasTextStyle.self, forKey: .textStyle) ?? .plain
        doodle = try container.decodeIfPresent(CanvasDoodleKind.self, forKey: .doodle)
        emojiAsset = try container.decodeIfPresent(String.self, forKey: .emojiAsset)
    }
}

private struct CanvasStyledTextContent: View {
    let text: String
    let visibleText: String
    let font: CanvasTextFont
    let fontSize: CGFloat
    let color: CanvasTextColor
    let textStyle: CanvasTextStyle
    let isLightSurface: Bool
    var compact: Bool = false

    private var effectiveForeground: Color {
        switch textStyle {
        case .paper:
            return color == .white ? CanvasPalette.obsidianInk : color.color
        case .pill:
            let useDarkFill = color == .white || color == .butter || color == .mint || color == .sky
            return useDarkFill ? color.color : CanvasPalette.obsidianInk
        case .highlight:
            return color == .ink ? CanvasPalette.obsidianInk : color.color
        case .glass, .plain:
            return color.color
        }
    }

    var body: some View {
        let hPad: CGFloat = textStyle == .plain ? (compact ? 2 : 5) : (compact ? 8 : 14)
        let vPad: CGFloat = textStyle == .plain ? (compact ? 1 : 3) : (compact ? 4 : 8)

        ZStack {
            Text(text).hidden()
            Text(visibleText)
        }
        .font(font.font(size: fontSize, weight: .semibold))
        .tracking(0.35)
        .multilineTextAlignment(.center)
        .lineLimit(3)
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(effectiveForeground)
        .padding(.horizontal, hPad)
        .padding(.vertical, vPad)
        .background { backgroundView }
        .shadow(
            color: textStyle == .plain
                ? (color != .ink ? Color.black.opacity(isLightSurface ? 0.18 : 0.30) : Color.white.opacity(0.6))
                : (textStyle == .highlight ? .clear : Color.black.opacity(isLightSurface ? 0.12 : 0.24)),
            radius: textStyle == .plain ? (color == .ink && isLightSurface ? 1 : 8) : (compact ? 3 : 8),
            y: textStyle == .plain ? (color == .ink && isLightSurface ? 0.5 : 3) : (compact ? 1 : 4)
        )
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch textStyle {
        case .plain:
            Color.clear
        case .glass:
            let useDarkGlass = !isLightSurface || color == .white || color == .butter
            RoundedRectangle(cornerRadius: compact ? 10 : 16, style: .continuous)
                .fill(useDarkGlass ? Color.black.opacity(0.42) : Color.white.opacity(0.84))
                .overlay {
                    RoundedRectangle(cornerRadius: compact ? 10 : 16, style: .continuous)
                        .strokeBorder(useDarkGlass ? Color.white.opacity(0.32) : Color.black.opacity(0.10), lineWidth: 0.85)
                }
        case .pill:
            let useDarkFill = color == .white || color == .butter || color == .mint || color == .sky
            RoundedRectangle(cornerRadius: compact ? 10 : 16, style: .continuous)
                .fill(useDarkFill ? CanvasPalette.obsidianInk.opacity(0.92) : Color(red: 0.992, green: 0.988, blue: 0.976))
                .overlay {
                    RoundedRectangle(cornerRadius: compact ? 10 : 16, style: .continuous)
                        .strokeBorder(useDarkFill ? Color.white.opacity(0.14) : Color.black.opacity(0.08), lineWidth: 0.7)
                }
        case .paper:
            RoundedRectangle(cornerRadius: compact ? 5 : 8, style: .continuous)
                .fill(Color(red: 0.992, green: 0.976, blue: 0.941))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color(red: 0.89, green: 0.83, blue: 0.73).opacity(0.45))
                        .frame(width: compact ? 18 : 34, height: compact ? 3 : 5)
                        .offset(y: compact ? -1.5 : -2.5)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: compact ? 5 : 8, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.7)
                }
        case .highlight:
            let stripColor: Color = color == .ink
                ? Color(red: 0.98, green: 0.87, blue: 0.44).opacity(0.90)
                : (color == .white
                    ? Color(red: 0.74, green: 0.42, blue: 0.30).opacity(0.88)
                    : CanvasPalette.obsidianInk.opacity(0.76))
            RoundedRectangle(cornerRadius: compact ? 5 : 8, style: .continuous)
                .fill(stripColor)
                .padding(.vertical, compact ? 1 : 2)
                .rotationEffect(.degrees(-0.8))
        }
    }
}

private struct CanvasDoodleView: View {
    let kind: CanvasDoodleKind
    let tint: Color
    var isLightSurface: Bool = false
    var compact: Bool = false

    private static let filmDateString: String = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "''yy MM dd"
        return f.string(from: Date())
    }()

    var body: some View {
        let s: CGFloat = compact ? 0.56 : 1.0
        content(scale: s)
            .shadow(
                color: kind == .filmDate
                    ? Color(red: 1.0, green: 0.48, blue: 0.12).opacity(0.72)
                    : Color.black.opacity(isLightSurface ? 0.14 : 0.28),
                radius: kind == .filmDate ? (compact ? 3 : 7) : (compact ? 2 : 5),
                y: kind == .filmDate ? 0 : (compact ? 1 : 2.5)
            )
    }

    @ViewBuilder
    private func content(scale s: CGFloat) -> some View {
        switch kind {
        case .yummy:
            VStack(spacing: 2 * s) {
                Text("YUM!")
                    .font(.system(size: 26 * s, weight: .black, design: .rounded))
                    .italic()
                    .foregroundStyle(tint)
                RoundedRectangle(cornerRadius: 2 * s)
                    .fill(tint)
                    .frame(width: 56 * s, height: 3.2 * s)
                    .rotationEffect(.degrees(-2))
            }
            .padding(.horizontal, 8 * s)
            .padding(.vertical, 4 * s)
            .rotationEffect(.degrees(-5))

        case .tonight:
            HStack(spacing: 5 * s) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 12 * s, weight: .bold))
                Text("今日份")
                    .font(.system(size: 14 * s, weight: .bold, design: .rounded))
            }
            .foregroundStyle(tint == .white ? CanvasPalette.obsidianInk : .white)
            .padding(.horizontal, 12 * s)
            .padding(.vertical, 6 * s)
            .background(tint, in: Capsule())

        case .homemade:
            ZStack {
                Circle()
                    .strokeBorder(tint, lineWidth: max(1.2, 2.0 * s))
                    .frame(width: 72 * s, height: 72 * s)
                Circle()
                    .strokeBorder(tint.opacity(0.75), style: StrokeStyle(lineWidth: max(0.8, 1.1 * s), dash: [3 * s, 2.5 * s]))
                    .frame(width: 61 * s, height: 61 * s)
                VStack(spacing: 1 * s) {
                    Text("HOME")
                        .font(.system(size: 10.5 * s, weight: .black, design: .rounded))
                        .tracking(1.1 * s)
                    Image(systemName: "fork.knife")
                        .font(.system(size: 9 * s, weight: .bold))
                    Text("MADE")
                        .font(.system(size: 10.5 * s, weight: .black, design: .rounded))
                        .tracking(1.1 * s)
                }
                .foregroundStyle(tint)
            }
            .rotationEffect(.degrees(-8))

        case .perfect:
            VStack(spacing: 1 * s) {
                Text("100%")
                    .font(.system(size: 24 * s, weight: .heavy, design: .rounded))
                    .foregroundStyle(tint)
                Path { path in
                    path.move(to: CGPoint(x: 4 * s, y: 2 * s))
                    path.addQuadCurve(to: CGPoint(x: 60 * s, y: 1 * s), control: CGPoint(x: 32 * s, y: 6 * s))
                    path.move(to: CGPoint(x: 10 * s, y: 7 * s))
                    path.addQuadCurve(to: CGPoint(x: 54 * s, y: 6 * s), control: CGPoint(x: 32 * s, y: 10 * s))
                }
                .stroke(tint, style: StrokeStyle(lineWidth: max(1.3, 2.2 * s), lineCap: .round))
                .frame(width: 64 * s, height: 11 * s)
            }
            .rotationEffect(.degrees(-4))

        case .cheers:
            HStack(spacing: 4 * s) {
                Text("干杯")
                    .font(.system(size: 16 * s, weight: .bold, design: .rounded))
                Text("✦")
                    .font(.system(size: 13 * s, weight: .bold))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 12 * s)
            .padding(.vertical, 6 * s)
            .overlay {
                RoundedRectangle(cornerRadius: 12 * s, style: .continuous)
                    .strokeBorder(tint, style: StrokeStyle(lineWidth: max(1.2, 1.8 * s), dash: [5 * s, 3 * s]))
            }
            .rotationEffect(.degrees(3))

        case .spicy:
            HStack(spacing: 4 * s) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 12 * s))
                    .foregroundStyle(Color(red: 0.96, green: 0.42, blue: 0.34))
                Text("微辣刚好")
                    .font(.system(size: 12.5 * s, weight: .bold, design: .rounded))
                    .foregroundStyle(CanvasPalette.obsidianInk)
            }
            .padding(.horizontal, 11 * s)
            .padding(.vertical, 6 * s)
            .background(Color(red: 0.992, green: 0.986, blue: 0.968), in: Capsule())

        case .cleanPlate:
            HStack(spacing: 4 * s) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 13 * s))
                Text("光盘行动")
                    .font(.system(size: 13 * s, weight: .bold, design: .rounded))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 11 * s)
            .padding(.vertical, 5 * s)
            .overlay {
                Capsule().strokeBorder(tint, lineWidth: max(1.2, 1.8 * s))
            }

        case .speechBubble:
            VStack(spacing: 0) {
                Text("真香!")
                    .font(.system(size: 15 * s, weight: .bold, design: .rounded))
                    .foregroundStyle(CanvasPalette.obsidianInk)
                    .padding(.horizontal, 13 * s)
                    .padding(.vertical, 7 * s)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 14 * s, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14 * s, style: .continuous)
                            .strokeBorder(CanvasPalette.obsidianInk.opacity(0.14), lineWidth: 0.8)
                    }
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 11 * s, y: 0))
                    path.addLine(to: CGPoint(x: 3 * s, y: 8 * s))
                    path.closeSubpath()
                }
                .fill(Color.white)
                .frame(width: 11 * s, height: 8 * s)
                .offset(x: -10 * s, y: -1 * s)
            }

        case .bonAppetit:
            VStack(spacing: 2 * s) {
                Image(systemName: "sparkle")
                    .font(.system(size: 10 * s, weight: .bold))
                Text("Bon Appétit")
                    .font(.system(size: 20 * s, weight: .semibold, design: .serif))
                    .italic()
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 6 * s)

        case .filmDate:
            Text(Self.filmDateString)
                .font(.system(size: 18 * s, weight: .bold, design: .monospaced))
                .tracking(1.6 * s)
                .foregroundStyle(Color(red: 1.0, green: 0.56, blue: 0.14))
                .padding(.horizontal, 8 * s)
                .padding(.vertical, 4 * s)

        case .starCluster:
            Canvas { context, size in
                func addStar(cx: CGFloat, cy: CGFloat, r: CGFloat) {
                    var star = Path()
                    star.move(to: CGPoint(x: cx, y: cy - r))
                    star.addQuadCurve(to: CGPoint(x: cx + r, y: cy), control: CGPoint(x: cx + r * 0.16, y: cy - r * 0.16))
                    star.addQuadCurve(to: CGPoint(x: cx, y: cy + r), control: CGPoint(x: cx + r * 0.16, y: cy + r * 0.16))
                    star.addQuadCurve(to: CGPoint(x: cx - r, y: cy), control: CGPoint(x: cx - r * 0.16, y: cy + r * 0.16))
                    star.addQuadCurve(to: CGPoint(x: cx, y: cy - r), control: CGPoint(x: cx - r * 0.16, y: cy - r * 0.16))
                    star.closeSubpath()
                    context.fill(star, with: .color(tint))
                }
                addStar(cx: size.width * 0.34, cy: size.height * 0.48, r: 19 * s)
                addStar(cx: size.width * 0.72, cy: size.height * 0.28, r: 11 * s)
                addStar(cx: size.width * 0.70, cy: size.height * 0.74, r: 7.5 * s)
            }
            .frame(width: 68 * s, height: 58 * s)

        case .curvedArrow:
            Canvas { context, size in
                let w = size.width
                let h = size.height
                var shaft = Path()
                shaft.move(to: CGPoint(x: w * 0.14, y: h * 0.80))
                shaft.addQuadCurve(to: CGPoint(x: w * 0.84, y: h * 0.24), control: CGPoint(x: w * 0.26, y: h * 0.22))
                context.stroke(shaft, with: .color(tint), style: StrokeStyle(lineWidth: max(1.8, 3.2 * s), lineCap: .round, lineJoin: .round))

                var head = Path()
                head.move(to: CGPoint(x: w * 0.64, y: h * 0.16))
                head.addLine(to: CGPoint(x: w * 0.86, y: h * 0.23))
                head.addLine(to: CGPoint(x: w * 0.72, y: h * 0.44))
                context.stroke(head, with: .color(tint), style: StrokeStyle(lineWidth: max(1.8, 3.2 * s), lineCap: .round, lineJoin: .round))
            }
            .frame(width: 74 * s, height: 56 * s)

        case .heartDoodle:
            Canvas { context, size in
                let w = size.width
                let h = size.height
                var heart = Path()
                heart.move(to: CGPoint(x: w * 0.50, y: h * 0.86))
                heart.addCurve(
                    to: CGPoint(x: w * 0.14, y: h * 0.32),
                    control1: CGPoint(x: w * 0.18, y: h * 0.66),
                    control2: CGPoint(x: w * 0.08, y: h * 0.44)
                )
                heart.addCurve(
                    to: CGPoint(x: w * 0.50, y: h * 0.30),
                    control1: CGPoint(x: w * 0.20, y: h * 0.12),
                    control2: CGPoint(x: w * 0.46, y: h * 0.16)
                )
                heart.addCurve(
                    to: CGPoint(x: w * 0.86, y: h * 0.34),
                    control1: CGPoint(x: w * 0.56, y: h * 0.14),
                    control2: CGPoint(x: w * 0.82, y: h * 0.12)
                )
                heart.addCurve(
                    to: CGPoint(x: w * 0.46, y: h * 0.88),
                    control1: CGPoint(x: w * 0.90, y: h * 0.56),
                    control2: CGPoint(x: w * 0.66, y: h * 0.72)
                )
                context.stroke(heart, with: .color(tint), style: StrokeStyle(lineWidth: max(1.8, 3.2 * s), lineCap: .round, lineJoin: .round))
            }
            .frame(width: 64 * s, height: 56 * s)

        case .wavyLine:
            Canvas { context, size in
                let w = size.width
                let midY = size.height / 2
                let amp: CGFloat = 7 * s
                var wave = Path()
                wave.move(to: CGPoint(x: 4 * s, y: midY))
                let segments = 5
                let step = (w - 8 * s) / CGFloat(segments)
                for idx in 0..<segments {
                    let x0 = 4 * s + CGFloat(idx) * step
                    let xMid = x0 + step * 0.5
                    let x1 = x0 + step
                    let yCtrl = midY + (idx % 2 == 0 ? -amp : amp)
                    wave.addQuadCurve(to: CGPoint(x: x1, y: midY), control: CGPoint(x: xMid, y: yCtrl))
                }
                context.stroke(wave, with: .color(tint), style: StrokeStyle(lineWidth: max(1.8, 3.0 * s), lineCap: .round, lineJoin: .round))
            }
            .frame(width: 96 * s, height: 28 * s)

        case .crown:
            Canvas { context, size in
                let w = size.width
                let h = size.height
                var path = Path()
                path.move(to: CGPoint(x: w * 0.16, y: h * 0.74))
                path.addLine(to: CGPoint(x: w * 0.14, y: h * 0.30))
                path.addLine(to: CGPoint(x: w * 0.36, y: h * 0.54))
                path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.22))
                path.addLine(to: CGPoint(x: w * 0.64, y: h * 0.54))
                path.addLine(to: CGPoint(x: w * 0.86, y: h * 0.30))
                path.addLine(to: CGPoint(x: w * 0.84, y: h * 0.74))
                path.closeSubpath()
                context.stroke(path, with: .color(tint), style: StrokeStyle(lineWidth: max(1.6, 2.8 * s), lineCap: .round, lineJoin: .round))
            }
            .frame(width: 66 * s, height: 48 * s)

        case .washiTape:
            ZStack {
                RoundedRectangle(cornerRadius: 2 * s, style: .continuous)
                    .fill(Color(red: 0.965, green: 0.918, blue: 0.788).opacity(0.84))
                    .frame(width: 88 * s, height: 22 * s)
                    .overlay {
                        HStack(spacing: 8 * s) {
                            ForEach(0..<6, id: \.self) { _ in
                                Rectangle()
                                    .fill(Color(red: 0.84, green: 0.75, blue: 0.58).opacity(0.32))
                                    .frame(width: 2.5 * s, height: 22 * s)
                                    .rotationEffect(.degrees(18))
                            }
                        }
                        .clipped()
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 2 * s, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.42), lineWidth: 0.7)
                    }
            }
        }
    }
}

private struct CanvasNoteView: View {
    @Binding var note: CanvasNote
    let canvasSize: CGSize
    let isSelected: Bool
    var freezesMotion = false
    var reportsBounds = false
    var isLightSurface: Bool = false
    var canMoveForward: Bool = true
    var canMoveBackward: Bool = true
    var alignmentTargets: [CanvasPoint] = []
    var remotePreview: CanvasRemoteLivePreview? = nil
    var onTransformStart: () -> Void = {}
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onTransform: () -> Void
    let onLayerMove: (CanvasLayerMove) -> Void
    let onDelete: () -> Void
    var onDuplicate: (() -> Void)? = nil
    var onLiveChange: (() -> Void)? = nil
    let onChange: () -> Void

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.scenePhase) private var scenePhase
    private var reduceMotion: Bool { freezesMotion || systemReduceMotion }

    @State private var isGestureActive = false
    @State private var hasAppeared = false
    @State private var isHandleActive = false

    private var isManipulating: Bool { isGestureActive || isHandleActive }

    private var textFontSize: CGFloat {
        let count = note.text.count
        if count > 18 { return 16 }
        if count > 11 { return 18 }
        return 21
    }

    var body: some View {
        let activePreview = isManipulating ? nil : remotePreview
        let displayPosition = activePreview?.position ?? note.position
        let displayScale = activePreview?.scale ?? note.scale
        let displayRotation = activePreview?.rotationDegrees ?? note.rotationDegrees
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion || scenePhase != .active || isSelected || isManipulating || activePreview != nil || note.textEffect == .plain)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let effectsPaused = reduceMotion || isSelected || isManipulating || activePreview != nil
            let phase = note.id.motionPhaseOffset
            let visible = note.textEffect.visibleText(note.text, time: time, reduceMotion: effectsPaused)

            Group {
                if let doodle = note.doodle {
                    CanvasDoodleView(
                        kind: doodle,
                        tint: note.color.color,
                        isLightSurface: isLightSurface,
                        compact: false
                    )
                } else if note.isEmoji {
                    if let asset = note.emojiAsset {
                        Image(asset)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 78, height: 78)
                            .shadow(color: Color.black.opacity(isLightSurface ? 0.14 : 0.30), radius: 9, y: 4)
                            .shadow(color: Color.black.opacity(isLightSurface ? 0.06 : 0.16), radius: 2, y: 1)
                    } else {
                        ZStack {
                            Text(note.text).hidden()
                            Text(visible)
                        }
                        .font(.system(size: 38))
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .foregroundStyle(.white)
                        .shadow(color: Color.black.opacity(isLightSurface ? 0.18 : 0.30), radius: 8, y: 3)
                        .shadow(color: Color.black.opacity(isLightSurface ? 0.06 : 0.22), radius: 2, y: 1)
                    }
                } else {
                    CanvasStyledTextContent(
                        text: note.text,
                        visibleText: visible,
                        font: note.font,
                        fontSize: textFontSize,
                        color: note.color,
                        textStyle: note.textStyle,
                        isLightSurface: isLightSurface
                    )
                }
            }
            .opacity(note.textEffect.opacity(time: time, reduceMotion: effectsPaused))
            .offset(note.textEffect.offset(time: time, phase: phase, reduceMotion: effectsPaused))
            .scaleEffect(x: note.textEffect.scaleX(time: time, reduceMotion: effectsPaused), y: note.textEffect.scaleY(time: time, reduceMotion: effectsPaused))
            .rotationEffect(.degrees(note.textEffect.rotation(time: time, reduceMotion: effectsPaused)))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isSelected)
        }
        // 完整文字保留排版尺寸，打字过程中选中框和触摸区域保持稳定。
        .padding(.horizontal, note.isEmoji ? 10 : 14)
        .padding(.vertical, note.isEmoji ? 10 : 10)
        .frame(minWidth: note.isEmoji ? 82 : (note.isDoodle ? 82 : 136), minHeight: note.isEmoji ? 82 : 60)
        .contentShape(Rectangle())
        .scaleEffect(min(max(displayScale, 0.3), 3) * (hasAppeared || reduceMotion ? 1 : 0.86))
        .rotationEffect(.degrees(displayRotation))
        .overlay(alignment: .top) {
            if let activePreview {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(red: 0.44, green: 0.88, blue: 0.56))
                        .frame(width: 5.5, height: 5.5)
                    Text(activePreview.actor.nickname)
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(CanvasPalette.obsidianInk.opacity(0.88), in: Capsule())
                .overlay {
                    Capsule().strokeBorder(Color.white.opacity(0.24), lineWidth: 0.6)
                }
                .shadow(color: Color.black.opacity(0.20), radius: 5, y: 2)
                .offset(y: -14)
                .allowsHitTesting(false)
            }
        }
        .opacity(hasAppeared || reduceMotion ? 1 : 0)
        .animation(reduceMotion || isManipulating ? nil : .easeOut(duration: 0.08), value: activePreview)
        .onTapGesture {
            if isSelected && note.isPlainText {
                Haptics.light()
                onEdit()
            } else {
                onSelect()
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.74), value: note.textEffect)
        .contextMenu {
            elementContextMenu
        }
        .accessibilityLabel(note.doodle.map { "\($0.title)手绘贴纸" } ?? (note.isEmoji ? "\(note.text)表情" : "画布文字"))
        .accessibilityValue("\(Int((note.scale * 100).rounded()))%，\(note.textEffect.title)")
        .accessibilityHint("拖动内容移动，选中后拖动旋转或缩放手柄；双指可缩放或旋转")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { onSelect() }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.72)) {
                hasAppeared = true
            }
        }
        .overlay {
            if isSelected {
                GeometryReader { proxy in
                    Color.clear
                        .allowsHitTesting(false)
                        .preference(key: CanvasTransformOverlayKey.self, value: CanvasTransformOverlay(
                            selection: .note(note.id),
                            controls: CanvasTransformControls(size: proxy.size, canvasSize: canvasSize,
                                rotationDegrees: $note.rotationDegrees,
                                position: $note.position,
                                scale: $note.scale, isHandleActive: $isHandleActive,
                                isLightSurface: isLightSurface,
                                onTransformStart: onTransformStart,
                                onLiveChange: onLiveChange,
                                onChange: onChange),
                            size: proxy.size))
                }
            }
        }
        .modifier(CanvasElementBoundsReporter(selection: .note(note.id), canvasSize: canvasSize,
            position: note.position, scale: note.scale, rotation: note.rotationDegrees,
            isEnabled: reportsBounds))
        .modifier(CanvasManipulation(position: $note.position, scale: $note.scale,
            rotationDegrees: $note.rotationDegrees, isGestureActive: $isGestureActive,
            canvasSize: canvasSize, alignmentTargets: alignmentTargets, isSelected: isSelected, isHandleActive: isHandleActive,
            onTransformStart: onTransformStart,
            onSelect: onSelect, onLiveChange: onLiveChange, onChange: onChange))
        .position(
            x: canvasSize.width * displayPosition.x,
            y: canvasSize.height * displayPosition.y
        )
    }

    @ViewBuilder
    private var elementContextMenu: some View {
        if note.isPlainText {
            Button("编辑文字", systemImage: "pencil", action: onEdit)
        }
        Button("精细调整", systemImage: "arrow.up.left.and.arrow.down.right", action: onTransform)
        if let onDuplicate {
            Button("复制一份", systemImage: "doc.on.doc", action: onDuplicate)
        }
        Section("层级") {
            Button("置顶", systemImage: "arrow.up.to.line") {
                onLayerMove(.front)
            }
            .disabled(!canMoveForward)
            Button("上移一层", systemImage: "chevron.up") {
                onLayerMove(.forward)
            }
            .disabled(!canMoveForward)
            Button("下移一层", systemImage: "chevron.down") {
                onLayerMove(.backward)
            }
            .disabled(!canMoveBackward)
            Button("置底", systemImage: "arrow.down.to.line") {
                onLayerMove(.back)
            }
            .disabled(!canMoveBackward)
        }
        Button("删除", systemImage: "trash", role: .destructive, action: onDelete)
    }
}

private struct CanvasStrokeDrawingLayer: View {
    let strokes: [CanvasStroke]
    let activeStroke: [CGPoint]
    var remoteActiveStrokes: [CanvasStroke] = []
    let paintColor: Color
    let style: CanvasBrushStyle
    let width: CGFloat

    private func resolvedPoints(for stroke: CanvasStroke, in size: CGSize) -> [CGPoint] {
        guard stroke.isNormalized else { return stroke.points }
        let w = max(size.width, 1)
        let h = max(size.height, 1)
        return stroke.points.map { CGPoint(x: $0.x * w, y: $0.y * h) }
    }

    private func smoothedPath(for points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        if points.count == 2 {
            path.addLine(to: points[1])
            return path
        }
        for idx in 1..<points.count {
            let prev = points[idx - 1]
            let curr = points[idx]
            let mid = CGPoint(x: (prev.x + curr.x) * 0.5, y: (prev.y + curr.y) * 0.5)
            path.addQuadCurve(to: mid, control: prev)
        }
        if let last = points.last {
            path.addLine(to: last)
        }
        return path
    }

    private func drawStroke(in context: inout GraphicsContext, points: [CGPoint], color: Color, style: CanvasBrushStyle, width: CGFloat) {
        guard let first = points.first else { return }
        let strokeWidth = width * style.lineWidthMultiplier
        if style == .dotted {
            for point in points {
                context.fill(
                    Path(ellipseIn: CGRect(x: point.x - strokeWidth / 2, y: point.y - strokeWidth / 2, width: strokeWidth, height: strokeWidth)),
                    with: .color(color.opacity(style.opacity))
                )
            }
            return
        }

        if style == .neon {
            if points.count == 1 {
                let outer = strokeWidth * 2.8
                let mid = strokeWidth * 1.7
                let core = strokeWidth * 0.65
                context.fill(Path(ellipseIn: CGRect(x: first.x - outer / 2, y: first.y - outer / 2, width: outer, height: outer)), with: .color(color.opacity(0.22)))
                context.fill(Path(ellipseIn: CGRect(x: first.x - mid / 2, y: first.y - mid / 2, width: mid, height: mid)), with: .color(color.opacity(0.50)))
                context.fill(Path(ellipseIn: CGRect(x: first.x - core / 2, y: first.y - core / 2, width: core, height: core)), with: .color(Color.white.opacity(0.96)))
                return
            }
            let path = smoothedPath(for: points)
            context.stroke(path, with: .color(color.opacity(0.22)), style: StrokeStyle(lineWidth: strokeWidth * 2.8, lineCap: .round, lineJoin: .round))
            context.stroke(path, with: .color(color.opacity(0.50)), style: StrokeStyle(lineWidth: strokeWidth * 1.7, lineCap: .round, lineJoin: .round))
            context.stroke(path, with: .color(Color.white.opacity(0.96)), style: StrokeStyle(lineWidth: max(1.5, strokeWidth * 0.62), lineCap: .round, lineJoin: .round))
            return
        }

        if points.count == 1 {
            context.fill(
                Path(ellipseIn: CGRect(x: first.x - strokeWidth / 2, y: first.y - strokeWidth / 2, width: strokeWidth, height: strokeWidth)),
                with: .color(color.opacity(style.opacity))
            )
        } else {
            let path = smoothedPath(for: points)
            context.stroke(
                path,
                with: .color(color.opacity(style.opacity)),
                style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round, dash: style == .dashed ? [strokeWidth * 1.8, strokeWidth * 1.4] : [])
            )
        }
    }

    var body: some View {
        Canvas { context, size in
            for stroke in strokes {
                let strokeColor = stroke.customColor?.color ?? stroke.color.color
                let points = resolvedPoints(for: stroke, in: size)
                drawStroke(in: &context, points: points, color: strokeColor, style: stroke.style, width: stroke.width)
            }
            for remoteStroke in remoteActiveStrokes {
                let strokeColor = remoteStroke.customColor?.color ?? remoteStroke.color.color
                let points = resolvedPoints(for: remoteStroke, in: size)
                drawStroke(in: &context, points: points, color: strokeColor, style: remoteStroke.style, width: remoteStroke.width)
            }
            drawStroke(in: &context, points: activeStroke, color: paintColor, style: style, width: width)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CanvasDrawingView: View {
    @Binding var strokes: [CanvasStroke]
    @Binding var activeStroke: [CGPoint]
    var remoteActiveStrokes: [CanvasStroke] = []
    let isEnabled: Bool
    let brush: CanvasBrushColor
    let paintColor: Color
    let style: CanvasBrushStyle
    let width: CGFloat
    var onStart: () -> Void = {}
    var onLiveStroke: (([CGPoint]) -> Void)? = nil
    let onEnd: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                CanvasStrokeDrawingLayer(
                    strokes: strokes,
                    activeStroke: activeStroke,
                    remoteActiveStrokes: remoteActiveStrokes,
                    paintColor: paintColor,
                    style: style,
                    width: width
                )
                .frame(width: proxy.size.width, height: proxy.size.height)

                // The hit layer must exactly cover the canvas. An unconstrained
                // transparent Rectangle can collapse to the trailing side in a
                // ScrollView and makes drawing appear offset or unavailable.
                if isEnabled {
                    Rectangle()
                        .fill(.black.opacity(0.001))
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .contentShape(Rectangle())
                        .highPriorityGesture(drawGesture(in: proxy.size), including: .all)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .allowsHitTesting(isEnabled)
    }

    private func normalizedPoints(from rawPoints: [CGPoint], in size: CGSize) -> [CGPoint] {
        let w = max(size.width, 1)
        let h = max(size.height, 1)
        return rawPoints.map { CGPoint(x: $0.x / w, y: $0.y / h) }
    }

    private func drawGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if activeStroke.isEmpty {
                    onStart()
                    activeStroke = [value.startLocation]
                    onLiveStroke?(normalizedPoints(from: activeStroke, in: size))
                }
                if let last = activeStroke.last, hypot(value.location.x - last.x, value.location.y - last.y) < 2.0 {
                    return
                }
                activeStroke.append(value.location)
                onLiveStroke?(normalizedPoints(from: activeStroke, in: size))
            }
            .onEnded { _ in
                guard !activeStroke.isEmpty else { return }
                let normalized = normalizedPoints(from: activeStroke, in: size)
                strokes.append(
                    CanvasStroke(
                        points: normalized,
                        color: brush,
                        customColor: CanvasRGBA(color: paintColor),
                        style: style,
                        width: width,
                        isNormalized: true
                    )
                )
                activeStroke.removeAll()
                onEnd()
            }
    }
}

private struct LiveControlButton: View {
    let title: String
    var shortLabel: String? = nil
    let icon: String
    var isLightSurface = true
    var isActive = false
    var isDisabled = false
    let action: () -> Void

    private var glyph: ProductIcon.Kind? {
        switch icon {
        case "plus": return .add
        case "textformat": return .text
        case "face.smiling": return .sticker
        case "pencil": return .draw
        case "photo": return .background
        case "rectangle.3.group": return .layout
        case "arrow.uturn.backward": return .undo
        case "arrow.uturn.forward": return .redo
        case "trash": return .trash
        case "slider.horizontal.3": return .adjust
        case "checkmark": return .check
        case "selection": return .select
        case "selection.all": return .selectAll
        default: return nil
        }
    }

    var body: some View {
        let baseInk = isLightSurface ? CanvasPalette.obsidianInk : Color.white
        let activeBackground = isLightSurface ? Color.black.opacity(0.08) : Color.white.opacity(0.20)
        Button {
            Haptics.light()
            action()
        } label: {
            VStack(spacing: 1) {
                Group {
                    if let glyph {
                        ProductIcon(kind: glyph, size: shortLabel == nil ? 16 : 15, weight: isActive ? .semibold : .medium)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: shortLabel == nil ? 16 : 15, weight: isActive ? .semibold : .medium))
                    }
                }
                if let shortLabel {
                    Text(shortLabel)
                        .font(.system(size: 9.5, weight: isActive ? .semibold : .medium, design: .rounded))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(baseInk)
            .frame(width: shortLabel == nil ? 36 : 41, height: shortLabel == nil ? 38 : 46)
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: shortLabel == nil ? 18 : 14, style: .continuous)
                        .fill(activeBackground)
                }
            }
            .contentShape(Rectangle())
            .opacity(isDisabled ? 0.35 : 1)
        }
        .buttonStyle(CanvasPressStyle(scale: 0.90))
        .disabled(isDisabled)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

private struct CanvasElementActionBar: View {
    let title: String
    let canEditText: Bool
    var canDuplicate: Bool = false
    let isDeleting: Bool
    let layers: [CanvasLayerEntry]
    let selection: CanvasSelection
    let onSelect: (CanvasSelection) -> Void
    let onEditText: () -> Void
    let onEdit: () -> Void
    var onDuplicate: (() -> Void)? = nil
    let onLayerMove: (CanvasLayerMove) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(CanvasPalette.obsidianInk)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(maxWidth: 84, alignment: .leading)
                    .padding(.leading, 12)
                    .padding(.trailing, 4)

                Divider()
                    .frame(height: 16)
                    .overlay(Color.black.opacity(0.12))
                    .padding(.horizontal, 2)
            }

            if canEditText {
                Button {
                    Haptics.light()
                    onEditText()
                } label: {
                    ProductIcon(kind: .draw)
                        .foregroundStyle(CanvasPalette.obsidianInk)
                        .frame(width: 38, height: 40)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("编辑文字")
            }
            Button {
                Haptics.light()
                onEdit()
            } label: {
                ProductIcon(kind: .effects)
                    .foregroundStyle(CanvasPalette.obsidianInk)
                    .frame(width: 38, height: 40)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("添加特效")

            layerMenu
                .foregroundStyle(CanvasPalette.obsidianInk)

            Button(role: .destructive) {
                Haptics.light()
                onDelete()
            } label: {
                Group {
                    if isDeleting {
                        ProgressView().tint(CanvasPalette.obsidianInk)
                    } else {
                        ProductIcon(kind: .trash)
                            .foregroundStyle(Color(red: 0.78, green: 0.24, blue: 0.24))
                    }
                }
                .frame(width: 38, height: 40)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("删除元素")
        }
        .fixedSize()
        .font(.system(size: 13, weight: .medium))
        .lineLimit(1)
        .foregroundStyle(CanvasPalette.obsidianInk)
        .padding(.horizontal, 4)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule().fill(Color.white.opacity(0.92))
                }
        }
        .overlay {
            Capsule()
                .strokeBorder(Color.black.opacity(0.10), lineWidth: 0.7)
        }
        .shadow(color: CanvasPalette.obsidianInk.opacity(0.14), radius: 10, y: 4)
        .buttonStyle(CanvasPressStyle(scale: 0.88))
        .disabled(isDeleting)
        .preferredColorScheme(.light)
    }

    private var layerMenu: some View {
        let isTop = layers.first?.selection == selection
        let isBottom = layers.last?.selection == selection
        return Menu {
            if canDuplicate, let onDuplicate {
                Button("复制一份", systemImage: "doc.on.doc", action: onDuplicate)
            }
            Section("层级") {
                Button("置顶", systemImage: "arrow.up.to.line") {
                    onLayerMove(.front)
                }
                .disabled(isTop)
                Button("上移一层", systemImage: "chevron.up") {
                    onLayerMove(.forward)
                }
                .disabled(isTop)
                Button("下移一层", systemImage: "chevron.down") {
                    onLayerMove(.backward)
                }
                .disabled(isBottom)
                Button("置底", systemImage: "arrow.down.to.line") {
                    onLayerMove(.back)
                }
                .disabled(isBottom)
            }
            Menu("选择内容", systemImage: "square.stack") {
                ForEach(layers, id: \.selection) { entry in
                    let isCurrent = entry.selection == selection
                    Button(entry.title, systemImage: isCurrent ? "checkmark" : entry.icon) {
                        onSelect(entry.selection)
                    }
                    .accessibilityAddTraits(isCurrent ? .isSelected : [])
                }
            }
        } label: {
            ProductIcon(kind: .layers)
                .frame(minWidth: 40, minHeight: 44)
        }
        .accessibilityLabel("调整图层")
        .accessibilityHint("可复制、选择被遮住的内容，或调整前后层级")
    }
}

private enum CanvasInsertItem: String, CaseIterable, Identifiable {
    case text
    case emoji

    var id: String { rawValue }

    var title: String {
        switch self {
        case .text: return "写一句"
        case .emoji: return "放表情"
        }
    }

    var icon: String {
        switch self {
        case .text: return "textformat"
        case .emoji: return "face.smiling"
        }
    }
}

// MARK: - 自由画布开屏模板、持久化与全屏工坊

enum LaunchCanvasTemplate: String, CaseIterable, Identifiable {
    case morningTable
    case sunlitPicnic
    case nightFilm
    case blankPaper

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morningTable: return "晨光餐桌"
        case .sunlitPicnic: return "暖阳野餐"
        case .nightFilm: return "夜色胶片"
        case .blankPaper: return "留白画纸"
        }
    }

    var subtitle: String {
        switch self {
        case .morningTable: return "温柔晨光 + 干杯贴纸"
        case .sunlitPicnic: return "野餐草地 + 暖阳滤镜"
        case .nightFilm: return "暖光咖啡 + 胶片氛围"
        case .blankPaper: return "极简斜阳画纸自由挥洒"
        }
    }

    fileprivate var previewBackground: CanvasBackground {
        switch self {
        case .morningTable: return .morningTable
        case .sunlitPicnic: return .meadow
        case .nightFilm: return .gingham
        case .blankPaper: return .linen
        }
    }

    fileprivate var previewAccentAsset: String? {
        switch self {
        case .morningTable: return "StickerEmoji_food_cheers"
        case .sunlitPicnic: return "StickerEmoji_vibe_cat"
        case .nightFilm: return "StickerEmoji_mood_star_eyes"
        case .blankPaper: return nil
        }
    }
}

struct LaunchCanvasDocumentPayload {
    fileprivate let document: CanvasDocument

    var isLightSurface: Bool {
        (CanvasBackground(rawValue: document.background) ?? .morningTable).isLightSurface
    }
}

enum LaunchCanvasStore {
    private static var documentURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("launch_canvas_document_v1.json")
    }

    private static var todayStampText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "M.dd · EEEE"
        return f.string(from: Date())
    }

    static func hasSavedDocument() -> Bool {
        FileManager.default.fileExists(atPath: documentURL.path)
    }

    static func loadOrDefaultPayload() -> LaunchCanvasDocumentPayload {
        if let data = try? Data(contentsOf: documentURL),
           let doc = try? JSONDecoder().decode(CanvasDocument.self, from: data) {
            return LaunchCanvasDocumentPayload(document: doc)
        }
        return makeTemplatePayload(.morningTable)
    }

    static func save(_ payload: LaunchCanvasDocumentPayload) {
        do {
            try FileManager.default.createDirectory(
                at: documentURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(payload.document)
            try data.write(to: documentURL, options: .atomic)
        } catch {
            // Keep prior saved launch document if disk write fails.
        }
    }

    @discardableResult
    static func resetToDefault() -> LaunchCanvasDocumentPayload {
        try? FileManager.default.removeItem(at: documentURL)
        return makeTemplatePayload(.morningTable)
    }

    static func isLightSurface(for payload: LaunchCanvasDocumentPayload? = nil) -> Bool {
        (payload ?? loadOrDefaultPayload()).isLightSurface
    }

    static func makeTemplatePayload(_ template: LaunchCanvasTemplate) -> LaunchCanvasDocumentPayload {
        let defaultSize = CGSize(width: 402, height: 874)
        let notes: [CanvasNote]
        let bg: CanvasBackground
        let filter: CanvasMoodFilter

        switch template {
        case .morningTable:
            bg = .morningTable
            filter = .none
            notes = [
                CanvasNote(
                    text: todayStampText,
                    isEmoji: false,
                    position: CanvasPoint(x: 0.5, y: 0.34),
                    scale: 0.90,
                    layer: 0,
                    textEffect: .float,
                    font: .handwritten,
                    color: .white,
                    textStyle: .plain
                ),
                CanvasNote(
                    text: "干杯",
                    isEmoji: true,
                    position: CanvasPoint(x: 0.5, y: 0.46),
                    scale: 1.28,
                    layer: 1,
                    textEffect: .float,
                    emojiAsset: "StickerEmoji_food_cheers"
                ),
                CanvasNote(
                    text: "今天吃什么呢",
                    isEmoji: false,
                    position: CanvasPoint(x: 0.5, y: 0.58),
                    scale: 1.32,
                    layer: 2,
                    textEffect: .float,
                    font: .rounded,
                    color: .white,
                    textStyle: .plain
                ),
                CanvasNote(
                    text: "把这一顿，摆成一张会动的画",
                    isEmoji: false,
                    position: CanvasPoint(x: 0.5, y: 0.655),
                    scale: 0.76,
                    layer: 3,
                    textEffect: .float,
                    font: .rounded,
                    color: .white,
                    textStyle: .glass
                ),
                CanvasNote(
                    text: CanvasDoodleKind.starCluster.title,
                    isEmoji: false,
                    position: CanvasPoint(x: 0.22, y: 0.30),
                    scale: 0.85,
                    layer: 4,
                    textEffect: .float,
                    font: .rounded,
                    color: .white,
                    textStyle: .plain,
                    doodle: .starCluster
                )
            ]
        case .sunlitPicnic:
            bg = .meadow
            filter = .warmFilm
            notes = [
                CanvasNote(
                    text: CanvasDoodleKind.yummy.title,
                    isEmoji: false,
                    position: CanvasPoint(x: 0.5, y: 0.33),
                    scale: 1.0,
                    layer: 0,
                    textEffect: .float,
                    font: .rounded,
                    color: .white,
                    textStyle: .plain,
                    doodle: .yummy
                ),
                CanvasNote(
                    text: "小笼包",
                    isEmoji: true,
                    position: CanvasPoint(x: 0.26, y: 0.44),
                    scale: 1.15,
                    rotationDegrees: -8,
                    layer: 1,
                    textEffect: .float,
                    emojiAsset: "StickerEmoji_food_dumpling"
                ),
                CanvasNote(
                    text: "小猫",
                    isEmoji: true,
                    position: CanvasPoint(x: 0.74, y: 0.48),
                    scale: 1.18,
                    rotationDegrees: 7,
                    layer: 2,
                    textEffect: .bounce,
                    emojiAsset: "StickerEmoji_vibe_cat"
                ),
                CanvasNote(
                    text: "回家吃饭啦",
                    isEmoji: false,
                    position: CanvasPoint(x: 0.5, y: 0.60),
                    scale: 1.24,
                    layer: 3,
                    textEffect: .float,
                    font: .rounded,
                    color: .ink,
                    textStyle: .paper
                ),
                CanvasNote(
                    text: CanvasDoodleKind.starCluster.title,
                    isEmoji: false,
                    position: CanvasPoint(x: 0.78, y: 0.32),
                    scale: 0.85,
                    layer: 4,
                    textEffect: .float,
                    font: .rounded,
                    color: .white,
                    textStyle: .plain,
                    doodle: .starCluster
                )
            ]
        case .nightFilm:
            bg = .gingham
            filter = .cinema
            notes = [
                CanvasNote(
                    text: CanvasDoodleKind.filmDate.title,
                    isEmoji: false,
                    position: CanvasPoint(x: 0.5, y: 0.34),
                    scale: 0.96,
                    layer: 0,
                    textEffect: .plain,
                    font: .mono,
                    color: .butter,
                    textStyle: .plain,
                    doodle: .filmDate
                ),
                CanvasNote(
                    text: "超爱",
                    isEmoji: true,
                    position: CanvasPoint(x: 0.5, y: 0.46),
                    scale: 1.24,
                    layer: 1,
                    textEffect: .float,
                    emojiAsset: "StickerEmoji_mood_star_eyes"
                ),
                CanvasNote(
                    text: "今日份烟火气",
                    isEmoji: false,
                    position: CanvasPoint(x: 0.5, y: 0.58),
                    scale: 1.28,
                    layer: 2,
                    textEffect: .float,
                    font: .serif,
                    color: .butter,
                    textStyle: .plain
                ),
                CanvasNote(
                    text: CanvasDoodleKind.cheers.title,
                    isEmoji: false,
                    position: CanvasPoint(x: 0.5, y: 0.67),
                    scale: 0.95,
                    layer: 3,
                    textEffect: .float,
                    font: .rounded,
                    color: .butter,
                    textStyle: .plain,
                    doodle: .cheers
                )
            ]
        case .blankPaper:
            bg = .linen
            filter = .none
            notes = [
                CanvasNote(
                    text: todayStampText,
                    isEmoji: false,
                    position: CanvasPoint(x: 0.5, y: 0.46),
                    scale: 1.0,
                    layer: 0,
                    textEffect: .float,
                    font: .handwritten,
                    color: .ink,
                    textStyle: .plain
                )
            ]
        }

        let doc = CanvasDocument(
            schemaVersion: 2,
            background: bg.rawValue,
            blur: 0,
            moodFilter: filter,
            customBackgroundData: nil,
            stickers: [],
            notes: notes,
            strokes: [],
            size: defaultSize
        )
        return LaunchCanvasDocumentPayload(document: doc)
    }
}

struct LaunchCanvasPlaybackView: View {
    var payload: LaunchCanvasDocumentPayload? = nil
    var isLiveActive: Bool = true
    var inPolaroidFrame: Bool = false
    var isExiting: Bool = false
    var motionScale: CGFloat = 1.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var dateStampText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "M.dd · EEEE"
        return f.string(from: Date())
    }

    var body: some View {
        let doc = (payload ?? LaunchCanvasStore.loadOrDefaultPayload()).document
        let size = doc.size ?? CGSize(width: 402, height: 874)
        let shouldAnimate = isLiveActive && !reduceMotion

        if shouldAnimate {
            TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
                playbackContent(
                    doc: doc,
                    size: size,
                    time: context.date.timeIntervalSinceReferenceDate,
                    live: true
                )
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        } else {
            playbackContent(doc: doc, size: size, time: 0.5, live: false)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func playbackContent(doc: CanvasDocument, size: CGSize, time: TimeInterval, live: Bool) -> some View {
        let bg = CanvasBackground(rawValue: doc.background) ?? .morningTable
        if inPolaroidFrame {
            GeometryReader { proxy in
                ZStack {
                    ZStack {
                        CanvasMediaBackground(
                            source: bg,
                            blur: max(doc.blur, 14),
                            customData: doc.customBackgroundData,
                            customURL: doc.customBackgroundURL
                        )
                            .scaleEffect(1.06)
                        CanvasMoodFilterOverlay(filter: doc.moodFilter)
                        Color(bg.isLightSurface ? .white : .black)
                            .opacity(bg.isLightSurface ? 0.22 : 0.30)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                    VStack(spacing: 0) {
                        aspectFilledArtwork(doc: doc, docSize: size, time: time, live: live, fillsSafeArea: false)
                            .frame(width: 244, height: 324)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .padding(.top, 12)
                            .padding(.horizontal, 12)

                        Text(dateStampText)
                            .font(.custom("Noteworthy-Bold", size: 15))
                            .foregroundStyle(Color(red: 0.34, green: 0.32, blue: 0.30))
                            .padding(.vertical, 16)
                    }
                    .frame(width: 268)
                    .background(
                        Color(red: 0.985, green: 0.975, blue: 0.955),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .shadow(color: Color.black.opacity(0.32), radius: 26, y: 14)
                    .rotationEffect(.degrees(isLiveActive ? -2.5 : -6.5))
                    .scaleEffect(isExiting ? 0.94 : (isLiveActive ? 1.0 : 0.86))
                    .offset(y: isExiting ? -34 : (isLiveActive ? 0 : -28))
                    .opacity(isLiveActive ? 1 : 0)
                    .animation(reduceMotion ? nil : .spring(response: 0.62, dampingFraction: 0.78), value: isLiveActive)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.36), value: isExiting)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .ignoresSafeArea()
        } else {
            aspectFilledArtwork(doc: doc, docSize: size, time: time, live: live, fillsSafeArea: true)
        }
    }

    @ViewBuilder
    private func aspectFilledArtwork(
        doc: CanvasDocument,
        docSize: CGSize,
        time: TimeInterval,
        live: Bool,
        fillsSafeArea: Bool
    ) -> some View {
        let artwork = GeometryReader { proxy in
            let scale = max(proxy.size.width / max(docSize.width, 1), proxy.size.height / max(docSize.height, 1))
            CanvasDocumentArtwork(document: doc, size: docSize, time: time, isLiveActive: live)
                .frame(width: docSize.width, height: docSize.height)
                .scaleEffect(scale * (fillsSafeArea ? motionScale : 1.0))
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
        if fillsSafeArea {
            artwork.ignoresSafeArea()
        } else {
            artwork
        }
    }
}

private struct LaunchStudioOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var config: LaunchCurtainConfig
    let onSelectTemplate: (LaunchCanvasTemplate) -> Void
    let onPreview: () -> Void
    let onResetDefault: () -> Void

    private let obsidian = Color(red: 0.067, green: 0.067, blue: 0.075)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    SectionCard {
                        Toggle(isOn: $config.enabled) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("每次打开 App 播放开屏动画")
                                    .font(AppFont.headline(15))
                                    .foregroundStyle(Color.inkPrimary)
                                Text("关闭后直接进入「这一顿」画布")
                                    .font(AppFont.caption(11))
                                    .foregroundStyle(Color.inkMuted)
                            }
                        }
                        .tint(obsidian)

                        Divider().background(Color.dividerLine.opacity(0.6))

                        FieldLabel("出场动效")
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                            ForEach(LaunchCurtainMotion.allCases) { item in
                                let isChosen = config.motion == item
                                Button {
                                    Haptics.light()
                                    config.motion = item
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: item.icon)
                                            .font(.system(size: 13, weight: .semibold))
                                        Text(item.title)
                                            .font(.system(size: 13, weight: isChosen ? .semibold : .medium, design: .rounded))
                                    }
                                    .foregroundStyle(isChosen ? .white : Color.inkPrimary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 40)
                                    .background(isChosen ? obsidian : Color.appBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay {
                                        if !isChosen {
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .strokeBorder(Color.dividerLine.opacity(0.75), lineWidth: 0.7)
                                        }
                                    }
                                }
                                .buttonStyle(SoftPressStyle())
                            }
                        }

                        FieldLabel("停留节奏")
                        HStack(spacing: 8) {
                            ForEach(LaunchHoldSpeed.allCases) { speed in
                                let isChosen = config.holdSpeed == speed
                                Button {
                                    Haptics.light()
                                    config.holdSpeed = speed
                                } label: {
                                    VStack(spacing: 1) {
                                        Text(speed.title)
                                            .font(.system(size: 13, weight: isChosen ? .semibold : .medium, design: .rounded))
                                        Text(speed.subtitle)
                                            .font(.system(size: 10, design: .monospaced))
                                            .opacity(0.76)
                                    }
                                    .foregroundStyle(isChosen ? .white : Color.inkPrimary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 42)
                                    .background(isChosen ? obsidian : Color.appBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay {
                                        if !isChosen {
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .strokeBorder(Color.dividerLine.opacity(0.75), lineWidth: 0.7)
                                        }
                                    }
                                }
                                .buttonStyle(SoftPressStyle())
                            }
                        }
                    }

                    SectionCard {
                        FieldLabel("套用开屏灵感模板")
                        Text("套用后仍可自由移动、增删文字贴纸与涂鸦，并支持撤销")
                            .font(AppFont.caption(11))
                            .foregroundStyle(Color.inkMuted)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(LaunchCanvasTemplate.allCases) { template in
                                    Button {
                                        onSelectTemplate(template)
                                        dismiss()
                                    } label: {
                                        VStack(alignment: .leading, spacing: 6) {
                                            ZStack {
                                                CanvasMediaBackground(source: template.previewBackground, blur: 0, customData: nil)
                                                    .frame(width: 112, height: 80)
                                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                                if let asset = template.previewAccentAsset {
                                                    Image(asset)
                                                        .resizable()
                                                        .scaledToFit()
                                                        .frame(width: 34, height: 34)
                                                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                                                }
                                            }
                                            Text(template.title)
                                                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                                .foregroundStyle(Color.inkPrimary)
                                            Text(template.subtitle)
                                                .font(.system(size: 10.5))
                                                .foregroundStyle(Color.inkMuted)
                                                .lineLimit(1)
                                        }
                                        .padding(8)
                                        .frame(width: 128, alignment: .leading)
                                        .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .strokeBorder(Color.dividerLine.opacity(0.75), lineWidth: 0.7)
                                        }
                                    }
                                    .buttonStyle(SoftPressStyle())
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.lg)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: AppSpacing.md) {
                    SecondaryButton(title: "恢复默认", icon: "arrow.counterclockwise") {
                        onResetDefault()
                        dismiss()
                    }
                    PrimaryButton(title: "试看完整开屏", icon: "play.fill") {
                        onPreview()
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.sm)
                .background(Color.appBackground)
                .overlay(alignment: .top) {
                    Divider().overlay(Color.dividerLine.opacity(0.6))
                }
            }
            .navigationTitle("开屏动效与模板")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(obsidian)
                }
            }
        }
    }
}

struct LaunchCanvasStudioView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var studioVM = MealNowViewModel()
    @State private var isLightSurface = LaunchCanvasStore.isLightSurface()

    var body: some View {
        MealCanvasView(
            vm: studioVM,
            pendingReviewMealId: nil,
            onAddDish: {},
            onReview: { _ in },
            onConfirm: {},
            onShoppingList: {},
            onDining: {},
            onRetry: {},
            isLaunchStudio: true,
            onCloseLaunchStudio: { dismiss() },
            onLaunchLightSurfaceChange: { isLightSurface = $0 }
        )
        .preferredColorScheme(isLightSurface ? .light : .dark)
    }
}
