import SwiftUI
import PhotosUI
import UIKit

/// 首页的主画布。菜谱仍然由 AddDishView 负责，首页只负责把「这一顿」拼出来。
/// 这是第一版可玩的画布：底图、贴纸、文字、涂鸦和轻量动效都在本地即时生效。
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
    @State private var drawingEnabled = false
    @State private var restoredMealID: UInt?
    @State private var liveDuration = 5
    @State private var isMuted = true
    @State private var isEditing = false
    @State private var activeEditor: CanvasEditorPanel?
    @State private var insertMode: CanvasInsertItem?
    @State private var draftText = "今晚吃点好的"
    @State private var emojiCategory: CanvasEmojiCategory = .recent
    @State private var backgroundPhotoItem: PhotosPickerItem?
    @FocusState private var textEditorFocused: Bool

    var body: some View {
        ZStack {
            CanvasPalette.page.ignoresSafeArea()
            CanvasPaperTexture()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    header
                    canvas

                    if vm.loadFailed && vm.meal == nil {
                        retryStrip
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 0)
            }
            .scrollDisabled(drawingEnabled)

        }
        .onAppear { restoreDocumentIfNeeded() }
        .onChange(of: vm.meal?.id) { _, _ in
            selectedStickerID = nil
            selectedNoteID = nil
            activeStroke.removeAll()
            isEditing = false
            activeEditor = nil
            insertMode = nil
            textEditorFocused = false
            restoreDocumentIfNeeded()
        }
        .onChange(of: vm.meal?.status) { _, status in
            if status == .confirmed || status == .completed {
                finishEditing()
            }
        }
        .onChange(of: vm.dishCount) { _, _ in syncStickers() }
        .onChange(of: background) { _, _ in saveDocument() }
        .onChange(of: blur) { _, _ in saveDocument() }
        .onChange(of: customBackgroundData) { _, _ in saveDocument() }
        .onChange(of: backgroundPhotoItem) { _, item in
            guard let item else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data),
                      let preview = image.canvasPreviewData else { return }
                await MainActor.run {
                    customBackgroundData = preview
                    background = .custom
                    backgroundPhotoItem = nil
                }
            }
        }
        .sheet(isPresented: $isEditing, onDismiss: {
            // 下滑关闭编辑器时也要完整退出画笔和选中态，避免回到首页后
            // 画布仍拦截滚动或继续接收涂鸦手势。
            activeEditor = nil
            drawingEnabled = false
            selectedStickerID = nil
            selectedNoteID = nil
        }) {
            if activeEditor != nil {
                inlineEditorPanel
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                    .presentationDetents([.height(320), .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Color.white)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text("今日")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        Text("LiveLog")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(CanvasPalette.ink)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(CanvasPalette.muted)
                    Text("· \(vm.dishCount)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(CanvasPalette.accent)
                }
                Text(isEditing ? "拖一拖，摆成你喜欢的样子" : "把想吃的，放在一起")
                    .font(.system(size: 12))
                    .foregroundStyle(CanvasPalette.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Menu {
                Button("保存至相册", systemImage: "square.and.arrow.down") {
                    saveCanvasToPhotos()
                }
                if vm.meal?.status == .planning {
                    Button("从菜谱加菜", systemImage: "plus") {
                        onAddDish()
                    }
                }
                if isEditing {
                    Button("完成编辑", systemImage: "checkmark") {
                        finishEditing()
                    }
                } else {
                    Button("编辑画布", systemImage: "pencil") {
                        beginEditing()
                    }
                    if vm.dishCount > 0 || (vm.meal?.status != nil && vm.meal?.status != .planning) {
                        Button(confirmTitle, systemImage: confirmIcon) {
                            Haptics.light()
                            actionBarConfirm()
                        }
                    }
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
                Text("保存至相册")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(CanvasPalette.ink)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(CanvasPalette.surface, in: Capsule())
                    .overlay {
                        Capsule().stroke(CanvasPalette.ink.opacity(0.06), lineWidth: 0.8)
                    }
            }
            .accessibilityLabel("保存至相册及更多操作")

        }
    }

    private var canvas: some View {
        GeometryReader { proxy in
            ZStack {
                CanvasMediaBackground(
                    source: background,
                    blur: blur,
                    reduceMotion: reduceMotion,
                    customData: customBackgroundData
                )
                .allowsHitTesting(false)

                if stickers.isEmpty && notes.isEmpty && strokes.isEmpty {
                    VStack(spacing: 7) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 23, weight: .light))
                        Text("从菜谱挑几道菜")
                            .font(.system(size: 16, weight: .semibold))
                        Text("它们会变成画布上的贴纸")
                            .font(.system(size: 12))
                            .opacity(0.76)
                        Button {
                            Haptics.light()
                            onAddDish()
                        } label: {
                            Label("去菜谱挑几道", systemImage: "book.closed")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(CanvasPalette.ink)
                                .padding(.horizontal, 13)
                                .frame(height: 32)
                                .background(.white.opacity(0.92), in: Capsule())
                        }
                        .buttonStyle(CanvasPressStyle(scale: 0.94))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(.black.opacity(0.20), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                ForEach($stickers) { $sticker in
                    CanvasStickerView(
                        sticker: $sticker,
                        canvasSize: proxy.size,
                        isSelected: sticker.id == selectedStickerID,
                        reduceMotion: reduceMotion,
                        onSelect: {
                            withAnimation(.spring(response: 0.30, dampingFraction: 0.76)) {
                                selectedStickerID = sticker.id
                                selectedNoteID = nil
                            }
                        },
                        onLayerMove: { move in
                            moveLayer(move, for: .sticker(sticker.id))
                        },
                        onDelete: {
                            deleteElement(.sticker(sticker.id))
                        },
                        onChange: saveDocument
                    )
                    .zIndex(Double(sticker.layer))
                }

                ForEach($notes) { $note in
                    CanvasNoteView(
                        note: $note,
                        canvasSize: proxy.size,
                        isSelected: note.id == selectedNoteID,
                        onSelect: {
                            withAnimation(.spring(response: 0.30, dampingFraction: 0.76)) {
                                selectedStickerID = nil
                                selectedNoteID = note.id
                            }
                        },
                        onLayerMove: { move in
                            moveLayer(move, for: .note(note.id))
                        },
                        onDelete: {
                            deleteElement(.note(note.id))
                        },
                        onChange: saveDocument
                    )
                    .zIndex(Double(note.layer))
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

                if let selected = selectedCanvasElement {
                    CanvasElementActionBar(
                        onEdit: { beginEditing(preferred: .effects) },
                        onLayerMove: { moveLayer($0, for: selected) },
                        onDelete: { deleteElement(selected) }
                    )
                    .position(elementMenuPosition(for: selected, in: proxy.size))
                    .transition(.scale(scale: 0.82, anchor: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.30, dampingFraction: 0.72), value: selected)
                    .zIndex(1000)
                }
            }
            .overlay(alignment: .topLeading) {
                HStack(spacing: 5) {
                    Image(systemName: "livephoto")
                        .font(.system(size: 13, weight: .semibold))
                    Text("实况")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(.black.opacity(0.25), in: Capsule())
                .padding(12)
            }
            .overlay(alignment: .bottom) {
                liveControls
                    .padding(.horizontal, 9)
                    .padding(.bottom, 9)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            // 所有点按都由画布这一层统一命中；元素自身只处理拖动、缩放和旋转。
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        handleCanvasTap(at: value.location, in: proxy.size)
                    },
                including: .all
            )
        }
        // The editor is a sheet, so the canvas keeps its poster proportion while editing.
        .aspectRatio(0.58, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.13), radius: 18, y: 8)
    }

    private func handleCanvasTap(at point: CGPoint, in size: CGSize) {
        guard !drawingEnabled, size.width > 0, size.height > 0 else { return }

        // 先按层级从上到下命中，避免两个装饰元素靠近时总是选到先渲染的那个。
        var candidates: [(layer: Int, selection: CanvasSelection, distance: CGFloat, radius: CGFloat)] = []
        for sticker in stickers {
            let center = CGPoint(x: size.width * sticker.position.x, y: size.height * sticker.position.y)
            // 命中范围按贴纸实际可拖动外框计算，避免点到透明边缘时落空。
            let radius = max(54, min(size.width, size.height) * 0.18 * sticker.scale)
            candidates.append((sticker.layer, .sticker(sticker.id), hypot(point.x - center.x, point.y - center.y), radius))
        }
        for note in notes {
            let center = CGPoint(x: size.width * note.position.x, y: size.height * note.position.y)
            let radius = note.isEmoji ? max(34, min(size.width, size.height) * 0.085 * note.scale) : max(74, min(size.width, size.height) * 0.16 * note.scale)
            candidates.append((note.layer, .note(note.id), hypot(point.x - center.x, point.y - center.y), radius))
        }

        guard let hit = candidates
            .filter({ $0.distance <= $0.radius })
            .sorted(by: { $0.layer == $1.layer ? $0.distance < $1.distance : $0.layer > $1.layer })
            .first else {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                selectedStickerID = nil
                selectedNoteID = nil
            }
            return
        }

        withAnimation(.spring(response: 0.30, dampingFraction: 0.76)) {
            switch hit.selection {
            case .sticker(let id):
                selectedStickerID = id
                selectedNoteID = nil
            case .note(let id):
                selectedStickerID = nil
                selectedNoteID = id
            }
        }
    }

    /// 画布内唯一的编辑工具条，详细设置在底部工作表中展开。
    private var liveControls: some View {
        HStack(spacing: 4) {
            Menu {
                ForEach([3, 5, 10], id: \.self) { seconds in
                    Button("\(seconds)s") {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.80)) {
                            liveDuration = seconds
                        }
                    }
                }
            } label: {
                LiveControlLabel(title: "\(liveDuration)s", icon: "chevron.down")
            }

            LiveControlButton(title: "Aa", icon: nil, isActive: isEditing && activeEditor == .insert) {
                openEditor(.insert)
            }
            LiveControlButton(title: "贴纸", icon: nil, isActive: isEditing && activeEditor == .emoji) {
                openEditor(.emoji)
            }
            LiveControlButton(
                title: nil,
                icon: "sparkles",
                isActive: isEditing && activeEditor == .effects || hasActiveCanvasEffect
            ) {
                openEditor(.effects)
            }
            LiveControlButton(title: "画笔", icon: nil, isActive: drawingEnabled || activeEditor == .brush) {
                if drawingEnabled {
                    drawingEnabled = false
                } else {
                    openEditor(.brush)
                }
            }
            LiveControlButton(title: "背景", icon: nil, isActive: isEditing && activeEditor == .background) {
                openEditor(.background)
            }
            LiveControlButton(
                title: nil,
                icon: isMuted ? "speaker.slash" : "speaker.wave.2",
                isActive: !isMuted
            ) {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.80)) {
                    isMuted.toggle()
                }
            }
        }
        .padding(.vertical, 2)
        // The editor row is deliberately full-width. Without an explicit frame,
        // SwiftUI can measure the overlay at its intrinsic width on compact
        // simulator sizes and push the trailing controls outside the canvas.
        // Keep the controls anchored to the leading edge of the full-width
        // pill. Centering an intrinsic-width overlay can resolve to a trailing
        // frame inside GeometryReader on compact iPhones.
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private var inlineEditorPanel: some View {
        if let activeEditor {
            VStack(alignment: .leading, spacing: 0) {
                editorSheetHeader(activeEditor)
                if activeEditor != .background {
                    editorToolSwitcher
                        .padding(.top, 14)
                }
                Group {
                    switch activeEditor {
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
        }
    }

    private func editorSheetHeader(_ panel: CanvasEditorPanel) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(panel == .insert ? "写一句" : panel == .emoji ? "Live 贴纸" : panel == .effects ? "给画布加点动效" : panel == .brush ? "画笔" : "画布背景")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundStyle(CanvasPalette.ink)
                Text(panel == .insert ? "文字会作为贴纸放在画布上" : panel == .emoji ? "点击添加，拖出实况区域移除" : panel == .effects ? effectEditorHint : panel == .brush ? "选颜色和粗细，然后直接在画布上涂写" : "换一张照片或调整背景氛围")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(CanvasPalette.muted)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Button { finishEditing() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(CanvasPalette.ink)
                    .frame(width: 32, height: 32)
                    .background(CanvasPalette.page, in: Circle())
            }
            .buttonStyle(CanvasPressStyle(scale: 0.90))
            .accessibilityLabel("关闭编辑器")
        }
    }

    private var effectEditorHint: String {
        switch selectedCanvasElement {
        case .sticker: return "当前选中菜品贴纸"
        case .note: return "当前选中文字贴纸"
        case nil: return "先在画布上点选一个菜品或文字"
        }
    }

    private var editorToolSwitcher: some View {
        HStack(spacing: 0) {
            ForEach([CanvasEditorPanel.insert, .emoji, .effects, .brush]) { panel in
                Button {
                    Haptics.light()
                    openEditor(panel)
                } label: {
                    VStack(spacing: 7) {
                        Label(panel.title, systemImage: panel.icon)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(activeEditor == panel ? CanvasPalette.ink : CanvasPalette.muted)
                        Rectangle()
                            .fill(activeEditor == panel ? CanvasPalette.accent : .clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 39)
                }
                .buttonStyle(CanvasPressStyle(scale: 0.97))
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(CanvasPalette.ink.opacity(0.08))
                .frame(height: 1)
        }
    }

    private var textEditorContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $draftText)
                    .focused($textEditorFocused)
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
                                        .frame(height: 32)
                                        .background(note.font == font ? CanvasPalette.accent.opacity(0.18) : CanvasPalette.page, in: Capsule())
                                }
                                .buttonStyle(CanvasPressStyle(scale: 0.94))
                            }
                        }
                        HStack(spacing: 8) {
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
                                        .overlay(Circle().stroke(note.color == color ? CanvasPalette.ink : .white.opacity(0.72), lineWidth: note.color == color ? 2 : 1))
                                }
                                .buttonStyle(CanvasPressStyle(scale: 0.92))
                                .accessibilityLabel("文字颜色 (color.title)")
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
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(abs((notes.first(where: { $0.id == selectedNoteID })?.scale ?? 1) - CGFloat(preset.0)) < 0.02 ? CanvasPalette.ink : CanvasPalette.muted)
                                .frame(maxWidth: .infinity)
                                .frame(height: 30)
                                .background(abs((notes.first(where: { $0.id == selectedNoteID })?.scale ?? 1) - CGFloat(preset.0)) < 0.02 ? CanvasPalette.accent.opacity(0.18) : CanvasPalette.page, in: Capsule())
                        }
                        .buttonStyle(CanvasPressStyle(scale: 0.94))
                    }
                }
            }
            HStack(spacing: 10) {
                Button {
                    Haptics.light()
                    openEditor(.emoji)
                } label: {
                    Label("贴纸", systemImage: "face.smiling")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(CanvasPalette.ink)
                        .frame(height: 38)
                        .frame(maxWidth: .infinity)
                        .background(CanvasPalette.page, in: Capsule())
                }
                .buttonStyle(CanvasPressStyle(scale: 0.96))
                Button {
                    Haptics.light()
                    commitDraftText()
                } label: {
                    Text("放到画布")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(height: 38)
                        .frame(maxWidth: .infinity)
                        .background(CanvasPalette.ink, in: Capsule())
                }
                .buttonStyle(CanvasPressStyle(scale: 0.96))
                .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.35 : 1)
            }
        }
        .padding(.bottom, 6)
        }
    }

    private var emojiEditorContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("贴纸库")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(CanvasPalette.ink)
                Spacer()
                Button("清空") {
                    Haptics.light()
                    clearEmojiStickers()
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(CanvasPalette.muted)
                .disabled(!notes.contains(where: { $0.isEmoji }))
            }
            HStack(spacing: 6) {
                ForEach(CanvasEmojiCategory.allCases) { item in
                    Button {
                        Haptics.light()
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) { emojiCategory = item }
                    } label: {
                        Capsule()
                            .fill(emojiCategory == item ? CanvasPalette.accent : CanvasPalette.ink.opacity(0.14))
                            .frame(width: emojiCategory == item ? 28 : 7, height: 6)
                    }
                    .buttonStyle(CanvasPressStyle(scale: 0.92))
                    .accessibilityLabel("贴纸分页 \(item.title)")
                }
                Spacer()
            }
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
        }
    }

    @ViewBuilder
    private var effectsEditorContent: some View {
        if selectedCanvasElement == nil {
            VStack(spacing: 8) {
                Image(systemName: "cursorarrow.click.2")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(CanvasPalette.accent)
                Text("先点选画布里的菜品或文字")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(CanvasPalette.ink)
                Text("选中后这里会显示适合它的动效")
                    .font(.system(size: 12))
                    .foregroundStyle(CanvasPalette.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
        } else {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                if case .sticker = selectedCanvasElement {
                    ForEach(CanvasEffect.allCases) { effect in
                        CanvasInlineEditorCard(icon: effect.icon, title: effect.title, previewKind: .sticker(effect), isSelected: selectedStickerEffect == effect) { applyEffect(effect) }
                    }
                } else {
                    ForEach(CanvasTextEffect.allCases) { effect in
                        CanvasInlineEditorCard(icon: effect.icon, title: effect.title, previewKind: .text(effect), isSelected: selectedTextEffect == effect) { applyTextEffect(effect) }
                    }
                }
            }
        }
    }

    private var brushEditorContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("颜色")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CanvasPalette.muted)
                Spacer()
                Text(usesCustomBrushColor ? "自定义" : brushColor.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(CanvasPalette.ink)
            }
            HStack(spacing: 6) {
                ForEach(CanvasBrushColor.allCases) { item in
                    Button {
                        Haptics.light()
                        brushColor = item
                        customBrushColor = item.color
                        usesCustomBrushColor = false
                    } label: {
                        VStack(spacing: 5) {
                            Circle()
                                .fill(item.color)
                                .frame(width: 28, height: 28)
                                .overlay(Circle().stroke(item == brushColor ? CanvasPalette.ink : CanvasPalette.ink.opacity(0.12), lineWidth: item == brushColor ? 2 : 0.8))
                                .overlay { if item == brushColor { Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(item == .ink ? .white : CanvasPalette.ink) } }
                            Text(item.shortTitle)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(item == brushColor ? CanvasPalette.ink : CanvasPalette.muted)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(CanvasPressStyle(scale: 0.92))
                }
            }
            HStack(spacing: 10) {
                ColorPicker("自由取色", selection: $customBrushColor, supportsOpacity: true)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(CanvasPalette.ink)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(CanvasPalette.page, in: Capsule())
                    .onChange(of: customBrushColor) { _, _ in usesCustomBrushColor = true }
                Spacer()
                Circle()
                    .fill(customBrushColor)
                    .frame(width: 25, height: 25)
                    .overlay(Circle().stroke(CanvasPalette.ink.opacity(0.16), lineWidth: 1))
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("笔触")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CanvasPalette.muted)
                HStack(spacing: 8) {
                    ForEach(CanvasBrushStyle.allCases) { item in
                        Button {
                            Haptics.light()
                            brushStyle = item
                        } label: {
                            VStack(spacing: 5) {
                                CanvasBrushPreview(style: item, color: brushColor.color)
                                    .frame(height: 22)
                                Text(item.title)
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundStyle(item == brushStyle ? CanvasPalette.ink : CanvasPalette.muted)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(item == brushStyle ? CanvasPalette.accent.opacity(0.15) : CanvasPalette.page, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(item == brushStyle ? CanvasPalette.accent : CanvasPalette.ink.opacity(0.08), lineWidth: item == brushStyle ? 1.2 : 0.8)
                            }
                        }
                        .buttonStyle(CanvasPressStyle(scale: 0.94))
                    }
                }
            }
            HStack(spacing: 10) {
                Text("粗细")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CanvasPalette.muted)
                Slider(value: $brushWidth, in: 2...14, step: 1)
                    .tint(CanvasPalette.ink)
                Text("\(Int(brushWidth)) pt")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(CanvasPalette.ink)
                    .frame(width: 42, alignment: .trailing)
            }
            Button {
                startDrawing()
            } label: {
                Label(drawingEnabled ? "正在画布上绘制" : "开始在画布上绘制", systemImage: drawingEnabled ? "pencil.tip" : "hand.tap")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(drawingEnabled ? CanvasPalette.accent : CanvasPalette.ink, in: Capsule())
            }
            .buttonStyle(CanvasPressStyle(scale: 0.96))
        }
    }

    private func elementMenuPosition(for selection: CanvasSelection, in size: CGSize) -> CGPoint {
        let point: CanvasPoint
        switch selection {
        case .sticker(let id):
            point = stickers.first(where: { $0.id == id })?.position ?? CanvasPoint(x: 0.5, y: 0.5)
        case .note(let id):
            point = notes.first(where: { $0.id == id })?.position ?? CanvasPoint(x: 0.5, y: 0.5)
        }
        return CGPoint(
            x: min(max(size.width * point.x + 30, 18), max(18, size.width - 18)),
            y: min(max(size.height * point.y - 30, 18), max(18, size.height - 18))
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
                                CanvasMediaBackground(source: item, blur: 0, reduceMotion: true, customData: customBackgroundData)
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
                        .disabled(item == .custom && customBackgroundData == nil)
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

    private var hasActiveCanvasEffect: Bool {
        switch selectedCanvasElement {
        case .sticker(let id):
            return stickers.first(where: { $0.id == id })?.effect != CanvasEffect.none
        case .note(let id):
            return notes.first(where: { $0.id == id })?.textEffect != .plain
        case nil:
            return false
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

    private var layerEntries: [CanvasLayerEntry] {
        stickers.map { CanvasLayerEntry(selection: .sticker($0.id), layer: $0.layer) }
            + notes.map { CanvasLayerEntry(selection: .note($0.id), layer: $0.layer) }
    }

    private func moveLayer(_ move: CanvasLayerMove, for selected: CanvasSelection) {
        let ordered = layerEntries.sorted { $0.layer < $1.layer }
        guard let currentIndex = ordered.firstIndex(where: { $0.selection == selected }) else { return }

        switch move {
        case .front:
            setLayer((ordered.last?.layer ?? 0) + 1, for: selected)
        case .back:
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
            stickers.removeAll { $0.id == id }
            selectedStickerID = nil
        case .note(let id):
            notes.removeAll { $0.id == id }
            selectedNoteID = nil
        }
        saveDocument()
    }

    private func beginEditing(preferred: CanvasEditorPanel? = nil) {
        if !isEditing {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                isEditing = true
            }
        }
        if let preferred {
            activeEditor = preferred
        } else if activeEditor == nil {
            withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                activeEditor = .insert
            }
        }
    }

    private func openEditor(_ panel: CanvasEditorPanel) {
        beginEditing()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.80)) {
            activeEditor = panel
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

    private func startDrawing() {
        Haptics.light()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.80)) {
            isEditing = false
            activeEditor = nil
            selectedStickerID = nil
            selectedNoteID = nil
            drawingEnabled = true
        }
    }

    private func finishEditing() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            isEditing = false
            activeEditor = nil
            insertMode = nil
            drawingEnabled = false
            selectedStickerID = nil
            selectedNoteID = nil
        }
    }

    private func actionBarConfirm() {
        guard vm.meal?.status == .planning else {
            finishEditing()
            return
        }
        onConfirm()
    }

    private var hasCanvasAdditions: Bool {
        !notes.isEmpty || !strokes.isEmpty || !activeStroke.isEmpty
    }

    private var nextLayerIndex: Int {
        let highest = (stickers.map(\.layer) + notes.map(\.layer)).max() ?? -1
        return highest + 1
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
            // Keep the first caption in the quiet sky area, above the dish
            // cluster, so a newly added note never lands on a sticker.
            position: CanvasPoint(x: 0.50, y: 0.16),
            layer: nextLayerIndex
        )
        notes.append(note)
        selectedStickerID = nil
        selectedNoteID = note.id
        saveDocument()
    }

    private func setSelectedNoteScale(_ scale: CGFloat) {
        guard let selectedNoteID, let index = notes.firstIndex(where: { $0.id == selectedNoteID }), !notes[index].isEmoji else { return }
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
    }

    private func clearEmojiStickers() {
        notes.removeAll { $0.isEmoji }
        if case .note = selectedCanvasElement { selectedNoteID = nil }
        saveDocument()
    }

    private func insertEmoji(_ emoji: String) {
        // Put decorative marks in the lower-right breathing room by default;
        // users can still drag, pinch, and rotate them directly on the canvas.
        let note = CanvasNote(text: emoji, isEmoji: true, position: CanvasPoint(x: 0.78, y: 0.73), layer: nextLayerIndex)
        notes.append(note)
        selectedStickerID = nil
        selectedNoteID = note.id
        saveDocument()
    }

    private func syncStickers() {
        let existing = Dictionary(uniqueKeysWithValues: stickers.map { ($0.mealDishID, $0) })
        var newLayer = nextLayerIndex
        let positions: [CanvasPoint] = [
            CanvasPoint(x: 0.28, y: 0.27),
            CanvasPoint(x: 0.72, y: 0.25),
            CanvasPoint(x: 0.42, y: 0.58),
            CanvasPoint(x: 0.74, y: 0.68),
            CanvasPoint(x: 0.24, y: 0.74),
            CanvasPoint(x: 0.52, y: 0.78)
        ]
        stickers = vm.dishes.enumerated().map { index, dish in
            if var old = existing[dish.id] {
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
                image: dish.recipeImage,
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
        // 用户上传的菜在完成自动/手动抠图前不显示封面，避免把整张照片伪装成贴纸。
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
                strokes: strokes
            ),
            mealID: mealID
        )
    }

    /// 将当前屏幕上的实况画布保存为一张静态图。顶部入口原先只是菜单
    /// 外观，实际没有对应动作，容易让人误以为保存失败。
    private func saveCanvasToPhotos() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first else {
            vm.tipMessage = "当前页面还不能保存"
            return
        }

        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let image = renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        vm.tipMessage = "已保存到相册"
    }
}

// 历史页只读地还原某顿饭当时保存的首页画布，避免把编辑控件带进回忆页面。
struct MealCanvasSnapshotView: View {
    let mealID: UInt
    @State private var document: CanvasDocument?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let document {
                    CanvasMediaBackground(
                        source: CanvasBackground(rawValue: document.background) ?? .meadow,
                        blur: document.blur,
                        reduceMotion: true,
                        customData: document.customBackgroundData
                    )
                    Canvas { context, _ in
                        for stroke in document.strokes {
                            guard let first = stroke.points.first else { continue }
                            if stroke.points.count == 1 {
                                context.fill(
                                    Path(ellipseIn: CGRect(
                                        x: first.x - stroke.width / 2,
                                        y: first.y - stroke.width / 2,
                                        width: stroke.width,
                                        height: stroke.width
                                    )),
                                    with: .color(stroke.color.color)
                                )
                                continue
                            }
                            var path = Path()
                            path.move(to: first)
                            for point in stroke.points.dropFirst() {
                                path.addLine(to: point)
                            }
                            context.stroke(
                                path,
                                with: .color(stroke.color.color),
                                style: StrokeStyle(lineWidth: stroke.width, lineCap: .round, lineJoin: .round)
                            )
                        }
                    }
                    ForEach(document.stickers.sorted { $0.layer < $1.layer }) { sticker in
                        StickerImageView(assetName: sticker.assetName, name: sticker.name)
                            .frame(width: max(74, min(proxy.size.width, proxy.size.height) * 0.23) * 1.12)
                            .scaleEffect(sticker.scale)
                            .rotationEffect(.degrees(sticker.rotationDegrees))
                            .position(x: proxy.size.width * sticker.position.x, y: proxy.size.height * sticker.position.y)
                    }
                    ForEach(document.notes.sorted { $0.layer < $1.layer }) { note in
                        Text(note.text)
                            .font(note.isEmoji ? .system(size: 34) : .system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                            .rotationEffect(.degrees(note.rotationDegrees))
                            .scaleEffect(note.scale)
                            .position(x: proxy.size.width * note.position.x, y: proxy.size.height * note.position.y)
                    }
                } else {
                    CanvasMediaBackground(source: .meadow, blur: 3, reduceMotion: true, customData: nil)
                    Text("当时没有保存画布")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .frame(maxWidth: 420)
        .aspectRatio(0.58, contentMode: .fit)
        .clipped()
        .task {
            document = CanvasDocumentStore.load(mealID: mealID)
        }
    }
}

private enum CanvasPalette {
    // The LiveLog reference uses a neutral studio white, charcoal type and a
    // dusty olive accent. Keep these values local to the canvas so the older
    // meal flows retain their existing green brand token.
    static let page = Color(red: 0.985, green: 0.985, blue: 0.975)
    static let surface = Color.white.opacity(0.97)
    static let ink = Color(red: 0.20, green: 0.20, blue: 0.19)
    static let muted = Color(red: 0.56, green: 0.56, blue: 0.54)
    static let accent = Color.brandGreen
    static let live = Color.dopamineYellow
    static let coral = Color.dopaminePink
}

/// Very light paper grain: enough to make the page feel tactile, never enough
/// to compete with the canvas or reduce text contrast.
private struct CanvasPaperTexture: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 24
            var index = 0
            for y in stride(from: 0, through: size.height, by: step) {
                for x in stride(from: 0, through: size.width, by: step) {
                    let variation = CGFloat((index * 37) % 17) / 17
                    let diameter = 0.45 + variation * 0.9
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: x + variation * 5,
                            y: y + CGFloat((index * 11) % 7),
                            width: diameter,
                            height: diameter
                        )),
                        with: .color(CanvasPalette.ink.opacity(0.004 + variation * 0.006))
                    )
                    index += 1
                }
            }
        }
    }
}

private struct CanvasPoint: Codable, Hashable {
    var x: CGFloat
    var y: CGFloat
}

private enum CanvasSelection: Hashable {
    case sticker(UUID)
    case note(UUID)
}

private enum CanvasEditorPanel: String, CaseIterable, Identifiable {
    case insert
    case emoji
    case effects
    case brush
    case background

    var id: String { rawValue }

    var title: String {
        switch self {
        case .insert: return "文字"
        case .emoji: return "贴纸"
        case .effects: return "动效"
        case .brush: return "画笔"
        case .background: return "背景"
        }
    }

    var icon: String {
        switch self {
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
        case .recent: return "最近"
        case .mood: return "情绪"
        case .food: return "美食"
        case .nature: return "自然"
        case .symbols: return "符号"
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
                "💎", "🪄", "🧡", "💜", "🩷", "🩵", "🤝", "🩶"
            ]
        }
    }
}

/// 画布里的按钮都用同一套轻触反馈：缩小、变淡、回弹，避免 SwiftUI 默认的“点了没反应”。
private struct CanvasPressStyle: ButtonStyle {
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(.spring(response: 0.20, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

private enum CanvasEffectPreviewKind {
    case sticker(CanvasEffect)
    case text(CanvasTextEffect)
}

private struct CanvasEffectPreview: View {
    let kind: CanvasEffectPreviewKind
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            switch kind {
            case .text(let effect):
                let visible = effect.visibleText("今晚吃点好的", time: time, reduceMotion: reduceMotion)
                Text(visible.isEmpty ? "今晚…" : visible)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(CanvasPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .opacity(effect.opacity(time: time, reduceMotion: reduceMotion))
                    .offset(effect.offset(time: time, reduceMotion: reduceMotion))
                    .scaleEffect(x: effect.scaleX(time: time, reduceMotion: reduceMotion), y: effect.scaleY(time: time, reduceMotion: reduceMotion))
                    .rotationEffect(.degrees(effect.rotation(time: time, reduceMotion: reduceMotion)))
            case .sticker(let effect):
                Text("🍓")
                    .font(.system(size: 31))
                    .scaleEffect(effect == .bounce && !reduceMotion ? 1 + abs(sin(time * 2.1)) * 0.10 : 1)
                    .rotationEffect(.degrees(effect == .shake && !reduceMotion ? sin(time * 9) * 4 : 0))
                    .shadow(color: effect == .glow ? CanvasPalette.accent.opacity(0.78) : .clear, radius: effect == .glow ? 10 : 0)
                    .overlay {
                        if effect == .outline {
                            Text("🍓")
                                .font(.system(size: 31))
                                .foregroundStyle(.clear)
                                .overlay(Text("🍓").font(.system(size: 31)).foregroundStyle(.clear).shadow(color: CanvasPalette.ink.opacity(0.7), radius: 0, x: 1, y: 0))
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
                        .background(isSelected ? CanvasPalette.accent.opacity(0.16) : CanvasPalette.page, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
            .background(isSelected ? CanvasPalette.accent.opacity(0.12) : Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? CanvasPalette.accent : CanvasPalette.ink.opacity(0.08), lineWidth: isSelected ? 1.2 : 0.8)
            }
        }
        .buttonStyle(CanvasPressStyle(scale: 0.95))
        .animation(.spring(response: 0.24, dampingFraction: 0.80), value: isSelected)
    }
}

private enum CanvasLayerMove: Equatable {
    case front, forward, backward, back
}

private struct CanvasLayerEntry {
    let selection: CanvasSelection
    let layer: Int
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

    var shortTitle: String {
        switch self {
        case .white: return "白"
        case .butter: return "黄"
        case .coral: return "红"
        case .sky: return "蓝"
        case .mint: return "绿"
        case .ink: return "黑"
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

    init(
        background: String,
        blur: Double,
        customBackgroundData: Data? = nil,
        stickers: [CanvasSticker],
        notes: [CanvasNote],
        strokes: [CanvasStroke] = []
    ) {
        self.background = background
        self.blur = blur
        self.customBackgroundData = customBackgroundData
        self.stickers = stickers
        self.notes = notes
        self.strokes = strokes
    }

    private enum CodingKeys: String, CodingKey {
        case background, blur, customBackgroundData, stickers, notes, strokes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        background = try container.decode(String.self, forKey: .background)
        blur = try container.decode(Double.self, forKey: .blur)
        customBackgroundData = try container.decodeIfPresent(Data.self, forKey: .customBackgroundData)
        stickers = try container.decode([CanvasSticker].self, forKey: .stickers)
        notes = try container.decode([CanvasNote].self, forKey: .notes)
        if let records = try? container.decode([CanvasStroke].self, forKey: .strokes) {
            strokes = records
        } else if let legacy = try? container.decode([[CGPoint]].self, forKey: .strokes) {
            strokes = legacy.map { CanvasStroke(points: $0) }
        } else {
            strokes = []
        }
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
    let reduceMotion: Bool
    let customData: Data?

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
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
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
            LinearGradient(
                colors: [.black.opacity(0.02), .black.opacity(0.30)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        // 手账的底图要有空气感，压低一点数码照片的饱和度，让菜品和手绘
        // 元素成为主角，而不是被背景抢走注意力。
        .saturation(0.94)
        .contrast(1.02)
        .clipped()
        .overlay {
            // A barely-there warm wash keeps downloaded photos in the same
            // paper world as the page instead of letting neon colors take over.
            Rectangle()
                .fill(Color(red: 0.83, green: 0.86, blue: 0.70).opacity(0.045))
                .blendMode(.softLight)

            if !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { context in
                    let phase = context.date.timeIntervalSinceReferenceDate
                    RadialGradient(
                        colors: [.white.opacity(0.075), .white.opacity(0.0)],
                        center: .center,
                        startRadius: 8,
                        endRadius: 118
                    )
                    .frame(width: 190, height: 270)
                    .blur(radius: 18)
                    .rotationEffect(.degrees(14))
                    .offset(x: CGFloat(sin(phase / 3.2) * 250), y: CGFloat(cos(phase / 4.1) * 230))
                    .blendMode(.screen)
                }
                .allowsHitTesting(false)
            }
        }
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
    let mealDishID: UInt
    let name: String
    let image: String?
    var assetName: String?
    var position: CanvasPoint
    var scale: CGFloat
    var rotationDegrees: Double
    var effect: CanvasEffect = .none
    var shapeIndex: Int = 0
    var layer: Int = 0

    init(
        id: UUID = UUID(),
        mealDishID: UInt,
        name: String,
        image: String?,
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
        self.assetName = assetName
        self.position = position
        self.scale = scale
        self.rotationDegrees = rotationDegrees
        self.effect = effect
        self.shapeIndex = shapeIndex
        self.layer = layer
    }

    private enum CodingKeys: String, CodingKey {
        case id, mealDishID, name, image, assetName, position, scale, rotationDegrees, effect, shapeIndex, layer
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        mealDishID = try container.decode(UInt.self, forKey: .mealDishID)
        name = try container.decode(String.self, forKey: .name)
        image = try container.decodeIfPresent(String.self, forKey: .image)
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

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "无"
        case .outline: return "描边"
        case .glow: return "星闪"
        case .shake: return "抖动"
        case .bounce: return "弹跳"
        }
    }

    var icon: String {
        switch self {
        case .none: return "circle.slash"
        case .outline: return "scribble.variable"
        case .glow: return "sparkles"
        case .shake: return "waveform.path.ecg"
        case .bounce: return "arrow.up.and.down"
        }
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
    let onSelect: () -> Void
    let onLayerMove: (CanvasLayerMove) -> Void
    let onDelete: () -> Void
    let onChange: () -> Void

    @GestureState private var drag: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1
    @GestureState private var twist: Angle = .zero
    @State private var animationPhase = false

    private var baseSize: CGFloat {
        max(74, min(canvasSize.width, canvasSize.height) * 0.23)
    }

    var body: some View {
        let x = canvasSize.width * sticker.position.x + drag.width
        let y = canvasSize.height * sticker.position.y + drag.height

        ZStack(alignment: .topTrailing) {
            StickerImageView(assetName: sticker.assetName, name: sticker.name)
                .frame(width: baseSize * 1.12, height: baseSize * 1.12)
                .overlay {
                    // 每道菜都保留一圈很轻的手绘轮廓，让透明图像像贴纸而不是
                    // 生硬地漂浮在照片上；选中或显式描边时再提高对比度。
                    if sticker.effect == .outline || isSelected {
                        StickerBlobShape(index: sticker.shapeIndex)
                            .stroke(
                                .white.opacity(isSelected || sticker.effect == .outline ? 0.94 : 0.46),
                                style: StrokeStyle(
                                    lineWidth: isSelected ? 2 : 1.6,
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

        }
        .frame(width: baseSize * 1.34, height: baseSize * 1.34)
        .scaleEffect(sticker.scale * pinch * bounceScale)
        .rotationEffect(.degrees(sticker.rotationDegrees) + twist + shakeAngle)
        .position(x: x, y: y)
        .contentShape(Rectangle())
        .animation(.spring(response: 0.30, dampingFraction: 0.76), value: isSelected)
        .animation(.spring(response: 0.34, dampingFraction: 0.74), value: sticker.effect)
        // 画布外层有 ScrollView，移动必须优先交给当前选中的元素。
        .highPriorityGesture(dragGesture)
        .simultaneousGesture(magnifyGesture)
        .simultaneousGesture(rotationGesture)
        .contextMenu {
            elementContextMenu
        }
        .accessibilityLabel(sticker.name)
        .accessibilityHint("先点按选中，再拖动移动；双指缩放或旋转；长按管理层级或删除")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onSelect() }
        .onAppear { startEffectAnimation() }
        .onChange(of: sticker.effect) { _, _ in startEffectAnimation() }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .updating($drag) { value, state, _ in
                guard isSelected else { return }
                state = value.translation
            }
            .onEnded { value in
                guard isSelected, canvasSize.width > 0, canvasSize.height > 0 else { return }
                sticker.position.x = min(max(sticker.position.x + value.translation.width / canvasSize.width, 0.10), 0.90)
                sticker.position.y = min(max(sticker.position.y + value.translation.height / canvasSize.height, 0.10), 0.90)
                onChange()
            }
    }

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .updating($pinch) { value, state, _ in
                guard isSelected else { return }
                state = value
            }
            .onEnded { value in
                guard isSelected else { return }
                sticker.scale = min(max(sticker.scale * value, 0.55), 1.75)
                onChange()
            }
    }

    private var rotationGesture: some Gesture {
        RotationGesture()
            .updating($twist) { value, state, _ in
                guard isSelected else { return }
                state = value
            }
            .onEnded { value in
                guard isSelected else { return }
                sticker.rotationDegrees += value.degrees
                onChange()
            }
    }

    @ViewBuilder
    private var elementContextMenu: some View {
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

    private var shakeAngle: Angle {
        guard sticker.effect == .shake, !reduceMotion, animationPhase else { return .zero }
        return .degrees(-2)
    }

    private var bounceScale: CGFloat {
        guard sticker.effect == .bounce, !reduceMotion, animationPhase else { return 1 }
        return 1.045
    }

    private func startEffectAnimation() {
        guard !reduceMotion, sticker.effect == .shake || sticker.effect == .bounce else {
            animationPhase = false
            return
        }
        withAnimation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true)) {
            animationPhase.toggle()
        }
    }
}

/// 画布只使用真正带 alpha 的贴纸资源；菜单封面图不再被硬切成贴纸。
private struct StickerImageView: View {
    let assetName: String?
    let name: String

    var body: some View {
        Group {
            if let assetName {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
            } else {
                placeholder
            }
        }
        .background(Color.clear)
    }

    private var placeholder: some View {
        Image(systemName: "fork.knife.circle")
            .font(.system(size: 34, weight: .light))
            .foregroundStyle(.white.opacity(0.78))
            .shadow(color: .black.opacity(0.22), radius: 4, y: 2)
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
    let onSelect: () -> Void
    let onLayerMove: (CanvasLayerMove) -> Void
    let onDelete: () -> Void
    let onChange: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @GestureState private var drag: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1
    @GestureState private var twist: Angle = .zero

    private var textFontSize: CGFloat {
        let count = note.text.count
        if count > 18 { return 16 }
        if count > 11 { return 18 }
        return 21
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: note.textEffect == .plain ? 1 : 1.0 / 24.0)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            Text(note.textEffect.visibleText(note.text, time: time, reduceMotion: reduceMotion))
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
                .overlay(alignment: .bottom) {
                    if !note.isEmoji && !note.text.isEmpty {
                        CanvasNoteUnderline()
                            .stroke(
                                .white.opacity(0.72),
                                style: StrokeStyle(lineWidth: 1.15, lineCap: .round)
                            )
                            .frame(height: 7)
                            .padding(.horizontal, 3)
                            .offset(y: 5)
                    }
                }
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: note.isEmoji ? 18 : 9, style: .continuous)
                            .stroke(.white.opacity(0.92), style: StrokeStyle(lineWidth: 1.6, dash: [4, 3]))
                            .padding(note.isEmoji ? -6 : -3)
                    }
                }
                .opacity(note.textEffect.opacity(time: time, reduceMotion: reduceMotion))
                .offset(note.textEffect.offset(time: time, reduceMotion: reduceMotion))
                .scaleEffect(x: note.textEffect.scaleX(time: time, reduceMotion: reduceMotion), y: note.textEffect.scaleY(time: time, reduceMotion: reduceMotion))
                .rotationEffect(.degrees(note.textEffect.rotation(time: time, reduceMotion: reduceMotion)))
        }
        // Typewriter starts with an empty prefix. Keep a stable hit target so
        // the layer remains selectable while it is being revealed.
        .padding(.horizontal, note.isEmoji ? 10 : 16)
        .padding(.vertical, note.isEmoji ? 10 : 12)
        .frame(minWidth: note.isEmoji ? 64 : 136, minHeight: note.isEmoji ? 64 : 64)
        .position(
            x: canvasSize.width * note.position.x + drag.width,
            y: canvasSize.height * note.position.y + drag.height
        )
        .scaleEffect(note.scale * pinch)
        .rotationEffect(.degrees(note.rotationDegrees) + twist)
        .contentShape(Rectangle())
        .animation(.spring(response: 0.30, dampingFraction: 0.76), value: isSelected)
        .animation(.spring(response: 0.34, dampingFraction: 0.74), value: note.textEffect)
        // 画布外层有 ScrollView，移动必须优先交给当前选中的元素。
        .highPriorityGesture(
            DragGesture()
                .updating($drag) { value, state, _ in
                    guard isSelected else { return }
                    state = value.translation
                }
                .onEnded { value in
                    guard isSelected, canvasSize.width > 0, canvasSize.height > 0 else { return }
                    note.position.x = min(max(note.position.x + value.translation.width / canvasSize.width, 0.08), 0.92)
                    note.position.y = min(max(note.position.y + value.translation.height / canvasSize.height, 0.08), 0.92)
                    onChange()
                }
        )
        .simultaneousGesture(
            MagnificationGesture()
                .updating($pinch) { value, state, _ in
                    guard isSelected else { return }
                    state = value
                }
                .onEnded { value in
                    guard isSelected else { return }
                    note.scale = min(max(note.scale * value, 0.55), 1.75)
                    onChange()
                }
        )
        .simultaneousGesture(
            RotationGesture()
                .updating($twist) { value, state, _ in
                    guard isSelected else { return }
                    state = value
                }
                .onEnded { value in
                    guard isSelected else { return }
                    note.rotationDegrees += value.degrees
                    onChange()
                }
        )
        .contextMenu {
            elementContextMenu
        }
        .accessibilityLabel(note.isEmoji ? "\(note.text)表情" : "画布文字")
        .accessibilityValue(note.textEffect.title)
        .accessibilityHint("先点按选中，再拖动移动；双指缩放或旋转；长按管理层级或删除")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onSelect() }
    }

    @ViewBuilder
    private var elementContextMenu: some View {
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

/// A tiny irregular underline makes a text note feel drawn onto the page,
/// while staying quiet enough to disappear into the background when unselected.
private struct CanvasNoteUnderline: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let y = rect.midY
        path.move(to: CGPoint(x: rect.minX, y: y + 0.6))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: y - 0.4),
            control1: CGPoint(x: rect.width * 0.28, y: y - 1.8),
            control2: CGPoint(x: rect.width * 0.72, y: y + 1.6)
        )
        return path
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
        ZStack {
            drawingSurface

            // Canvas itself is a rendering surface, not a reliable hit target
            // on every iOS version. Keep a transparent layer above it while
            // drawing is enabled so a stroke cannot fall through to a sticker
            // or the ScrollView underneath.
            if isEnabled {
                Rectangle()
                    .fill(.black.opacity(0.001))
                    .contentShape(Rectangle())
                    .highPriorityGesture(drawGesture, including: .all)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

private struct LiveControlLabel: View {
    let title: String
    let icon: String?

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
            }
        }
        .foregroundStyle(.white)
        .frame(width: 52, height: 31)
        .background(.black.opacity(0.28), in: Capsule())
        .overlay(
            Capsule()
                .stroke(.white.opacity(0.16), lineWidth: 0.8)
        )
    }
}

private struct LiveControlButton: View {
    let title: String?
    let icon: String?
    var isActive = false
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            Group {
                if let title, let icon {
                    Label(title, systemImage: icon)
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                } else if let title {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundStyle(isDisabled ? .white.opacity(0.38) : .white)
            .frame(width: title == nil ? 34 : 43, height: 31)
            .background(isActive ? .white.opacity(0.24) : .black.opacity(0.28), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(isActive ? .white.opacity(0.72) : .white.opacity(0.16), lineWidth: 0.8)
            )
        }
        .buttonStyle(CanvasPressStyle(scale: 0.94))
        .disabled(isDisabled)
        .accessibilityLabel(accessibilityTitle)
    }

    private var accessibilityTitle: String {
        if let title { return title }
        switch icon {
        case "sparkles": return "特效"
        case "face.smiling": return "贴纸"
        case "pencil.tip": return isActive ? "关闭画笔" : "打开画笔"
        case "photo": return "背景"
        case "speaker.slash", "speaker.wave.2": return "声音"
        default: return "画布工具"
        }
    }
}

/// 编辑文字或画笔时的轻量全屏聚焦层。它不是一个可点击的模态遮罩，
/// 只用 Material 和极低对比度把页面压软，保留画布的实时可操作性。
private struct CanvasEditorFocusVeil: View {
    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.07),
                        Color.clear,
                        Color.black.opacity(0.06)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .opacity(0.32)
            .accessibilityHidden(true)
    }
}

private struct CanvasElementActionBar: View {
    let onEdit: () -> Void
    let onLayerMove: (CanvasLayerMove) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 3) {
            Button(action: onEdit) {
                Label("动效", systemImage: "sparkles")
                    .labelStyle(.titleAndIcon)
            }
            .accessibilityLabel("编辑动效")

            Menu {
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
            } label: {
                Image(systemName: "square.3.layers.3d")
            }
            .accessibilityLabel("调整图层")

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .accessibilityLabel("删除元素")
        }
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(.white)
        .padding(5)
        .background(.black.opacity(0.64), in: Capsule())
        .overlay {
            Capsule().stroke(.white.opacity(0.42), lineWidth: 0.8)
        }
        .buttonStyle(CanvasPressStyle(scale: 0.88))
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

private struct CanvasInsertPicker: View {
    let onSelect: (CanvasInsertItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("往画布上加一点")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(CanvasPalette.ink)

            HStack(spacing: 12) {
                ForEach(CanvasInsertItem.allCases) { item in
                    Button { onSelect(item) } label: {
                        VStack(spacing: 8) {
                            Image(systemName: item.icon)
                                .font(.system(size: 20, weight: .semibold))
                            Text(item.title)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(CanvasPalette.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 84)
                        .background(CanvasPalette.page, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
        }
        .padding(22)
    }
}

private struct CanvasTextComposer: View {
    let onInsert: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = "今晚吃点好的"

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("写一句")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(CanvasPalette.ink)
                Text("放入后可以在画布里拖动，也可以给它加上打字、漂浮或浮现效果。")
                    .font(.system(size: 12))
                    .foregroundStyle(CanvasPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)

                TextField("例如：今晚吃点好的", text: $text, axis: .vertical)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(CanvasPalette.ink)
                    .lineLimit(1...3)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(CanvasPalette.page, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .accessibilityLabel("画布文字内容")

                Button {
                    let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !value.isEmpty else { return }
                    onInsert(value)
                    dismiss()
                } label: {
                    Text("放到画布")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(CanvasPalette.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()
            }
            .padding(22)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(CanvasPalette.muted)
                }
            }
        }
    }
}

private struct CanvasEmojiDrawer: View {
    @Binding var category: CanvasEmojiCategory
    let onDismiss: () -> Void
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("表情贴纸")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(CanvasPalette.ink)
                Spacer()
                Button {
                    Haptics.light()
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(CanvasPalette.ink)
                        .frame(width: 30, height: 30)
                        .background(CanvasPalette.page, in: Circle())
                }
                .buttonStyle(CanvasPressStyle(scale: 0.92))
                .accessibilityLabel("关闭表情抽屉")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 5)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(CanvasEmojiCategory.allCases) { item in
                        Button {
                            Haptics.light()
                            withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                                category = item
                            }
                        } label: {
                            VStack(spacing: 5) {
                                Text(item.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(category == item ? CanvasPalette.ink : CanvasPalette.muted)
                                Capsule()
                                    .fill(category == item ? CanvasPalette.accent : .clear)
                                    .frame(width: 20, height: 2)
                            }
                            .frame(height: 30)
                        }
                        .buttonStyle(CanvasPressStyle(scale: 0.96))
                        .accessibilityLabel("表情分类 \(item.title)")
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 36)

            Divider()
                .overlay(CanvasPalette.ink.opacity(0.07))

            TabView(selection: $category) {
                ForEach(CanvasEmojiCategory.allCases) { item in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 8),
                            spacing: 1
                        ) {
                            ForEach(item.items, id: \.self) { emoji in
                                Button {
                                    Haptics.light()
                                    onSelect(emoji)
                                } label: {
                                    Text(emoji)
                                        .font(.system(size: 22))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 38)
                                }
                                .buttonStyle(CanvasPressStyle(scale: 0.90))
                                .accessibilityLabel("添加表情 \(emoji)")
                            }
                        }
                        .padding(.horizontal, 17)
                        .padding(.top, 5)
                        .padding(.bottom, 14)
                    }
                    .tag(item)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxHeight: .infinity)
        }
    }
}

private struct CanvasColorDrawer: View {
    @Binding var selection: CanvasBrushColor
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 11) {
            HStack(spacing: 10) {
                Text("颜色")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(CanvasPalette.ink)
                Text("画笔")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(CanvasPalette.muted)
                Spacer()
                Button {
                    Haptics.light()
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(CanvasPalette.ink)
                        .frame(width: 30, height: 30)
                        .background(CanvasPalette.page, in: Circle())
                }
                .buttonStyle(CanvasPressStyle(scale: 0.92))
                .accessibilityLabel("关闭颜色抽屉")
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6),
                spacing: 10
            ) {
                ForEach(CanvasBrushColor.allCases) { item in
                    Button {
                        Haptics.light()
                        selection = item
                        onDismiss()
                    } label: {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(item.color)
                            .frame(height: 42)
                            .overlay {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .stroke(
                                        item == selection ? CanvasPalette.ink : CanvasPalette.ink.opacity(0.12),
                                        lineWidth: item == selection ? 2 : 0.8
                                    )
                            }
                            .overlay {
                                if item == selection {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(item == .ink ? .white : CanvasPalette.ink)
                                }
                            }
                    }
                    .buttonStyle(CanvasPressStyle(scale: 0.92))
                    .accessibilityLabel("选择\(item.title)")
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 15)
    }
}

private struct CanvasBrushPicker: View {
    @Binding var color: CanvasBrushColor
    @Binding var width: CGFloat
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("画笔设置")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(CanvasPalette.ink)

                Text("颜色")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CanvasPalette.muted)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                    ForEach(CanvasBrushColor.allCases) { item in
                        Button {
                            color = item
                        } label: {
                            VStack(spacing: 5) {
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 28, height: 28)
                                    .overlay(Circle().stroke(CanvasPalette.ink.opacity(0.18), lineWidth: 1))
                                Text(item.title)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(CanvasPalette.ink)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(color == item ? CanvasPalette.accent.opacity(0.14) : CanvasPalette.page, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    Text("粗细")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text("\(Int(width)) pt")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(CanvasPalette.muted)
                }
                Slider(value: $width, in: 2...14, step: 1)
                    .tint(CanvasPalette.accent)
                    .accessibilityLabel("画笔粗细")

                HStack(spacing: 12) {
                    ForEach([2.0, 4.0, 8.0, 14.0], id: \.self) { preset in
                        Button {
                            width = preset
                        } label: {
                            VStack(spacing: 2) {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: preset + 12, height: preset + 12)
                                    .overlay(Circle().stroke(CanvasPalette.ink.opacity(0.18), lineWidth: 1))
                                Text("\(Int(preset)) pt")
                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                                    .foregroundStyle(CanvasPalette.muted)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(CanvasPalette.page, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(Int(preset)) 点")
                    }
                }
                Spacer()
            }
            .padding(22)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(CanvasPalette.accent)
                }
            }
        }
    }
}

private struct CanvasBackgroundPicker: View {
    @Binding var selection: CanvasBackground
    @Binding var blur: Double
    @Binding var customData: Data?
    @State private var photoItem: PhotosPickerItem?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("选择画布底图")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(CanvasPalette.ink)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(CanvasBackground.allCases) { item in
                        Button {
                            if item != .custom || customData != nil { selection = item }
                        } label: {
                            ZStack(alignment: .bottomLeading) {
                                CanvasMediaBackground(source: item, blur: 0, reduceMotion: true, customData: customData)
                                Text(item.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(10)
                                if selection == item {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(6)
                                        .background(CanvasPalette.accent, in: Circle())
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                        .padding(8)
                                }
                            }
                            .frame(height: 86)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(item == .custom && customData == nil)
                    }
                }

                PhotosPicker(
                    selection: $photoItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label("从相册选择底图", systemImage: "photo.badge.plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CanvasPalette.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(CanvasPalette.page, in: Capsule())
                }
                .buttonStyle(.plain)
                .onChange(of: photoItem) { _, item in
                    guard let item else { return }
                    Task {
                        guard let data = try? await item.loadTransferable(type: Data.self),
                              let image = UIImage(data: data),
                              let jpeg = image.canvasPreviewData else { return }
                        await MainActor.run {
                            customData = jpeg
                            selection = .custom
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("毛玻璃")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        Text(blur == 0 ? "关" : "开")
                            .font(.system(size: 12))
                            .foregroundStyle(CanvasPalette.muted)
                    }
                    Slider(value: $blur, in: 0...10)
                        .tint(CanvasPalette.accent)
                }

                Text("内置底图之外，也可以从相册选一张照片。Live Photo 和短视频的动态时间轴随后接入。")
                    .font(.system(size: 12))
                    .foregroundStyle(CanvasPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .padding(22)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(CanvasPalette.accent)
                }
            }
        }
    }
}

private struct CanvasEffectPicker: View {
    let onSelect: (CanvasEffect) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("给选中的菜加特效")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(CanvasPalette.ink)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(CanvasEffect.allCases) { effect in
                    Button { onSelect(effect) } label: {
                        VStack(spacing: 7) {
                            Image(systemName: effect.icon)
                                .font(.system(size: 17, weight: .semibold))
                            Text(effect.title)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(CanvasPalette.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 68)
                        .background(effect == .none ? CanvasPalette.page : CanvasPalette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
        }
        .padding(22)
    }
}

private struct CanvasTextEffectPicker: View {
    let selected: CanvasTextEffect?
    let onSelect: (CanvasTextEffect) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("文字动效")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(CanvasPalette.ink)
            Text("普通文字也可以变成实况里的小动画")
                .font(.system(size: 12))
                .foregroundStyle(CanvasPalette.muted)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(CanvasTextEffect.allCases) { effect in
                    Button { onSelect(effect) } label: {
                        VStack(spacing: 7) {
                            Image(systemName: effect.icon)
                                .font(.system(size: 17, weight: .semibold))
                            Text(effect.title)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(CanvasPalette.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 68)
                        .background(
                            selected == effect ? CanvasPalette.accent.opacity(0.18) : CanvasPalette.page,
                            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                        )
                        .overlay {
                            if selected == effect {
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .stroke(CanvasPalette.accent, lineWidth: 1.5)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(effect.title)
                }
            }
            Spacer()
        }
        .padding(22)
    }
}
