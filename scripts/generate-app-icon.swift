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
    let bgRect = NSRect(x: 64 * scale, y: 64 * scale, width: 896 * scale, height: 896 * scale)
    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 210 * scale, yRadius: 210 * scale)
    let gradient = NSGradient(colors: [
        NSColor(red: 0.13, green: 0.39, blue: 0.92, alpha: 1),
        NSColor(red: 0.05, green: 0.47, blue: 0.43, alpha: 1),
        NSColor(red: 0.07, green: 0.10, blue: 0.17, alpha: 1)
    ])!
    gradient.draw(in: bgPath, angle: -38)

    NSColor.white.withAlphaComponent(0.10).setStroke()
    bgPath.lineWidth = 4 * scale
    bgPath.stroke()

    let pageRect = NSRect(x: 360 * scale, y: 204 * scale, width: 360 * scale, height: 560 * scale)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
    shadow.shadowOffset = NSSize(width: 0, height: -18 * scale)
    shadow.shadowBlurRadius = 28 * scale
    shadow.set()

    let page = NSBezierPath(roundedRect: pageRect, xRadius: 56 * scale, yRadius: 56 * scale)
    NSColor(red: 0.94, green: 0.97, blue: 1, alpha: 1).setFill()
    page.fill()
    NSShadow().set()

    let fold = NSBezierPath()
    fold.move(to: NSPoint(x: 624 * scale, y: 764 * scale))
    fold.line(to: NSPoint(x: 720 * scale, y: 668 * scale))
    fold.line(to: NSPoint(x: 642 * scale, y: 668 * scale))
    fold.curve(to: NSPoint(x: 624 * scale, y: 686 * scale),
               controlPoint1: NSPoint(x: 632 * scale, y: 668 * scale),
               controlPoint2: NSPoint(x: 624 * scale, y: 676 * scale))
    fold.close()
    NSColor(red: 0.72, green: 0.84, blue: 1, alpha: 1).setFill()
    fold.fill()

    func line(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ color: NSColor) {
        let path = NSBezierPath(roundedRect: NSRect(x: x * scale, y: y * scale, width: width * scale, height: 32 * scale),
                                xRadius: 16 * scale,
                                yRadius: 16 * scale)
        color.setFill()
        path.fill()
    }
    line(424, 552, 232, NSColor(red: 0.10, green: 0.31, blue: 0.82, alpha: 1))
    line(424, 466, 184, NSColor(red: 0.05, green: 0.47, blue: 0.43, alpha: 1))
    line(424, 386, 224, NSColor(red: 0.05, green: 0.47, blue: 0.43, alpha: 0.82))
    line(424, 306, 148, NSColor(red: 0.05, green: 0.47, blue: 0.43, alpha: 0.68))

    func wave(points: [CGPoint], color: NSColor, width: CGFloat) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: points[0].x * scale, y: points[0].y * scale))
        for point in points.dropFirst() {
            path.line(to: NSPoint(x: point.x * scale, y: point.y * scale))
        }
        color.setStroke()
        path.lineWidth = width * scale
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }

    wave(points: [
        CGPoint(x: 172, y: 472),
        CGPoint(x: 240, y: 600),
        CGPoint(x: 312, y: 364),
        CGPoint(x: 376, y: 488),
        CGPoint(x: 420, y: 434)
    ], color: NSColor(red: 0.65, green: 0.96, blue: 0.82, alpha: 1), width: 54)

    wave(points: [
        CGPoint(x: 154, y: 314),
        CGPoint(x: 224, y: 386),
        CGPoint(x: 302, y: 260),
        CGPoint(x: 370, y: 330),
        CGPoint(x: 424, y: 296)
    ], color: NSColor(red: 0.58, green: 0.77, blue: 1, alpha: 0.95), width: 40)

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
