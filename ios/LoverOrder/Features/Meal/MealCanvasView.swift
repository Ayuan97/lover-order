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
    @State private var brushWidth: CGFloat = 4
    @State private var selectedStickerID: UUID?
    @State private var selectedNoteID: UUID?
    @State private var drawingEnabled = false
    @State private var showBackgroundPicker = false
    @State private var showInsertPicker = false
    @State private var showEmojiPicker = false
    @State private var showBrushPicker = false
    @State private var showEffectPicker = false
    @State private var restoredMealID: UInt?
    @State private var liveDuration = 5
    @State private var isMuted = true

    var body: some View {
        ZStack {
            CanvasPalette.page.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    header

                    canvas
                    if selectedCanvasElement != nil {
                        selectionTools
                    }
                    if selectedCanvasElement != nil {
                        transformBar
                    }
                    actionBar

                    if vm.loadFailed && vm.meal == nil {
                        retryStrip
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 14)
            }
            .scrollDisabled(drawingEnabled)
        }
        .sheet(isPresented: $showBackgroundPicker) {
            CanvasBackgroundPicker(
                selection: $background,
                blur: $blur,
                customData: $customBackgroundData
            )
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showInsertPicker) {
            CanvasInsertPicker { item in
                if item == .emoji {
                    showInsertPicker = false
                    showEmojiPicker = true
                } else {
                    insert(item)
                    showInsertPicker = false
                }
            }
                .presentationDetents([.height(250)])
        }
        .sheet(isPresented: $showEmojiPicker) {
            CanvasEmojiPicker { emoji in
                insertEmoji(emoji)
                showInsertPicker = false
                showEmojiPicker = false
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showBrushPicker) {
            CanvasBrushPicker(color: $brushColor, width: $brushWidth)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showEffectPicker) {
            CanvasEffectPicker { effect in
                applyEffect(effect)
                showEffectPicker = false
            }
            .presentationDetents([.height(300)])
        }
        .onAppear { restoreDocumentIfNeeded() }
        .onChange(of: vm.meal?.id) { _, _ in
            selectedStickerID = nil
            selectedNoteID = nil
            activeStroke.removeAll()
            restoreDocumentIfNeeded()
        }
        .onChange(of: vm.dishCount) { _, _ in syncStickers() }
        .onChange(of: background) { _, _ in saveDocument() }
        .onChange(of: blur) { _, _ in saveDocument() }
        .onChange(of: customBackgroundData) { _, _ in saveDocument() }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("今日 LiveLog")
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .foregroundStyle(CanvasPalette.ink)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(CanvasPalette.muted)
                    Text("· \(vm.dishCount)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(CanvasPalette.accent)
                }
                Text("可自由拖动菜品，将其留在这一顿里")
                    .font(.system(size: 12))
                    .foregroundStyle(CanvasPalette.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Menu {
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
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(CanvasPalette.ink)
                    .frame(width: 38, height: 38)
                    .background(CanvasPalette.surface)
                    .clipShape(Circle())
            }
            .accessibilityLabel("更多操作")

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

                if stickers.isEmpty && notes.isEmpty && strokes.isEmpty {
                    VStack(spacing: 7) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 23, weight: .light))
                        Text("从菜谱挑几道菜")
                            .font(.system(size: 16, weight: .semibold))
                        Text("它们会变成画布上的贴纸")
                            .font(.system(size: 12))
                            .opacity(0.76)
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
                            selectedStickerID = sticker.id
                            selectedNoteID = nil
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
                            selectedStickerID = nil
                            selectedNoteID = note.id
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
                    width: brushWidth,
                    onEnd: saveDocument
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
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
            .overlay(alignment: .topTrailing) {
                if drawingEnabled {
                    Text("画笔中")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(CanvasPalette.ink)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(CanvasPalette.live, in: Capsule())
                        .padding(12)
                }
            }
            .overlay(alignment: .bottom) {
                liveControls
                    .padding(.horizontal, 9)
                    .padding(.bottom, 9)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .onTapGesture {
                if !drawingEnabled {
                    selectedStickerID = nil
                    selectedNoteID = nil
                }
            }
        }
        .aspectRatio(0.78, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.13), radius: 18, y: 8)
    }

    /// 画布内唯一的编辑工具条。加菜和提交动作放在画布外的 actionBar，避免和编辑工具混在一起。
    private var liveControls: some View {
        HStack(spacing: 7) {
            Menu {
                ForEach([3, 5, 10], id: \.self) { seconds in
                    Button("\(seconds)s") { liveDuration = seconds }
                }
            } label: {
                LiveControlLabel(title: "\(liveDuration)s", icon: "chevron.down")
            }

            LiveControlButton(title: "Aa", icon: nil) {
                showInsertPicker = true
            }
            LiveControlButton(title: nil, icon: "sparkles", isDisabled: selectedStickerID == nil) {
                showEffectPicker = true
            }
            LiveControlButton(title: nil, icon: "pencil.tip", isActive: drawingEnabled) {
                drawingEnabled.toggle()
            }
            if drawingEnabled {
                LiveControlButton(title: nil, icon: "slider.horizontal.3") {
                    showBrushPicker = true
                }
            }
            LiveControlButton(title: nil, icon: "photo") {
                showBackgroundPicker = true
            }
            LiveControlButton(title: nil, icon: isMuted ? "speaker.slash" : "speaker.wave.2") {
                isMuted.toggle()
            }
        }
        .padding(6)
        // The editor row is deliberately full-width. Without an explicit frame,
        // SwiftUI can measure the overlay at its intrinsic width on compact
        // simulator sizes and push the trailing controls outside the canvas.
        // Keep the controls anchored to the leading edge of the full-width
        // pill. Centering an intrinsic-width overlay can resolve to a trailing
        // frame inside GeometryReader on compact iPhones.
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.22), in: Capsule())
        .foregroundStyle(.white)
    }

    private var selectedCanvasElement: CanvasSelection? {
        if let selectedStickerID { return .sticker(selectedStickerID) }
        if let selectedNoteID { return .note(selectedNoteID) }
        return nil
    }

    private var selectedElementTitle: String {
        switch selectedCanvasElement {
        case .sticker(let id):
            return stickers.first(where: { $0.id == id })?.name ?? "菜品"
        case .note(let id):
            guard let note = notes.first(where: { $0.id == id }) else { return "画布元素" }
            return note.isEmoji ? "\(note.text) 表情" : "文字"
        case nil:
            return "画布元素"
        }
    }

    private var selectionTools: some View {
        HStack(spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: selectedCanvasElement?.icon ?? "square.3.layers.3d")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(CanvasPalette.accent)
                    .frame(width: 22, height: 22)
                    .background(CanvasPalette.accent.opacity(0.13), in: Circle())
                Text(selectedElementTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(CanvasPalette.ink)
                    .lineLimit(1)
            }
            .frame(width: 76, alignment: .leading)

            CanvasSelectionAction(title: "置底", icon: "arrow.down.to.line") {
                moveSelectedLayer(.back)
            }
            CanvasSelectionAction(title: "下移", icon: "chevron.down") {
                moveSelectedLayer(.backward)
            }
            CanvasSelectionAction(title: "上移", icon: "chevron.up") {
                moveSelectedLayer(.forward)
            }
            CanvasSelectionAction(title: "置顶", icon: "arrow.up.to.line") {
                moveSelectedLayer(.front)
            }
            CanvasSelectionAction(title: "删除", icon: "trash", role: .destructive) {
                deleteSelectedElement()
            }
        }
        .padding(7)
        .frame(height: 58)
        .background(CanvasPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(CanvasPalette.ink.opacity(0.08), lineWidth: 1))
    }

    private var transformBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CanvasPalette.accent)
            Slider(value: selectedScaleBinding, in: 0.55...1.75)
                .tint(CanvasPalette.accent)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("元素大小")

            Image(systemName: "rotate.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CanvasPalette.accent)
            Slider(value: selectedRotationBinding, in: -180...180)
                .tint(CanvasPalette.accent)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("元素旋转")

            Button {
                switch selectedCanvasElement {
                case .sticker(let id):
                    guard let index = stickers.firstIndex(where: { $0.id == id }) else { return }
                    stickers[index].scale = 1
                    stickers[index].rotationDegrees = 0
                case .note(let id):
                    guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
                    notes[index].scale = 1
                    notes[index].rotationDegrees = 0
                case nil:
                    return
                }
                saveDocument()
            } label: {
                Text("重置")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CanvasPalette.ink)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(CanvasPalette.page, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(CanvasPalette.surface, in: Capsule())
        .overlay(Capsule().stroke(CanvasPalette.ink.opacity(0.08), lineWidth: 1))
    }

    private var selectedScaleBinding: Binding<CGFloat> {
        Binding(
            get: {
                switch selectedCanvasElement {
                case .sticker(let id): return stickers.first(where: { $0.id == id })?.scale ?? 1
                case .note(let id): return notes.first(where: { $0.id == id })?.scale ?? 1
                case nil: return 1
                }
            },
            set: { value in
                switch selectedCanvasElement {
                case .sticker(let id):
                    guard let index = stickers.firstIndex(where: { $0.id == id }) else { return }
                    stickers[index].scale = value
                case .note(let id):
                    guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
                    notes[index].scale = value
                case nil:
                    return
                }
                saveDocument()
            }
        )
    }

    private var selectedRotationBinding: Binding<Double> {
        Binding(
            get: {
                switch selectedCanvasElement {
                case .sticker(let id): return stickers.first(where: { $0.id == id })?.rotationDegrees ?? 0
                case .note(let id): return notes.first(where: { $0.id == id })?.rotationDegrees ?? 0
                case nil: return 0
                }
            },
            set: { value in
                switch selectedCanvasElement {
                case .sticker(let id):
                    guard let index = stickers.firstIndex(where: { $0.id == id }) else { return }
                    stickers[index].rotationDegrees = value
                case .note(let id):
                    guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
                    notes[index].rotationDegrees = value
                case nil:
                    return
                }
                saveDocument()
            }
        )
    }

    private var layerEntries: [CanvasLayerEntry] {
        stickers.map { CanvasLayerEntry(selection: .sticker($0.id), layer: $0.layer) }
            + notes.map { CanvasLayerEntry(selection: .note($0.id), layer: $0.layer) }
    }

    private func moveSelectedLayer(_ move: CanvasLayerMove) {
        guard let selected = selectedCanvasElement else { return }
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

    private func deleteSelectedElement() {
        guard let selected = selectedCanvasElement else { return }
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

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button(action: onAddDish) {
                Label("从菜谱加菜", systemImage: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CanvasPalette.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(CanvasPalette.surface, in: Capsule())
                    .overlay(Capsule().stroke(CanvasPalette.ink.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button(action: onConfirm) {
                HStack(spacing: 7) {
                    Image(systemName: confirmIcon)
                        .font(.system(size: 15, weight: .bold))
                    Text(confirmTitle)
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(confirmColor, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(vm.isActing)
            .accessibilityLabel(confirmAccessibilityLabel)
        }
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

    private var confirmColor: Color {
        vm.dishCount == 0 && vm.meal?.status == .planning ? CanvasPalette.muted : CanvasPalette.accent
    }

    private var confirmAccessibilityLabel: String {
        switch vm.meal?.status {
        case .confirmed: return "记录吃完"
        case .completed, .cancelled: return "重新开始"
        default: return vm.dishCount == 0 ? "先加菜" : "定下这一顿"
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

    private func insert(_ item: CanvasInsertItem) {
        switch item {
        case .text:
            let note = CanvasNote(text: "今晚吃点好的", isEmoji: false, position: CanvasPoint(x: 0.50, y: 0.22), layer: nextLayerIndex)
            notes.append(note)
            selectedStickerID = nil
            selectedNoteID = note.id
        case .emoji:
            insertEmoji("♥︎")
        }
        saveDocument()
    }

    private func insertEmoji(_ emoji: String) {
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
        stickers[index].effect = effect
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
}

private enum CanvasPalette {
    static let page = Color(red: 0.965, green: 0.963, blue: 0.945)
    static let surface = Color.white.opacity(0.96)
    static let ink = Color(red: 0.10, green: 0.10, blue: 0.09)
    static let muted = Color(red: 0.40, green: 0.41, blue: 0.38)
    static let accent = Color(red: 0.39, green: 0.47, blue: 0.32)
    static let live = Color(red: 0.79, green: 0.94, blue: 0.35)
    static let coral = Color(red: 0.88, green: 0.30, blue: 0.24)
}

private struct CanvasPoint: Codable, Hashable {
    var x: CGFloat
    var y: CGFloat
}

private enum CanvasSelection: Hashable {
    case sticker(UUID)
    case note(UUID)

    var icon: String {
        switch self {
        case .sticker: return "fork.knife"
        case .note: return "face.smiling"
        }
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

    var color: Color {
        switch self {
        case .white: return .white
        case .butter: return Color(red: 0.98, green: 0.82, blue: 0.28)
        case .coral: return Color(red: 0.95, green: 0.30, blue: 0.24)
        case .sky: return Color(red: 0.32, green: 0.72, blue: 0.92)
        case .mint: return Color(red: 0.48, green: 0.82, blue: 0.46)
        case .ink: return Color(red: 0.10, green: 0.10, blue: 0.09)
        }
    }
}

private struct CanvasStroke: Codable, Hashable {
    var points: [CGPoint]
    var color: CanvasBrushColor
    var width: CGFloat

    init(points: [CGPoint], color: CanvasBrushColor = .white, width: CGFloat = 4) {
        self.points = points
        self.color = color
        self.width = width
    }
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
                    .opacity(min(0.66, blur / 12))
            }
            LinearGradient(
                colors: [.black.opacity(0.02), .black.opacity(0.30)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .clipped()
        .overlay {
            if !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { context in
                    let phase = context.date.timeIntervalSinceReferenceDate
                    LinearGradient(
                        colors: [.white.opacity(0.0), .white.opacity(0.08), .white.opacity(0.0)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: 140)
                    .rotationEffect(.degrees(14))
                    .offset(x: CGFloat(sin(phase / 3.2) * 280), y: CGFloat(cos(phase / 4.1) * 260))
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
        case .none: return "原图"
        case .outline: return "虚线描边"
        case .glow: return "柔光"
        case .shake: return "轻轻抖"
        case .bounce: return "弹一下"
        }
    }

    var icon: String {
        switch self {
        case .none: return "circle"
        case .outline: return "scribble.variable"
        case .glow: return "sun.max"
        case .shake: return "waveform.path"
        case .bounce: return "arrow.up.and.down"
        }
    }
}

private struct CanvasStickerView: View {
    @Binding var sticker: CanvasSticker
    let canvasSize: CGSize
    let isSelected: Bool
    let reduceMotion: Bool
    let onSelect: () -> Void
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
                    if sticker.effect == .outline || isSelected {
                        StickerBlobShape(index: sticker.shapeIndex)
                            .stroke(
                                sticker.effect == .outline ? CanvasPalette.live : .white.opacity(0.90),
                                style: StrokeStyle(
                                    lineWidth: isSelected ? 2 : 2.5,
                                    lineCap: .round,
                                    dash: sticker.effect == .outline || isSelected ? [5, 4] : []
                                )
                            )
                    }
                }
                .shadow(
                    color: sticker.effect == .glow ? .white.opacity(0.8) : .black.opacity(0.28),
                    radius: sticker.effect == .glow ? 20 : 8,
                    y: 6
                )

            if isSelected {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(CanvasPalette.ink)
                    .padding(6)
                    .background(.white.opacity(0.92), in: Circle())
                    .offset(x: 5, y: -5)
            }
        }
        .frame(width: baseSize, height: baseSize)
        .scaleEffect(sticker.scale * pinch * bounceScale)
        .rotationEffect(.degrees(sticker.rotationDegrees) + twist + shakeAngle)
        .position(x: x, y: y)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .simultaneousGesture(dragGesture)
        .simultaneousGesture(magnifyGesture)
        .simultaneousGesture(rotationGesture)
        .accessibilityLabel(sticker.name)
        .accessibilityHint("点按选中，拖动移动，双指缩放或旋转")
        .accessibilityAddTraits(.isButton)
        .onAppear { startEffectAnimation() }
        .onChange(of: sticker.effect) { _, _ in startEffectAnimation() }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .updating($drag) { value, state, _ in
                onSelect()
                state = value.translation
            }
            .onEnded { value in
                guard canvasSize.width > 0, canvasSize.height > 0 else { return }
                sticker.position.x = min(max(sticker.position.x + value.translation.width / canvasSize.width, 0.10), 0.90)
                sticker.position.y = min(max(sticker.position.y + value.translation.height / canvasSize.height, 0.10), 0.90)
                onChange()
            }
    }

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .updating($pinch) { value, state, _ in
                onSelect()
                state = value
            }
            .onEnded { value in
                sticker.scale = min(max(sticker.scale * value, 0.55), 1.75)
                onChange()
            }
    }

    private var rotationGesture: some Gesture {
        RotationGesture()
            .updating($twist) { value, state, _ in
                onSelect()
                state = value
            }
            .onEnded { value in
                sticker.rotationDegrees += value.degrees
                onChange()
            }
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

private struct CanvasNote: Identifiable, Codable, Hashable {
    let id: UUID
    var text: String
    var isEmoji: Bool
    var position: CanvasPoint
    var scale: CGFloat
    var rotationDegrees: Double
    var layer: Int

    init(
        id: UUID = UUID(),
        text: String,
        isEmoji: Bool,
        position: CanvasPoint,
        scale: CGFloat = 1,
        rotationDegrees: Double = 0,
        layer: Int = 0
    ) {
        self.id = id
        self.text = text
        self.isEmoji = isEmoji
        self.position = position
        self.scale = scale
        self.rotationDegrees = rotationDegrees
        self.layer = layer
    }

    private enum CodingKeys: String, CodingKey {
        case id, text, isEmoji, position, scale, rotationDegrees, layer
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
    }
}

private struct CanvasNoteView: View {
    @Binding var note: CanvasNote
    let canvasSize: CGSize
    let isSelected: Bool
    let onSelect: () -> Void
    let onChange: () -> Void

    @GestureState private var drag: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1
    @GestureState private var twist: Angle = .zero

    var body: some View {
        Text(note.text)
            .font(note.isEmoji ? .system(size: 38) : .system(size: 19, weight: .semibold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.42), radius: 5, y: 3)
            .padding(.horizontal, note.isEmoji ? 0 : 10)
            .padding(.vertical, note.isEmoji ? 0 : 6)
            .background(note.isEmoji ? .clear : .black.opacity(0.20), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: note.isEmoji ? 18 : 9, style: .continuous)
                        .stroke(.white.opacity(0.92), style: StrokeStyle(lineWidth: 1.6, dash: [4, 3]))
                        .padding(note.isEmoji ? -6 : -3)
                }
            }
            .position(
                x: canvasSize.width * note.position.x + drag.width,
                y: canvasSize.height * note.position.y + drag.height
            )
            .scaleEffect(note.scale * pinch)
            .rotationEffect(.degrees(note.rotationDegrees) + twist)
            .contentShape(Rectangle())
            .onTapGesture { onSelect() }
            .simultaneousGesture(
                DragGesture()
                    .updating($drag) { value, state, _ in
                        onSelect()
                        state = value.translation
                    }
                    .onEnded { value in
                        guard canvasSize.width > 0, canvasSize.height > 0 else { return }
                        note.position.x = min(max(note.position.x + value.translation.width / canvasSize.width, 0.08), 0.92)
                        note.position.y = min(max(note.position.y + value.translation.height / canvasSize.height, 0.08), 0.92)
                        onChange()
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .updating($pinch) { value, state, _ in
                        onSelect()
                        state = value
                    }
                    .onEnded { value in
                        note.scale = min(max(note.scale * value, 0.55), 1.75)
                        onChange()
                    }
            )
            .simultaneousGesture(
                RotationGesture()
                    .updating($twist) { value, state, _ in
                        onSelect()
                        state = value
                    }
                    .onEnded { value in
                        note.rotationDegrees += value.degrees
                        onChange()
                    }
            )
            .accessibilityLabel(note.isEmoji ? "\(note.text)表情" : "画布文字")
            .accessibilityHint("点按选中，拖动移动，双指缩放或旋转")
            .accessibilityAddTraits(.isButton)
    }
}

private struct CanvasDrawingView: View {
    @Binding var strokes: [CanvasStroke]
    @Binding var activeStroke: [CGPoint]
    let isEnabled: Bool
    let brush: CanvasBrushColor
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
                    let strokeColor = stroke.color.color
                    let strokeWidth = stroke.width
                    guard let first = points.first else { continue }
                    if points.count == 1 {
                        context.fill(
                            Path(ellipseIn: CGRect(x: first.x - strokeWidth / 2, y: first.y - strokeWidth / 2, width: strokeWidth, height: strokeWidth)),
                            with: .color(strokeColor)
                        )
                        continue
                    }
                    var path = Path()
                    path.move(to: first)
                    for point in points.dropFirst() { path.addLine(to: point) }
                    context.stroke(
                        path,
                        with: .color(strokeColor),
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)
                    )
                }

                if let first = activeStroke.first {
                    if activeStroke.count == 1 {
                        context.fill(
                            Path(ellipseIn: CGRect(x: first.x - width / 2, y: first.y - width / 2, width: width, height: width)),
                            with: .color(brush.color)
                        )
                    } else {
                        var path = Path()
                        path.move(to: first)
                        for point in activeStroke.dropFirst() { path.addLine(to: point) }
                        context.stroke(
                            path,
                            with: .color(brush.color),
                            style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
                        )
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
                strokes.append(CanvasStroke(points: activeStroke, color: brush, width: width))
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
    }
}

private struct LiveControlButton: View {
    let title: String?
    let icon: String?
    var isActive = false
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let title {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundStyle(isDisabled ? .white.opacity(0.38) : .white)
            .frame(width: 36, height: 31)
            .background(isActive ? CanvasPalette.accent.opacity(0.78) : .black.opacity(0.28), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(accessibilityTitle)
    }

    private var accessibilityTitle: String {
        if let title { return title }
        switch icon {
        case "sparkles": return "特效"
        case "pencil.tip": return isActive ? "关闭画笔" : "打开画笔"
        case "photo": return "背景"
        case "speaker.slash", "speaker.wave.2": return "声音"
        default: return "画布工具"
        }
    }
}

private struct CanvasSelectionAction: View {
    let title: String
    let icon: String
    var role: ButtonRole?
    let action: () -> Void

    init(title: String, icon: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.role = role
        self.action = action
    }

    var body: some View {
        Button(role: role, action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 9, weight: .medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .foregroundStyle(role == .destructive ? CanvasPalette.coral : CanvasPalette.ink)
            .background(CanvasPalette.page, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
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

private struct CanvasEmojiPicker: View {
    let onSelect: (String) -> Void

    private let emojis = [
        "♥︎", "♡", "😊", "😍", "🥰", "😋", "🤤", "🫶",
        "🍴", "✨", "🔥", "🌿", "🍓", "🍋", "🍕", "🍜",
        "🍣", "🍰", "☕️", "🥂", "🌙", "⭐️", "🎉", "🐱"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("挑一个放到画布上")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(CanvasPalette.ink)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                ForEach(emojis, id: \.self) { emoji in
                    Button { onSelect(emoji) } label: {
                        Text(emoji)
                            .font(.system(size: 28))
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(CanvasPalette.page, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
        }
        .padding(22)
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
