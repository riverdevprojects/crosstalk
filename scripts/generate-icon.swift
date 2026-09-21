// Run from the repository root: swift scripts/generate-icon.swift
// Draw the app's existing signal motif using vector paths at each required size.
import AppKit
import Foundation

let directory = URL(fileURLWithPath: "Crosstalk/Assets.xcassets/AppIcon.appiconset")
let specs: [(String, String, Int)] = [
    ("20x20", "2x", 40), ("20x20", "3x", 60),
    ("29x29", "2x", 58), ("29x29", "3x", 87),
    ("40x40", "2x", 80), ("40x40", "3x", 120),
    ("60x60", "2x", 120), ("60x60", "3x", 180),
    ("1024x1024", "1x", 1024)
]
var images: [[String: String]] = []
for (size, scale, pixels) in specs {
    let canvas = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
        bytesPerRow: pixels * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    let context = NSGraphicsContext(cgContext: canvas, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    NSGradient(starting: NSColor(red: 0.42, green: 0.16, blue: 0.86, alpha: 1),
               ending: NSColor(red: 0.90, green: 0.20, blue: 0.66, alpha: 1))!
        .draw(in: NSRect(x: 0, y: 0, width: 1024, height: 1024), angle: -45)
    NSColor(red: 1, green: 0.78, blue: 0.20, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: 440, y: 462, width: 144, height: 144)).fill()
    let mast = NSBezierPath()
    mast.move(to: NSPoint(x: 512, y: 474)); mast.line(to: NSPoint(x: 512, y: 268))
    mast.lineWidth = 58; mast.lineCapStyle = .round; NSColor.white.setStroke(); mast.stroke()
    for radius: CGFloat in [168, 282] {
        for (start, end) in [(CGFloat(-55), CGFloat(55)), (CGFloat(125), CGFloat(235))] {
            let wave = NSBezierPath()
            wave.appendArc(withCenter: NSPoint(x: 512, y: 534), radius: radius, startAngle: start, endAngle: end)
            wave.lineWidth = 48; wave.lineCapStyle = .round; wave.stroke()
        }
    }
    let base = NSBezierPath()
    base.move(to: NSPoint(x: 416, y: 260)); base.line(to: NSPoint(x: 608, y: 260))
    base.lineWidth = 48; base.lineCapStyle = .round; base.stroke()
    NSGraphicsContext.restoreGraphicsState()
    let filename = "Icon-\(size)-\(scale).png"
    let bitmap = NSBitmapImageRep(cgImage: canvas.makeImage()!)
    try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(filename))
    images.append(["idiom": pixels == 1024 ? "ios-marketing" : "iphone", "size": size, "scale": scale, "filename": filename])
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys]).write(to: directory.appendingPathComponent("Contents.json"))
