#!/usr/bin/env swift
//
// Generates a launcher icon as a .icns file.
//
// The artwork is entirely original: a rounded-square gradient plate with a
// monogram. Nothing from the Codex or OpenAI icon set is copied or
// redistributed. Its only job is to make the profile launcher easy to tell
// apart in the Dock, Finder and Spotlight.
//
// Usage:
//   swift scripts/make-icon.swift --label CP --top '#7C5CFF' --bottom '#2A1B6B' \
//       --output build/AppIcon.icns
//
// CoreGraphics and CoreText are used directly rather than AppKit so this runs
// on a headless CI machine with no window server.

import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Arguments

func argument(_ name: String, default defaultValue: String) -> String {
    let arguments = CommandLine.arguments
    guard let index = arguments.firstIndex(of: "--" + name), index + 1 < arguments.count else {
        return defaultValue
    }
    return arguments[index + 1]
}

let label = argument("label", default: "CP")
let topColorHex = argument("top", default: "#7C5CFF")
let bottomColorHex = argument("bottom", default: "#2A1B6B")
let outputPath = argument("output", default: "AppIcon.icns")

func parseHexColor(_ hex: String) -> (CGFloat, CGFloat, CGFloat) {
    var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    if value.hasPrefix("#") { value.removeFirst() }
    guard value.count == 6, let number = UInt32(value, radix: 16) else {
        FileHandle.standardError.write(Data("Invalid colour \"\(hex)\"; expected #RRGGBB\n".utf8))
        exit(1)
    }
    return (
        CGFloat((number >> 16) & 0xFF) / 255.0,
        CGFloat((number >> 8) & 0xFF) / 255.0,
        CGFloat(number & 0xFF) / 255.0
    )
}

let topColor = parseHexColor(topColorHex)
let bottomColor = parseHexColor(bottomColorHex)

// MARK: - Drawing

/// Approximates the macOS app-icon grid: the plate is inset inside the canvas
/// and uses a continuous-looking corner radius.
func drawIcon(size: CGFloat) -> CGImage? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: Int(size),
        height: Int(size),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    context.setAllowsAntialiasing(true)
    context.interpolationQuality = .high

    let inset = size * 0.085
    let plate = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let radius = plate.width * 0.225
    let platePath = CGPath(roundedRect: plate, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // Gradient plate.
    context.saveGState()
    context.addPath(platePath)
    context.clip()
    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            CGColor(red: topColor.0, green: topColor.1, blue: topColor.2, alpha: 1),
            CGColor(red: bottomColor.0, green: bottomColor.1, blue: bottomColor.2, alpha: 1),
        ] as CFArray,
        locations: [0, 1]
    )
    if let gradient {
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: plate.midX, y: plate.maxY),
            end: CGPoint(x: plate.midX, y: plate.minY),
            options: []
        )
    }
    context.restoreGState()

    // Hairline highlight so the plate reads as a surface rather than a flat block.
    context.saveGState()
    context.addPath(
        CGPath(
            roundedRect: plate.insetBy(dx: size * 0.012, dy: size * 0.012),
            cornerWidth: radius * 0.94,
            cornerHeight: radius * 0.94,
            transform: nil
        )
    )
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.18))
    context.setLineWidth(max(size * 0.006, 0.5))
    context.strokePath()
    context.restoreGState()

    // Monogram.
    let fontSize = plate.width * (label.count > 2 ? 0.34 : 0.42)
    let font = CTFontCreateWithName("Helvetica-Bold" as CFString, fontSize, nil)
    let attributes: [CFString: Any] = [
        kCTFontAttributeName: font,
        kCTForegroundColorAttributeName: CGColor(red: 1, green: 1, blue: 1, alpha: 0.97),
        kCTKernAttributeName: fontSize * 0.02,
    ]
    let attributed = CFAttributedStringCreate(
        nil,
        label as CFString,
        attributes as CFDictionary
    )
    if let attributed {
        let line = CTLineCreateWithAttributedString(attributed)
        let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        context.textPosition = CGPoint(
            x: plate.midX - bounds.width / 2 - bounds.origin.x,
            y: plate.midY - bounds.height / 2 - bounds.origin.y
        )
        CTLineDraw(line, context)
    }

    return context.makeImage()
}

func writePNG(_ image: CGImage, to url: URL) -> Bool {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else { return false }
    CGImageDestinationAddImage(destination, image, nil)
    return CGImageDestinationFinalize(destination)
}

// MARK: - Iconset assembly

let fileManager = FileManager.default
let outputURL = URL(fileURLWithPath: outputPath)
try? fileManager.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

let iconsetURL = outputURL
    .deletingLastPathComponent()
    .appendingPathComponent(outputURL.deletingPathExtension().lastPathComponent + ".iconset")
try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let variants: [(name: String, pixels: CGFloat)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]

for variant in variants {
    guard let image = drawIcon(size: variant.pixels),
          writePNG(image, to: iconsetURL.appendingPathComponent(variant.name))
    else {
        FileHandle.standardError.write(Data("Failed to render \(variant.name)\n".utf8))
        exit(1)
    }
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["--convert", "icns", iconsetURL.path, "--output", outputURL.path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
    FileHandle.standardError.write(Data("iconutil failed\n".utf8))
    exit(iconutil.terminationStatus)
}

try? fileManager.removeItem(at: iconsetURL)
print("Wrote \(outputURL.path)")
