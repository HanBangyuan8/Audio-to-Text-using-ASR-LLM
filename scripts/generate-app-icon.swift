#!/usr/bin/env swift
import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("Resources", isDirectory: true)
let iconset = FileManager.default.temporaryDirectory
    .appendingPathComponent("AudioToTextASRLLM-AppIcon.iconset", isDirectory: true)
let pngURL = resources.appendingPathComponent("AppIcon.png")
let icnsURL = resources.appendingPathComponent("AppIcon.icns")

try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func drawIcon(size: CGFloat) -> NSImage {
    let scale = size / 1024
    let iconFrame = NSRect(x: 96 * scale, y: 96 * scale, width: 832 * scale, height: 832 * scale)
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    let bgPath = NSBezierPath(roundedRect: iconFrame, xRadius: 198 * scale, yRadius: 198 * scale)
    let gradient = NSGradient(colors: [
        NSColor(red: 0.38, green: 0.43, blue: 0.96, alpha: 1),
        NSColor(red: 0.09, green: 0.55, blue: 0.62, alpha: 1),
        NSColor(red: 0.07, green: 0.11, blue: 0.19, alpha: 1)
    ])!
    gradient.draw(in: bgPath, angle: -36)

    func capsule(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, alpha: CGFloat = 1) {
        let path = NSBezierPath(
            roundedRect: NSRect(x: x * scale, y: y * scale, width: width * scale, height: height * scale),
            xRadius: height * scale / 2,
            yRadius: height * scale / 2
        )
        NSColor.white.withAlphaComponent(alpha).setFill()
        path.fill()
    }

    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: size / 2, yBy: size / 2)
    transform.scale(by: 0.94)
    transform.translateX(by: -size / 2, yBy: -size / 2)
    transform.concat()

    // Audio bars, progressively resolving into text lines.
    capsule(x: 268, y: 432, width: 42, height: 160, alpha: 0.92)
    capsule(x: 336, y: 360, width: 42, height: 304, alpha: 1.00)
    capsule(x: 404, y: 410, width: 42, height: 204, alpha: 0.94)
    capsule(x: 472, y: 386, width: 42, height: 252, alpha: 0.86)

    capsule(x: 570, y: 598, width: 210, height: 46, alpha: 1.00)
    capsule(x: 570, y: 489, width: 270, height: 46, alpha: 0.88)
    capsule(x: 570, y: 380, width: 190, height: 46, alpha: 0.72)

    // A small quiet connector keeps the conversion readable without becoming an arrow.
    capsule(x: 524, y: 489, width: 38, height: 46, alpha: 0.78)

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
