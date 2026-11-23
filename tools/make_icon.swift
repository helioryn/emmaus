import AppKit

let S: CGFloat = 1024
let image = NSImage(size: NSSize(width: S, height: S))
image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { exit(1) }
ctx.clear(CGRect(x: 0, y: 0, width: S, height: S))

let tile = CGRect(x: 44, y: 44, width: S - 88, height: S - 88)
ctx.saveGState()
ctx.addPath(CGPath(roundedRect: tile, cornerWidth: 218, cornerHeight: 218, transform: nil))
ctx.clip()

let bgColors = [
    NSColor(calibratedRed: 0.62, green: 0.41, blue: 0.21, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.35, green: 0.22, blue: 0.11, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.12, green: 0.07, blue: 0.04, alpha: 1).cgColor
] as CFArray
let bg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: bgColors, locations: [0, 0.55, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 120, y: 980), end: CGPoint(x: 900, y: 60), options: [])

ctx.setStrokeColor(NSColor(calibratedWhite: 1, alpha: 0.10).cgColor)
ctx.setLineWidth(3)
ctx.addPath(CGPath(roundedRect: tile.insetBy(dx: 7, dy: 7), cornerWidth: 210, cornerHeight: 210, transform: nil))
ctx.strokePath()

// Open book
let cx: CGFloat = 512
let bookBottom: CGFloat = 360
let bookTop: CGFloat = 560
let bookHalfWidth: CGFloat = 330

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -24), blur: 44,
              color: NSColor(calibratedWhite: 0, alpha: 0.42).cgColor)
let paper = NSColor(calibratedRed: 0.976, green: 0.925, blue: 0.812, alpha: 1)
ctx.setFillColor(paper.cgColor)

let left = CGMutablePath()
left.move(to: CGPoint(x: cx - bookHalfWidth, y: bookBottom + 30))
left.addCurve(to: CGPoint(x: cx - 12, y: bookTop),
              control1: CGPoint(x: cx - 250, y: bookBottom + 62),
              control2: CGPoint(x: cx - 150, y: bookTop - 6))
left.addLine(to: CGPoint(x: cx - 12, y: bookTop - 214))
left.addCurve(to: CGPoint(x: cx - bookHalfWidth, y: bookBottom - 42),
              control1: CGPoint(x: cx - 170, y: bookTop - 194),
              control2: CGPoint(x: cx - 270, y: bookBottom + 4))
left.closeSubpath()
ctx.addPath(left); ctx.fillPath()

let right = CGMutablePath()
right.move(to: CGPoint(x: cx + 12, y: bookTop))
right.addCurve(to: CGPoint(x: cx + bookHalfWidth, y: bookBottom + 30),
               control1: CGPoint(x: cx + 150, y: bookTop - 6),
               control2: CGPoint(x: cx + 250, y: bookBottom + 62))
right.addLine(to: CGPoint(x: cx + bookHalfWidth, y: bookBottom - 42))
right.addCurve(to: CGPoint(x: cx + 12, y: bookTop - 214),
               control1: CGPoint(x: cx + 270, y: bookBottom + 4),
               control2: CGPoint(x: cx + 170, y: bookTop - 194))
right.closeSubpath()
ctx.addPath(right); ctx.fillPath()
ctx.restoreGState()

// Spine and page block
ctx.setFillColor(NSColor(calibratedRed: 0.85, green: 0.68, blue: 0.38, alpha: 1).cgColor)
ctx.fill(CGRect(x: cx - 12, y: bookTop - 206, width: 24, height: 212))
ctx.setFillColor(NSColor(calibratedRed: 0.70, green: 0.51, blue: 0.26, alpha: 0.55).cgColor)
ctx.fill(CGRect(x: cx - bookHalfWidth, y: bookBottom - 52, width: bookHalfWidth * 2, height: 9))

func pageLine(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) {
    ctx.setStrokeColor(NSColor(calibratedRed: 0.44, green: 0.32, blue: 0.18, alpha: 0.23).cgColor)
    ctx.setLineWidth(5)
    ctx.move(to: CGPoint(x: x1, y: y1))
    ctx.addLine(to: CGPoint(x: x2, y: y2))
    ctx.strokePath()
}
for i in 0..<7 {
    let y = bookTop - 44 - CGFloat(i) * 23
    pageLine(cx - 286, y - 2, cx - 58, y + 8)
    pageLine(cx + 58, y + 8, cx + 286, y - 2)
}
pageLine(cx - 286, bookBottom - 6, cx - 58, bookBottom + 6)
pageLine(cx + 58, bookBottom + 6, cx + 286, bookBottom - 6)

// Flame
ctx.saveGState()
let flame = CGMutablePath()
flame.move(to: CGPoint(x: cx, y: 892))
flame.addCurve(to: CGPoint(x: cx + 82, y: 772),
               control1: CGPoint(x: cx + 42, y: 858),
               control2: CGPoint(x: cx + 80, y: 818))
flame.addCurve(to: CGPoint(x: cx + 24, y: 676),
               control1: CGPoint(x: cx + 83, y: 726),
               control2: CGPoint(x: cx + 50, y: 696))
flame.addCurve(to: CGPoint(x: cx - 8, y: 736),
               control1: CGPoint(x: cx + 5, y: 690),
               control2: CGPoint(x: cx - 4, y: 712))
flame.addCurve(to: CGPoint(x: cx - 52, y: 694),
               control1: CGPoint(x: cx - 34, y: 728),
               control2: CGPoint(x: cx - 48, y: 712))
flame.addCurve(to: CGPoint(x: cx, y: 892),
               control1: CGPoint(x: cx - 92, y: 762),
               control2: CGPoint(x: cx - 54, y: 846))
flame.closeSubpath()
let fgColors = [
    NSColor(calibratedRed: 1.0, green: 0.95, blue: 0.78, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.97, green: 0.73, blue: 0.33, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.84, green: 0.45, blue: 0.13, alpha: 1).cgColor
] as CFArray
let fg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: fgColors, locations: [0, 0.52, 1])!
ctx.addPath(flame); ctx.clip()
ctx.drawLinearGradient(fg, start: CGPoint(x: cx, y: 892), end: CGPoint(x: cx, y: 676), options: [])
ctx.restoreGState()

// Flame shadow/foundation removed intentionally — no floating artifact.

ctx.restoreGState()
image.unlockFocus()

let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
let png = rep.representation(using: .png, properties: [:])!
try png.write(to: URL(fileURLWithPath: "Resources/AppIcon-1024.png"))
print("wrote icon")
