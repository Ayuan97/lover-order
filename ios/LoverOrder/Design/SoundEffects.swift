import AVFoundation
import Combine
import QuartzCore
import UIKit

/// 画笔笔触的音频特征分类，供音效引擎按不同笔触合成实时声音。
enum BrushAudioProfile: String, CaseIterable {
    case solid
    case dotted
    case dashed
    case marker
    case crayon
    case neon
    case sparkle
    case rainbow
    case hearts
}

/// 零外部音频资源、内存预合成 PCM 的自由画布实时创作音效引擎。
/// 采用 `.ambient` 会话，遵守硬件静音键并与后台音乐混合。
@MainActor
final class CanvasSoundEngine: ObservableObject {
    static let shared = CanvasSoundEngine()

    private static let enabledKey = "canvas.creative.sound.enabled.v1"
    private static let sampleRate: Double = 44_100
    private static let poolSize = 10

    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey)
            if !isEnabled {
                stopAllNodes()
            }
        }
    }

    private let audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    private let engine = AVAudioEngine()
    private var playerPool: [AVAudioPlayerNode] = []
    private var nextPoolIndex = 0
    private var isEngineConfigured = false
    private var buffers: [String: AVAudioPCMBuffer] = [:]

    private var lastBrushMoveTime: CFTimeInterval = 0
    private var lastSnapTime: CFTimeInterval = 0
    private var emojiStepIndex = -1
    private var doodleStepIndex = -1
    private var cutoutStepIndex = -1
    private var textStepIndex = -1
    private var dishTextureIndex = -1
    private var sparkleStepIndex = 0
    private var rainbowStepIndex = 0
    private var dottedStepIndex = 0
    private var heartsStepIndex = 0

    private var observers: [NSObjectProtocol] = []

    private init() {
        if UserDefaults.standard.object(forKey: Self.enabledKey) == nil {
            self.isEnabled = true
        } else {
            self.isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        }
        registerLifecycleObservers()
    }

    // MARK: - 公开播放接口

    /// 在加菜面板中选中菜谱 / 确认自定义菜名
    func playDishPick() {
        playCached(key: "dish_pick", volume: 0.62) {
            Self.makeTwoToneMarimba(f1: 783.99, f2: 1046.50, duration: 0.16, format: self.audioFormat)
        }
    }

    private func nextNonRepeatingVariant(last: inout Int, count: Int) -> Int {
        guard count > 1 else { return 0 }
        if last < 0 {
            let initial = Int.random(in: 0..<count)
            last = initial
            return initial
        }
        let step = 1 + Int.random(in: 0..<(count - 1))
        let next = (last + step) % count
        last = next
        return next
    }

    /// 菜品抛投落桌（空中轻抛呼声 + 5 种不同器皿落桌质感与五声音阶和弦）
    func playDishPlated(comboIndex: Int = 0) {
        let pitchIdx = abs(comboIndex) % 5
        let textureIdx = nextNonRepeatingVariant(last: &dishTextureIndex, count: 5)
        let bases: [Double] = [523.25, 587.33, 659.25, 783.99, 880.00]
        let base = bases[pitchIdx]
        playCached(key: "dish_toss_\(pitchIdx)_\(textureIdx)", volume: 0.72) {
            Self.makeDishTossBuffer(baseFreq: base, variant: textureIdx, format: self.audioFormat)
        }
    }

    /// 抛入表情贴纸：6 种截然不同的抛飞 + 落地音效（果冻弹啵 / 双气泡 / 软垫噗通 / 玻璃弹珠 / 俏皮木琴 / 糖果脆星）
    func playEmojiPop() {
        let variant = nextNonRepeatingVariant(last: &emojiStepIndex, count: 6)
        playCached(key: "emoji_toss_\(variant)", volume: 0.66) {
            Self.makeEmojiTossBuffer(variant: variant, format: self.audioFormat)
        }
    }

    /// 抛入手绘涂鸦贴纸：5 种手账文具抛落音（木质印章 / 和纸胶带嘶啪 / 厚卡纸拍桌 / 牛皮纸炭笔叩击 / 软木图钉笃声）
    func playDoodleStamp() {
        let variant = nextNonRepeatingVariant(last: &doodleStepIndex, count: 5)
        playCached(key: "doodle_toss_\(variant)", volume: 0.68) {
            Self.makeDoodleTossBuffer(variant: variant, format: self.audioFormat)
        }
    }

    /// 抛入照片 / 抠图贴纸：5 种相纸与贴纸抛落音（拍立得甩落 / 不干胶轻拍 / 发牌滑落 / 亚克力脆响 / 梦幻相册琶音）
    func playCutoutMagic() {
        let variant = nextNonRepeatingVariant(last: &cutoutStepIndex, count: 5)
        playCached(key: "cutout_toss_\(variant)", volume: 0.68) {
            Self.makeCutoutTossBuffer(variant: variant, format: self.audioFormat)
        }
    }

    /// 抛入文字便签：5 种纸笺字卡抛落音；原地改字时用 playTextEdit()
    func playTextToss() {
        let variant = nextNonRepeatingVariant(last: &textStepIndex, count: 5)
        playCached(key: "text_toss_\(variant)", volume: 0.64) {
            Self.makeTextTossBuffer(variant: variant, format: self.audioFormat)
        }
    }

    /// 画布原地更新文字：轻脆打字触键 + 木质共鸣 + A5 收尾
    func playTextPlace() {
        playCached(key: "text_place", volume: 0.56) {
            Self.makeTextPlaceBuffer(format: self.audioFormat)
        }
    }

    /// 实时绘制起笔
    func playBrushStart(profile: BrushAudioProfile) {
        switch profile {
        case .sparkle:
            playCached(key: "brush_start_sparkle", volume: 0.34) {
                Self.makeChimeBell(freq: 1318.51, duration: 0.14, format: self.audioFormat)
            }
        case .rainbow:
            playCached(key: "brush_start_rainbow", volume: 0.36) {
                Self.makeMarimbaHit(freq: 659.25, duration: 0.13, format: self.audioFormat)
            }
        case .hearts:
            playCached(key: "brush_start_hearts", volume: 0.36) {
                Self.makeHeartBubble(freq: 698.46, duration: 0.12, format: self.audioFormat)
            }
        case .neon:
            playCached(key: "brush_start_neon", volume: 0.30) {
                Self.makeNeonHum(freq: 987.77, duration: 0.15, format: self.audioFormat)
            }
        case .dotted:
            playCached(key: "brush_start_dotted", volume: 0.32) {
                Self.makeWaterDrop(freq: 880.0, duration: 0.09, format: self.audioFormat)
            }
        case .crayon:
            playCached(key: "brush_start_crayon", volume: 0.28) {
                Self.makeBrushTexture(duration: 0.065, centerFreq: 1850, grit: 0.55, format: self.audioFormat)
            }
        case .marker:
            playCached(key: "brush_start_marker", volume: 0.26) {
                Self.makeBrushTexture(duration: 0.075, centerFreq: 900, grit: 0.15, format: self.audioFormat)
            }
        case .dashed:
            playCached(key: "brush_start_dashed", volume: 0.28) {
                Self.makeSoftTick(freq: 1480, duration: 0.045, format: self.audioFormat)
            }
        case .solid:
            playCached(key: "brush_start_solid", volume: 0.24) {
                Self.makeBrushTexture(duration: 0.06, centerFreq: 1250, grit: 0.22, format: self.audioFormat)
            }
        }
    }

    /// 实时绘制滑动中（按笔触区分声音与节流周期）
    func playBrushMove(profile: BrushAudioProfile, speed: CGFloat) {
        guard isEnabled, speed > 45 else { return }
        let now = CACurrentMediaTime()
        let interval: CFTimeInterval
        switch profile {
        case .sparkle, .rainbow, .dotted, .hearts:
            interval = 0.085
        case .solid, .crayon, .marker, .dashed, .neon:
            interval = 0.10
        }
        guard now - lastBrushMoveTime >= interval else { return }
        lastBrushMoveTime = now

        let normalizedSpeed = min(max((Double(speed) - 45.0) / 900.0, 0), 1)
        let volume = Float(0.12 + normalizedSpeed * 0.24)

        switch profile {
        case .sparkle:
            let scale: [Double] = [1046.50, 1174.66, 1318.51, 1567.98, 1760.00, 2093.00]
            let idx = sparkleStepIndex % scale.count
            sparkleStepIndex &+= 1
            let freq = scale[idx]
            playCached(key: "brush_sparkle_\(idx)", volume: volume) {
                Self.makeChimeBell(freq: freq, duration: 0.16, format: self.audioFormat)
            }
        case .rainbow:
            let scale: [Double] = [523.25, 587.33, 659.25, 783.99, 880.00, 1046.50, 1174.66, 1318.51]
            let idx = rainbowStepIndex % scale.count
            rainbowStepIndex &+= 1
            let freq = scale[idx]
            playCached(key: "brush_rainbow_\(idx)", volume: volume) {
                Self.makeMarimbaHit(freq: freq, duration: 0.13, format: self.audioFormat)
            }
        case .hearts:
            let scale: [Double] = [698.46, 880.00, 1046.50, 1174.66]
            let idx = heartsStepIndex % scale.count
            heartsStepIndex &+= 1
            let freq = scale[idx]
            playCached(key: "brush_hearts_\(idx)", volume: volume) {
                Self.makeHeartBubble(freq: freq, duration: 0.11, format: self.audioFormat)
            }
        case .dotted:
            let scale: [Double] = [659.25, 783.99, 880.00, 987.77, 1174.66]
            let idx = dottedStepIndex % scale.count
            dottedStepIndex &+= 1
            let freq = scale[idx]
            playCached(key: "brush_dotted_\(idx)", volume: volume) {
                Self.makeWaterDrop(freq: freq, duration: 0.085, format: self.audioFormat)
            }
        case .neon:
            let freq = 880.0 + normalizedSpeed * 420.0
            let bucket = Int((freq / 60).rounded())
            playCached(key: "brush_neon_\(bucket)", volume: volume * 0.92) {
                Self.makeNeonHum(freq: Double(bucket * 60), duration: 0.12, format: self.audioFormat)
            }
        case .crayon:
            playCached(key: "brush_crayon_move", volume: volume) {
                Self.makeBrushTexture(duration: 0.09, centerFreq: 2100, grit: 0.68, format: self.audioFormat)
            }
        case .marker:
            playCached(key: "brush_marker_move", volume: volume * 0.85) {
                Self.makeBrushTexture(duration: 0.095, centerFreq: 780, grit: 0.14, format: self.audioFormat)
            }
        case .dashed:
            playCached(key: "brush_dashed_move", volume: volume * 0.88) {
                Self.makeSoftTick(freq: 1620, duration: 0.04, format: self.audioFormat)
            }
        case .solid:
            playCached(key: "brush_solid_move", volume: volume * 0.78) {
                Self.makeBrushTexture(duration: 0.085, centerFreq: 1320, grit: 0.22, format: self.audioFormat)
            }
        }
    }

    /// 实时绘制收笔
    func playBrushEnd(profile: BrushAudioProfile) {
        switch profile {
        case .sparkle, .rainbow:
            playCached(key: "brush_end_sparkle", volume: 0.36) {
                Self.makeTwoToneMarimba(f1: 1174.66, f2: 1567.98, duration: 0.17, format: self.audioFormat)
            }
        case .hearts:
            playCached(key: "brush_end_hearts", volume: 0.34) {
                Self.makeHeartBubble(freq: 1046.50, duration: 0.13, format: self.audioFormat)
            }
        case .neon:
            playCached(key: "brush_end_neon", volume: 0.28) {
                Self.makeNeonHum(freq: 1318.51, duration: 0.16, format: self.audioFormat)
            }
        default:
            playCached(key: "brush_end_soft", volume: 0.22) {
                Self.makeSoftTick(freq: 980, duration: 0.045, format: self.audioFormat)
            }
        }
    }

    /// 切换贴纸样式或动效特效：晶透双和弦光效注入
    func playEffectSparkle() {
        playCached(key: "effect_sparkle", volume: 0.56) {
            Self.makeEffectChordBuffer(format: self.audioFormat)
        }
    }

    /// 一键智能换排版：三连轻快翻牌 + G5 归位音
    func playLayoutShuffle() {
        playCached(key: "layout_shuffle", volume: 0.58) {
            Self.makeLayoutShuffleBuffer(format: self.audioFormat)
        }
    }

    /// 切换画布背景或氛围滤镜：柔和微风拂过 + 温暖玻璃共鸣
    func playBackgroundWhoosh() {
        playCached(key: "bg_whoosh", volume: 0.50) {
            Self.makeWhooshBuffer(format: self.audioFormat)
        }
    }

    /// 复制元素：双生回声两连啵
    func playDuplicate() {
        playCached(key: "duplicate", volume: 0.54) {
            Self.makeTwoToneMarimba(f1: 659.25, f2: 783.99, duration: 0.14, format: self.audioFormat)
        }
    }

    /// 删除元素：轻柔下行消散气声
    func playDeletePoof() {
        playCached(key: "delete_poof", volume: 0.46) {
            Self.makeDeletePoofBuffer(format: self.audioFormat)
        }
    }

    /// 撤销：轻巧下行双音拨弦
    func playUndo() {
        playCached(key: "undo", volume: 0.48) {
            Self.makeTwoToneMarimba(f1: 659.25, f2: 523.25, duration: 0.13, format: self.audioFormat)
        }
    }

    /// 重做：轻巧上行双音拨弦
    func playRedo() {
        playCached(key: "redo", volume: 0.48) {
            Self.makeTwoToneMarimba(f1: 523.25, f2: 659.25, duration: 0.13, format: self.audioFormat)
        }
    }

    /// 磁吸居中 / 90 度吸附微轻哒
    func playSnapTick() {
        guard isEnabled else { return }
        let now = CACurrentMediaTime()
        guard now - lastSnapTime >= 0.09 else { return }
        lastSnapTime = now
        playCached(key: "snap_tick", volume: 0.15) {
            Self.makeSoftTick(freq: 1760, duration: 0.032, format: self.audioFormat)
        }
    }

    /// 底部创作工具坞展开 / 收起
    func playToolbarPop(open: Bool) {
        let key = open ? "toolbar_open" : "toolbar_close"
        playCached(key: key, volume: 0.34) {
            if open {
                Self.makeTwoToneMarimba(f1: 587.33, f2: 880.00, duration: 0.11, format: self.audioFormat)
            } else {
                Self.makeTwoToneMarimba(f1: 783.99, f2: 523.25, duration: 0.10, format: self.audioFormat)
            }
        }
    }

    /// 全部动起来 / 保存实况照片 / 定下这一顿：明亮大九和弦礼赞
    func playCelebrate() {
        playCached(key: "celebrate", volume: 0.70) {
            Self.makeArpeggioBuffer(
                frequencies: [523.25, 659.25, 783.99, 987.77, 1174.66],
                stepSeconds: 0.052,
                noteDuration: 0.34,
                shimmerHarmonic: true,
                format: self.audioFormat
            )
        }
    }

    /// 在线收到或发出「开饭啦」摇铃传呼：清脆三叠餐桌铜铃 E5 -> B5 -> E6
    func playDinnerBell() {
        playCached(key: "nudge_dinner_bell", volume: 0.74) {
            Self.makeArpeggioBuffer(
                frequencies: [659.25, 987.77, 1318.51],
                stepSeconds: 0.115,
                noteDuration: 0.42,
                shimmerHarmonic: true,
                format: self.audioFormat
            )
        }
    }

    /// 在线收到或发出餐桌轻传呼（饿啦 / 快看画布）：俏皮双音木琴上扬 A5 -> C6 -> E6
    func playNudgePing() {
        playCached(key: "nudge_ping", volume: 0.68) {
            Self.makeArpeggioBuffer(
                frequencies: [783.99, 987.77, 1318.51],
                stepSeconds: 0.072,
                noteDuration: 0.24,
                shimmerHarmonic: false,
                format: self.audioFormat
            )
        }
    }

    /// 收到或点按回戳 / 赞成：温柔心形气泡双跳音
    func playNudgeHeartReply() {
        playCached(key: "nudge_heart_reply", volume: 0.64) {
            Self.makeTwoToneMarimba(f1: 880.00, f2: 1174.66, duration: 0.20, format: self.audioFormat)
        }
    }

    // MARK: - 音频会话与复音引擎管理

    private func registerLifecycleObservers() {
        let nc = NotificationCenter.default
        observers.append(
            nc.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
                let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                let isEnded = typeValue.flatMap(AVAudioSession.InterruptionType.init) == .ended
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if isEnded {
                        try? AVAudioSession.sharedInstance().setActive(true)
                        if self.isEnabled && self.isEngineConfigured && !self.engine.isRunning {
                            try? self.engine.start()
                        }
                    } else {
                        self.engine.pause()
                    }
                }
            }
        )
        observers.append(
            nc.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.engine.pause()
                }
            }
        )
        observers.append(
            nc.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.isEnabled, self.isEngineConfigured else { return }
                    try? AVAudioSession.sharedInstance().setActive(true)
                    if !self.engine.isRunning {
                        try? self.engine.start()
                    }
                }
            }
        )
    }

    @discardableResult
    private func ensureEngineReady() -> Bool {
        guard isEnabled else { return false }
        if isEngineConfigured && engine.isRunning {
            return true
        }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [])
        try? session.setActive(true)

        let outputFormat = engine.outputNode.outputFormat(forBus: 0)
        guard outputFormat.sampleRate > 0 else { return false }

        if !isEngineConfigured {
            playerPool = (0..<Self.poolSize).map { _ in AVAudioPlayerNode() }
            for node in playerPool {
                engine.attach(node)
                engine.connect(node, to: engine.mainMixerNode, format: audioFormat)
            }
            engine.mainMixerNode.outputVolume = 0.85
            isEngineConfigured = true
        }

        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                return false
            }
        }
        return true
    }

    private func stopAllNodes() {
        for node in playerPool where node.isPlaying {
            node.stop()
        }
    }

    private func playCached(key: String, volume: Float, builder: () -> AVAudioPCMBuffer?) {
        guard isEnabled, ensureEngineReady(), !playerPool.isEmpty else { return }
        let buffer: AVAudioPCMBuffer?
        if let hit = buffers[key] {
            buffer = hit
        } else {
            let built = builder()
            if let built {
                buffers[key] = built
            }
            buffer = built
        }
        guard let buffer else { return }
        let node = playerPool[nextPoolIndex % playerPool.count]
        nextPoolIndex &+= 1
        if node.isPlaying {
            node.stop()
        }
        node.volume = min(max(volume, 0), 1)
        node.scheduleBuffer(buffer, at: nil, options: [])
        node.play()
    }

    // MARK: - 内存 PCM 波形合成器（全部含平滑包络防爆音）

    private static func makeBuffer(duration: Double, format: AVAudioFormat, fill: (UnsafeMutablePointer<Float>, Int, Double) -> Void) -> AVAudioPCMBuffer? {
        let count = max(1, Int((duration * sampleRate).rounded()))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)) else {
            return nil
        }
        buffer.frameLength = AVAudioFrameCount(count)
        guard let ptr = buffer.floatChannelData?[0] else { return nil }
        for i in 0..<count {
            ptr[i] = 0
        }
        fill(ptr, count, sampleRate)
        // 3ms 首尾防咔哒淡入淡出 + 软限幅
        let fadeSamples = min(count / 3, Int(0.004 * sampleRate))
        if fadeSamples > 1 {
            for i in 0..<fadeSamples {
                let gain = Float(i) / Float(fadeSamples)
                ptr[i] *= gain
                ptr[count - 1 - i] *= gain
            }
        }
        for i in 0..<count {
            ptr[i] = tanh(ptr[i] * 0.92)
        }
        return buffer
    }

    /// 统一的脱手抛飞破空气流合成（0 ..< flightSeconds），模拟卡片/贴纸在空中划出弧线的呼声
    private static func sampleTossFlightAir(
        index: Int,
        t: Double,
        sr: Double,
        flightSeconds: Double,
        baseCutoff: Double,
        sweepCutoff: Double,
        spinTone: Double,
        airState: inout Double,
        seed: Double
    ) -> Double {
        guard t < flightSeconds else { return 0 }
        let u = min(max(t / flightSeconds, 0), 1)
        let raw = sin(Double(index) * 37.719 + seed) * 43758.5453
        let white = (raw - floor(raw)) * 2.0 - 1.0
        let cutoff = baseCutoff + sweepCutoff * sin(.pi * pow(u, 0.82))
        let alpha = min(max((2 * .pi * cutoff) / (2 * .pi * cutoff + sr), 0.015), 0.85)
        airState += alpha * (white - airState)
        let env = pow(sin(.pi * u), 1.15)
        let whistleFreq = spinTone * (0.82 + 0.36 * sin(.pi * u))
        let whistle = sin(2 * .pi * whistleFreq * t) * 0.055 * env
        return airState * env * 0.20 + whistle
    }

    private static func makeDishTossBuffer(baseFreq: Double, variant: Int, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let landAt = 0.20
        return makeBuffer(duration: 0.56, format: format) { ptr, count, sr in
            var airLP = 0.0
            let chord: [(delay: Double, freq: Double, amp: Double, decay: Double)] = [
                (0.00, baseFreq, 0.34, 11.5),
                (0.030, baseFreq * 1.25, 0.26, 11.0),
                (0.064, baseFreq * 1.50, 0.28, 9.6),
                (0.064, baseFreq * (variant == 4 ? 2.25 : 2.00), 0.13, 16.0)
            ]
            for i in 0..<count {
                let t = Double(i) / sr
                var sample = sampleTossFlightAir(
                    index: i, t: t, sr: sr, flightSeconds: landAt,
                    baseCutoff: 420 + Double(variant) * 90,
                    sweepCutoff: 1150, spinTone: 320 + Double(variant) * 35,
                    airState: &airLP, seed: Double(variant) * 3.1
                )
                if t >= landAt {
                    let lt = t - landAt
                    switch variant {
                    case 0: // 温润瓷盘落木桌
                        if lt < 0.045 {
                            let pitch = 340.0 - lt * 2600.0
                            sample += sin(2 * .pi * max(95, pitch) * lt) * exp(-lt * 115.0) * 0.34
                        }
                    case 1: // 清脆白瓷碗轻碰叮声
                        sample += (sin(2 * .pi * 1940.0 * lt) + 0.45 * sin(2 * .pi * 2910.0 * lt)) * exp(-lt * 52.0) * 0.24
                        sample += sin(2 * .pi * 210.0 * lt) * exp(-lt * 95.0) * 0.22
                    case 2: // 竹蒸笼 / 木托盘柔厚落音
                        sample += sin(2 * .pi * (168.0 - 70.0 * min(lt / 0.04, 1))) * exp(-lt * 64.0) * 0.38
                        sample += sin(2 * .pi * 760.0 * lt) * exp(-lt * 88.0) * 0.18
                    case 3: // 粗陶餐盘双触归位（盘沿轻触 + 盘底落稳）
                        sample += sin(2 * .pi * 1180.0 * lt) * exp(-lt * 95.0) * 0.22
                        if lt >= 0.032 {
                            let b = lt - 0.032
                            sample += sin(2 * .pi * 240.0 * b) * exp(-b * 78.0) * 0.30
                            sample += sin(2 * .pi * 1480.0 * b) * exp(-b * 70.0) * 0.16
                        }
                    default: // 欢快端盘上桌清铃
                        sample += sin(2 * .pi * 260.0 * lt) * exp(-lt * 85.0) * 0.26
                        sample += sin(2 * .pi * 2349.32 * lt) * exp(-lt * 34.0) * 0.16
                    }
                    for tone in chord where lt >= tone.delay {
                        let dt = lt - tone.delay
                        let env = min(1.0, dt / 0.005) * exp(-dt * tone.decay)
                        sample += (sin(2 * .pi * tone.freq * dt) + 0.20 * sin(4 * .pi * tone.freq * dt)) * env * tone.amp
                    }
                }
                ptr[i] = Float(sample)
            }
        }
    }

    private static func makeEmojiTossBuffer(variant: Int, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let landAt = 0.19
        return makeBuffer(duration: 0.48, format: format) { ptr, count, sr in
            var airLP = 0.0
            var phase1 = 0.0
            var phase2 = 0.0
            for i in 0..<count {
                let t = Double(i) / sr
                var sample = sampleTossFlightAir(
                    index: i, t: t, sr: sr, flightSeconds: landAt,
                    baseCutoff: 580 + Double(variant) * 110,
                    sweepCutoff: 1550, spinTone: 480 + Double(variant) * 55,
                    airState: &airLP, seed: 11.7 + Double(variant) * 2.3
                )
                if t >= landAt {
                    let lt = t - landAt
                    switch variant {
                    case 0: // Q弹果冻啵 + C6 晶铃
                        let p = min(lt / 0.095, 1.0)
                        let f = 290.0 + 470.0 * pow(p, 0.68)
                        phase1 += 2 * .pi * f / sr
                        sample += sin(phase1) * min(1.0, lt / 0.004) * exp(-lt * 25.0) * 0.46
                        if lt >= 0.032 {
                            let dt = lt - 0.032
                            sample += (sin(2 * .pi * 1046.50 * dt) + 0.26 * sin(2 * .pi * 2093.0 * dt)) * exp(-dt * 20.0) * 0.30
                        }
                    case 1: // 清脆双连气泡啵啵 + D6
                        let f1 = 350.0 + 340.0 * min(lt / 0.055, 1.0)
                        phase1 += 2 * .pi * f1 / sr
                        sample += sin(phase1) * exp(-lt * 38.0) * 0.38
                        if lt >= 0.042 {
                            let dt = lt - 0.042
                            let f2 = 520.0 + 440.0 * min(dt / 0.055, 1.0)
                            phase2 += 2 * .pi * f2 / sr
                            sample += sin(phase2) * exp(-dt * 30.0) * 0.42
                            sample += sin(2 * .pi * 1174.66 * dt) * exp(-dt * 22.0) * 0.24
                        }
                    case 2: // 软萌软垫噗通回弹 + E6
                        let bounce = 205.0 + 150.0 * sin(.pi * min(lt / 0.085, 1.0))
                        phase1 += 2 * .pi * bounce / sr
                        sample += sin(phase1) * min(1.0, lt / 0.004) * exp(-lt * 22.0) * 0.48
                        if lt >= 0.028 {
                            let dt = lt - 0.028
                            sample += (sin(2 * .pi * 659.25 * dt) + 0.35 * sin(2 * .pi * 1318.51 * dt)) * exp(-dt * 19.0) * 0.28
                        }
                    case 3: // 玻璃弹珠轻落两跳叮咚
                        sample += (sin(2 * .pi * 1840.0 * lt) + 0.45 * sin(2 * .pi * 2760.0 * lt)) * exp(-lt * 65.0) * 0.34
                        if lt >= 0.046 {
                            let dt = lt - 0.046
                            sample += (sin(2 * .pi * 1567.98 * dt) + 0.35 * sin(2 * .pi * 3135.96 * dt)) * exp(-dt * 28.0) * 0.32
                        }
                    case 4: // 俏皮三连木琴跳音
                        let notes: [(Double, Double)] = [(0.00, 659.25), (0.036, 987.77), (0.072, 1318.51)]
                        for (delay, freq) in notes where lt >= delay {
                            let dt = lt - delay
                            sample += (sin(2 * .pi * freq * dt) + 0.18 * sin(4 * .pi * freq * dt)) * min(1.0, dt / 0.003) * exp(-dt * 26.0) * 0.34
                        }
                    default: // 糖果脆啪 + 闪耀大三和弦
                        sample += sin(2 * .pi * 1420.0 * lt) * exp(-lt * 105.0) * 0.28
                        let triad: [Double] = [880.00, 1108.73, 1318.51]
                        for (k, freq) in triad.enumerated() {
                            let delay = Double(k) * 0.018
                            guard lt >= delay else { continue }
                            let dt = lt - delay
                            sample += sin(2 * .pi * freq * dt) * min(1.0, dt / 0.004) * exp(-dt * 18.0) * 0.22
                        }
                    }
                }
                ptr[i] = Float(sample)
            }
        }
    }

    private static func makeDoodleTossBuffer(variant: Int, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let landAt = 0.19
        return makeBuffer(duration: 0.44, format: format) { ptr, count, sr in
            var airLP = 0.0
            var phase = 0.0
            var grainLP = 0.0
            for i in 0..<count {
                let t = Double(i) / sr
                var sample = sampleTossFlightAir(
                    index: i, t: t, sr: sr, flightSeconds: landAt,
                    baseCutoff: 520 + Double(variant) * 95,
                    sweepCutoff: 1320, spinTone: 360 + Double(variant) * 40,
                    airState: &airLP, seed: 29.4 + Double(variant) * 4.1
                )
                if t >= landAt {
                    let lt = t - landAt
                    let raw = sin(Double(i) * 19.173 + Double(variant)) * 43758.5453
                    let white = (raw - floor(raw)) * 2.0 - 1.0
                    grainLP = grainLP * 0.58 + white * 0.42

                    switch variant {
                    case 0: // 手账木质印章沉稳盖落
                        let f = 165.0 - 92.0 * min(lt / 0.052, 1.0)
                        phase += 2 * .pi * f / sr
                        sample += sin(phase) * min(1.0, lt / 0.003) * exp(-lt * 36.0) * 0.48
                        if lt < 0.045 { sample += grainLP * exp(-lt * 65.0) * 0.22 }
                        if lt >= 0.022 {
                            let dt = lt - 0.022
                            sample += sin(2 * .pi * 910.0 * dt) * exp(-dt * 50.0) * 0.22
                        }
                    case 1: // 和纸胶带轻撕贴合嘶啪
                        if lt < 0.065 {
                            sample += grainLP * sin(.pi * min(lt / 0.065, 1.0)) * 0.34
                        }
                        sample += sin(2 * .pi * 240.0 * lt) * exp(-lt * 58.0) * 0.30
                        if lt >= 0.026 {
                            let dt = lt - 0.026
                            sample += sin(2 * .pi * 698.46 * dt) * exp(-dt * 28.0) * 0.26
                        }
                    case 2: // 厚卡纸甩落桌面清脆啪嗒
                        sample += sin(2 * .pi * 1160.0 * lt) * exp(-lt * 95.0) * 0.32
                        sample += sin(2 * .pi * 195.0 * lt) * exp(-lt * 54.0) * 0.36
                        if lt < 0.035 { sample += grainLP * exp(-lt * 80.0) * 0.24 }
                        if lt >= 0.020 {
                            let dt = lt - 0.020
                            sample += sin(2 * .pi * 1046.50 * dt) * exp(-dt * 34.0) * 0.20
                        }
                    case 3: // 牛皮纸炭笔双叩
                        sample += (sin(2 * .pi * 740.0 * lt) * 0.28 + grainLP * 0.18) * exp(-lt * 68.0)
                        if lt >= 0.038 {
                            let dt = lt - 0.038
                            sample += (sin(2 * .pi * 1108.73 * dt) * 0.30 + sin(2 * .pi * 370.0 * dt) * 0.20) * exp(-dt * 36.0)
                        }
                    default: // 软木板图钉笃声
                        let f = 148.0 - 54.0 * min(lt / 0.04, 1.0)
                        phase += 2 * .pi * f / sr
                        sample += sin(phase) * exp(-lt * 44.0) * 0.42
                        sample += sin(2 * .pi * 1960.0 * lt) * exp(-lt * 85.0) * 0.26
                        if lt >= 0.018 {
                            let dt = lt - 0.018
                            sample += sin(2 * .pi * 1174.66 * dt) * exp(-dt * 28.0) * 0.22
                        }
                    }
                }
                ptr[i] = Float(sample)
            }
        }
    }

    private static func makeCutoutTossBuffer(variant: Int, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let landAt = 0.20
        return makeBuffer(duration: 0.54, format: format) { ptr, count, sr in
            var airLP = 0.0
            var slideLP = 0.0
            for i in 0..<count {
                let t = Double(i) / sr
                var sample = sampleTossFlightAir(
                    index: i, t: t, sr: sr, flightSeconds: landAt,
                    baseCutoff: 640 + Double(variant) * 100,
                    sweepCutoff: 1680, spinTone: 430 + Double(variant) * 48,
                    airState: &airLP, seed: 53.2 + Double(variant) * 3.7
                )
                if t >= landAt {
                    let lt = t - landAt
                    let raw = sin(Double(i) * 31.415 + Double(variant)) * 28491.3
                    let white = (raw - floor(raw)) * 2.0 - 1.0
                    slideLP = slideLP * 0.72 + white * 0.28

                    switch variant {
                    case 0: // 拍立得相纸落桌清脆啪声 + 晶透五度
                        sample += (sin(2 * .pi * 235.0 * lt) * 0.34 + slideLP * 0.24) * exp(-lt * 68.0)
                        sample += sin(2 * .pi * 1320.0 * lt) * exp(-lt * 90.0) * 0.24
                        if lt >= 0.020 {
                            let dt = lt - 0.020
                            sample += (sin(2 * .pi * 1046.50 * dt) * 0.24 + sin(2 * .pi * 1567.98 * dt) * 0.20) * exp(-dt * 16.0)
                        }
                    case 1: // 模切不干胶贴纸柔韧轻拍贴合
                        let pat = 250.0 - 125.0 * min(lt / 0.05, 1.0)
                        sample += sin(2 * .pi * pat * lt) * exp(-lt * 46.0) * 0.38
                        sample += sin(2 * .pi * 1580.0 * lt) * exp(-lt * 95.0) * 0.20
                        let notes: [(Double, Double)] = [(0.015, 587.33), (0.052, 880.00), (0.088, 1174.66)]
                        for (d, f) in notes where lt >= d {
                            let dt = lt - d
                            sample += sin(2 * .pi * f * dt) * exp(-dt * 20.0) * 0.22
                        }
                    case 2: // 铜版纸发牌滑落桌面 + 钢片琴双音
                        if lt < 0.055 {
                            sample += slideLP * sin(.pi * min(lt / 0.055, 1.0)) * 0.32
                        }
                        sample += sin(2 * .pi * 783.99 * lt) * exp(-lt * 22.0) * 0.26
                        if lt >= 0.044 {
                            let dt = lt - 0.044
                            sample += (sin(2 * .pi * 1174.66 * dt) + 0.30 * sin(2 * .pi * 2349.32 * dt)) * exp(-dt * 18.0) * 0.28
                        }
                    case 3: // 水晶亚克力贴片清脆落音
                        sample += (sin(2 * .pi * 2180.0 * lt) * 0.28 + sin(2 * .pi * 1440.0 * lt) * 0.24) * exp(-lt * 72.0)
                        if lt >= 0.016 {
                            let dt = lt - 0.016
                            sample += (sin(2 * .pi * 1318.51 * dt) + 0.25 * sin(2 * .pi * 2637.02 * dt)) * exp(-dt * 15.0) * 0.26
                        }
                    default: // 相册卡扣轻响 + 梦幻上行琶音
                        sample += sin(2 * .pi * 310.0 * lt) * exp(-lt * 75.0) * 0.28
                        let arp: [Double] = [659.25, 830.61, 987.77, 1318.51]
                        for (k, f) in arp.enumerated() {
                            let d = Double(k) * 0.032
                            guard lt >= d else { continue }
                            let dt = lt - d
                            sample += (sin(2 * .pi * f * dt) + 0.18 * sin(4 * .pi * f * dt)) * exp(-dt * 16.0) * 0.20
                        }
                    }
                }
                ptr[i] = Float(sample)
            }
        }
    }

    private static func makeTextTossBuffer(variant: Int, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let landAt = 0.19
        return makeBuffer(duration: 0.48, format: format) { ptr, count, sr in
            var airLP = 0.0
            for i in 0..<count {
                let t = Double(i) / sr
                var sample = sampleTossFlightAir(
                    index: i, t: t, sr: sr, flightSeconds: landAt,
                    baseCutoff: 500 + Double(variant) * 85,
                    sweepCutoff: 1280, spinTone: 400 + Double(variant) * 45,
                    airState: &airLP, seed: 71.9 + Double(variant) * 2.9
                )
                if t >= landAt {
                    let lt = t - landAt
                    switch variant {
                    case 0: // 便签纸轻落木桌 + 打字机清亮叮声
                        sample += sin(2 * .pi * 420.0 * lt) * exp(-lt * 52.0) * 0.28
                        sample += sin(2 * .pi * 1680.0 * lt) * exp(-lt * 95.0) * 0.24
                        if lt >= 0.022 {
                            let dt = lt - 0.022
                            sample += (sin(2 * .pi * 1396.91 * dt) + 0.22 * sin(2 * .pi * 2793.83 * dt)) * exp(-dt * 18.0) * 0.28
                        }
                    case 1: // 信笺落案柔响 + 温暖双音木琴
                        sample += sin(2 * .pi * 260.0 * lt) * exp(-lt * 60.0) * 0.26
                        sample += sin(2 * .pi * 523.25 * lt) * exp(-lt * 24.0) * 0.28
                        if lt >= 0.042 {
                            let dt = lt - 0.042
                            sample += (sin(2 * .pi * 783.99 * dt) + 0.18 * sin(2 * .pi * 1567.98 * dt)) * exp(-dt * 20.0) * 0.30
                        }
                    case 2: // 字卡轻拍桌面 + 双音风铃
                        sample += sin(2 * .pi * 980.0 * lt) * exp(-lt * 88.0) * 0.26
                        sample += (sin(2 * .pi * 1046.50 * lt) * 0.22 + sin(2 * .pi * 1567.98 * max(0, lt - 0.028)) * (lt >= 0.028 ? 0.22 : 0))
                            * exp(-lt * 16.0)
                    case 3: // 活字木块轻叩 + 清透泛音
                        sample += sin(2 * .pi * 392.00 * lt) * exp(-lt * 46.0) * 0.34
                        sample += sin(2 * .pi * 1567.98 * lt) * exp(-lt * 105.0) * 0.24
                        if lt >= 0.018 {
                            let dt = lt - 0.018
                            sample += sin(2 * .pi * 783.99 * dt) * exp(-dt * 22.0) * 0.28
                        }
                    default: // 羊皮纸舒展 + 三弦轻拨
                        let chord: [Double] = [587.33, 739.99, 1174.66]
                        for (k, f) in chord.enumerated() {
                            let d = Double(k) * 0.026
                            guard lt >= d else { continue }
                            let dt = lt - d
                            sample += sin(2 * .pi * f * dt) * min(1.0, dt / 0.004) * exp(-dt * 17.0) * 0.24
                        }
                    }
                }
                ptr[i] = Float(sample)
            }
        }
    }

    private static func makeTextPlaceBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        makeBuffer(duration: 0.125, format: format) { ptr, count, sr in
            for i in 0..<count {
                let t = Double(i) / sr
                let click = sin(2 * .pi * 1650.0 * t) * exp(-t * 110.0) * 0.26
                let wood = sin(2 * .pi * 440.0 * t) * exp(-t * 48.0) * 0.26
                let tailDt = max(0, t - 0.018)
                let tail = t >= 0.018 ? sin(2 * .pi * 880.0 * tailDt) * exp(-tailDt * 24.0) * 0.28 : 0
                ptr[i] = Float(click + wood + tail)
            }
        }
    }

    private static func makeTwoToneMarimba(f1: Double, f2: Double, duration: Double, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        makeBuffer(duration: duration, format: format) { ptr, count, sr in
            let split = min(0.055, duration * 0.42)
            for i in 0..<count {
                let t = Double(i) / sr
                var sample = 0.0
                let e1 = min(1.0, t / 0.004) * exp(-t * 24.0)
                sample += (sin(2 * .pi * f1 * t) + 0.18 * sin(4 * .pi * f1 * t)) * e1 * 0.34
                if t >= split {
                    let dt = t - split
                    let e2 = min(1.0, dt / 0.004) * exp(-dt * 20.0)
                    sample += (sin(2 * .pi * f2 * dt) + 0.18 * sin(4 * .pi * f2 * dt)) * e2 * 0.38
                }
                ptr[i] = Float(sample)
            }
        }
    }

    private static func makeArpeggioBuffer(
        frequencies: [Double],
        stepSeconds: Double,
        noteDuration: Double,
        shimmerHarmonic: Bool,
        format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let total = stepSeconds * Double(max(frequencies.count - 1, 0)) + noteDuration
        return makeBuffer(duration: total, format: format) { ptr, count, sr in
            for i in 0..<count {
                let t = Double(i) / sr
                var sample = 0.0
                for (idx, freq) in frequencies.enumerated() {
                    let start = Double(idx) * stepSeconds
                    guard t >= start else { continue }
                    let dt = t - start
                    let attack = min(1.0, dt / 0.005)
                    let env = attack * exp(-dt * 12.0)
                    var note = sin(2 * .pi * freq * dt) * 0.26
                    if shimmerHarmonic {
                        note += sin(4 * .pi * freq * dt) * exp(-dt * 18.0) * 0.10
                    }
                    sample += note * env
                }
                ptr[i] = Float(sample)
            }
        }
    }

    private static func makeChimeBell(freq: Double, duration: Double, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        makeBuffer(duration: duration, format: format) { ptr, count, sr in
            for i in 0..<count {
                let t = Double(i) / sr
                let attack = min(1.0, t / 0.003)
                let env1 = attack * exp(-t * 17.0)
                let env2 = attack * exp(-t * 28.0)
                let sample = sin(2 * .pi * freq * t) * env1 * 0.34
                    + sin(2 * .pi * (freq * 2.0) * t) * env2 * 0.15
                    + sin(2 * .pi * (freq * 3.01) * t) * env2 * 0.08
                ptr[i] = Float(sample)
            }
        }
    }

    private static func makeMarimbaHit(freq: Double, duration: Double, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        makeBuffer(duration: duration, format: format) { ptr, count, sr in
            for i in 0..<count {
                let t = Double(i) / sr
                let attack = min(1.0, t / 0.004)
                let sample = sin(2 * .pi * freq * t) * attack * exp(-t * 22.0) * 0.38
                    + sin(2 * .pi * (freq * 4.0) * t) * exp(-t * 68.0) * 0.10
                ptr[i] = Float(sample)
            }
        }
    }

    private static func makeHeartBubble(freq: Double, duration: Double, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        makeBuffer(duration: duration, format: format) { ptr, count, sr in
            var phase = 0.0
            for i in 0..<count {
                let t = Double(i) / sr
                let curFreq = freq * (0.76 + 0.42 * min(t / 0.065, 1.0))
                phase += 2 * .pi * curFreq / sr
                let env = min(1.0, t / 0.005) * exp(-t * 25.0)
                ptr[i] = Float(sin(phase) * env * 0.40)
            }
        }
    }

    private static func makeWaterDrop(freq: Double, duration: Double, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        makeBuffer(duration: duration, format: format) { ptr, count, sr in
            var phase = 0.0
            for i in 0..<count {
                let t = Double(i) / sr
                let curFreq = freq * (0.85 + 0.55 * min(t / duration, 1.0))
                phase += 2 * .pi * curFreq / sr
                let env = min(1.0, t / 0.003) * exp(-t * 34.0)
                ptr[i] = Float(sin(phase) * env * 0.38)
            }
        }
    }

    private static func makeNeonHum(freq: Double, duration: Double, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        makeBuffer(duration: duration, format: format) { ptr, count, sr in
            for i in 0..<count {
                let t = Double(i) / sr
                let env = sin(.pi * min(t / duration, 1.0)) * exp(-t * 7.0)
                let shimmer = 1.0 + 0.12 * sin(2 * .pi * 22.0 * t)
                let sample = (sin(2 * .pi * freq * t) * 0.24 + sin(2 * .pi * (freq * 1.5) * t) * 0.14) * env * shimmer
                ptr[i] = Float(sample)
            }
        }
    }

    private static func makeBrushTexture(duration: Double, centerFreq: Double, grit: Double, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        makeBuffer(duration: duration, format: format) { ptr, count, sr in
            var lp = 0.0
            var hp = 0.0
            var prev = 0.0
            let alpha = min(max((2 * .pi * centerFreq) / (2 * .pi * centerFreq + sr), 0.02), 0.9)
            for i in 0..<count {
                let t = Double(i) / sr
                let raw = sin(Double(i) * 78.233 + 1.37) * 43758.5453
                let white = (raw - floor(raw)) * 2.0 - 1.0
                lp += alpha * (white - lp)
                hp = lp - prev * 0.85
                prev = lp
                let env = sin(.pi * min(t / duration, 1.0))
                let grainMod = 1.0 - grit * 0.45 * (0.5 + 0.5 * sin(2 * .pi * 115.0 * t))
                ptr[i] = Float((hp * 0.45 + lp * (1.0 - grit) * 0.20) * env * grainMod)
            }
        }
    }

    private static func makeSoftTick(freq: Double, duration: Double, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        makeBuffer(duration: duration, format: format) { ptr, count, sr in
            for i in 0..<count {
                let t = Double(i) / sr
                let env = min(1.0, t / 0.002) * exp(-t * 95.0)
                ptr[i] = Float(sin(2 * .pi * freq * t) * env * 0.34)
            }
        }
    }

    private static func makeEffectChordBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        makeBuffer(duration: 0.24, format: format) { ptr, count, sr in
            let tones: [(start: Double, f1: Double, f2: Double)] = [
                (0.00, 659.25, 987.77),
                (0.065, 830.61, 1318.51)
            ]
            for i in 0..<count {
                let t = Double(i) / sr
                var sample = 0.0
                for tone in tones where t >= tone.start {
                    let dt = t - tone.start
                    let env = min(1.0, dt / 0.005) * exp(-dt * 15.0)
                    sample += (sin(2 * .pi * tone.f1 * dt) + 0.78 * sin(2 * .pi * tone.f2 * dt)) * env * 0.22
                }
                ptr[i] = Float(sample)
            }
        }
    }

    private static func makeLayoutShuffleBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        makeBuffer(duration: 0.22, format: format) { ptr, count, sr in
            let swishes: [Double] = [0.00, 0.045, 0.09]
            for i in 0..<count {
                let t = Double(i) / sr
                var sample = 0.0
                for (idx, s) in swishes.enumerated() where t >= s && t < s + 0.036 {
                    let dt = t - s
                    let env = sin(.pi * dt / 0.036)
                    let f = 460.0 + Double(idx) * 140.0
                    sample += sin(2 * .pi * f * dt) * env * 0.24
                }
                if t >= 0.12 {
                    let dt = t - 0.12
                    sample += sin(2 * .pi * 783.99 * dt) * min(1.0, dt / 0.004) * exp(-dt * 20.0) * 0.32
                }
                ptr[i] = Float(sample)
            }
        }
    }

    private static func makeWhooshBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        makeBuffer(duration: 0.22, format: format) { ptr, count, sr in
            var lp = 0.0
            for i in 0..<count {
                let t = Double(i) / sr
                let raw = sin(Double(i) * 41.913) * 19283.71
                let white = (raw - floor(raw)) * 2.0 - 1.0
                let cutoff = 500.0 + 1600.0 * sin(.pi * min(t / 0.22, 1.0))
                let alpha = (2 * .pi * cutoff) / (2 * .pi * cutoff + sr)
                lp += alpha * (white - lp)
                let env = sin(.pi * min(t / 0.22, 1.0))
                let air = lp * env * 0.26
                let chime = t >= 0.04 ? sin(2 * .pi * 659.25 * (t - 0.04)) * exp(-(t - 0.04) * 15.0) * 0.16 : 0
                ptr[i] = Float(air + chime)
            }
        }
    }

    private static func makeDeletePoofBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        makeBuffer(duration: 0.14, format: format) { ptr, count, sr in
            var phase = 0.0
            var lp = 0.0
            for i in 0..<count {
                let t = Double(i) / sr
                let freq = 420.0 - 240.0 * min(t / 0.12, 1.0)
                phase += 2 * .pi * freq / sr
                let raw = sin(Double(i) * 23.17) * 43758.5453
                let white = (raw - floor(raw)) * 2.0 - 1.0
                lp = lp * 0.85 + white * 0.15
                let env = min(1.0, t / 0.004) * exp(-t * 24.0)
                ptr[i] = Float((sin(phase) * 0.24 + lp * 0.22) * env)
            }
        }
    }
}
