import SwiftUI

/// 画布工具和主导航共享的原生 SF Symbols 图标，统一 24 pt 网格定位。
struct ProductIcon: View {
    enum Kind: Equatable {
        case meal, recipes, history, profile, add, text, sticker, draw, background
        case effects, layers, trash, undo, redo, layout, adjust, check, rotate, resize, select, selectAll
    }

    let kind: Kind
    var size: CGFloat = 17
    var weight: Font.Weight = .regular

    var body: some View {
        Group {
            if kind == .text {
                Text("T")
                    .font(.system(size: size + 2, weight: .semibold, design: .serif))
            } else {
                Image(systemName: symbolName)
                    .font(.system(size: size, weight: weight))
            }
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }

    private var symbolName: String {
        switch kind {
        case .meal: return "fork.knife"
        case .recipes: return "book.closed"
        case .history: return "clock"
        case .profile: return "person"
        case .add: return "plus"
        case .text: return "textformat"
        case .sticker: return "face.smiling"
        case .draw: return "pencil.tip"
        case .background: return "photo"
        case .effects: return "sparkles"
        case .layers: return "square.3.layers.3d"
        case .trash: return "trash"
        case .undo: return "arrow.uturn.backward"
        case .redo: return "arrow.uturn.forward"
        case .layout: return "rectangle.3.group"
        case .adjust: return "slider.horizontal.3"
        case .check: return "checkmark"
        case .rotate: return "arrow.clockwise"
        case .resize: return "arrow.up.left.and.arrow.down.right"
        case .select: return "rectangle.dashed"
        case .selectAll: return "checkmark.rectangle.stack"
        }
    }
}
