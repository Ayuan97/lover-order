// AppIcon 生成脚本
// 运行：swift ios/scripts/gen_icon.swift
// 输出：ios/LoverOrder/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
// 风格：日式侘寂 米白底 + 墨绿圆 + 衬线"我"字 + 心形点缀

import AppKit
import CoreGraphics
import Foundation

let size: CGFloat = 1024
let imageSize = NSSize(width: size, height: size)

// 配色
let bgTop = NSColor(srgbRed: 0xF3/255.0, green: 0xEE/255.0, blue: 0xE6/255.0, alpha: 1)
let bgBottom = NSColor(srgbRed: 0xEA/255.0, green: 0xE2/255.0, blue: 0xD2/255.0, alpha: 1)
let brandGreen = NSColor(srgbRed: 0x51/255.0, green: 0x6B/255.0, blue: 0x4A/255.0, alpha: 1)
let darkGreen = NSColor(srgbRed: 0x42/255.0, green: 0x59/255.0, blue: 0x3C/255.0, alpha: 1)
let ink = NSColor(srgbRed: 0x2E/255.0, green: 0x32/255.0, blue: 0x2C/255.0, alpha: 1)

let image = NSImage(size: imageSize)
image.lockFocus()

let ctx = NSGraphicsContext.current!.cgContext
ctx.setShouldAntialias(true)
ctx.interpolationQuality = .high

// 1. 米白渐变背景
let bgGradient = NSGradient(colors: [bgTop, bgBottom])!
bgGradient.draw(in: NSRect(origin: .zero, size: imageSize), angle: -90)

// 2. 装饰：左上角几片浅墨绿叶纹（极淡）
let leafColor = brandGreen.withAlphaComponent(0.07)
leafColor.setFill()
for i in 0..<3 {
    let leaf = NSBezierPath()
    let cx: CGFloat = 120 + CGFloat(i) * 90
    let cy: CGFloat = size - 160 - CGFloat(i) * 40
    leaf.move(to: NSPoint(x: cx, y: cy))
    leaf.curve(to: NSPoint(x: cx + 80, y: cy + 60),
               controlPoint1: NSPoint(x: cx + 20, y: cy + 60),
               controlPoint2: NSPoint(x: cx + 60, y: cy + 80))
    leaf.curve(to: NSPoint(x: cx, y: cy),
               controlPoint1: NSPoint(x: cx + 60, y: cy + 20),
               controlPoint2: NSPoint(x: cx + 30, y: cy))
    leaf.close()
    leaf.fill()
}

// 右下角几片
for i in 0..<2 {
    let leaf = NSBezierPath()
    let cx: CGFloat = size - 240 - CGFloat(i) * 80
    let cy: CGFloat = 120 + CGFloat(i) * 60
    leaf.move(to: NSPoint(x: cx, y: cy))
    leaf.curve(to: NSPoint(x: cx + 100, y: cy + 70),
               controlPoint1: NSPoint(x: cx + 30, y: cy + 80),
               controlPoint2: NSPoint(x: cx + 80, y: cy + 90))
    leaf.curve(to: NSPoint(x: cx, y: cy),
               controlPoint1: NSPoint(x: cx + 70, y: cy + 30),
               controlPoint2: NSPoint(x: cx + 40, y: cy))
    leaf.close()
    leaf.fill()
}

// 3. 中央墨绿圆形主图
let circleSize: CGFloat = 660
let circleRect = NSRect(
    x: (size - circleSize) / 2,
    y: (size - circleSize) / 2 - 20,
    width: circleSize,
    height: circleSize
)

// 圆下方加柔和阴影
ctx.saveGState()
ctx.setShadow(
    offset: CGSize(width: 0, height: -20),
    blur: 40,
    color: brandGreen.withAlphaComponent(0.25).cgColor
)
brandGreen.setFill()
NSBezierPath(ovalIn: circleRect).fill()
ctx.restoreGState()

// 4. 圆内顶部细弧 加点深色提示是个碗的感觉
let innerArc = NSBezierPath()
let arcCenter = NSPoint(x: circleRect.midX, y: circleRect.midY + 40)
innerArc.appendArc(
    withCenter: arcCenter,
    radius: circleSize / 2 - 50,
    startAngle: 200,
    endAngle: 340
)
darkGreen.withAlphaComponent(0.35).setStroke()
innerArc.lineWidth = 3
innerArc.stroke()

// 5. 中央"我们"二字 衬线 白色
let fontSize: CGFloat = 280
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center

let textAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont(name: "Songti SC", size: fontSize)
        ?? NSFont(name: "PingFangSC-Semibold", size: fontSize)
        ?? NSFont.systemFont(ofSize: fontSize, weight: .semibold),
    .foregroundColor: NSColor.white,
    .paragraphStyle: paragraph,
    .kern: -8,
]

let text = NSAttributedString(string: "我们", attributes: textAttrs)
let textSize = text.size()
let textRect = NSRect(
    x: (size - textSize.width) / 2,
    y: circleRect.midY - textSize.height / 2 + 10,
    width: textSize.width,
    height: textSize.height
)
text.draw(in: textRect)

// 6. 心形点缀 右上角小
let heart = NSBezierPath()
let heartScale: CGFloat = 1.5
let hcx: CGFloat = circleRect.maxX - 80
let hcy: CGFloat = circleRect.maxY - 110
heart.move(to: NSPoint(x: hcx, y: hcy - 20 * heartScale))
heart.curve(to: NSPoint(x: hcx + 30 * heartScale, y: hcy + 10 * heartScale),
            controlPoint1: NSPoint(x: hcx, y: hcy + 10 * heartScale),
            controlPoint2: NSPoint(x: hcx + 30 * heartScale, y: hcy + 30 * heartScale))
heart.curve(to: NSPoint(x: hcx, y: hcy - 30 * heartScale),
            controlPoint1: NSPoint(x: hcx + 30 * heartScale, y: hcy - 10 * heartScale),
            controlPoint2: NSPoint(x: hcx + 15 * heartScale, y: hcy - 20 * heartScale))
heart.curve(to: NSPoint(x: hcx - 30 * heartScale, y: hcy + 10 * heartScale),
            controlPoint1: NSPoint(x: hcx - 15 * heartScale, y: hcy - 20 * heartScale),
            controlPoint2: NSPoint(x: hcx - 30 * heartScale, y: hcy - 10 * heartScale))
heart.curve(to: NSPoint(x: hcx, y: hcy - 20 * heartScale),
            controlPoint1: NSPoint(x: hcx - 30 * heartScale, y: hcy + 30 * heartScale),
            controlPoint2: NSPoint(x: hcx, y: hcy + 10 * heartScale))
heart.close()
NSColor.white.withAlphaComponent(0.95).setFill()
heart.fill()

image.unlockFocus()

// 7. 写出 PNG
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:])
else {
    FileHandle.standardError.write("生成 PNG 数据失败".data(using: .utf8)!)
    exit(1)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "AppIcon-1024.png")

do {
    try png.write(to: outputURL)
    print("已生成：\(outputURL.path)")
} catch {
    FileHandle.standardError.write("写文件失败：\(error)".data(using: .utf8)!)
    exit(1)
}
