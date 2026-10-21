import SwiftUI
import PhotosUI
import Photos
import UIKit

/// 这一顿的自由画布，支持菜品、文字、表情和涂鸦。
struct MealCanvasView: View {
    @ObservedObject var vm: MealNowViewModel
    let pendingReviewMealId: UInt?
    let onAddDish: () -> Void
    let onReview: (UInt) -> Void
    let onConfirm: () -> Void
    let onShoppingList: () -> Void
    let onDining: () -> Void
    let onRetry: () async -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var background: CanvasBackground = .meadow
    @State private var blur: Double = 3.0
    @State private var customBackgroundData: Data?
    @State private var stickers: [CanvasSticker] = []
    @State private var notes: [CanvasNote] = []
    @State private var strokes: [CanvasStroke] = []
    @State private var activeStroke: [CGPoint] = []
    @State private var brushColor: CanvasBrushColor = .white
    @State private var customBrushColor: Color = .white
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
    @State private var transformUndo: [CanvasTransformUndo] = []
    @State private var transformEditorHasChanges = false
    @State private var activeEditor: CanvasEditorPanel?
    @State private var insertMode: CanvasInsertItem?
    @State private var draftText = ""
    @State private var emojiCategory: CanvasEmojiCategory = .recent
    @Namespace private var emojiCategoryHighlight
    @State private var backgroundPhotoItem: PhotosPickerItem?
    @State private var showPhotoSticker = false
    @State private var photoStickerMealID: UInt?
    @State private var didInsertPhotoSticker = false
    @FocusState private var textEditorFocused: Bool

    var body: some View {
        ZStack {
            CanvasPalette.page.ignoresSafeArea()
            GeometryReader { viewport in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        header.frame(height: 52)
                        canvas
                            .frame(height: max(240, viewport.size.height - 80))

                        if vm.loadFailed && vm.meal == nil {
                            retryStrip
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
                }
                .scrollDisabled(drawingEnabled || isSelecting || isCanvasInteracting)
            }

        }
        .onAppear { restoreDocumentIfNeeded() }
        .onChange(of: vm.meal?.id) { _, _ in
            selectedStickerID = nil
            selectedNoteID = nil
            finishSelecting()
            activeStroke.removeAll()
            drawingEnabled = false
            isEditing = false
            activeEditor = nil
            insertMode = nil
            textEditorFocused = false
            transformUndo = []
            restoreDocumentIfNeeded()
        }
        .onChange(of: vm.meal?.status) { _, status in
            if status == .confirmed || status == .completed {
                finishEditing()
            }
        }
        .onChange(of: vm.dishes.map(\.id)) { _, _ in
            let addedDishID = restoredMealID == vm.meal?.id
                ? vm.dishes.first(where: { dish in !stickers.contains(where: { $0.mealDishID == dish.id }) })?.id
                : nil
            syncStickers()
            selectedElements.formIntersection(Set(layerEntries.map(\.selection)))
            if let addedDishID, let added = stickers.first(where: { $0.mealDishID == addedDishID }) {
                finishSelecting()
                selectedStickerID = added.id
                selectedNoteID = nil
            }
        }
        .onChange(of: selectedNoteID) { _, _ in
            if activeEditor == .insert {
                draftText = selectedTextNote?.text ?? ""
            }
        }
        .onChange(of: selectedCanvasElement) { _, _ in transformEditorHasChanges = false }
        .onChange(of: notes.map(\.id)) { _, _ in
            selectedElements.formIntersection(Set(layerEntries.map(\.selection)))
        }
        .onChange(of: background) { _, _ in saveDocument() }
        .onChange(of: blur) { _, _ in saveDocument() }
        .onChange(of: customBackgroundData) { _, _ in saveDocument() }
        .onChange(of: backgroundPhotoItem) { _, item in
            guard let item else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data),
                      let preview = image.canvasPreviewData else {
                    backgroundPhotoItem = nil
                    vm.tipMessage = "无法读取照片，请重新选择"
                    return
                }
                await MainActor.run {
                    customBackgroundData = preview
                    background = .custom
                    backgroundPhotoItem = nil
                }
            }
        }
        .sheet(isPresented: $isEditing, onDismiss: {
            activeEditor = nil
            textEditorFocused = false
        }) {
            if activeEditor != nil {
                inlineEditorPanel
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                    .presentationDetents(editorDetents)
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
                    .presentationBackground(Color.white)
                    .presentationBackgroundInteraction(.enabled)
                    .fullScreenCover(isPresented: $showPhotoSticker, onDismiss: {
                        if didInsertPhotoSticker { closeEditor() }
                    }) {
                        PhotoStickerSheet { path in
                            guard photoStickerMealID == vm.meal?.id else {
                                vm.tipMessage = "这一顿已切换，请重新添加贴图"
                                return
                            }
                            insertPhotoSticker(path)
                            didInsertPhotoSticker = true
                        }
                    }
            }
        }
    }

    private var editorDetents: Set<PresentationDetent> {
        switch activeEditor {
        case .transform: return [.height(360)]
        case .emoji: return [.height(520), .large]
        case .brush: return [.height(440), .large]
        case .effects: return [.height(360)]
        case .insert: return [.height(selectedTextNote == nil ? 300 : 500), .large]
        case .background: return [.height(260)]
        case nil: return [.height(430)]
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("这一顿")
                        .font(.system(size: 27, weight: .semibold))
                        .foregroundStyle(CanvasPalette.ink)
                    Text("\(vm.dishCount) 道菜")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(CanvasPalette.accent)
                        .contentTransition(.numericText())
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: vm.dishCount)
                }
                Text(isRemovingDish ? "正在移除…" : drawingEnabled ? "正在画画" : isSelecting
                    ? (selectedElements.isEmpty ? "拖出范围框选内容" : "已选 \(selectedElements.count) 项 · 拖动一起移动")
                    : "拖动移动 · 手柄调整")
                    .font(.system(size: 12))
                    .foregroundStyle(CanvasPalette.muted)
                    .lineLimit(1)
                    .opacity(isRemovingDish || drawingEnabled || isSelecting || selectedCanvasElement != nil ? 1 : 0)
                    .accessibilityHidden(!isRemovingDish && !drawingEnabled && !isSelecting && selectedCanvasElement == nil)
            }

            Spacer(minLength: 8)

            Button(action: undoLastTransform) {
                ProductIcon(kind: .undo)
                    .scaleEffect(0.8)
                    .foregroundStyle(CanvasPalette.ink)
                    .opacity(canUndoTransform ? 1 : 0.25)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(CanvasPressStyle())
            .disabled(!canUndoTransform)
            .accessibilityLabel("撤销上次位置、大小和角度调整")

            if vm.dishCount > 0 {
                Button {
                    Haptics.light()
                    actionBarConfirm()
                } label: {
                    Group {
                        if vm.isActing { ProgressView().tint(CanvasPalette.accent) }
                        else { Image(systemName: confirmIcon).font(.system(size: 18, weight: .medium)) }
                    }
                    .foregroundStyle(CanvasPalette.accent)
                    .frame(width: 44, height: 44)
                    .background(Color.paperGreen, in: Circle())
                }
                .buttonStyle(SoftPressStyle())
                .disabled(vm.isActing || isRemovingDish || isCanvasInteracting)
                .accessibilityLabel(confirmTitle)
            }

            Menu {
                Button("保存至相册", systemImage: "square.and.arrow.down") {
                    saveCanvasToPhotos()
                }
                if vm.meal?.status == .planning || vm.meal?.status == .confirmed {
                    Button("从菜谱加菜", systemImage: "plus") {
                        onAddDish()
                    }
                    .disabled(vm.isActing || isRemovingDish)
                }
                if vm.dishCount > 0 || (vm.meal?.status != nil && vm.meal?.status != .planning) {
                    Button(confirmTitle, systemImage: confirmIcon) {
                        Haptics.light()
                        actionBarConfirm()
                    }
                    .disabled(vm.isActing || isRemovingDish)
                }
                Button("买菜清单", systemImage: "cart") { onShoppingList() }
                Button("邀请一起点", systemImage: "person.2") { onDining() }
                if let pendingReviewMealId {
                    Button("补写记录", systemImage: "square.and.pencil") {
                        onReview(pendingReviewMealId)
                    }
                }
                Button("撤销最后一笔", systemImage: "arrow.uturn.backward") {
                    _ = strokes.popLast()
                    saveDocument()
                }
                .disabled(strokes.isEmpty)
                Button("清除文字和涂鸦", systemImage: "trash", role: .destructive) {
                    clearCanvasAdditions()
                }
                .disabled(!hasCanvasAdditions)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(CanvasPalette.ink)
                    .frame(width: 44, height: 44)
                    .background(CanvasPalette.surface, in: Circle())
            }
            .disabled(isCanvasInteracting)
            .accessibilityLabel("这一顿的更多操作")

        }
    }

    private var canvas: some View {
        GeometryReader { proxy in
            ZStack {
                CanvasMediaBackground(
                    source: background,
                    blur: blur,
                    customData: customBackgroundData
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
                .id(background)
                .transition(.opacity)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: background)
                .allowsHitTesting(false)
                .zIndex(-1_000_000)

                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                            selectedStickerID = nil
                            selectedNoteID = nil
                            textEditorFocused = false
                        }
                    }
                    .allowsHitTesting(!drawingEnabled && !isCanvasInteracting)
                    .zIndex(-999_999)

                if stickers.isEmpty && notes.isEmpty && strokes.isEmpty {
                    Button {
                        Haptics.light()
                        onAddDish()
                    } label: {
                        VStack(spacing: 14) {
                            ProductIcon(kind: .meal)
                                .scaleEffect(1.6)
                                .frame(width: 44, height: 44)
                            Text("今天想吃什么")
                                .font(.system(size: 17, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                        .padding(24)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(SoftPressStyle())
                    .disabled(vm.meal == nil || vm.isActing)
                    .accessibilityLabel("从菜谱添加第一道菜")
                }

                ForEach($stickers) { $sticker in
                    CanvasStickerView(
                        sticker: $sticker,
                        canvasSize: proxy.size,
                        isSelected: !isExporting && !isEditing && !isSelecting && sticker.id == selectedStickerID,
                        reduceMotion: reduceMotion || isSelecting,
                        reportsBounds: isSelecting,
                        alignmentTargets: alignmentTargets(excluding: .sticker(sticker.id)),
                        onTransformStart: { rememberTransform(for: .sticker(sticker.id)) },
                        onSelect: {
                            if selectedStickerID != sticker.id { Haptics.light() }
                            withAnimation(.spring(response: 0.30, dampingFraction: 0.76)) {
                                selectedStickerID = sticker.id
                                selectedNoteID = nil
                            }
                        },
                        onTransform: { openEditor(.transform) },
                        onLayerMove: { move in
                            moveLayer(move, for: .sticker(sticker.id))
                        },
                        onDelete: {
                            deleteElement(.sticker(sticker.id))
                        },
                        onChange: saveDocument
                    )
                    .transition(.opacity)
                    .zIndex(Double(sticker.layer))
                    .accessibilityHidden(isSelecting)
                    .allowsHitTesting(!drawingEnabled && !isSelecting && (!isCanvasInteracting || selectedStickerID == sticker.id))
                }

                ForEach($notes) { $note in
                    CanvasNoteView(
                        note: $note,
                        canvasSize: proxy.size,
                        isSelected: !isExporting && !isEditing && !isSelecting && note.id == selectedNoteID,
                        freezesMotion: isSelecting,
                        reportsBounds: isSelecting,
                        alignmentTargets: alignmentTargets(excluding: .note(note.id)),
                        onTransformStart: { rememberTransform(for: .note(note.id)) },
                        onSelect: {
                            if selectedNoteID != note.id { Haptics.light() }
                            withAnimation(.spring(response: 0.30, dampingFraction: 0.76)) {
                                selectedStickerID = nil
                                selectedNoteID = note.id
                            }
                        },
                        onEdit: {
                            selectedStickerID = nil
                            selectedNoteID = note.id
                            openEditor(.insert)
                        },
                        onTransform: { openEditor(.transform) },
                        onLayerMove: { move in
                            moveLayer(move, for: .note(note.id))
                        },
                        onDelete: {
                            deleteElement(.note(note.id))
                        },
                        onChange: saveDocument
                    )
                    .transition(.opacity)
                    .zIndex(Double(note.layer))
                    .accessibilityHidden(isSelecting)
                    .allowsHitTesting(!drawingEnabled && !isSelecting && (!isCanvasInteracting || selectedNoteID == note.id))
                }

                CanvasDrawingView(
                    strokes: $strokes,
                    activeStroke: $activeStroke,
                    isEnabled: drawingEnabled,
                    brush: brushColor,
                    paintColor: customBrushColor,
                    style: brushStyle,
                    width: brushWidth,
                    onEnd: saveDocument
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
                    .stroke(.white.opacity(0.95), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .shadow(color: .black.opacity(0.25), radius: 1)
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
                                    canEditText: selectedTextNote != nil,
                                    isDeleting: isRemovingDish,
                                    layers: layerEntries.sorted { $0.layer > $1.layer },
                                    selection: overlay.selection,
                                    onSelect: selectElement,
                                    onEditText: { openEditor(.insert) },
                                    onEdit: { openEditor(.effects) },
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
                        layers: layerEntries.sorted { $0.layer > $1.layer }.map(\.selection),
                        selection: $selectedElements,
                        transforms: selectedElements.compactMap { currentTransform(for: $0) },
                        onMoveStart: { transformUndo = $0 },
                        onMove: moveElements,
                        onChange: saveDocument
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
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(alignment: .bottom) {
            liveControls
                .padding(12)
                .opacity(isExporting ? 0 : 1)
        }
        .onPreferenceChange(CanvasElementInteractionKey.self) { isCanvasInteracting = $0 }
        .onPreferenceChange(CanvasAlignmentGuidesKey.self) { alignmentGuides = $0 }
    }

    /// 编辑工具随画布呈现，主导航保持独立。
    private var liveControls: some View {
        HStack(spacing: 8) {
            if isSelecting {
                LiveControlButton(title: "全选内容", icon: "selection.all", isActive: selectedElements.count == layerEntries.count,
                    isDisabled: layerEntries.isEmpty) {
                    selectedElements = Set(layerEntries.map(\.selection))
                }
                LiveControlButton(title: "清除选择", icon: "xmark", isDisabled: selectedElements.isEmpty) {
                    selectedElements.removeAll()
                }
                LiveControlButton(title: "完成框选", icon: "checkmark", isActive: true) {
                    finishSelecting()
                }
            } else if drawingEnabled {
                LiveControlButton(title: "撤销", icon: "arrow.uturn.backward", isDisabled: strokes.isEmpty) {
                    _ = strokes.popLast()
                    saveDocument()
                }
                LiveControlButton(title: "画笔设置", icon: "slider.horizontal.3") {
                    openEditor(.brush)
                }
                LiveControlButton(title: "完成", icon: "checkmark") {
                    drawingEnabled = false
                }
            } else {
                LiveControlButton(title: "加菜", icon: "plus", isDisabled: vm.meal == nil || vm.isActing || isRemovingDish) {
                    onAddDish()
                }
                LiveControlButton(title: "文字", icon: "textformat", isActive: activeEditor == .insert) {
                    addText()
                }
                LiveControlButton(title: "贴纸", icon: "face.smiling", isActive: activeEditor == .emoji) {
                    openEditor(.emoji)
                }
                LiveControlButton(title: "画笔", icon: "pencil", isActive: activeEditor == .brush) {
                    openEditor(.brush)
                }
                LiveControlButton(title: "背景", icon: "photo", isActive: activeEditor == .background) {
                    openEditor(.background)
                }
                LiveControlButton(title: "框选内容", icon: "selection", isDisabled: layerEntries.isEmpty || isRemovingDish) {
                    selectedStickerID = nil
                    selectedNoteID = nil
                    textEditorFocused = false
                    isSelecting = true
                }
            }
        }
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
                    .background(CanvasPalette.page, in: Circle())
            }
            .buttonStyle(CanvasPressStyle(scale: 0.90))
            .accessibilityLabel("关闭编辑器")
        }
    }

    private var textEditorContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $draftText)
                    .focused($textEditorFocused)
                    .accessibilityLabel("画布文字")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(CanvasPalette.ink)
                    .frame(minHeight: 72, maxHeight: 84)
                    .scrollContentBackground(.hidden)
                if draftText.isEmpty {
                    Text("例如：今晚吃点好的")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(CanvasPalette.muted.opacity(0.7))
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(CanvasPalette.page, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(CanvasPalette.ink.opacity(0.10), lineWidth: 0.8)
            }
            if let selectedNoteID, notes.first(where: { $0.id == selectedNoteID })?.isEmoji == false {
                if let note = notes.first(where: { $0.id == selectedNoteID }) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("字体")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(CanvasPalette.muted)
                        HStack(spacing: 8) {
                            ForEach(CanvasTextFont.allCases) { font in
                                Button {
                                    Haptics.light()
                                    setSelectedNoteFont(font)
                                } label: {
                                    Text(font.title)
                                        .font(font.font(size: 14, weight: .semibold))
                                        .foregroundStyle(note.font == font ? CanvasPalette.ink : CanvasPalette.muted)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 44)
                                        .background(note.font == font ? Color.paperGreen : CanvasPalette.page, in: Capsule())
                                }
                                .buttonStyle(CanvasPressStyle(scale: 0.94))
                            }
                        }
                        HStack(spacing: 0) {
                            Text("颜色")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(CanvasPalette.muted)
                            ForEach(CanvasTextColor.allCases) { color in
                                Button {
                                    Haptics.light()
                                    setSelectedNoteColor(color)
                                } label: {
                                    Circle()
                                        .fill(color.color)
                                        .frame(width: 25, height: 25)
                                        .overlay(Circle().stroke(note.color == color ? CanvasPalette.ink : Color.dividerLine, lineWidth: note.color == color ? 2 : 1))
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(CanvasPressStyle(scale: 0.92))
                                .accessibilityLabel("文字颜色 \(color.title)")
                                .accessibilityAddTraits(note.color == color ? .isSelected : [])
                            }
                            Spacer()
                        }
                    }
                }
                HStack(spacing: 8) {
                    Text("大小")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CanvasPalette.muted)
                    ForEach([(0.82, "小"), (1.0, "中"), (1.22, "大"), (1.46, "特大")], id: \.0) { preset in
                        Button {
                            Haptics.light()
                            setSelectedNoteScale(CGFloat(preset.0))
                        } label: {
                            Text(preset.1)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(abs((notes.first(where: { $0.id == selectedNoteID })?.scale ?? 1) - CGFloat(preset.0)) < 0.02 ? CanvasPalette.ink : CanvasPalette.muted)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(abs((notes.first(where: { $0.id == selectedNoteID })?.scale ?? 1) - CGFloat(preset.0)) < 0.02 ? Color.paperGreen : CanvasPalette.page, in: Capsule())
                        }
                        .buttonStyle(CanvasPressStyle(scale: 0.94))
                    }
                }
            }

        }
        .padding(.bottom, 4)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button {
                Haptics.light()
                commitDraftText()
            } label: {
                Text(selectedTextNote == nil ? "放到画布" : "更新文字")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(CanvasPalette.ink, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(SoftPressStyle())
            .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.35 : 1)
            .padding(.top, 12)
            .background(CanvasPalette.surface)
        }
    }

    private var emojiEditorContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                photoStickerMealID = vm.meal?.id
                didInsertPhotoSticker = false
                showPhotoSticker = true
            } label: {
                Label("拍照做贴图", systemImage: "camera")
                    .font(AppFont.body(14))
                    .foregroundStyle(CanvasPalette.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(CanvasPalette.page, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(SoftPressStyle())
            .disabled(vm.meal == nil)
            HStack(spacing: 4) {
                ForEach(CanvasEmojiCategory.allCases) { item in
                    Button {
                        Haptics.light()
                        emojiCategory = item
                    } label: {
                        Image(systemName: item.icon)
                            .font(.system(size: 19, weight: .regular))
                            .foregroundStyle(emojiCategory == item ? CanvasPalette.accent : CanvasPalette.muted)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background {
                                if emojiCategory == item {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.paperGreen)
                                        .matchedGeometryEffect(id: "emojiCategory", in: emojiCategoryHighlight)
                                }
                            }
                    }
                    .buttonStyle(SoftPressStyle())
                    .accessibilityLabel(item.title)
                    .accessibilityAddTraits(emojiCategory == item ? .isSelected : [])
                }
                Divider().frame(height: 20).padding(.horizontal, 4)
                Button {
                    Haptics.light()
                    clearEmojiStickers()
                } label: {
                    ProductIcon(kind: .trash)
                        .scaleEffect(0.8)
                        .frame(width: 44, height: 44)
                }
                .foregroundStyle(CanvasPalette.muted)
                .buttonStyle(SoftPressStyle())
                .disabled(!notes.contains(where: { $0.isEmoji }))
                .opacity(notes.contains(where: { $0.isEmoji }) ? 1 : 0.35)
                .accessibilityLabel("清空表情贴纸")
            }
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.86), value: emojiCategory)
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 10) {
                    ForEach(emojiCategory.items, id: \.self) { emoji in
                        Button {
                            Haptics.light()
                            insertEmoji(emoji)
                        } label: {
                            Text(emoji)
                                .font(.system(size: 28))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(CanvasPalette.page, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(CanvasPressStyle(scale: 0.90))
                        .accessibilityLabel("添加贴纸 \(emoji)")
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
            ), in: 0.3...3)
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
            ), in: -180...180)
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
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                if let sticker = stickers.first(where: { $0.id == selectedStickerID }) {
                    ForEach(CanvasEffect.allCases) { effect in
                        CanvasInlineEditorCard(icon: effect.icon, title: effect.title, previewKind: .sticker(effect, sticker), isSelected: selectedStickerEffect == effect) { applyEffect(effect) }
                    }
                } else if let note = notes.first(where: { $0.id == selectedNoteID }) {
                    ForEach(CanvasTextEffect.allCases) { effect in
                        CanvasInlineEditorCard(icon: effect.icon, title: effect.title, previewKind: .text(effect, note), isSelected: selectedTextEffect == effect) { applyTextEffect(effect) }
                    }
                }
                }
                .padding(.bottom, 2)
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
                                            .foregroundStyle(item == .ink ? .white : CanvasPalette.ink)
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
                    .background(usesCustomBrushColor ? Color.paperGreen : .clear, in: RoundedRectangle(cornerRadius: 12))
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("笔触")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(CanvasPalette.muted)
                    HStack(spacing: 8) {
                        ForEach(CanvasBrushStyle.allCases) { item in
                            Button {
                                Haptics.light()
                                brushStyle = item
                            } label: {
                                VStack(spacing: 8) {
                                    CanvasBrushPreview(style: item, color: CanvasPalette.ink)
                                        .frame(height: 22)
                                        .padding(.horizontal, 8)
                                    Text(item.title)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(item == brushStyle ? CanvasPalette.ink : CanvasPalette.muted)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(item == brushStyle ? Color.paperGreen : CanvasPalette.page, in: RoundedRectangle(cornerRadius: 14))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(item == brushStyle ? CanvasPalette.accent : .clear, lineWidth: 1)
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
        let halfWidth: CGFloat = (selectedTextNote == nil ? 148 : 195) / 2 + 8
        let top = overlay.center.y - halfElementHeight
        let bottom = overlay.center.y + halfElementHeight
        let lowerLimit = max(34, size.height - 103)
        let above = min(max(top - 49, 34), lowerLimit)
        let below = min(max(bottom + 49, 34), lowerLimit)
        let overlapAbove = max(0, min(above + 26, bottom) - max(above - 26, top))
        let overlapBelow = max(0, min(below + 26, bottom) - max(below - 26, top))
        return CGPoint(
            x: min(max(overlay.center.x, halfWidth), max(halfWidth, size.width - halfWidth)),
            y: overlapAbove <= overlapBelow ? above : below
        )
    }

    private var inlineBackgroundPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CanvasBackground.allCases) { item in
                        Button {
                            if item != .custom || customBackgroundData != nil {
                                Haptics.light()
                                background = item
                            }
                        } label: {
                            ZStack(alignment: .bottomLeading) {
                                CanvasMediaBackground(source: item, blur: 0, customData: customBackgroundData)
                                if background == item {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(5)
                                        .background(CanvasPalette.ink, in: Circle())
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                        .padding(5)
                                }
                            }
                            .frame(width: 74, height: 62)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .stroke(background == item ? CanvasPalette.accent : .white.opacity(0.0), lineWidth: 1.6)
                            }
                        }
                        .buttonStyle(CanvasPressStyle(scale: 0.96))
                        .animation(.spring(response: 0.24, dampingFraction: 0.80), value: background)
                        .accessibilityLabel(item.title)
                        .accessibilityAddTraits(background == item ? .isSelected : [])
                        .disabled(item == .custom && customBackgroundData == nil)
                        .opacity(item == .custom && customBackgroundData == nil ? 0.35 : 1)
                    }

                    PhotosPicker(selection: $backgroundPhotoItem, matching: .images, photoLibrary: .shared()) {
                        VStack(spacing: 4) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 16, weight: .semibold))
                            Text("相册")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(CanvasPalette.ink)
                        .frame(width: 74, height: 62)
                        .background(CanvasPalette.surface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(CanvasPalette.ink.opacity(0.08), lineWidth: 1)
                        }
                    }
                    .buttonStyle(CanvasPressStyle(scale: 0.96))
                }
            }

            HStack(spacing: 8) {
                Text("毛玻璃")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CanvasPalette.muted)
                Slider(value: $blur, in: 0...10)
                    .tint(CanvasPalette.ink)
                Text(blur == 0 ? "关" : "\(Int(blur))")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(CanvasPalette.ink)
                    .frame(width: 22)
            }
        }
    }

    private var selectedCanvasElement: CanvasSelection? {
        if let selectedStickerID { return .sticker(selectedStickerID) }
        if let selectedNoteID { return .note(selectedNoteID) }
        return nil
    }

    private var selectedTextNote: CanvasNote? {
        guard let selectedNoteID else { return nil }
        return notes.first { $0.id == selectedNoteID && !$0.isEmoji }
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

    private var canUndoTransform: Bool {
        guard !isCanvasInteracting, !isEditing, !drawingEnabled, !isRemovingDish else { return false }
        return transformUndo.contains { previous in
            guard let current = currentTransform(for: previous.selection) else { return false }
            return current != previous
        }
    }

    private func rememberTransform(for selection: CanvasSelection) {
        transformEditorHasChanges = false
        transformUndo = currentTransform(for: selection).map { [$0] } ?? []
    }

    private func undoLastTransform() {
        guard canUndoTransform else { return }
        let previous = transformUndo.filter { currentTransform(for: $0.selection) != nil }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            for item in previous {
                switch item.selection {
                case .sticker(let id):
                    guard let index = stickers.firstIndex(where: { $0.id == id }) else { continue }
                    stickers[index].position = item.position
                    stickers[index].scale = item.scale
                    stickers[index].rotationDegrees = item.rotationDegrees
                case .note(let id):
                    guard let index = notes.firstIndex(where: { $0.id == id }) else { continue }
                    notes[index].position = item.position
                    notes[index].scale = item.scale
                    notes[index].rotationDegrees = item.rotationDegrees
                }
            }
            selectedStickerID = nil
            selectedNoteID = nil
            if previous.count > 1 || isSelecting {
                isSelecting = true
                selectedElements = Set(previous.map(\.selection))
            } else if let item = previous.first {
                switch item.selection {
                case .sticker(let id): selectedStickerID = id
                case .note(let id): selectedNoteID = id
                }
            }
            transformUndo = []
        }
        saveDocument()
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
                    title: $0.isEmoji ? "\($0.text) 贴纸" : String($0.text.replacingOccurrences(of: "\n", with: " ").prefix(16)),
                    icon: $0.isEmoji ? "face.smiling" : "pencil")
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
            setLayer((ordered.last?.layer ?? 0) + 1, for: selected)
        case .back:
            guard currentIndex > 0 else { return }
            setLayer((ordered.first?.layer ?? 0) - 1, for: selected)
        case .forward, .backward:
            let targetIndex = move == .forward ? currentIndex + 1 : currentIndex - 1
            guard ordered.indices.contains(targetIndex) else { return }
            let other = ordered[targetIndex]
            setLayer(other.layer, for: selected)
            setLayer(ordered[currentIndex].layer, for: other.selection)
        }
        saveDocument()
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
                stickers.removeAll { $0.id == id }
                selectedStickerID = nil
                closeEditor()
                saveDocument()
                return
            }
            guard !isRemovingDish,
                  let dish = vm.dishes.first(where: { $0.id == sticker.mealDishID }) else { return }
            isRemovingDish = true
            Task {
                defer { isRemovingDish = false }
                await vm.removeDish(dish)
                if !vm.dishes.contains(where: { $0.id == dish.id }) {
                    syncStickers()
                }
            }
        case .note(let id):
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                notes.removeAll { $0.id == id }
                selectedNoteID = nil
            }
            closeEditor()
            saveDocument()
        }
    }

    private func addText() {
        selectedStickerID = nil
        selectedNoteID = nil
        draftText = ""
        openEditor(.insert)
    }

    private func openEditor(_ panel: CanvasEditorPanel) {
        finishSelecting()
        transformEditorHasChanges = false
        withAnimation(.spring(response: 0.28, dampingFraction: 0.80)) {
            activeEditor = panel
            isEditing = true
            drawingEnabled = false
            if panel == .insert, let selectedNoteID, let note = notes.first(where: { $0.id == selectedNoteID }), !note.isEmoji {
                draftText = note.text
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
            (point: $0.position, radius: ($0.isEmoji ? 32.0 : 80.0) * min(max($0.scale, 0.3), 3))
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
        notes.removeAll()
        strokes.removeAll()
        activeStroke.removeAll()
        selectedNoteID = nil
        saveDocument()
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
        let note = CanvasNote(
            text: text,
            isEmoji: false,
            position: insertionPosition(isEmoji: false),
            layer: nextLayerIndex
        )
        notes.append(note)
        selectedStickerID = nil
        selectedNoteID = note.id
        saveDocument()
    }

    private func setSelectedNoteScale(_ scale: CGFloat) {
        guard let selectedNoteID, let index = notes.firstIndex(where: { $0.id == selectedNoteID }), !notes[index].isEmoji else { return }
        guard notes[index].scale != scale else { return }
        rememberTransform(for: .note(selectedNoteID))
        withAnimation(.spring(response: 0.30, dampingFraction: 0.76)) {
            notes[index].scale = scale
        }
        saveDocument()
    }

    private func setSelectedNoteFont(_ font: CanvasTextFont) {
        guard let selectedNoteID, let index = notes.firstIndex(where: { $0.id == selectedNoteID }), !notes[index].isEmoji else { return }
        notes[index].font = font
        saveDocument()
    }

    private func setSelectedNoteColor(_ color: CanvasTextColor) {
        guard let selectedNoteID, let index = notes.firstIndex(where: { $0.id == selectedNoteID }), !notes[index].isEmoji else { return }
        notes[index].color = color
        saveDocument()
    }

    private func commitDraftText() {
        let value = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        if let selectedNoteID, let index = notes.firstIndex(where: { $0.id == selectedNoteID }), !notes[index].isEmoji {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.76)) {
                notes[index].text = value
            }
            saveDocument()
        } else {
            insertText(value)
        }
        insertMode = nil
        closeEditor()
    }

    private func clearEmojiStickers() {
        notes.removeAll { $0.isEmoji }
        if case .note = selectedCanvasElement { selectedNoteID = nil }
        saveDocument()
    }

    private func insertEmoji(_ emoji: String) {
        let note = CanvasNote(text: emoji, isEmoji: true, position: insertionPosition(isEmoji: true), layer: nextLayerIndex)
        notes.append(note)
        selectedStickerID = nil
        selectedNoteID = note.id
        saveDocument()
        closeEditor()
    }

    private func insertPhotoSticker(_ path: String) {
        let sticker = CanvasSticker(
            name: "拍照贴图", image: path, isCutout: true,
            position: CanvasPoint(x: 0.5, y: 0.5), layer: nextLayerIndex
        )
        stickers.append(sticker)
        finishSelecting()
        selectedStickerID = sticker.id
        selectedNoteID = nil
        saveDocument()
        Haptics.light()
    }

    private func syncStickers() {
        let customStickers = stickers.filter { $0.mealDishID == nil }
        let existing = Dictionary(uniqueKeysWithValues: stickers.compactMap { sticker in
            sticker.mealDishID.map { ($0, sticker) }
        })
        var newLayer = nextLayerIndex
        let positions: [CanvasPoint] = [
            CanvasPoint(x: 0.28, y: 0.27),
            CanvasPoint(x: 0.72, y: 0.25),
            CanvasPoint(x: 0.42, y: 0.58),
            CanvasPoint(x: 0.74, y: 0.68),
            CanvasPoint(x: 0.24, y: 0.74),
            CanvasPoint(x: 0.52, y: 0.78)
        ]
        stickers = customStickers + vm.dishes.enumerated().map { index, dish in
            let cutout = dish.recipeCutoutImage.flatMap { $0.isEmpty ? nil : $0 }
            if var old = existing[dish.id] {
                old.image = cutout ?? dish.recipeImage
                old.isCutout = cutout != nil
                if old.assetName == nil {
                    old.assetName = stickerAsset(for: dish.recipeName, index: index)
                }
                return old
            }
            let layer = newLayer
            newLayer += 1
            return CanvasSticker(
                mealDishID: dish.id,
                name: dish.recipeName,
                image: cutout ?? dish.recipeImage,
                isCutout: cutout != nil,
                assetName: stickerAsset(for: dish.recipeName, index: index),
                position: positions[index % positions.count],
                scale: [0.92, 0.78, 1.08, 0.86, 0.72, 0.98][index % 6],
                rotationDegrees: [(-8.0), 6.0, -4.0, 9.0, -12.0, 3.0][index % 6],
                shapeIndex: index % 5,
                layer: layer
            )
        }
        if let selectedStickerID, !stickers.contains(where: { $0.id == selectedStickerID }) {
            self.selectedStickerID = nil
        }
        saveDocument()
    }

    private func stickerAsset(for name: String, index: Int) -> String? {
        _ = index
        return DishArtwork.assetName(for: name)
    }

    private func applyEffect(_ effect: CanvasEffect) {
        guard let selectedStickerID,
              let index = stickers.firstIndex(where: { $0.id == selectedStickerID }) else { return }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
            stickers[index].effect = effect
        }
        saveDocument()
    }

    private func applyTextEffect(_ effect: CanvasTextEffect) {
        guard let selectedNoteID,
              let index = notes.firstIndex(where: { $0.id == selectedNoteID }) else { return }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) {
            notes[index].textEffect = effect
        }
        saveDocument()
    }

    private func restoreDocumentIfNeeded() {
        guard let mealID = vm.meal?.id, restoredMealID != mealID else {
            if vm.meal != nil { syncStickers() }
            return
        }
        restoredMealID = mealID
        if let document = CanvasDocumentStore.load(mealID: mealID) {
            background = CanvasBackground(rawValue: document.background) ?? .meadow
            blur = document.blur
            customBackgroundData = document.customBackgroundData
            stickers = document.stickers
            notes = document.notes
            strokes = document.strokes
            activeStroke = []
            migrateLegacyLayerOrderIfNeeded()
            repairOverlappingNoteLayout(mealID: mealID)
        } else {
            background = .meadow
            blur = 3.0
            customBackgroundData = nil
            stickers = []
            notes = []
            strokes = []
            activeStroke = []
            selectedStickerID = nil
            selectedNoteID = nil
        }
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

    private func saveDocument() {
        guard let mealID = vm.meal?.id else { return }
        CanvasDocumentStore.save(
            CanvasDocument(
                background: background.rawValue,
                blur: blur,
                customBackgroundData: customBackgroundData,
                stickers: stickers,
                notes: notes,
                strokes: strokes,
                size: canvasFrame.size.width > 0 ? canvasFrame.size : nil
            ),
            mealID: mealID
        )
    }

    /// 导出画布内容，隐藏编辑控件，并以相册实际写入结果反馈。
    private func saveCanvasToPhotos() {
        guard !isExporting, canvasFrame.width > 0 else { return }
        Task { @MainActor in
            let authorization = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard authorization == .authorized || authorization == .limited else {
                vm.tipMessage = "请在设置中允许添加照片后再保存"
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
                vm.tipMessage = "画布已保存到相册"
            } catch {
                vm.tipMessage = "保存失败，请重试"
            }
        }
    }
}

/// 以保存时的尺寸还原画布，让文字、笔迹与食物保持相同的构图。
struct MealCanvasSnapshotView: View {
    private let document: CanvasDocument?

    init(mealID: UInt) {
        document = CanvasDocumentStore.load(mealID: mealID)
    }

    var body: some View {
        if let document {
            let size = document.size ?? CGSize(width: 360, height: 600)
            GeometryReader { proxy in
                CanvasDocumentArtwork(document: document, size: size)
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(proxy.size.width / size.width, anchor: .topLeading)
            }
            .aspectRatio(size.width / size.height, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("这一顿保存的画布")
        }
    }
}

private struct CanvasDocumentArtwork: View {
    let document: CanvasDocument
    let size: CGSize

    var body: some View {
        ZStack {
            CanvasMediaBackground(
                source: CanvasBackground(rawValue: document.background) ?? .meadow,
                blur: document.blur,
                customData: document.customBackgroundData
            )
            .frame(width: size.width, height: size.height)
            .zIndex(-1_000_000)
            ForEach(document.stickers) { sticker in
                CanvasStickerView(
                    sticker: .constant(sticker), canvasSize: size, isSelected: false,
                    reduceMotion: true, onSelect: {}, onTransform: {}, onLayerMove: { _ in },
                    onDelete: {}, onChange: {}
                )
                .zIndex(Double(sticker.layer))
            }
            ForEach(document.notes) { note in
                CanvasNoteView(
                    note: .constant(note), canvasSize: size, isSelected: false, freezesMotion: true,
                    onSelect: {}, onEdit: {}, onTransform: {}, onLayerMove: { _ in }, onDelete: {}, onChange: {}
                )
                .zIndex(Double(note.layer))
            }
            CanvasDrawingView(
                strokes: .constant(document.strokes), activeStroke: .constant([]),
                isEnabled: false, brush: .white, paintColor: .white, style: .solid,
                width: 4, onEnd: {}
            )
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
}

private enum CanvasPalette {
    static let page = CanvasTheme.page
    static let surface = CanvasTheme.surface
    static let ink = CanvasTheme.ink
    static let muted = CanvasTheme.secondary
    static let accent = CanvasTheme.accent
    static let live = Color.dopamineYellow
    static let coral = Color.dopaminePink
}

private struct CanvasPoint: Codable, Hashable {
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
    let onTransformStart: () -> Void
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
        CGSize(width: (size.width + 8) * displayScale,
               height: (size.height + 8) * displayScale)
    }

    var center: CGPoint {
        CGPoint(x: position.x * canvasSize.width, y: position.y * canvasSize.height)
    }

    private var displayScale: CGFloat { min(max(scale, 0.3), 3) }
    private var handleScale: CGFloat { min(max(displayScale, 0.65), 1.2) }

    var body: some View {
        ZStack {
            Ellipse()
                .stroke(.white.opacity(0.75), lineWidth: 0.75)
                .frame(width: selectionSize.width, height: selectionSize.height)
                .rotationEffect(.degrees(rotationDegrees))
                .shadow(color: .black.opacity(0.3), radius: 1)
                .position(x: size.width / 2, y: size.height / 2)
                .allowsHitTesting(false)
            ForEach(CanvasTransformHandle.allCases, id: \.self) { handle in
                ProductIcon(kind: handle.icon)
                    .foregroundStyle(.white)
                    .scaleEffect(0.625 * handleScale)
                    .rotationEffect(.degrees(handle == .resize ? rotationDegrees : 0))
                    .frame(width: 26 * handleScale, height: 26 * handleScale)
                    .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 0.75))
                    .shadow(color: .black.opacity(0.3), radius: 1, y: 0.5)
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
        let x = selectionSize.width / (2 * sqrt(2)) * direction
        let y = selectionSize.height / (2 * sqrt(2)) * direction
        let angle = rotationDegrees * .pi / 180
        let point = CGPoint(x: center.x + x * cos(angle) - y * sin(angle),
                            y: center.y + x * sin(angle) + y * cos(angle))
        // 手柄靠近画布边缘时仍保留完整触摸范围，并避开底部工具。
        let visibleX = min(max(point.x, 22), max(22, canvasSize.width - 22))
        let visibleY = min(max(point.y, 22), max(22, canvasSize.height - 72))
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
                        .stroke(.white.opacity(0.65), lineWidth: 0.7)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                }
            }
            if let rect = drag?.rectangle ?? groupBounds {
                RoundedRectangle(cornerRadius: drag?.rectangle == nil ? 8 : 2)
                    .stroke(.white, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .shadow(color: .black.opacity(0.25), radius: 1)
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

private enum CanvasEmojiCatalog {
    static let items = [
        "♥︎", "♡", "😊", "😍", "🥰", "😋", "🤤", "🫶",
        "🍴", "✨", "🔥", "🌿", "🍓", "🍋", "🍕", "🍜",
        "🍣", "🍰", "☕️", "🥂", "🌙", "⭐️", "🎉", "🐱"
    ]
}

private enum CanvasEmojiCategory: String, CaseIterable, Identifiable, Hashable {
    case recent
    case mood
    case food
    case nature
    case symbols

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent: return "常用"
        case .mood: return "情绪"
        case .food: return "美食"
        case .nature: return "自然"
        case .symbols: return "符号"
        }
    }

    var icon: String {
        switch self {
        case .recent: return "square.grid.2x2"
        case .mood: return "face.smiling"
        case .food: return "fork.knife"
        case .nature: return "leaf"
        case .symbols: return "heart"
        }
    }

    var items: [String] {
        switch self {
        case .recent:
            return CanvasEmojiCatalog.items
        case .mood:
            return [
                "😊", "😍", "🥰", "😋", "🤤", "🫶", "😎", "😂",
                "😭", "😴", "🤗", "😳", "😡", "🥹", "🙌", "👏",
                "🫠", "🤍", "🫡", "😇", "🤩", "😌", "😮‍💨", "🥳",
                "😏", "😢", "😤", "🤭", "🫣", "😈", "👀", "💪",
                "🤞", "✌️", "🤟", "👌", "👍", "👎", "🎊", "🙏",
                "💋", "💐", "🌹", "💞", "💕", "💓", "💘", "💝"
            ]
        case .food:
            return [
                "🍴", "🍓", "🍋", "🍕", "🍜", "🍣", "🍰", "☕️",
                "🥂", "🍔", "🍟", "🌮", "🍙", "🥗", "🍎", "🍉",
                "🍌", "🍇", "🍑", "🥐", "🍳", "🥞", "🍩", "🍪",
                "🍫", "🍵", "🧋", "🍺", "🍷", "🥟", "🍱", "🍲",
                "🍛", "🍝", "🍖", "🍗", "🥩", "🌭", "🥪", "🌯",
                "🥙", "🫔", "🍤", "🦀", "🐟", "🍚", "🥣", "🧁"
            ]
        case .nature:
            return [
                "🌿", "🌱", "🌸", "🌼", "🌻", "🌹", "🌷", "🍀",
                "🌈", "☀️", "🌙", "⭐️", "☁️", "🌧️", "❄️", "🌊",
                "🍃", "🌾", "🌳", "🌲", "🌵", "🌴", "🌺", "🪻",
                "🦋", "🐝", "🐞", "🐚", "🪴", "🌞", "🌛", "🌟",
                "🌅", "🌄", "🏞️", "🌌", "🌠", "🌬️", "💧", "🔥",
                "🍂", "🍁", "🌰", "🏕️", "🪨", "🌍", "🌎", "🧺"
            ]
        case .symbols:
            return [
                "♥︎", "♡", "✨", "🔥", "💫", "⭐️", "🎉", "💌",
                "🎵", "✅", "❌", "💡", "🎈", "🧸", "🐱", "🐶",
                "🫶", "💖", "💗", "💛", "💚", "💙", "💜", "🤎",
                "🖤", "🤍", "💯", "💥", "💬", "🔔", "🎁", "🎀",
                "🎨", "📸", "🎬", "🎧", "🎤", "🎶", "🪩", "🕯️",
                "💎", "🪄", "🧡", "🩷", "🩵", "🤝", "🩶"
            ]
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
                Text(visible.isEmpty ? "…" : visible)
                    .font(note.isEmoji ? .system(size: 31) : note.font.font(size: 13, weight: .semibold))
                    .foregroundStyle(note.color == .white ? CanvasPalette.ink : note.color.color)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.55)
                    .opacity(effect.opacity(time: time, reduceMotion: reduceMotion))
                    .offset(effect.offset(time: time, reduceMotion: reduceMotion))
                    .scaleEffect(x: effect.scaleX(time: time, reduceMotion: reduceMotion), y: effect.scaleY(time: time, reduceMotion: reduceMotion))
                    .rotationEffect(.degrees(effect.rotation(time: time, reduceMotion: reduceMotion)))
            case .sticker(let effect, let sticker):
                StickerImageView(assetName: sticker.assetName, image: sticker.image, name: sticker.name, isCutout: sticker.isCutout)
                    .frame(width: 44, height: 44)
                    .scaleEffect(effect.scale(time: time, reduceMotion: reduceMotion))
                    .rotationEffect(.degrees(effect.rotation(time: time, reduceMotion: reduceMotion)))
                    .offset(effect.offset(time: time, reduceMotion: reduceMotion))
                    .shadow(color: effect == .glow ? CanvasPalette.accent.opacity(0.78) : .clear, radius: effect == .glow ? 10 : 0)
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

private enum CanvasBrushColor: String, CaseIterable, Identifiable, Codable {
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

private enum CanvasBrushStyle: String, CaseIterable, Identifiable, Codable {
    case solid, dotted, dashed, marker, crayon

    var id: String { rawValue }

    var title: String {
        switch self {
        case .solid: return "实线"
        case .dotted: return "点点"
        case .dashed: return "虚线"
        case .marker: return "荧光"
        case .crayon: return "蜡笔"
        }
    }

    var lineWidthMultiplier: CGFloat {
        switch self {
        case .marker: return 2.2
        case .crayon: return 1.35
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
            } else {
                var path = Path()
                path.move(to: CGPoint(x: 2, y: y))
                path.addLine(to: CGPoint(x: size.width - 2, y: y))
                context.stroke(path, with: .color(color.opacity(style.opacity)), style: StrokeStyle(lineWidth: style == .marker ? 7 : 3, lineCap: .round, dash: style == .dashed ? [6, 5] : []))
            }
        }
    }
}

private struct CanvasStroke: Codable, Hashable {
    var points: [CGPoint]
    var color: CanvasBrushColor
    var customColor: CanvasRGBA?
    var style: CanvasBrushStyle
    var width: CGFloat

    init(points: [CGPoint], color: CanvasBrushColor = .white, customColor: CanvasRGBA? = nil, style: CanvasBrushStyle = .solid, width: CGFloat = 4) {
        self.points = points
        self.color = color
        self.customColor = customColor
        self.style = style
        self.width = width
    }

    private enum CodingKeys: String, CodingKey { case points, color, customColor, style, width }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        points = try container.decode([CGPoint].self, forKey: .points)
        color = try container.decode(CanvasBrushColor.self, forKey: .color)
        customColor = try container.decodeIfPresent(CanvasRGBA.self, forKey: .customColor)
        style = try container.decodeIfPresent(CanvasBrushStyle.self, forKey: .style) ?? .solid
        width = try container.decodeIfPresent(CGFloat.self, forKey: .width) ?? 4
    }
}

private struct CanvasRGBA: Codable, Hashable {
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

private enum CanvasBackground: String, CaseIterable, Identifiable {
    case seaside, sunset, meadow, night, custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .seaside: return "海边"
        case .sunset: return "黄昏"
        case .meadow: return "草地"
        case .night: return "夜色"
        case .custom: return "自定义"
        }
    }

    var url: URL? {
        if self == .meadow { return nil }
        let raw: String
        switch self {
        case .seaside:
            raw = "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=85"
        case .sunset:
            raw = "https://images.unsplash.com/photo-1470252649378-9c29740c9fa8?auto=format&fit=crop&w=1200&q=85"
        case .meadow:
            raw = ""
        case .night:
            raw = "https://images.unsplash.com/photo-1519681393784-d120267933ba?auto=format&fit=crop&w=1200&q=85"
        case .custom:
            raw = ""
        }
        return URL(string: raw)
    }
}

private struct CanvasDocument: Codable {
    var background: String
    var blur: Double
    var customBackgroundData: Data?
    var stickers: [CanvasSticker]
    var notes: [CanvasNote]
    var strokes: [CanvasStroke]
    var size: CGSize?

    init(
        background: String,
        blur: Double,
        customBackgroundData: Data? = nil,
        stickers: [CanvasSticker],
        notes: [CanvasNote],
        strokes: [CanvasStroke] = [],
        size: CGSize? = nil
    ) {
        self.background = background
        self.blur = blur
        self.customBackgroundData = customBackgroundData
        self.stickers = stickers
        self.notes = notes
        self.strokes = strokes
        self.size = size
    }

    private enum CodingKeys: String, CodingKey {
        case background, blur, customBackgroundData, stickers, notes, strokes, size
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        background = try container.decode(String.self, forKey: .background)
        blur = try container.decode(Double.self, forKey: .blur)
        customBackgroundData = try container.decodeIfPresent(Data.self, forKey: .customBackgroundData)
        stickers = try container.decode([CanvasSticker].self, forKey: .stickers)
        notes = try container.decode([CanvasNote].self, forKey: .notes)
        strokes = try container.decodeIfPresent([CanvasStroke].self, forKey: .strokes) ?? []
        size = try container.decodeIfPresent(CGSize.self, forKey: .size)
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

private struct CanvasMediaBackground: View {
    let source: CanvasBackground
    let blur: Double
    let customData: Data?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if source == .custom, let customData, let image = UIImage(data: customData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if source == .meadow {
                Image("CanvasMeadow")
                    .resizable()
                    .scaledToFill()
            } else if let url = source.url {
                AsyncImage(url: url, transaction: Transaction(animation: reduceMotion ? nil : .easeInOut(duration: 0.25))) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .transition(.opacity)
                    case .empty:
                        fallback
                            .overlay(ProgressView().tint(.white.opacity(0.8)))
                    case .failure:
                        fallback
                    @unknown default:
                        fallback
                    }
                }
            } else {
                fallback
            }

            // 只给底图加毛玻璃，贴纸和文字保持清晰。
            if blur > 0 {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(min(0.42, blur / 20))
            }
        }
        .clipped()
    }

    private var fallback: some View {
        ZStack {
            LinearGradient(
                colors: source == .night
                    ? [Color(red: 0.07, green: 0.08, blue: 0.15), Color(red: 0.18, green: 0.12, blue: 0.24)]
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

private struct CanvasSticker: Identifiable, Codable, Hashable {
    let id: UUID
    let mealDishID: UInt?
    let name: String
    var image: String?
    var isCutout: Bool
    var assetName: String?
    var position: CanvasPoint
    var scale: CGFloat
    var rotationDegrees: Double
    var effect: CanvasEffect = .none
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
        effect: CanvasEffect = .none,
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
        self.shapeIndex = shapeIndex
        self.layer = layer
    }

    private enum CodingKeys: String, CodingKey {
        case id, mealDishID, name, image, isCutout, assetName, position, scale, rotationDegrees, effect, shapeIndex, layer
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
        shapeIndex = try container.decodeIfPresent(Int.self, forKey: .shapeIndex) ?? 0
        layer = try container.decodeIfPresent(Int.self, forKey: .layer) ?? 0
    }
}

private enum CanvasEffect: String, CaseIterable, Identifiable, Codable {
    case none
    case outline
    case glow
    case shake
    case bounce
    case float

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "无"
        case .outline: return "描边"
        case .glow: return "柔光"
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
        case .shake: return "waveform.path.ecg"
        case .bounce: return "arrow.up.and.down"
        case .float: return "wind"
        }
    }

    var isAnimated: Bool { self == .shake || self == .bounce || self == .float }

    func offset(time: TimeInterval, reduceMotion: Bool) -> CGSize {
        guard !reduceMotion else { return .zero }
        switch self {
        case .float: return CGSize(width: 0, height: sin(time * 1.5) * 6)
        case .bounce: return CGSize(width: 0, height: -abs(sin(time * 2.1)) * 5)
        default: return .zero
        }
    }

    func rotation(time: TimeInterval, reduceMotion: Bool) -> Double {
        self == .shake && !reduceMotion ? sin(time * 9) * 3 : 0
    }

    func scale(time: TimeInterval, reduceMotion: Bool) -> CGFloat {
        self == .bounce && !reduceMotion ? 1 + abs(sin(time * 2.1)) * 0.04 : 1
    }
}

private enum CanvasTextEffect: String, CaseIterable, Identifiable, Codable {
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
        case .plain: return "textformat"
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

    func offset(time: TimeInterval, reduceMotion: Bool) -> CGSize {
        guard !reduceMotion else { return .zero }
        switch self {
        case .float:
            return CGSize(width: 0, height: sin(time * 1.25) * 6)
        case .bounce:
            return CGSize(width: 0, height: -abs(sin(time * 2.1)) * 5)
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
    var alignmentTargets: [CanvasPoint] = []
    var onTransformStart: () -> Void = {}
    let onSelect: () -> Void
    let onTransform: () -> Void
    let onLayerMove: (CanvasLayerMove) -> Void
    let onDelete: () -> Void
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
        let x = canvasSize.width * sticker.position.x
        let y = canvasSize.height * sticker.position.y

        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion || scenePhase != .active || isSelected || isManipulating || !sticker.effect.isAnimated)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let effectsPaused = reduceMotion || isSelected || isManipulating
            ZStack(alignment: .topTrailing) {
                StickerImageView(assetName: sticker.assetName, image: sticker.image, name: sticker.name, isCutout: sticker.isCutout)
                    .frame(width: baseSize * 1.12, height: baseSize * 1.12)
                    .overlay {
                        if sticker.effect == .outline {
                            StickerBlobShape(index: sticker.shapeIndex)
                                .stroke(
                                    .white.opacity(0.94),
                                    style: StrokeStyle(
                                        lineWidth: 1.6,
                                        lineCap: .round,
                                        dash: [5, 4]
                                    )
                                )
                        }
                    }
                    .shadow(
                        color: sticker.effect == .glow
                            ? .white.opacity(0.8)
                            : Color(red: 0.20, green: 0.16, blue: 0.12).opacity(0.24),
                        radius: sticker.effect == .glow ? 20 : 8,
                        y: 6
                    )
                    .scaleEffect(sticker.effect.scale(time: time, reduceMotion: effectsPaused))
                    .rotationEffect(.degrees(sticker.effect.rotation(time: time, reduceMotion: effectsPaused)))
                    .offset(sticker.effect.offset(time: time, reduceMotion: effectsPaused))

            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isSelected)
        }
        .frame(width: baseSize * 1.34, height: baseSize * 1.34)
        .contentShape(Rectangle())
        .scaleEffect(min(max(sticker.scale, 0.3), 3) * (hasAppeared || reduceMotion ? 1 : 0.86))
        .rotationEffect(.degrees(sticker.rotationDegrees))
        .opacity(hasAppeared || reduceMotion ? 1 : 0)
        .onTapGesture(perform: onSelect)
        .animation(.spring(response: 0.34, dampingFraction: 0.74), value: sticker.effect)
        .contextMenu {
            elementContextMenu
        }
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
                                onTransformStart: onTransformStart,
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
            onSelect: onSelect, onChange: onChange))
        .position(x: x, y: y)
    }

    @ViewBuilder
    private var elementContextMenu: some View {
        Button("精细调整", systemImage: "arrow.up.left.and.arrow.down.right", action: onTransform)
        Section("层级") {
            Button("置顶", systemImage: "arrow.up.to.line") {
                onLayerMove(.front)
            }
            Button("上移一层", systemImage: "chevron.up") {
                onLayerMove(.forward)
            }
            Button("下移一层", systemImage: "chevron.down") {
                onLayerMove(.backward)
            }
            Button("置底", systemImage: "arrow.down.to.line") {
                onLayerMove(.back)
            }
        }
        Button("删除", systemImage: "trash", role: .destructive, action: onDelete)
    }

}

/// 真实菜品照片、透明食物素材和菜名使用相同的操作区域。
private struct StickerImageView: View {
    let assetName: String?
    let image: String?
    let name: String
    var isCutout = false
    @State private var loadedPhoto: UIImage?
    @State private var finishedLoading = false

    var body: some View {
        Group {
            if APIConfig.imageURL(image) != nil {
                if isCutout {
                    photoContent
                } else {
                    GeometryReader { proxy in
                        photoContent
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                }
            } else { fallback }
        }
        .task(id: image) {
            loadedPhoto = nil
            finishedLoading = false
            guard let url = APIConfig.imageURL(image) else { return }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled else { return }
                if (response as? HTTPURLResponse)?.statusCode == 200 {
                    loadedPhoto = UIImage(data: data)
                }
                finishedLoading = true
            } catch {
                if !Task.isCancelled { finishedLoading = true }
            }
        }
    }

    @ViewBuilder
    private var photoContent: some View {
        if let loadedPhoto {
            if isCutout {
                Image(uiImage: loadedPhoto).resizable().scaledToFit()
            } else {
                Image(uiImage: loadedPhoto).resizable().scaledToFill()
            }
        } else if finishedLoading {
            fallback
        } else {
            ProgressView().tint(.white)
        }
    }

    @ViewBuilder
    private var fallback: some View {
        if let assetName {
            Image(assetName).resizable().scaledToFit()
        } else {
            Text(name)
                .font(.system(size: 17, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding(14)
                .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 18))
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

private enum CanvasTextFont: String, CaseIterable, Identifiable, Codable, Hashable {
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
        case .handwritten: return .system(size: size, weight: weight, design: .rounded).italic()
        }
    }
}

private enum CanvasTextColor: String, CaseIterable, Identifiable, Codable, Hashable {
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

private struct CanvasNote: Identifiable, Codable, Hashable {
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
        color: CanvasTextColor = .white
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
    }

    private enum CodingKeys: String, CodingKey {
        case id, text, isEmoji, position, scale, rotationDegrees, layer, textEffect, font, color
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
    }
}

private struct CanvasNoteView: View {
    @Binding var note: CanvasNote
    let canvasSize: CGSize
    let isSelected: Bool
    var freezesMotion = false
    var reportsBounds = false
    var alignmentTargets: [CanvasPoint] = []
    var onTransformStart: () -> Void = {}
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onTransform: () -> Void
    let onLayerMove: (CanvasLayerMove) -> Void
    let onDelete: () -> Void
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
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion || scenePhase != .active || isSelected || isManipulating || note.textEffect == .plain)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let effectsPaused = reduceMotion || isSelected || isManipulating
            ZStack {
                Text(note.text).hidden()
                Text(note.textEffect.visibleText(note.text, time: time, reduceMotion: effectsPaused))
            }
                .font(note.isEmoji ? .system(size: 38) : note.font.font(size: textFontSize, weight: .semibold))
                .tracking(note.isEmoji ? 0 : 0.35)
                .multilineTextAlignment(.center)
                .lineLimit(note.isEmoji ? 1 : 3)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(note.isEmoji ? .white : note.color.color)
                .shadow(color: .black.opacity(0.34), radius: 5, y: 3)
                .padding(.horizontal, note.isEmoji ? 0 : 5)
                .padding(.vertical, note.isEmoji ? 0 : 3)
                .background(.clear)
                .opacity(note.textEffect.opacity(time: time, reduceMotion: effectsPaused))
                .offset(note.textEffect.offset(time: time, reduceMotion: effectsPaused))
                .scaleEffect(x: note.textEffect.scaleX(time: time, reduceMotion: effectsPaused), y: note.textEffect.scaleY(time: time, reduceMotion: effectsPaused))
                .rotationEffect(.degrees(note.textEffect.rotation(time: time, reduceMotion: effectsPaused)))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isSelected)
        }
        // 完整文字保留排版尺寸，打字过程中选中框和触摸区域保持稳定。
        .padding(.horizontal, note.isEmoji ? 10 : 16)
        .padding(.vertical, note.isEmoji ? 10 : 12)
        .frame(minWidth: note.isEmoji ? 64 : 136, minHeight: note.isEmoji ? 64 : 64)
        .contentShape(Rectangle())
        .scaleEffect(min(max(note.scale, 0.3), 3) * (hasAppeared || reduceMotion ? 1 : 0.86))
        .rotationEffect(.degrees(note.rotationDegrees))
        .opacity(hasAppeared || reduceMotion ? 1 : 0)
        .onTapGesture(perform: onSelect)
        .animation(.spring(response: 0.34, dampingFraction: 0.74), value: note.textEffect)
        .contextMenu {
            elementContextMenu
        }
        .accessibilityLabel(note.isEmoji ? "\(note.text)表情" : "画布文字")
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
                                onTransformStart: onTransformStart,
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
            onSelect: onSelect, onChange: onChange))
        .position(
            x: canvasSize.width * note.position.x,
            y: canvasSize.height * note.position.y
        )
    }

    @ViewBuilder
    private var elementContextMenu: some View {
        if !note.isEmoji {
            Button("编辑文字", systemImage: "pencil", action: onEdit)
        }
        Button("精细调整", systemImage: "arrow.up.left.and.arrow.down.right", action: onTransform)
        Section("层级") {
            Button("置顶", systemImage: "arrow.up.to.line") {
                onLayerMove(.front)
            }
            Button("上移一层", systemImage: "chevron.up") {
                onLayerMove(.forward)
            }
            Button("下移一层", systemImage: "chevron.down") {
                onLayerMove(.backward)
            }
            Button("置底", systemImage: "arrow.down.to.line") {
                onLayerMove(.back)
            }
        }
        Button("删除", systemImage: "trash", role: .destructive, action: onDelete)
    }
}

private struct CanvasDrawingView: View {
    @Binding var strokes: [CanvasStroke]
    @Binding var activeStroke: [CGPoint]
    let isEnabled: Bool
    let brush: CanvasBrushColor
    let paintColor: Color
    let style: CanvasBrushStyle
    let width: CGFloat
    let onEnd: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                drawingSurface
                    .frame(width: proxy.size.width, height: proxy.size.height)

                // The hit layer must exactly cover the canvas. An unconstrained
                // transparent Rectangle can collapse to the trailing side in a
                // ScrollView and makes drawing appear offset or unavailable.
                if isEnabled {
                    Rectangle()
                        .fill(.black.opacity(0.001))
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .contentShape(Rectangle())
                        .highPriorityGesture(drawGesture, including: .all)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .allowsHitTesting(isEnabled)
    }

    private var drawingSurface: some View {
        ZStack {
            Canvas { context, _ in
                for stroke in strokes {
                    let points = stroke.points
                    let strokeColor = stroke.customColor?.color ?? stroke.color.color
                    let strokeWidth = stroke.width * stroke.style.lineWidthMultiplier
                    guard let first = points.first else { continue }
                    if stroke.style == .dotted {
                        for point in points {
                            context.fill(
                                Path(ellipseIn: CGRect(x: point.x - strokeWidth / 2, y: point.y - strokeWidth / 2, width: strokeWidth, height: strokeWidth)),
                                with: .color(strokeColor.opacity(stroke.style.opacity))
                            )
                        }
                    } else if points.count == 1 {
                        context.fill(
                            Path(ellipseIn: CGRect(x: first.x - strokeWidth / 2, y: first.y - strokeWidth / 2, width: strokeWidth, height: strokeWidth)),
                            with: .color(strokeColor.opacity(stroke.style.opacity))
                        )
                        continue
                    } else {
                        var path = Path()
                        path.move(to: first)
                        for point in points.dropFirst() { path.addLine(to: point) }
                        context.stroke(
                            path,
                            with: .color(strokeColor.opacity(stroke.style.opacity)),
                            style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round, dash: stroke.style == .dashed ? [strokeWidth * 1.8, strokeWidth * 1.4] : [])
                        )
                    }
                }

                if let first = activeStroke.first {
                    let strokeWidth = width * style.lineWidthMultiplier
                    if style == .dotted {
                        for point in activeStroke {
                            context.fill(
                                Path(ellipseIn: CGRect(x: point.x - strokeWidth / 2, y: point.y - strokeWidth / 2, width: strokeWidth, height: strokeWidth)),
                                with: .color(paintColor.opacity(style.opacity))
                            )
                        }
                    } else if activeStroke.count == 1 {
                        context.fill(
                            Path(ellipseIn: CGRect(x: first.x - strokeWidth / 2, y: first.y - strokeWidth / 2, width: strokeWidth, height: strokeWidth)),
                            with: .color(paintColor.opacity(style.opacity))
                        )
                    } else {
                        var path = Path()
                        path.move(to: first)
                        for point in activeStroke.dropFirst() { path.addLine(to: point) }
                        context.stroke(path, with: .color(paintColor.opacity(style.opacity)), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round, dash: style == .dashed ? [strokeWidth * 1.8, strokeWidth * 1.4] : []))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var drawGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if activeStroke.isEmpty {
                    activeStroke = [value.startLocation]
                }
                activeStroke.append(value.location)
            }
            .onEnded { _ in
                guard !activeStroke.isEmpty else { return }
                strokes.append(CanvasStroke(points: activeStroke, color: brush, customColor: CanvasRGBA(color: paintColor), style: style, width: width))
                activeStroke.removeAll()
                onEnd()
            }
    }
}

private struct LiveControlButton: View {
    let title: String
    let icon: String
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
        case "arrow.uturn.backward": return .undo
        case "slider.horizontal.3": return .adjust
        case "checkmark": return .check
        case "selection": return .select
        case "selection.all": return .selectAll
        default: return nil
        }
    }

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            Group {
                if let glyph {
                    ProductIcon(kind: glyph)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .regular))
                }
            }
            .scaleEffect(0.88)
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background {
                Circle()
                    .fill(isActive ? CanvasPalette.accent : .black.opacity(0.44))
                    .frame(width: 34, height: 34)
            }
            .contentShape(Circle())
            .opacity(isDisabled ? 0.4 : 1)
        }
        .buttonStyle(CanvasPressStyle(scale: 0.90))
        .disabled(isDisabled)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

private struct CanvasElementActionBar: View {
    let canEditText: Bool
    let isDeleting: Bool
    let layers: [CanvasLayerEntry]
    let selection: CanvasSelection
    let onSelect: (CanvasSelection) -> Void
    let onEditText: () -> Void
    let onEdit: () -> Void
    let onLayerMove: (CanvasLayerMove) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 3) {
            if canEditText {
                Button {
                    Haptics.light()
                    onEditText()
                } label: {
                    ProductIcon(kind: .draw)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("编辑文字")
            }
            Button {
                Haptics.light()
                onEdit()
            } label: {
                ProductIcon(kind: .effects)
                    .foregroundStyle(CanvasPalette.accent)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("添加特效")

            Menu {
                Section("层级") {
                    Button("置顶", systemImage: "arrow.up.to.line") {
                        onLayerMove(.front)
                    }
                    .disabled(layers.first?.selection == selection)
                    Button("上移一层", systemImage: "chevron.up") {
                        onLayerMove(.forward)
                    }
                    .disabled(layers.first?.selection == selection)
                    Button("下移一层", systemImage: "chevron.down") {
                        onLayerMove(.backward)
                    }
                    .disabled(layers.last?.selection == selection)
                    Button("置底", systemImage: "arrow.down.to.line") {
                        onLayerMove(.back)
                    }
                    .disabled(layers.last?.selection == selection)
                }
                Menu("选择内容", systemImage: "square.stack") {
                    ForEach(layers, id: \.selection) { entry in
                        Button(entry.title, systemImage: entry.selection == selection ? "checkmark" : entry.icon) {
                            onSelect(entry.selection)
                        }
                        .accessibilityAddTraits(entry.selection == selection ? .isSelected : [])
                    }
                }
            } label: {
                ProductIcon(kind: .layers)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("调整图层")
            .accessibilityHint("可选择被遮住的内容，或调整前后层级")

            Button(role: .destructive) {
                Haptics.light()
                onDelete()
            } label: {
                Group {
                    if isDeleting {
                        ProgressView().tint(CanvasPalette.accent)
                    } else {
                        ProductIcon(kind: .trash)
                    }
                }
                .frame(width: 44, height: 44)
            }
            .accessibilityLabel("删除元素")
        }
        .font(.system(size: 13, weight: .medium))
        .lineLimit(1)
        .foregroundStyle(CanvasPalette.ink)
        .padding(4)
        .background(.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(CanvasPalette.ink.opacity(0.06), lineWidth: 0.8)
        }
        .shadow(color: CanvasPalette.ink.opacity(0.14), radius: 8, y: 3)
        .buttonStyle(CanvasPressStyle(scale: 0.88))
        .disabled(isDeleting)
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
