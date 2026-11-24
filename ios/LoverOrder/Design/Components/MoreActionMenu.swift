import SwiftUI
import UIKit

// MARK: - 自定义三点「更多」触发按钮

/// 统一视觉风格的自定义三点更多按钮：展开时圆底反色、三点轻巧过渡为关闭叉号。
struct AppMoreButton: View {
    enum Style {
        /// 自由画布毛玻璃圆钮，自适应深浅画布表面
        case canvasGlass(isLightSurface: Bool, diameter: CGFloat = 34, hitWidth: CGFloat = 36, hitHeight: CGFloat = 44)
        /// 菜谱图片卡右上角悬浮深色磨砂圆钮
        case photoBadge
        /// 详情页顶部悬浮纸感毛玻璃圆钮
        case paperGlass
    }

    let style: Style
    let isOpen: Bool
    var isDisabled: Bool = false
    var coordinateSpaceName: String? = nil
    let accessibilityTitle: String
    let onTap: (CGRect) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var anchorFrame: CGRect = .zero

    private var targetSpace: CoordinateSpace {
        if let coordinateSpaceName {
            return .named(coordinateSpaceName)
        }
        return .global
    }

    private var circleDiameter: CGFloat {
        switch style {
        case .canvasGlass(_, let diameter, _, _): return diameter
        case .photoBadge: return 30
        case .paperGlass: return 38
        }
    }

    private var hitSize: CGSize {
        switch style {
        case .canvasGlass(_, _, let w, let h): return CGSize(width: w, height: h)
        case .photoBadge: return CGSize(width: 40, height: 40)
        case .paperGlass: return CGSize(width: 44, height: 44)
        }
    }

    private var foreground: Color {
        switch style {
        case .canvasGlass(let isLight, _, _, _):
            if isOpen {
                return isLight ? .white : Color.actionInk
            }
            return isLight ? Color.inkPrimary : .white
        case .photoBadge:
            return isOpen ? Color.actionInk : .white
        case .paperGlass:
            return isOpen ? .white : Color.inkPrimary
        }
    }

    var body: some View {
        Button {
            Haptics.light()
            onTap(anchorFrame)
        } label: {
            MoreDotsGlyph(
                isOpen: isOpen,
                compact: circleDiameter <= 28
            )
            .foregroundStyle(foreground)
            .frame(width: circleDiameter, height: circleDiameter)
            .background { circleSurface }
            .frame(width: hitSize.width, height: hitSize.height)
            .contentShape(Rectangle())
        }
        .buttonStyle(SoftPressStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.42 : 1)
        .background {
            GeometryReader { proxy in
                let rect = proxy.frame(in: targetSpace)
                Color.clear
                    .onAppear { anchorFrame = rect }
                    .onChange(of: rect) { _, next in anchorFrame = next }
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.80), value: isOpen)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityAddTraits(isOpen ? .isSelected : [])
    }

    @ViewBuilder
    private var circleSurface: some View {
        switch style {
        case .canvasGlass(let isLight, _, _, _):
            if isOpen {
                Circle()
                    .fill(isLight ? Color.actionInk : Color.white)
                    .shadow(color: Color.black.opacity(isLight ? 0.16 : 0.28), radius: 10, y: 4)
            } else {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Circle().fill(isLight ? Color.white.opacity(0.76) : Color.black.opacity(0.20))
                    }
                    .overlay {
                        Circle().strokeBorder(
                            isLight ? Color.black.opacity(0.08) : Color.white.opacity(0.38),
                            lineWidth: isLight ? 0.6 : 0.85
                        )
                    }
                    .shadow(color: Color.black.opacity(isLight ? 0.08 : 0.22), radius: isLight ? 10 : 12, y: isLight ? 3 : 4)
            }

        case .photoBadge:
            if isOpen {
                Circle()
                    .fill(Color.white)
                    .overlay {
                        Circle().strokeBorder(Color.black.opacity(0.10), lineWidth: 0.6)
                    }
                    .shadow(color: Color.black.opacity(0.18), radius: 8, y: 3)
            } else {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Circle().fill(Color.actionInk.opacity(0.42))
                    }
                    .overlay {
                        Circle().strokeBorder(Color.white.opacity(0.32), lineWidth: 0.65)
                    }
            }

        case .paperGlass:
            if isOpen {
                Circle()
                    .fill(Color.actionInk)
                    .shadow(color: Color.black.opacity(0.16), radius: 10, y: 4)
            } else {
                PaperGlassCircleSurface()
            }
        }
    }
}

/// 手绘感比例调校的三圆点图标，展开时平滑切换为细线叉号。
private struct MoreDotsGlyph: View {
    let isOpen: Bool
    var compact: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let dotSize: CGFloat = compact ? 3.0 : 3.6
        let spacing: CGFloat = compact ? 2.6 : 3.2
        let crossSize: CGFloat = compact ? 9.5 : 11.5

        ZStack {
            HStack(spacing: spacing) {
                Circle().frame(width: dotSize, height: dotSize)
                Circle().frame(width: dotSize, height: dotSize)
                Circle().frame(width: dotSize, height: dotSize)
            }
            .scaleEffect(isOpen ? 0.45 : 1)
            .opacity(isOpen ? 0 : 1)
            .rotationEffect(.degrees(isOpen && !reduceMotion ? 90 : 0))

            Canvas { context, size in
                let inset = (min(size.width, size.height) - crossSize) * 0.5
                let minP = inset
                let maxP = min(size.width, size.height) - inset
                var path = Path()
                path.move(to: CGPoint(x: minP, y: minP))
                path.addLine(to: CGPoint(x: maxP, y: maxP))
                path.move(to: CGPoint(x: maxP, y: minP))
                path.addLine(to: CGPoint(x: minP, y: maxP))
                context.stroke(
                    path,
                    with: .foreground,
                    style: StrokeStyle(lineWidth: compact ? 1.5 : 1.75, lineCap: .round)
                )
            }
            .frame(width: compact ? 16 : 20, height: compact ? 16 : 20)
            .scaleEffect(isOpen ? 1 : 0.45)
            .opacity(isOpen ? 1 : 0)
            .rotationEffect(.degrees(isOpen || reduceMotion ? 0 : -90))
        }
        .accessibilityHidden(true)
    }
}

/// 详情页等图文顶栏共享的纸感毛玻璃圆底。
struct PaperGlassCircleSurface: View {
    var body: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .overlay {
                Circle().fill(Color.white.opacity(0.82))
            }
            .overlay {
                Circle().strokeBorder(Color.white.opacity(0.92), lineWidth: 0.85)
            }
            .overlay {
                Circle().strokeBorder(Color.black.opacity(0.075), lineWidth: 0.6)
            }
            .shadow(color: Color.black.opacity(0.09), radius: 10, y: 3)
    }
}

/// 与 `AppMoreButton(.paperGlass)` 成套的顶部悬浮圆钮（返回 / 收藏 / 编辑）。
struct PaperGlassIconButton: View {
    let systemImage: String
    var tint: Color = Color.inkPrimary
    var fontSize: CGFloat = 15
    var weight: Font.Weight = .semibold
    var isDisabled: Bool = false
    let accessibilityTitle: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: fontSize, weight: weight))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background { PaperGlassCircleSurface() }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(SoftPressStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.42 : 1)
        .accessibilityLabel(accessibilityTitle)
    }
}

// MARK: - 锚定悬浮菜单容器与卡片视觉

/// 根据触发按钮坐标自动对齐边缘、并在靠近底部时自动向上展开的悬浮菜单层。
struct AnchoredFloatingMenuOverlay<MenuContent: View>: View {
    @Binding var isPresented: Bool
    let anchorRect: CGRect
    var menuWidth: CGFloat = 244
    var horizontalMargin: CGFloat = 16
    var topReserved: CGFloat = 12
    var bottomReserved: CGFloat = 24
    var estimatedMenuHeight: CGFloat = 250
    var scrimOpacity: Double = 0.08
    @ViewBuilder let content: (_ maxCardHeight: CGFloat) -> MenuContent

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if isPresented {
                Color.black.opacity(scrimOpacity)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissMenu()
                    }
                    .transition(.opacity)
                    .accessibilityLabel("关闭菜单")
                    .accessibilityAddTraits(.isButton)

                GeometryReader { geo in
                    let size = geo.size
                    let effectiveAnchor = resolvedAnchor(in: size)
                    let spaceBelow = size.height - bottomReserved - effectiveAnchor.maxY - 8
                    let spaceAbove = effectiveAnchor.minY - topReserved - 8
                    let opensUpward = spaceBelow < estimatedMenuHeight && spaceAbove > spaceBelow
                    let clampedWidth = min(menuWidth, max(196, size.width - horizontalMargin * 2))
                    let leftX = min(
                        max(horizontalMargin, effectiveAnchor.maxX - clampedWidth),
                        max(horizontalMargin, size.width - horizontalMargin - clampedWidth)
                    )
                    let anchorXRatio = min(max(0.14, (effectiveAnchor.midX - leftX) / clampedWidth), 0.90)
                    let scaleOrigin = UnitPoint(x: anchorXRatio, y: opensUpward ? 1 : 0)
                    let maxCardHeight = max(180, opensUpward ? spaceAbove : spaceBelow)

                    ZStack(alignment: opensUpward ? .bottomLeading : .topLeading) {
                        Color.clear
                        FloatingMenuCardSurface(width: clampedWidth) {
                            content(maxCardHeight)
                        }
                        .padding(.leading, leftX)
                        .padding(
                            opensUpward ? .bottom : .top,
                            opensUpward
                                ? max(bottomReserved, size.height - effectiveAnchor.minY + 8)
                                : max(topReserved, effectiveAnchor.maxY + 8)
                        )
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .scale(scale: 0.90, anchor: scaleOrigin).combined(with: .opacity)
                        )
                    }
                    .frame(width: size.width, height: size.height)
                }
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 0.82), value: isPresented)
    }

    private func resolvedAnchor(in size: CGSize) -> CGRect {
        if anchorRect.width > 0, anchorRect.height > 0 {
            return anchorRect
        }
        return CGRect(x: size.width - 54, y: 52, width: 36, height: 36)
    }

    private func dismissMenu() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.86)) {
            isPresented = false
        }
    }
}

/// 纸感毛玻璃悬浮菜单卡片底座。
struct FloatingMenuCardSurface<Content: View>: View {
    var width: CGFloat = 244
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            content()
        }
        .padding(8)
        .frame(width: width, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.cardBackground.opacity(0.95))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .inset(by: 0.7)
                .strokeBorder(Color.white.opacity(0.88), lineWidth: 0.8)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.7)
        }
        .shadow(color: Color.black.opacity(0.14), radius: 24, x: 0, y: 10)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .preferredColorScheme(.light)
    }
}

// MARK: - 菜单内部快捷磁贴与标准行

struct FloatingMenuTileItem: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    var isDisabled: Bool = false
    let action: () -> Void
}

struct FloatingMenuTileRow: View {
    let items: [FloatingMenuTileItem]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items) { item in
                Button {
                    Haptics.light()
                    item.action()
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: item.systemImage)
                            .font(.system(size: 14.5, weight: .semibold))
                            .frame(height: 18)
                        Text(item.title)
                            .font(.system(size: 11.5, weight: .medium, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .foregroundStyle(Color.inkPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.dividerLine.opacity(0.55), lineWidth: 0.65)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(SoftPressStyle())
                .disabled(item.isDisabled)
                .opacity(item.isDisabled ? 0.36 : 1)
            }
        }
        .padding(.bottom, 2)
    }
}

struct FloatingMenuRow: View {
    enum Role {
        case normal
        case prominent
        case destructive
    }

    let title: String
    var systemImage: String? = nil
    var emoji: String? = nil
    var role: Role = .normal
    var badge: String? = nil
    var trailingText: String? = nil
    var showsChevron: Bool = false
    var isSelected: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    private var labelColor: Color {
        switch role {
        case .normal, .prominent: return Color.inkPrimary
        case .destructive: return Color.errorInk
        }
    }

    private var iconBadgeBackground: Color {
        switch role {
        case .normal: return Color.appBackground
        case .prominent: return Color.actionInk
        case .destructive: return Color.errorInk.opacity(0.10)
        }
    }

    private var iconForeground: Color {
        switch role {
        case .normal: return Color.inkPrimary
        case .prominent: return .white
        case .destructive: return Color.errorInk
        }
    }

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(spacing: 10) {
                if emoji != nil || systemImage != nil {
                    ZStack {
                        Circle().fill(iconBadgeBackground)
                        if let emoji {
                            Text(emoji)
                                .font(.system(size: 13.5))
                        } else if let systemImage {
                            Image(systemName: systemImage)
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(iconForeground)
                        }
                    }
                    .frame(width: 28, height: 28)
                }

                Text(title)
                    .font(.system(size: 14, weight: role == .prominent ? .semibold : .medium, design: .rounded))
                    .foregroundStyle(labelColor)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if let badge {
                    Text(badge)
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.brandGreen)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(Color.brandGreen.opacity(0.13), in: Capsule())
                }

                if let trailingText {
                    Text(trailingText)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.inkMuted)
                        .lineLimit(1)
                }

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.actionInk)
                } else if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.inkMuted.opacity(0.8))
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 40)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(FloatingMenuRowPressStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.36 : 1)
    }
}

struct FloatingMenuDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.dividerLine.opacity(0.55))
            .frame(height: 0.7)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
    }
}

private struct FloatingMenuRowPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(configuration.isPressed ? Color.inkPrimary.opacity(0.065) : Color.clear)
            }
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

// MARK: - 菜谱卡片与菜谱详情共享的双层自定义操作菜单

struct RecipeFloatingMenuCard: View {
    enum Page: Equatable {
        case actions
        case categories
    }

    let recipe: Recipe
    let categories: [RecipeCategory]
    var maxCardHeight: CGFloat = 320
    var showsRecipeHeader: Bool = true
    var showsBatchManage: Bool = false
    var initialPage: Page = .actions
    var canReturnToActions: Bool = true
    let onEdit: () -> Void
    let onEditPhotos: () -> Void
    let onSelectCategory: (UInt?, String) -> Void
    var onStartBatch: (() -> Void)? = nil
    let onDelete: () -> Void
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page: Page

    init(
        recipe: Recipe,
        categories: [RecipeCategory],
        maxCardHeight: CGFloat = 320,
        showsRecipeHeader: Bool = true,
        showsBatchManage: Bool = false,
        initialPage: Page = .actions,
        canReturnToActions: Bool = true,
        onEdit: @escaping () -> Void,
        onEditPhotos: @escaping () -> Void,
        onSelectCategory: @escaping (UInt?, String) -> Void,
        onStartBatch: (() -> Void)? = nil,
        onDelete: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.recipe = recipe
        self.categories = categories
        self.maxCardHeight = maxCardHeight
        self.showsRecipeHeader = showsRecipeHeader
        self.showsBatchManage = showsBatchManage
        self.initialPage = initialPage
        self.canReturnToActions = canReturnToActions
        self.onEdit = onEdit
        self.onEditPhotos = onEditPhotos
        self.onSelectCategory = onSelectCategory
        self.onStartBatch = onStartBatch
        self.onDelete = onDelete
        self.onClose = onClose
        _page = State(initialValue: initialPage)
    }

    private var currentCategoryName: String {
        if let cid = recipe.categoryId,
           let matched = categories.first(where: { $0.id == cid }) {
            return matched.name
        }
        if let name = recipe.category?.name, !name.isEmpty, recipe.categoryId != nil {
            return name
        }
        return "未分类"
    }

    var body: some View {
        Group {
            switch page {
            case .actions:
                actionsContent
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .opacity
                            )
                    )
            case .categories:
                categoriesContent
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .opacity
                            )
                    )
            }
        }
        .clipped()
    }

    private var actionsContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            if showsRecipeHeader {
                HStack(spacing: 9) {
                    let thumb = (recipe.coverImage?.isEmpty == false) ? recipe.coverImage : recipe.cutoutImage
                    AsyncImageView(url: thumb, name: recipe.name)
                        .frame(width: 30, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 1.5) {
                        Text(recipe.name)
                            .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.inkPrimary)
                            .lineLimit(1)
                        Text(currentCategoryName)
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(Color.inkMuted)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)
                .padding(.bottom, 5)

                FloatingMenuDivider()
            }

            FloatingMenuRow(title: "编辑菜谱", systemImage: "square.and.pencil") {
                onClose()
                onEdit()
            }

            FloatingMenuRow(title: "自定义主图与抠图", systemImage: "sparkles.rectangle.stack") {
                onClose()
                onEditPhotos()
            }

            FloatingMenuRow(
                title: "移动到分类",
                systemImage: "tag",
                trailingText: currentCategoryName,
                showsChevron: true
            ) {
                withAnimation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.84)) {
                    page = .categories
                }
            }

            if showsBatchManage, let onStartBatch {
                FloatingMenuRow(title: "多选批量管理", systemImage: "checklist") {
                    onClose()
                    onStartBatch()
                }
            }

            FloatingMenuDivider()

            FloatingMenuRow(title: "删除菜谱", systemImage: "trash", role: .destructive) {
                onClose()
                onDelete()
            }
        }
    }

    private var categoriesContent: some View {
        let listMaxHeight = max(132, min(236, maxCardHeight - 58))
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                if canReturnToActions {
                    Button {
                        Haptics.light()
                        withAnimation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.84)) {
                            page = .actions
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11.5, weight: .semibold))
                            Text("返回")
                                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(Color.inkSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.appBackground, in: Capsule())
                    }
                    .buttonStyle(SoftPressStyle())
                }

                Text("移动到分类")
                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.inkPrimary)
                    .padding(.leading, canReturnToActions ? 2 : 8)

                Spacer(minLength: 0)
            }
            .padding(.top, 3)
            .padding(.bottom, 3)

            FloatingMenuDivider()

            ViewThatFits(in: .vertical) {
                categoryRows
                ScrollView(.vertical, showsIndicators: false) {
                    categoryRows
                }
                .frame(maxHeight: listMaxHeight)
            }
        }
    }

    private var categoryRows: some View {
        VStack(alignment: .leading, spacing: 2) {
            FloatingMenuRow(
                title: "未分类",
                systemImage: "tray",
                isSelected: recipe.categoryId == nil
            ) {
                onClose()
                onSelectCategory(nil, "未分类")
            }

            ForEach(categories) { cat in
                let emoji = (cat.icon?.isEmpty == false) ? cat.icon : nil
                FloatingMenuRow(
                    title: cat.name,
                    systemImage: emoji == nil ? "tag" : nil,
                    emoji: emoji,
                    isSelected: recipe.categoryId == cat.id
                ) {
                    onClose()
                    onSelectCategory(cat.id, cat.name)
                }
            }
        }
    }
}

// MARK: - 隐藏系统导航栏后保留左侧边缘右滑返回手势

struct InteractivePopGestureEnabler: UIViewControllerRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> BridgeViewController {
        let controller = BridgeViewController()
        controller.coordinator = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: BridgeViewController, context: Context) {
        uiViewController.attachIfNeeded()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var navigationController: UINavigationController?

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let nav = navigationController else { return false }
            return nav.viewControllers.count > 1
        }
    }

    final class BridgeViewController: UIViewController {
        weak var coordinator: Coordinator?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            attachIfNeeded()
        }

        func attachIfNeeded() {
            guard let nav = navigationController,
                  let pop = nav.interactivePopGestureRecognizer,
                  let coordinator else { return }
            coordinator.navigationController = nav
            pop.isEnabled = true
            pop.delegate = coordinator
        }
    }
}
