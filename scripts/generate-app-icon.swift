#!/usr/bin/env swift
import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("Resources", isDirectory: true)
let iconset = resources.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let pngURL = resources.appendingPathComponent("AppIcon.png")
let icnsURL = resources.appendingPathComponent("AppIcon.icns")

try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    rect.fill()

    let scale = size / 1024
    let bgRect = NSRect(x: 116 * scale, y: 116 * scale, width: 792 * scale, height: 792 * scale)
    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 188 * scale, yRadius: 188 * scale)
    let gradient = NSGradient(colors: [
        NSColor(red: 0.13, green: 0.39, blue: 0.92, alpha: 1),
        NSColor(red: 0.05, green: 0.47, blue: 0.43, alpha: 1),
        NSColor(red: 0.07, green: 0.10, blue: 0.17, alpha: 1)
    ])!
    gradient.draw(in: bgPath, angle: -38)

    NSColor.white.withAlphaComponent(0.10).setStroke()
    bgPath.lineWidth = 4 * scale
    bgPath.stroke()

    NSGraphicsContext.saveGraphicsState()
    let foregroundScale: CGFloat = 0.88
    let foregroundTransform = NSAffineTransform()
    foregroundTransform.translateX(by: size / 2, yBy: size / 2)
    foregroundTransform.scale(by: foregroundScale)
    foregroundTransform.translateX(by: -size / 2, yBy: -size / 2)
    foregroundTransform.concat()

    func roundedRect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, radius: CGFloat, color: NSColor) {
        let path = NSBezierPath(
            roundedRect: NSRect(x: x * scale, y: y * scale, width: width * scale, height: height * scale),
            xRadius: radius * scale,
            yRadius: radius * scale
        )
        color.setFill()
        path.fill()
    }

    func capsule(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, color: NSColor) {
        roundedRect(x, y, width, height, radius: height / 2, color: color)
    }

    func label(_ text: String, x: CGFloat, y: CGFloat, size fontSize: CGFloat, color: NSColor) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize * scale, weight: .bold),
            .foregroundColor: color
        ]
        NSAttributedString(string: text, attributes: attributes)
            .draw(at: NSPoint(x: x * scale, y: y * scale))
    }

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
    shadow.shadowOffset = NSSize(width: 0, height: -16 * scale)
    shadow.shadowBlurRadius = 26 * scale
    shadow.set()

    roundedRect(190, 330, 270, 300, radius: 64, color: NSColor(red: 0.02, green: 0.17, blue: 0.28, alpha: 0.62))
    roundedRect(554, 264, 286, 432, radius: 56, color: NSColor(red: 0.94, green: 0.97, blue: 1, alpha: 1))
    NSShadow().set()

    label("WAV", x: 248, y: 356, size: 46, color: NSColor(red: 0.67, green: 0.96, blue: 0.83, alpha: 1))
    label("TXT", x: 614, y: 604, size: 52, color: NSColor(red: 0.09, green: 0.30, blue: 0.82, alpha: 1))

    let fold = NSBezierPath()
    fold.move(to: NSPoint(x: 750 * scale, y: 696 * scale))
    fold.line(to: NSPoint(x: 840 * scale, y: 606 * scale))
    fold.line(to: NSPoint(x: 768 * scale, y: 606 * scale))
    fold.curve(to: NSPoint(x: 750 * scale, y: 624 * scale),
               controlPoint1: NSPoint(x: 758 * scale, y: 606 * scale),
               controlPoint2: NSPoint(x: 750 * scale, y: 614 * scale))
    fold.close()
    NSColor(red: 0.70, green: 0.83, blue: 1, alpha: 1).setFill()
    fold.fill()

    let wavePath = NSBezierPath()
    wavePath.move(to: NSPoint(x: 224 * scale, y: 492 * scale))
    wavePath.line(to: NSPoint(x: 254 * scale, y: 492 * scale))
    wavePath.line(to: NSPoint(x: 284 * scale, y: 562 * scale))
    wavePath.line(to: NSPoint(x: 326 * scale, y: 408 * scale))
    wavePath.line(to: NSPoint(x: 366 * scale, y: 558 * scale))
    wavePath.line(to: NSPoint(x: 398 * scale, y: 492 * scale))
    wavePath.line(to: NSPoint(x: 428 * scale, y: 492 * scale))
    NSColor(red: 0.65, green: 0.96, blue: 0.82, alpha: 1).setStroke()
    wavePath.lineWidth = 34 * scale
    wavePath.lineCapStyle = .round
    wavePath.lineJoinStyle = .round
    wavePath.stroke()

    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 466 * scale, y: 488 * scale))
    arrow.line(to: NSPoint(x: 534 * scale, y: 488 * scale))
    NSColor.white.withAlphaComponent(0.92).setStroke()
    arrow.lineWidth = 30 * scale
    arrow.lineCapStyle = .round
    arrow.stroke()

    let arrowHead = NSBezierPath()
    arrowHead.move(to: NSPoint(x: 528 * scale, y: 534 * scale))
    arrowHead.line(to: NSPoint(x: 594 * scale, y: 488 * scale))
    arrowHead.line(to: NSPoint(x: 528 * scale, y: 442 * scale))
    arrowHead.close()
    NSColor.white.withAlphaComponent(0.92).setFill()
    arrowHead.fill()

    capsule(612, 528, 172, 26, color: NSColor(red: 0.05, green: 0.47, blue: 0.43, alpha: 1))
    capsule(612, 468, 196, 24, color: NSColor(red: 0.05, green: 0.47, blue: 0.43, alpha: 0.82))
    capsule(612, 410, 150, 24, color: NSColor(red: 0.05, green: 0.47, blue: 0.43, alpha: 0.68))
    capsule(612, 352, 186, 24, color: NSColor(red: 0.10, green: 0.31, blue: 0.82, alpha: 0.72))

    NSGraphicsContext.restoreGraphicsState()
    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL, pixels: Int) throws {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "IconGeneration", code: 1)
    }

    bitmap.size = NSSize(width: pixels, height: pixels)
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "IconGeneration", code: 2)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    image.draw(
        in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
        from: NSRect(x: 0, y: 0, width: image.size.width, height: image.size.height),
        operation: .sourceOver,
        fraction: 1
    )
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGeneration", code: 3)
    }
    try data.write(to: url)
}

let baseImage = drawIcon(size: 1024)
try writePNG(baseImage, to: pngURL, pixels: 1024)

let iconFiles: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, size) in iconFiles {
    try writePNG(drawIcon(size: size), to: iconset.appendingPathComponent(name), pixels: Int(size))
}

try? FileManager.default.removeItem(at: icnsURL)
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", icnsURL.path]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else {
    throw NSError(domain: "IconGeneration", code: Int(process.terminationStatus))
}
try? FileManager.default.removeItem(at: iconset)

print("Generated \(pngURL.path)")
print("Generated \(icnsURL.path)")
