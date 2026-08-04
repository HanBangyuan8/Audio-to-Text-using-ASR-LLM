#!/usr/bin/env swift
import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("Resources", isDirectory: true)
let iconset = resources.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let output = resources.appendingPathComponent("AppIcon.icns")
let readmePreview = resources.appendingPathComponent("AppIcon.png")
let fileManager = FileManager.default

try fileManager.createDirectory(at: resources, withIntermediateDirectories: true)
try? fileManager.removeItem(at: iconset)
try fileManager.createDirectory(at: iconset, withIntermediateDirectories: true)

let variants: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

func writeIcon(size: Int, name: String) throws {
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "AppIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to allocate bitmap \(name)"])
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current?.cgContext.clear(CGRect(x: 0, y: 0, width: size, height: size))

    let iconMargin = CGFloat(size) * (96.0 / 1024.0)
    let corner = CGFloat(size) * 0.19
    let bodyRect = rect.insetBy(dx: iconMargin, dy: iconMargin)
    let body = NSBezierPath(roundedRect: bodyRect, xRadius: corner, yRadius: corner)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.38, green: 0.43, blue: 0.96, alpha: 1),
        NSColor(calibratedRed: 0.09, green: 0.55, blue: 0.62, alpha: 1),
        NSColor(calibratedRed: 0.07, green: 0.11, blue: 0.19, alpha: 1)
    ])?.draw(in: body, angle: 144)

    NSColor.white.withAlphaComponent(0.20).setStroke()
    body.lineWidth = max(1, CGFloat(size) * 0.012)
    body.stroke()

    let contentRect = bodyRect.insetBy(dx: CGFloat(size) * 0.17, dy: CGFloat(size) * 0.20)
    let unit = CGFloat(size) / 1024.0

    func capsule(_ rect: NSRect, alpha: CGFloat = 1) {
        let path = NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)
        NSColor.white.withAlphaComponent(alpha).setFill()
        path.fill()
    }

    let barWidth = 42 * unit
    let barX = contentRect.minX
    let centerY = contentRect.midY
    capsule(NSRect(x: barX, y: centerY - 80 * unit, width: barWidth, height: 160 * unit), alpha: 0.92)
    capsule(NSRect(x: barX + 68 * unit, y: centerY - 152 * unit, width: barWidth, height: 304 * unit))
    capsule(NSRect(x: barX + 136 * unit, y: centerY - 102 * unit, width: barWidth, height: 204 * unit), alpha: 0.94)
    capsule(NSRect(x: barX + 204 * unit, y: centerY - 126 * unit, width: barWidth, height: 252 * unit), alpha: 0.86)

    let textX = contentRect.minX + contentRect.width * 0.57
    let lineHeight = 46 * unit
    capsule(NSRect(x: textX, y: centerY + 86 * unit, width: contentRect.maxX - textX, height: lineHeight))
    capsule(NSRect(x: textX, y: centerY - 23 * unit, width: contentRect.maxX - textX, height: lineHeight), alpha: 0.88)
    capsule(NSRect(x: textX, y: centerY - 132 * unit, width: (contentRect.maxX - textX) * 0.72, height: lineHeight), alpha: 0.72)
    capsule(NSRect(x: contentRect.minX + contentRect.width * 0.49, y: centerY - 23 * unit, width: 38 * unit, height: lineHeight), alpha: 0.78)

    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "AppIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to render icon \(name)"])
    }
    try png.write(to: iconset.appendingPathComponent(name))
}

for variant in variants {
    try writeIcon(size: variant.0, name: variant.1)
}

try? fileManager.removeItem(at: output)
try? fileManager.removeItem(at: readmePreview)
try fileManager.copyItem(at: iconset.appendingPathComponent("icon_512x512@2x.png"), to: readmePreview)

let icnsChunks: [(String, String)] = [
    ("icp4", "icon_16x16.png"),
    ("ic11", "icon_16x16@2x.png"),
    ("icp5", "icon_32x32.png"),
    ("ic12", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic13", "icon_128x128@2x.png"),
    ("ic08", "icon_256x256.png"),
    ("ic14", "icon_256x256@2x.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png")
]

func appendBigEndian(_ value: UInt32, to data: inout Data) {
    var bigEndian = value.bigEndian
    withUnsafeBytes(of: &bigEndian) { data.append(contentsOf: $0) }
}

var chunks = Data()
for (type, fileName) in icnsChunks {
    let png = try Data(contentsOf: iconset.appendingPathComponent(fileName))
    chunks.append(type.data(using: .ascii)!)
    appendBigEndian(UInt32(png.count + 8), to: &chunks)
    chunks.append(png)
}

var icns = Data("icns".utf8)
appendBigEndian(UInt32(chunks.count + 8), to: &icns)
icns.append(chunks)
try icns.write(to: output, options: .atomic)

print(output.path)
