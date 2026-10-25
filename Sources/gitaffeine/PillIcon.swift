import AppKit

/// Menu bar icon: an upright capsule, outlined on top and filled below a middle line.
/// Template image, so macOS tints it for light and dark menu bars.
enum PillIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            let lineWidth: CGFloat = 1.5
            let body = NSRect(x: 5, y: 1, width: 8, height: 16).insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
            let capsule = NSBezierPath(roundedRect: body, xRadius: body.width / 2, yRadius: body.width / 2)

            NSColor.black.set()
            NSGraphicsContext.saveGraphicsState()
            NSRect(x: 0, y: 0, width: 18, height: 9).clip()
            capsule.fill()
            NSGraphicsContext.restoreGraphicsState()

            capsule.lineWidth = lineWidth
            capsule.stroke()

            let divider = NSBezierPath()
            divider.move(to: NSPoint(x: body.minX, y: 9))
            divider.line(to: NSPoint(x: body.maxX, y: 9))
            divider.lineWidth = lineWidth
            divider.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }()
}
