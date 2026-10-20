import SwiftUI

/// 画布工具和主导航共享的圆润图标，图形均在 24 pt 坐标内绘制。
struct ProductIcon: View {
    enum Kind: Equatable {
        case meal, recipes, history, profile, add, text, sticker, draw, background
        case effects, layers, trash, undo, adjust, check, rotate, resize, select, selectAll
    }

    let kind: Kind

    var body: some View {
        path.stroke(style: StrokeStyle(lineWidth: 1.65, lineCap: .round, lineJoin: .round))
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }

    private var path: Path {
        Path { p in
            switch kind {
            case .meal:
                p.addEllipse(in: CGRect(x: 3, y: 8, width: 18, height: 5))
                p.move(to: CGPoint(x: 3.5, y: 11))
                p.addCurve(to: CGPoint(x: 20.5, y: 11), control1: CGPoint(x: 5, y: 23), control2: CGPoint(x: 19, y: 23))
                p.move(to: CGPoint(x: 8, y: 21)); p.addLine(to: CGPoint(x: 16, y: 21))
                p.move(to: CGPoint(x: 9, y: 3)); p.addQuadCurve(to: CGPoint(x: 10, y: 6), control: CGPoint(x: 8, y: 4))
                p.move(to: CGPoint(x: 15, y: 2.5)); p.addQuadCurve(to: CGPoint(x: 16, y: 5.5), control: CGPoint(x: 14, y: 4))
            case .recipes:
                p.addRoundedRect(in: CGRect(x: 5, y: 3, width: 15, height: 18), cornerSize: CGSize(width: 3.5, height: 3.5))
                p.move(to: CGPoint(x: 9, y: 3)); p.addLine(to: CGPoint(x: 9, y: 21))
                p.move(to: CGPoint(x: 13, y: 8)); p.addLine(to: CGPoint(x: 16.5, y: 8))
                p.move(to: CGPoint(x: 13, y: 12)); p.addLine(to: CGPoint(x: 15.5, y: 12))
                p.move(to: CGPoint(x: 3, y: 8)); p.addLine(to: CGPoint(x: 6, y: 8))
                p.move(to: CGPoint(x: 3, y: 16)); p.addLine(to: CGPoint(x: 6, y: 16))
            case .history:
                p.addArc(center: CGPoint(x: 12, y: 12), radius: 8.5, startAngle: .degrees(-145), endAngle: .degrees(180), clockwise: false)
                p.move(to: CGPoint(x: 3.5, y: 4)); p.addLine(to: CGPoint(x: 3.5, y: 9)); p.addLine(to: CGPoint(x: 8.5, y: 9))
                p.move(to: CGPoint(x: 12, y: 7)); p.addLine(to: CGPoint(x: 12, y: 12)); p.addLine(to: CGPoint(x: 15.5, y: 14))
            case .profile:
                p.addEllipse(in: CGRect(x: 8, y: 3, width: 8, height: 8))
                p.move(to: CGPoint(x: 4, y: 21)); p.addLine(to: CGPoint(x: 4, y: 19))
                p.addCurve(to: CGPoint(x: 20, y: 19), control1: CGPoint(x: 4, y: 11.5), control2: CGPoint(x: 20, y: 11.5))
                p.addLine(to: CGPoint(x: 20, y: 21))
            case .add:
                p.move(to: CGPoint(x: 4.5, y: 12)); p.addLine(to: CGPoint(x: 19.5, y: 12))
                p.move(to: CGPoint(x: 12, y: 4.5)); p.addLine(to: CGPoint(x: 12, y: 19.5))
            case .text:
                p.move(to: CGPoint(x: 4.5, y: 6.5)); p.addLine(to: CGPoint(x: 4.5, y: 4)); p.addLine(to: CGPoint(x: 19.5, y: 4)); p.addLine(to: CGPoint(x: 19.5, y: 6.5))
                p.move(to: CGPoint(x: 12, y: 4)); p.addLine(to: CGPoint(x: 12, y: 20))
                p.move(to: CGPoint(x: 8.5, y: 20)); p.addLine(to: CGPoint(x: 15.5, y: 20))
            case .sticker:
                p.move(to: CGPoint(x: 15, y: 21)); p.addLine(to: CGPoint(x: 7, y: 21))
                p.addQuadCurve(to: CGPoint(x: 3, y: 17), control: CGPoint(x: 3, y: 21))
                p.addLine(to: CGPoint(x: 3, y: 7)); p.addQuadCurve(to: CGPoint(x: 7, y: 3), control: CGPoint(x: 3, y: 3))
                p.addLine(to: CGPoint(x: 17, y: 3)); p.addQuadCurve(to: CGPoint(x: 21, y: 7), control: CGPoint(x: 21, y: 3))
                p.addLine(to: CGPoint(x: 21, y: 15)); p.addLine(to: CGPoint(x: 15, y: 21)); p.addLine(to: CGPoint(x: 15, y: 18))
                p.addQuadCurve(to: CGPoint(x: 18, y: 15), control: CGPoint(x: 15, y: 15)); p.addLine(to: CGPoint(x: 21, y: 15))
                p.move(to: CGPoint(x: 8, y: 9)); p.addLine(to: CGPoint(x: 8, y: 9.5))
                p.move(to: CGPoint(x: 15, y: 9)); p.addLine(to: CGPoint(x: 15, y: 9.5))
                p.move(to: CGPoint(x: 8, y: 13)); p.addQuadCurve(to: CGPoint(x: 14, y: 13), control: CGPoint(x: 11, y: 16))
            case .draw:
                p.move(to: CGPoint(x: 4, y: 20)); p.addLine(to: CGPoint(x: 5.5, y: 14.5)); p.addLine(to: CGPoint(x: 16, y: 4))
                p.addQuadCurve(to: CGPoint(x: 20, y: 8), control: CGPoint(x: 22, y: 2)); p.addLine(to: CGPoint(x: 9.5, y: 18.5)); p.closeSubpath()
                p.move(to: CGPoint(x: 14, y: 6)); p.addLine(to: CGPoint(x: 18, y: 10))
            case .background:
                p.addRoundedRect(in: CGRect(x: 3, y: 4, width: 18, height: 16), cornerSize: CGSize(width: 4, height: 4))
                p.addEllipse(in: CGRect(x: 7, y: 8, width: 2.5, height: 2.5))
                p.move(to: CGPoint(x: 3.5, y: 17)); p.addLine(to: CGPoint(x: 9, y: 12.5)); p.addLine(to: CGPoint(x: 13, y: 16))
                p.addLine(to: CGPoint(x: 17, y: 12)); p.addLine(to: CGPoint(x: 20.5, y: 15))
            case .effects:
                p.move(to: CGPoint(x: 10, y: 3)); p.addQuadCurve(to: CGPoint(x: 17, y: 11), control: CGPoint(x: 11, y: 10))
                p.addQuadCurve(to: CGPoint(x: 10, y: 20), control: CGPoint(x: 11, y: 12)); p.addQuadCurve(to: CGPoint(x: 3, y: 11), control: CGPoint(x: 9, y: 12))
                p.addQuadCurve(to: CGPoint(x: 10, y: 3), control: CGPoint(x: 9, y: 10))
                p.move(to: CGPoint(x: 19, y: 3)); p.addLine(to: CGPoint(x: 19, y: 7))
                p.move(to: CGPoint(x: 17, y: 5)); p.addLine(to: CGPoint(x: 21, y: 5))
            case .layers:
                p.move(to: CGPoint(x: 3, y: 8)); p.addLine(to: CGPoint(x: 12, y: 3.5)); p.addLine(to: CGPoint(x: 21, y: 8)); p.addLine(to: CGPoint(x: 12, y: 12.5)); p.closeSubpath()
                p.move(to: CGPoint(x: 3, y: 12.5)); p.addLine(to: CGPoint(x: 12, y: 17)); p.addLine(to: CGPoint(x: 21, y: 12.5))
                p.move(to: CGPoint(x: 3, y: 17)); p.addLine(to: CGPoint(x: 12, y: 21.5)); p.addLine(to: CGPoint(x: 21, y: 17))
            case .trash:
                p.move(to: CGPoint(x: 4, y: 6)); p.addLine(to: CGPoint(x: 20, y: 6))
                p.move(to: CGPoint(x: 9, y: 6)); p.addLine(to: CGPoint(x: 9, y: 3)); p.addLine(to: CGPoint(x: 15, y: 3)); p.addLine(to: CGPoint(x: 15, y: 6))
                p.move(to: CGPoint(x: 6, y: 6)); p.addLine(to: CGPoint(x: 7, y: 19)); p.addQuadCurve(to: CGPoint(x: 9, y: 21), control: CGPoint(x: 7, y: 21))
                p.addLine(to: CGPoint(x: 15, y: 21)); p.addQuadCurve(to: CGPoint(x: 17, y: 19), control: CGPoint(x: 17, y: 21)); p.addLine(to: CGPoint(x: 18, y: 6))
                p.move(to: CGPoint(x: 10, y: 10)); p.addLine(to: CGPoint(x: 10, y: 17))
                p.move(to: CGPoint(x: 14, y: 10)); p.addLine(to: CGPoint(x: 14, y: 17))
            case .undo:
                p.move(to: CGPoint(x: 8, y: 4)); p.addLine(to: CGPoint(x: 3, y: 9)); p.addLine(to: CGPoint(x: 8, y: 14))
                p.move(to: CGPoint(x: 3, y: 9)); p.addLine(to: CGPoint(x: 14, y: 9))
                p.addCurve(to: CGPoint(x: 14, y: 21), control1: CGPoint(x: 23, y: 9), control2: CGPoint(x: 23, y: 21))
            case .adjust:
                p.move(to: CGPoint(x: 3, y: 7)); p.addLine(to: CGPoint(x: 8, y: 7))
                p.move(to: CGPoint(x: 13, y: 7)); p.addLine(to: CGPoint(x: 21, y: 7))
                p.addEllipse(in: CGRect(x: 8, y: 4.5, width: 5, height: 5))
                p.move(to: CGPoint(x: 3, y: 17)); p.addLine(to: CGPoint(x: 13, y: 17))
                p.move(to: CGPoint(x: 18, y: 17)); p.addLine(to: CGPoint(x: 21, y: 17))
                p.addEllipse(in: CGRect(x: 13, y: 14.5, width: 5, height: 5))
            case .check:
                p.move(to: CGPoint(x: 4, y: 12)); p.addLine(to: CGPoint(x: 9.5, y: 17.5)); p.addLine(to: CGPoint(x: 20, y: 6))
            case .rotate:
                p.addArc(center: CGPoint(x: 12, y: 12), radius: 7, startAngle: .degrees(-40), endAngle: .degrees(245), clockwise: false)
                p.move(to: CGPoint(x: 5, y: 5.7)); p.addLine(to: CGPoint(x: 9, y: 5.7)); p.addLine(to: CGPoint(x: 9, y: 9.7))
            case .resize:
                p.move(to: CGPoint(x: 5, y: 10)); p.addLine(to: CGPoint(x: 5, y: 5)); p.addLine(to: CGPoint(x: 10, y: 5))
                p.move(to: CGPoint(x: 5, y: 5)); p.addLine(to: CGPoint(x: 10, y: 10))
                p.move(to: CGPoint(x: 14, y: 14)); p.addLine(to: CGPoint(x: 19, y: 19))
                p.move(to: CGPoint(x: 14, y: 19)); p.addLine(to: CGPoint(x: 19, y: 19)); p.addLine(to: CGPoint(x: 19, y: 14))
            case .select, .selectAll:
                p.move(to: CGPoint(x: 4, y: 8)); p.addLine(to: CGPoint(x: 4, y: 4)); p.addLine(to: CGPoint(x: 8, y: 4))
                p.move(to: CGPoint(x: 16, y: 4)); p.addLine(to: CGPoint(x: 20, y: 4)); p.addLine(to: CGPoint(x: 20, y: 8))
                p.move(to: CGPoint(x: 20, y: 16)); p.addLine(to: CGPoint(x: 20, y: 20)); p.addLine(to: CGPoint(x: 16, y: 20))
                p.move(to: CGPoint(x: 8, y: 20)); p.addLine(to: CGPoint(x: 4, y: 20)); p.addLine(to: CGPoint(x: 4, y: 16))
                if kind == .selectAll {
                    p.move(to: CGPoint(x: 8, y: 12)); p.addLine(to: CGPoint(x: 11, y: 15)); p.addLine(to: CGPoint(x: 16, y: 9))
                } else {
                    p.move(to: CGPoint(x: 11, y: 4)); p.addLine(to: CGPoint(x: 13, y: 4))
                    p.move(to: CGPoint(x: 20, y: 11)); p.addLine(to: CGPoint(x: 20, y: 13))
                    p.move(to: CGPoint(x: 13, y: 20)); p.addLine(to: CGPoint(x: 11, y: 20))
                    p.move(to: CGPoint(x: 4, y: 13)); p.addLine(to: CGPoint(x: 4, y: 11))
                }
            }
        }
    }
}
