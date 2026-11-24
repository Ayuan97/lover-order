import SwiftUI
import UIKit

/// 画布瞬时创作特效（粒子爆发、波纹、笔尖实时流光）与持续星芒环绕层。
@MainActor
final class CanvasFXController: ObservableObject {
    @Published private(set) var hasActiveFX: Bool = false

    struct BrushTipAura {
        var point: CGPoint
        var color: Color
        var profile: BrushAudioProfile
        var width: CGFloat
        var updatedAt: TimeInterval
    }

    enum ParticleShape {
        case star
        case dot
        case heart
        case diamond
        case wisp
    }

    struct FXParticle {
        let bornAt: TimeInterval
        let life: TimeInterval
        let origin: CGPoint
        let velocity: CGVector
        let gravity: CGFloat
        let drag: CGFloat
        let size: CGFloat
        let rotation: Double
        let spin: Double
        let color: Color
        let shape: ParticleShape
    }

    struct FXRing {
        let bornAt: TimeInterval
        let life: TimeInterval
        let origin: CGPoint
        let startRadius: CGFloat
        let endRadius: CGFloat
        let lineWidth: CGFloat
        let color: Color
        let isDashed: Bool
    }

    private(set) var particles: [FXParticle] = []
    private(set) var rings: [FXRing] = []
    private(set) var activeBrushTip: BrushTipAura?

    private var activeUntil: TimeInterval = 0
    private var cleanupTask: Task<Void, Never>?
    private var lastBrushEmitAt: TimeInterval = 0
    private var rainbowHueIndex: Int = 0
    private static let maxParticles = 120

    // MARK: - 各类创作瞬时粒子特效

    /// 加菜上桌落地：双金环波纹 + 四角星芒 + 柔和升腾热气丝
    func emitDishPlated(at normalized: CanvasPoint, in size: CGSize) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let now = Date.timeIntervalSinceReferenceDate
        let center = resolve(normalized, in: size)
        let palette: [Color] = [
            Color(red: 1.00, green: 0.84, blue: 0.44),
            Color(red: 1.00, green: 0.94, blue: 0.78),
            Color(red: 0.98, green: 0.66, blue: 0.44),
            .white
        ]

        appendRing(FXRing(
            bornAt: now, life: 0.62, origin: center,
            startRadius: 16, endRadius: 96, lineWidth: 2.2,
            color: Color(red: 1.00, green: 0.84, blue: 0.46), isDashed: false
        ))
        appendRing(FXRing(
            bornAt: now + 0.06, life: 0.56, origin: center,
            startRadius: 10, endRadius: 68, lineWidth: 1.4,
            color: Color.white.opacity(0.92), isDashed: false
        ))

        for idx in 0..<12 {
            let angle = (Double(idx) / 12.0) * .pi * 2 + Double.random(in: -0.18...0.18)
            let speed = CGFloat.random(in: 75...165)
            appendParticle(FXParticle(
                bornAt: now,
                life: Double.random(in: 0.48...0.74),
                origin: center,
                velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed - 18),
                gravity: 64,
                drag: 1.9,
                size: CGFloat.random(in: 7...13),
                rotation: Double.random(in: 0...360),
                spin: Double.random(in: -140...140),
                color: palette[idx % palette.count],
                shape: idx % 3 == 0 ? .diamond : .star
            ))
        }

        // 4 道轻盈升腾的暖白热气丝
        for idx in 0..<4 {
            let offsetX = CGFloat(idx - 1) * 18 - 9
            appendParticle(FXParticle(
                bornAt: now + Double(idx) * 0.04,
                life: 0.78,
                origin: CGPoint(x: center.x + offsetX, y: center.y - 10),
                velocity: CGVector(dx: CGFloat.random(in: -10...10), dy: CGFloat.random(in: -68 ... -46)),
                gravity: -16,
                drag: 0.8,
                size: CGFloat.random(in: 14...20),
                rotation: Double.random(in: -15...15),
                spin: Double.random(in: -24...24),
                color: Color.white.opacity(0.75),
                shape: .wisp
            ))
        }

        scheduleCleanup(until: now + 0.85)
    }

    /// 贴入表情贴纸：按分类自动配色的彩屑爱心星爆
    func emitEmojiPop(at normalized: CanvasPoint, in size: CGSize, assetID: String) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let now = Date.timeIntervalSinceReferenceDate
        let center = resolve(normalized, in: size)
        let palette: [Color]
        if assetID.hasPrefix("mood_") {
            palette = [
                Color(red: 0.99, green: 0.56, blue: 0.62),
                Color(red: 1.00, green: 0.80, blue: 0.44),
                Color(red: 0.99, green: 0.72, blue: 0.84),
                .white
            ]
        } else if assetID.hasPrefix("food_") {
            palette = [
                Color(red: 1.00, green: 0.82, blue: 0.44),
                Color(red: 0.62, green: 0.85, blue: 0.58),
                Color(red: 0.96, green: 0.54, blue: 0.48),
                .white
            ]
        } else {
            palette = [
                Color(red: 0.76, green: 0.68, blue: 0.98),
                Color(red: 0.58, green: 0.82, blue: 0.98),
                Color(red: 1.00, green: 0.86, blue: 0.52),
                .white
            ]
        }

        appendRing(FXRing(
            bornAt: now, life: 0.46, origin: center,
            startRadius: 12, endRadius: 64, lineWidth: 1.8,
            color: palette[0], isDashed: false
        ))

        for idx in 0..<14 {
            let angle = (Double(idx) / 14.0) * .pi * 2 + Double.random(in: -0.22...0.22)
            let speed = CGFloat.random(in: 68...155)
            let shape: ParticleShape = idx % 3 == 0 ? .heart : (idx % 2 == 0 ? .star : .dot)
            appendParticle(FXParticle(
                bornAt: now,
                life: Double.random(in: 0.44...0.68),
                origin: center,
                velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed - 22),
                gravity: 110,
                drag: 2.2,
                size: CGFloat.random(in: 6...12),
                rotation: Double.random(in: -25...25),
                spin: Double.random(in: -180...180),
                color: palette[idx % palette.count],
                shape: shape
            ))
        }

        scheduleCleanup(until: now + 0.75)
    }

    /// 贴入手绘涂鸦贴纸：虚线印章圈 + 墨点微星
    func emitDoodleStamp(at normalized: CanvasPoint, in size: CGSize, color: Color) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let now = Date.timeIntervalSinceReferenceDate
        let center = resolve(normalized, in: size)

        appendRing(FXRing(
            bornAt: now, life: 0.42, origin: center,
            startRadius: 20, endRadius: 62, lineWidth: 1.8,
            color: color.opacity(0.9), isDashed: true
        ))

        for idx in 0..<10 {
            let angle = (Double(idx) / 10.0) * .pi * 2 + 0.15
            let speed = CGFloat.random(in: 55...115)
            appendParticle(FXParticle(
                bornAt: now,
                life: Double.random(in: 0.36...0.52),
                origin: CGPoint(x: center.x + cos(angle) * 14, y: center.y + sin(angle) * 14),
                velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed),
                gravity: 40,
                drag: 2.6,
                size: CGFloat.random(in: 4.5...8.5),
                rotation: Double.random(in: 0...180),
                spin: Double.random(in: -90...90),
                color: idx.isMultiple(of: 2) ? color : .white,
                shape: idx % 3 == 0 ? .star : .dot
            ))
        }

        scheduleCleanup(until: now + 0.58)
    }

    /// 抠图贴纸贴入：棱镜双环 + 菱形星光魔法爆发
    func emitCutoutMagic(at normalized: CanvasPoint, in size: CGSize) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let now = Date.timeIntervalSinceReferenceDate
        let center = resolve(normalized, in: size)
        let prism: [Color] = [
            Color(red: 0.62, green: 0.90, blue: 1.00),
            Color(red: 0.84, green: 0.72, blue: 1.00),
            Color(red: 1.00, green: 0.88, blue: 0.66),
            .white
        ]

        appendRing(FXRing(
            bornAt: now, life: 0.58, origin: center,
            startRadius: 14, endRadius: 90, lineWidth: 2.0,
            color: prism[0], isDashed: false
        ))
        appendRing(FXRing(
            bornAt: now + 0.07, life: 0.52, origin: center,
            startRadius: 10, endRadius: 68, lineWidth: 1.5,
            color: prism[1], isDashed: false
        ))

        for idx in 0..<14 {
            let angle = (Double(idx) / 14.0) * .pi * 2
            let speed = CGFloat.random(in: 75...160)
            appendParticle(FXParticle(
                bornAt: now,
                life: Double.random(in: 0.50...0.76),
                origin: center,
                velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed),
                gravity: 24,
                drag: 2.0,
                size: CGFloat.random(in: 6.5...12.5),
                rotation: Double.random(in: 0...180),
                spin: Double.random(in: -160...160),
                color: prism[idx % prism.count],
                shape: idx.isMultiple(of: 2) ? .diamond : .star
            ))
        }

        scheduleCleanup(until: now + 0.82)
    }

    /// 画布落字：沿文字横线洒落温柔星点
    func emitTextPlace(at normalized: CanvasPoint, in size: CGSize, color: Color) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let now = Date.timeIntervalSinceReferenceDate
        let center = resolve(normalized, in: size)

        appendRing(FXRing(
            bornAt: now, life: 0.40, origin: center,
            startRadius: 16, endRadius: 60, lineWidth: 1.4,
            color: color.opacity(0.75), isDashed: false
        ))

        for idx in 0..<10 {
            let spreadX = CGFloat(idx - 5) * 11 + CGFloat.random(in: -4...4)
            appendParticle(FXParticle(
                bornAt: now + Double(idx) * 0.015,
                life: Double.random(in: 0.40...0.60),
                origin: CGPoint(x: center.x + spreadX, y: center.y + CGFloat.random(in: -8...8)),
                velocity: CGVector(dx: spreadX * 0.65, dy: CGFloat.random(in: -62 ... -18)),
                gravity: 54,
                drag: 1.8,
                size: CGFloat.random(in: 5...9),
                rotation: Double.random(in: 0...90),
                spin: Double.random(in: -90...90),
                color: idx % 3 == 0 ? .white : color,
                shape: idx.isMultiple(of: 2) ? .star : .dot
            ))
        }

        scheduleCleanup(until: now + 0.72)
    }

    /// 应用贴纸样式/动效特效：聚焦高光圈 + 四散微星
    func emitEffectApplied(at normalized: CanvasPoint, in size: CGSize, accent: Color) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let now = Date.timeIntervalSinceReferenceDate
        let center = resolve(normalized, in: size)

        appendRing(FXRing(
            bornAt: now, life: 0.45, origin: center,
            startRadius: 18, endRadius: 72, lineWidth: 1.6,
            color: accent, isDashed: false
        ))

        for idx in 0..<8 {
            let angle = (Double(idx) / 8.0) * .pi * 2 + 0.2
            let speed = CGFloat.random(in: 58...112)
            appendParticle(FXParticle(
                bornAt: now,
                life: 0.48,
                origin: center,
                velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed),
                gravity: 16,
                drag: 2.2,
                size: CGFloat.random(in: 6...10),
                rotation: 0,
                spin: 120,
                color: idx.isMultiple(of: 2) ? accent : .white,
                shape: .star
            ))
        }

        scheduleCleanup(until: now + 0.55)
    }

    /// 复制元素：双生叠加波纹
    func emitDuplicate(at normalized: CanvasPoint, in size: CGSize) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let now = Date.timeIntervalSinceReferenceDate
        let center = resolve(normalized, in: size)

        appendRing(FXRing(
            bornAt: now, life: 0.40, origin: center,
            startRadius: 12, endRadius: 56, lineWidth: 1.5,
            color: Color.white.opacity(0.85), isDashed: false
        ))
        appendRing(FXRing(
            bornAt: now + 0.06, life: 0.38, origin: CGPoint(x: center.x + 8, y: center.y + 8),
            startRadius: 10, endRadius: 48, lineWidth: 1.2,
            color: Color(red: 1.0, green: 0.88, blue: 0.56), isDashed: false
        ))
        for idx in 0..<8 {
            let angle = (Double(idx) / 8.0) * .pi * 2
            appendParticle(FXParticle(
                bornAt: now, life: 0.42, origin: center,
                velocity: CGVector(dx: cos(angle) * 76, dy: sin(angle) * 76),
                gravity: 20, drag: 2.4, size: 5.5,
                rotation: 0, spin: 80, color: .white, shape: .dot
            ))
        }
        scheduleCleanup(until: now + 0.52)
    }

    /// 删除元素：柔和消散微尘
    func emitDeletePoof(at normalized: CanvasPoint, in size: CGSize) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let now = Date.timeIntervalSinceReferenceDate
        let center = resolve(normalized, in: size)

        for idx in 0..<10 {
            let angle = (Double(idx) / 10.0) * .pi * 2 + Double.random(in: -0.2...0.2)
            let speed = CGFloat.random(in: 36...82)
            appendParticle(FXParticle(
                bornAt: now,
                life: Double.random(in: 0.34...0.48),
                origin: center,
                velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed - 12),
                gravity: -18,
                drag: 2.6,
                size: CGFloat.random(in: 6...11),
                rotation: 0,
                spin: 0,
                color: Color.white.opacity(0.76),
                shape: .dot
            ))
        }
        scheduleCleanup(until: now + 0.52)
    }

    /// 一键排版：多元素错峰轻星波
    func emitLayoutWave(positions: [CanvasPoint], in size: CGSize) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let now = Date.timeIntervalSinceReferenceDate
        for (idx, pos) in positions.prefix(8).enumerated() {
            let delay = Double(idx) * 0.045
            let center = resolve(pos, in: size)
            appendRing(FXRing(
                bornAt: now + delay, life: 0.42, origin: center,
                startRadius: 12, endRadius: 54, lineWidth: 1.3,
                color: Color.white.opacity(0.86), isDashed: false
            ))
            for k in 0..<4 {
                let angle = (Double(k) / 4.0) * .pi * 2 + Double(idx) * 0.4
                appendParticle(FXParticle(
                    bornAt: now + delay, life: 0.45, origin: center,
                    velocity: CGVector(dx: cos(angle) * 64, dy: sin(angle) * 64),
                    gravity: 16, drag: 2.2, size: 6.5,
                    rotation: 0, spin: 90,
                    color: k.isMultiple(of: 2) ? Color(red: 1.0, green: 0.88, blue: 0.55) : .white,
                    shape: .star
                ))
            }
        }
        scheduleCleanup(until: now + 0.85)
    }

    /// 切换背景 / 滤镜：轻柔画布光尘
    func emitBackgroundPulse(in size: CGSize, isLight: Bool) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let now = Date.timeIntervalSinceReferenceDate
        let resolved = resolvedSize(size)
        let center = CGPoint(x: resolved.width * 0.5, y: resolved.height * 0.48)
        let tint = isLight ? Color(red: 0.46, green: 0.56, blue: 0.42) : Color.white

        appendRing(FXRing(
            bornAt: now, life: 0.55, origin: center,
            startRadius: 36, endRadius: min(resolved.width, resolved.height) * 0.48,
            lineWidth: 1.4, color: tint.opacity(0.45), isDashed: false
        ))

        for _ in 0..<12 {
            let pt = CGPoint(
                x: CGFloat.random(in: resolved.width * 0.14 ... resolved.width * 0.86),
                y: CGFloat.random(in: resolved.height * 0.20 ... resolved.height * 0.78)
            )
            appendParticle(FXParticle(
                bornAt: now,
                life: Double.random(in: 0.45...0.68),
                origin: pt,
                velocity: CGVector(dx: CGFloat.random(in: -14...14), dy: CGFloat.random(in: -32 ... -10)),
                gravity: -8,
                drag: 1.4,
                size: CGFloat.random(in: 5...9),
                rotation: 0,
                spin: 85,
                color: tint.opacity(0.85),
                shape: .star
            ))
        }
        scheduleCleanup(until: now + 0.75)
    }

    /// 全部动起来 / 保存实况 / 定下这一顿：双侧彩星礼赞
    func emitCelebrationShower(in size: CGSize) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let now = Date.timeIntervalSinceReferenceDate
        let resolved = resolvedSize(size)
        let origin = CGPoint(x: resolved.width * 0.5, y: resolved.height * 0.34)
        let colors: [Color] = [
            Color(red: 1.00, green: 0.82, blue: 0.42),
            Color(red: 0.99, green: 0.58, blue: 0.64),
            Color(red: 0.64, green: 0.88, blue: 0.66),
            Color(red: 0.62, green: 0.84, blue: 1.00),
            .white
        ]

        appendRing(FXRing(
            bornAt: now, life: 0.68, origin: origin,
            startRadius: 18, endRadius: 130, lineWidth: 2.0,
            color: colors[0].opacity(0.85), isDashed: false
        ))

        for idx in 0..<28 {
            let spreadAngle = -Double.pi / 2 + Double.random(in: -1.15...1.15)
            let speed = CGFloat.random(in: 120...280)
            let shape: ParticleShape = idx % 4 == 0 ? .heart : (idx % 2 == 0 ? .star : .diamond)
            appendParticle(FXParticle(
                bornAt: now + Double(idx % 5) * 0.025,
                life: Double.random(in: 0.68...1.05),
                origin: CGPoint(x: origin.x + CGFloat.random(in: -44...44), y: origin.y),
                velocity: CGVector(dx: cos(spreadAngle) * speed, dy: sin(spreadAngle) * speed),
                gravity: 220,
                drag: 1.6,
                size: CGFloat.random(in: 7...13),
                rotation: Double.random(in: 0...360),
                spin: Double.random(in: -220...220),
                color: colors[idx % colors.count],
                shape: shape
            ))
        }
        scheduleCleanup(until: now + 1.15)
    }

    // MARK: - 画笔实时笔尖光环与专属拖尾粒子

    func updateBrushTip(point: CGPoint, color: Color, profile: BrushAudioProfile, width: CGFloat, speed: CGFloat) {
        let now = Date.timeIntervalSinceReferenceDate
        if UIAccessibility.isReduceMotionEnabled {
            activeBrushTip = nil
            return
        }
        activeBrushTip = BrushTipAura(point: point, color: color, profile: profile, width: width, updatedAt: now)
        if !hasActiveFX {
            hasActiveFX = true
        }

        let minInterval: TimeInterval
        switch profile {
        case .rainbow: minInterval = 0.028
        case .sparkle: minInterval = 0.032
        case .neon: minInterval = 0.038
        case .dotted: minInterval = 0.050
        case .hearts: minInterval = 0.055
        default: minInterval = 0.060
        }

        if now - lastBrushEmitAt >= minInterval {
            lastBrushEmitAt = now
            switch profile {
            case .sparkle:
                for _ in 0..<2 {
                    let jitter = CGVector(dx: CGFloat.random(in: -34...34), dy: CGFloat.random(in: -38...22))
                    appendParticle(FXParticle(
                        bornAt: now, life: Double.random(in: 0.34...0.52), origin: point,
                        velocity: jitter, gravity: 18, drag: 2.2,
                        size: CGFloat.random(in: 5...9.5), rotation: Double.random(in: 0...90), spin: 160,
                        color: Bool.random() ? .white : Color(red: 1.0, green: 0.90, blue: 0.56),
                        shape: Bool.random() ? .star : .diamond
                    ))
                }
            case .rainbow:
                let hue = Double(rainbowHueIndex % 12) / 12.0
                rainbowHueIndex &+= 1
                let rainbowColor = Color(hue: hue, saturation: 0.78, brightness: 0.98)
                appendParticle(FXParticle(
                    bornAt: now, life: 0.42, origin: point,
                    velocity: CGVector(dx: CGFloat.random(in: -30...30), dy: CGFloat.random(in: -34...24)),
                    gravity: 28, drag: 2.0, size: CGFloat.random(in: 5.5...9),
                    rotation: 0, spin: 120, color: rainbowColor,
                    shape: rainbowHueIndex.isMultiple(of: 2) ? .star : .dot
                ))
            case .hearts:
                appendParticle(FXParticle(
                    bornAt: now, life: 0.55, origin: point,
                    velocity: CGVector(dx: CGFloat.random(in: -18...18), dy: CGFloat.random(in: -54 ... -24)),
                    gravity: -18, drag: 1.5, size: CGFloat.random(in: 7...11),
                    rotation: Double.random(in: -18...18), spin: Double.random(in: -30...30),
                    color: color, shape: .heart
                ))
            case .neon:
                appendParticle(FXParticle(
                    bornAt: now, life: 0.34, origin: point,
                    velocity: CGVector(dx: CGFloat.random(in: -26...26), dy: CGFloat.random(in: -26...26)),
                    gravity: 0, drag: 2.6, size: CGFloat.random(in: 4.5...7.5),
                    rotation: 0, spin: 0, color: Bool.random() ? color : .white, shape: .dot
                ))
            case .dotted:
                appendParticle(FXParticle(
                    bornAt: now, life: 0.32, origin: point,
                    velocity: CGVector(dx: CGFloat.random(in: -22...22), dy: CGFloat.random(in: -28...14)),
                    gravity: 40, drag: 2.4, size: CGFloat.random(in: 4...6.5),
                    rotation: 0, spin: 0, color: color, shape: .dot
                ))
            default:
                if speed > 180 {
                    appendParticle(FXParticle(
                        bornAt: now, life: 0.28, origin: point,
                        velocity: CGVector(dx: CGFloat.random(in: -18...18), dy: CGFloat.random(in: -18...18)),
                        gravity: 10, drag: 3.0, size: CGFloat.random(in: 3.5...5.5),
                        rotation: 0, spin: 0, color: color.opacity(0.8), shape: .dot
                    ))
                }
            }
        }

        scheduleCleanup(until: now + 0.65)
    }

    func endBrushTip(at point: CGPoint?, color: Color, profile: BrushAudioProfile) {
        activeBrushTip = nil
        let now = Date.timeIntervalSinceReferenceDate
        if !UIAccessibility.isReduceMotionEnabled,
           let point,
           profile == .sparkle || profile == .rainbow || profile == .hearts || profile == .neon {
            let shape: ParticleShape = profile == .hearts ? .heart : .star
            for idx in 0..<6 {
                let angle = (Double(idx) / 6.0) * .pi * 2
                let emitColor: Color = profile == .rainbow
                    ? Color(hue: Double(idx) / 6.0, saturation: 0.78, brightness: 0.98)
                    : (idx.isMultiple(of: 2) ? color : .white)
                appendParticle(FXParticle(
                    bornAt: now, life: 0.42, origin: point,
                    velocity: CGVector(dx: cos(angle) * 52, dy: sin(angle) * 52),
                    gravity: 16, drag: 2.4, size: 7.5,
                    rotation: 0, spin: 110, color: emitColor, shape: shape
                ))
            }
            scheduleCleanup(until: now + 0.48)
        } else {
            scheduleCleanup(until: max(activeUntil, now + 0.05))
        }
    }

    // MARK: - 内部生命周期管理

    private func resolvedSize(_ size: CGSize) -> CGSize {
        if size.width > 10 && size.height > 10 { return size }
        return UIScreen.main.bounds.size
    }

    private func resolve(_ normalized: CanvasPoint, in size: CGSize) -> CGPoint {
        let s = resolvedSize(size)
        return CGPoint(x: normalized.x * s.width, y: normalized.y * s.height)
    }

    private func appendParticle(_ particle: FXParticle) {
        particles.append(particle)
        if particles.count > Self.maxParticles {
            particles.removeFirst(particles.count - Self.maxParticles)
        }
    }

    private func appendRing(_ ring: FXRing) {
        rings.append(ring)
        if rings.count > 24 {
            rings.removeFirst(rings.count - 24)
        }
    }

    private func scheduleCleanup(until deadline: TimeInterval) {
        activeUntil = max(activeUntil, deadline)
        if !hasActiveFX {
            hasActiveFX = true
        }
        cleanupTask?.cancel()
        let waitSeconds = max(0.05, activeUntil - Date.timeIntervalSinceReferenceDate + 0.08)
        cleanupTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(waitSeconds))
            guard let self, !Task.isCancelled else { return }
            let now = Date.timeIntervalSinceReferenceDate
            self.particles.removeAll { now - $0.bornAt >= $0.life }
            self.rings.removeAll { now - $0.bornAt >= $0.life }
            if let tip = self.activeBrushTip, now - tip.updatedAt > 0.6 {
                self.activeBrushTip = nil
            }
            if self.particles.isEmpty && self.rings.isEmpty && self.activeBrushTip == nil {
                self.hasActiveFX = false
                self.activeUntil = 0
            } else {
                let remaining = max(
                    self.particles.map { $0.bornAt + $0.life }.max() ?? now,
                    self.rings.map { $0.bornAt + $0.life }.max() ?? now
                )
                self.scheduleCleanup(until: remaining)
            }
        }
    }
}

/// 瞬时创作特效画布叠层：仅在有活跃特效时激活 60fps 渲染，闲置时零耗电且全程不拦截点击手势。
struct CanvasBurstFXOverlay: View {
    @ObservedObject var controller: CanvasFXController
    let isLightSurface: Bool

    var body: some View {
        if controller.hasActiveFX {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
                let now = context.date.timeIntervalSinceReferenceDate
                Canvas { graphics, _ in
                    // 1. 扩撒光环
                    for ring in controller.rings {
                        let age = now - ring.bornAt
                        guard age >= 0, age < ring.life else { continue }
                        let t = age / ring.life
                        let eased = 1 - pow(1 - t, 3)
                        let radius = ring.startRadius + (ring.endRadius - ring.startRadius) * CGFloat(eased)
                        let alpha = (1 - t) * (1 - t) * (isLightSurface ? 0.85 : 0.95)
                        let rect = CGRect(
                            x: ring.origin.x - radius,
                            y: ring.origin.y - radius,
                            width: radius * 2,
                            height: radius * 2
                        )
                        let style = StrokeStyle(
                            lineWidth: max(0.6, ring.lineWidth * CGFloat(1 - t * 0.45)),
                            lineCap: .round,
                            dash: ring.isDashed ? [5, 5] : []
                        )
                        graphics.stroke(Path(ellipseIn: rect), with: .color(ring.color.opacity(alpha)), style: style)
                    }

                    // 2. 笔尖实时光环
                    if let tip = controller.activeBrushTip, now - tip.updatedAt < 0.45 {
                        let pulse = 0.88 + 0.14 * sin(now * 16.0)
                        let radius = max(10, tip.width * 1.45) * CGFloat(pulse)
                        let ringRect = CGRect(
                            x: tip.point.x - radius,
                            y: tip.point.y - radius,
                            width: radius * 2,
                            height: radius * 2
                        )
                        let auraColor: Color = tip.profile == .rainbow
                            ? Color(hue: (now * 0.8).truncatingRemainder(dividingBy: 1.0), saturation: 0.78, brightness: 0.98)
                            : tip.color
                        graphics.fill(
                            Path(ellipseIn: ringRect.insetBy(dx: -3, dy: -3)),
                            with: .color(auraColor.opacity(0.16))
                        )
                        graphics.stroke(
                            Path(ellipseIn: ringRect),
                            with: .color(auraColor.opacity(0.76)),
                            style: StrokeStyle(lineWidth: 1.6)
                        )
                    }

                    // 3. 瞬时粒子（四角星、爱心、菱形、热气丝、圆点）
                    for p in controller.particles {
                        let age = now - p.bornAt
                        guard age >= 0, age < p.life else { continue }
                        let t = age / p.life
                        let damp = p.drag > 0 ? (1 - exp(-p.drag * age)) / p.drag : age
                        let x = p.origin.x + p.velocity.dx * CGFloat(damp)
                        let y = p.origin.y + p.velocity.dy * CGFloat(damp) + 0.5 * p.gravity * CGFloat(age * age)
                        let fadeOut = 1 - pow(t, 1.8)
                        let scale = Self.particleScale(shape: p.shape, t: t)
                        let r = max(1.2, p.size * scale * 0.5)
                        let angle = Angle.degrees(p.rotation + p.spin * age)

                        switch p.shape {
                        case .dot:
                            let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                            graphics.fill(Path(ellipseIn: rect), with: .color(p.color.opacity(fadeOut)))
                        case .star:
                            let path = Self.fourPointStarPath(center: CGPoint(x: x, y: y), radius: r, rotation: angle)
                            graphics.fill(path, with: .color(p.color.opacity(fadeOut)))
                        case .diamond:
                            let path = Self.diamondPath(center: CGPoint(x: x, y: y), radius: r, rotation: angle)
                            graphics.fill(path, with: .color(p.color.opacity(fadeOut)))
                        case .heart:
                            let path = Self.heartPath(center: CGPoint(x: x, y: y), radius: r, rotation: angle)
                            graphics.fill(path, with: .color(p.color.opacity(fadeOut)))
                        case .wisp:
                            let path = Self.wispPath(center: CGPoint(x: x, y: y), length: r * 2.2, phase: now * 5.0 + p.rotation)
                            graphics.stroke(
                                path,
                                with: .color(p.color.opacity(fadeOut * 0.62)),
                                style: StrokeStyle(lineWidth: 1.8, lineCap: .round)
                            )
                        }
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private static func particleScale(shape: CanvasFXController.ParticleShape, t: Double) -> CGFloat {
        if shape == .wisp {
            return CGFloat(0.75 + 0.45 * t)
        }
        if t < 0.18 {
            return CGFloat(0.4 + 0.6 * (t / 0.18))
        }
        return CGFloat(1.0 - (t - 0.18) * 0.45)
    }

    static func fourPointStarPath(center: CGPoint, radius: CGFloat, rotation: Angle) -> Path {
        let rad = CGFloat(rotation.radians)
        let cosR = cos(rad)
        let sinR = sin(rad)
        func rot(_ dx: CGFloat, _ dy: CGFloat) -> CGPoint {
            CGPoint(x: center.x + dx * cosR - dy * sinR, y: center.y + dx * sinR + dy * cosR)
        }
        let inner = radius * 0.22
        var path = Path()
        path.move(to: rot(0, -radius))
        path.addQuadCurve(to: rot(radius, 0), control: rot(inner, -inner))
        path.addQuadCurve(to: rot(0, radius), control: rot(inner, inner))
        path.addQuadCurve(to: rot(-radius, 0), control: rot(-inner, inner))
        path.addQuadCurve(to: rot(0, -radius), control: rot(-inner, -inner))
        path.closeSubpath()
        return path
    }

    private static func diamondPath(center: CGPoint, radius: CGFloat, rotation: Angle) -> Path {
        let rad = CGFloat(rotation.radians)
        let cosR = cos(rad)
        let sinR = sin(rad)
        func rot(_ dx: CGFloat, _ dy: CGFloat) -> CGPoint {
            CGPoint(x: center.x + dx * cosR - dy * sinR, y: center.y + dx * sinR + dy * cosR)
        }
        var path = Path()
        path.move(to: rot(0, -radius))
        path.addLine(to: rot(radius * 0.72, 0))
        path.addLine(to: rot(0, radius))
        path.addLine(to: rot(-radius * 0.72, 0))
        path.closeSubpath()
        return path
    }

    static func heartPath(center: CGPoint, radius: CGFloat, rotation: Angle) -> Path {
        let r = radius
        var raw = Path()
        raw.move(to: CGPoint(x: 0, y: r * 0.85))
        raw.addCurve(
            to: CGPoint(x: -r, y: -r * 0.22),
            control1: CGPoint(x: -r * 0.55, y: r * 0.42),
            control2: CGPoint(x: -r, y: r * 0.14)
        )
        raw.addArc(
            center: CGPoint(x: -r * 0.5, y: -r * 0.26),
            radius: r * 0.5,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        raw.addArc(
            center: CGPoint(x: r * 0.5, y: -r * 0.26),
            radius: r * 0.5,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        raw.addCurve(
            to: CGPoint(x: 0, y: r * 0.85),
            control1: CGPoint(x: r, y: r * 0.14),
            control2: CGPoint(x: r * 0.55, y: r * 0.42)
        )
        raw.closeSubpath()

        var transform = CGAffineTransform(translationX: center.x, y: center.y)
        transform = transform.rotated(by: CGFloat(rotation.radians))
        return raw.applying(transform)
    }

    private static func wispPath(center: CGPoint, length: CGFloat, phase: Double) -> Path {
        let sway = CGFloat(sin(phase)) * 4.5
        var path = Path()
        path.move(to: CGPoint(x: center.x, y: center.y + length * 0.5))
        path.addCurve(
            to: CGPoint(x: center.x + sway * 0.5, y: center.y - length * 0.5),
            control1: CGPoint(x: center.x - sway, y: center.y + length * 0.15),
            control2: CGPoint(x: center.x + sway, y: center.y - length * 0.18)
        )
        return path
    }
}

/// 元素外围持续环绕的纯 Canvas 星芒点缀层（同时适配实时画布与 Live Photo 离线帧导出，无 Material）。
struct CanvasSparkleOrbitOverlay: View {
    let time: TimeInterval
    var phase: Double = 0
    var isLightSurface: Bool = false
    var compact: Bool = false
    var reduceMotion: Bool = false

    var body: some View {
        Canvas { context, size in
            let cx = size.width * 0.5
            let cy = size.height * 0.5
            let rx = size.width * (compact ? 0.43 : 0.46)
            let ry = size.height * (compact ? 0.43 : 0.46)
            let primaryTint = isLightSurface
                ? Color(red: 0.96, green: 0.72, blue: 0.26)
                : Color(red: 1.00, green: 0.94, blue: 0.74)
            let secondaryTint = isLightSurface
                ? Color(red: 0.45, green: 0.62, blue: 0.40)
                : Color.white

            let t = reduceMotion ? 0.5 : (time + phase)
            let nodes: [(baseAngle: Double, speed: Double, radius: CGFloat, star: Bool)] = [
                (0.25, 0.45, compact ? 4.2 : 8.2, true),
                (1.32, 0.45, compact ? 2.6 : 4.2, false),
                (2.38, 0.45, compact ? 3.8 : 7.2, true),
                (3.45, 0.45, compact ? 2.4 : 3.8, false),
                (4.52, 0.45, compact ? 4.0 : 7.8, true),
                (5.58, 0.45, compact ? 2.5 : 4.0, false)
            ]

            for (idx, item) in nodes.enumerated() {
                let angle = item.baseAngle + t * item.speed
                let twinkle = reduceMotion ? 0.85 : (0.38 + 0.62 * (sin(t * 2.4 + Double(idx) * 1.15) + 1) * 0.5)
                let x = cx + CGFloat(cos(angle)) * rx
                let y = cy + CGFloat(sin(angle)) * ry
                let color = (idx.isMultiple(of: 2) ? primaryTint : secondaryTint).opacity(twinkle)
                if item.star {
                    let r = item.radius * CGFloat(0.75 + 0.35 * twinkle)
                    let path = CanvasBurstFXOverlay.fourPointStarPath(
                        center: CGPoint(x: x, y: y),
                        radius: r,
                        rotation: .radians(t * 0.6 + Double(idx))
                    )
                    context.fill(path, with: .color(color))
                } else {
                    let r = item.radius * CGFloat(0.78 + 0.28 * twinkle)
                    let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
