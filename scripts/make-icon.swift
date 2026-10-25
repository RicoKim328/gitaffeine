// Draws the app icon (the menu bar pill in white on a coffee-brown rounded square) into an .iconset folder.
// Usage: swift scripts/make-icon.swift build/AppIcon.iconset && iconutil -c icns build/AppIcon.iconset
import AppKit

let folder = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

/// Drawn on a 1024 canvas; the square leaves Apple's usual 100pt margin for the icon shadow.
func draw() {
    NSColor(red: 0.29, green: 0.18, blue: 0.12, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185).fill()

    // PillIcon's 18pt shapes scaled up: an 8×16 capsule, outlined on top, filled below the middle line.
    let scale: CGFloat = 32, lineWidth = 1.5 * scale
    let body = NSRect(x: 512 - 4 * scale, y: 512 - 8 * scale, width: 8 * scale, height: 16 * scale)
        .insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
    let capsule = NSBezierPath(roundedRect: body, xRadius: body.width / 2, yRadius: body.width / 2)
    NSColor.white.set()
    NSGraphicsContext.saveGraphicsState()
    NSRect(x: 0, y: 0, width: 1024, height: 512).clip()
    capsule.fill()
    NSGraphicsContext.restoreGraphicsState()
    capsule.lineWidth = lineWidth
    capsule.stroke()
    let divider = NSBezierPath()
    divider.move(to: NSPoint(x: body.minX, y: 512))
    divider.line(to: NSPoint(x: body.maxX, y: 512))
    divider.lineWidth = lineWidth
    divider.stroke()
}

for points in [16, 32, 128, 256, 512] {
    for factor in [1, 2] {
        let pixels = points * factor
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current!.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        draw()
        NSGraphicsContext.restoreGraphicsState()
        let name = factor == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        try rep.representation(using: .png, properties: [:])!.write(to: folder.appending(path: name))
    }
}
