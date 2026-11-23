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

// Night-to-dawn sky
let sky = [
    NSColor(calibratedRed: 0.035, green: 0.075, blue: 0.135, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.105, green: 0.125, blue: 0.190, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.300, green: 0.205, blue: 0.140, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.520, green: 0.330, blue: 0.190, alpha: 1).cgColor
] as CFArray
let skyGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: sky, locations: [0, 0.42, 0.78, 1])!
ctx.drawLinearGradient(skyGradient, start: CGPoint(x: 120, y: 980), end: CGPoint(x: 900, y: 60), options: [])

// Stars
for (x, y, r, a) in [(320.0, 900.0, 5.0, 0.55), (700.0, 940.0, 4.0, 0.45),
                     (800.0, 820.0, 3.0, 0.4), (245.0, 790.0, 3.5, 0.35),
                     (610.0, 860.0, 2.5, 0.3), (420.0, 830.0, 2.5, 0.25)] {
    ctx.setFillColor(NSColor(calibratedRed: 1.0, green: 0.90, blue: 0.68, alpha: a).cgColor)
    ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
}

// Sun glow
let glowColors = [
    NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.48, alpha: 0.38).cgColor,
    NSColor(calibratedRed: 1.0, green: 0.70, blue: 0.30, alpha: 0.13).cgColor,
    NSColor(calibratedRed: 1.0, green: 0.70, blue: 0.30, alpha: 0.0).cgColor
] as CFArray
let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glowColors, locations: [0, 0.45, 1])!
ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 512, y: 690), startRadius: 50,
                       endCenter: CGPoint(x: 512, y: 690), endRadius: 330, options: [])

// Sun
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 26, color: NSColor(calibratedRed: 1, green: 0.72, blue: 0.30, alpha: 0.55).cgColor)
let sunColors = [
    NSColor(calibratedRed: 1.0, green: 0.96, blue: 0.80, alpha: 1).cgColor,
    NSColor(calibratedRed: 1.0, green: 0.80, blue: 0.42, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.93, green: 0.58, blue: 0.18, alpha: 1).cgColor
] as CFArray
let sun = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: sunColors, locations: [0, 0.55, 1])!
ctx.saveGState()
ctx.addEllipse(in: CGRect(x: 512 - 104, y: 690 - 104, width: 208, height: 208))
ctx.clip()
ctx.drawLinearGradient(sun, start: CGPoint(x: 512, y: 794), end: CGPoint(x: 512, y: 586), options: [])
ctx.restoreGState()
ctx.restoreGState()

// The road: narrow at the horizon, widening toward the viewer
let road = CGMutablePath()
road.move(to: CGPoint(x: 478, y: 616))
road.addCurve(to: CGPoint(x: 258, y: 244),
              control1: CGPoint(x: 452, y: 500),
              control2: CGPoint(x: 344, y: 334))
road.addLine(to: CGPoint(x: 766, y: 244))
road.addCurve(to: CGPoint(x: 546, y: 616),
              control1: CGPoint(x: 680, y: 334),
              control2: CGPoint(x: 572, y: 500))
road.closeSubpath()

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 22,
              color: NSColor(calibratedWhite: 0, alpha: 0.28).cgColor)
let roadColors = [
    NSColor(calibratedRed: 0.980, green: 0.930, blue: 0.820, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.920, green: 0.820, blue: 0.650, alpha: 1).cgColor
] as CFArray
let roadGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: roadColors, locations: [0, 1])!
ctx.addPath(road)
ctx.clip()
ctx.drawLinearGradient(roadGradient, start: CGPoint(x: 512, y: 616), end: CGPoint(x: 512, y: 244), options: [])
ctx.restoreGState()

ctx.setStrokeColor(NSColor(calibratedRed: 0.72, green: 0.56, blue: 0.33, alpha: 0.55).cgColor)
ctx.setLineWidth(4)
ctx.addPath(road)
ctx.strokePath()

// Road dashes
for (y, w) in [(320.0, 32.0), (392.0, 25.0), (462.0, 19.0), (530.0, 14.0)] {
    ctx.setFillColor(NSColor(calibratedRed: 0.78, green: 0.60, blue: 0.34, alpha: 0.50).cgColor)
    ctx.fill(CGRect(x: 512 - w / 2, y: y, width: w, height: 4.2))
}

// Two travelers
func traveler(footX: CGFloat, footY: CGFloat, height: CGFloat, staff: Bool) {
    let color = NSColor(calibratedRed: 0.090, green: 0.070, blue: 0.050, alpha: 1)
    ctx.setFillColor(color.cgColor)
    let headR = height * 0.105
    let headY = footY + height * 0.84
    ctx.fillEllipse(in: CGRect(x: footX - headR, y: headY - headR, width: headR * 2, height: headR * 2))
    let robe = CGMutablePath()
    robe.move(to: CGPoint(x: footX - height * 0.10, y: headY - headR * 1.6))
    robe.addLine(to: CGPoint(x: footX + height * 0.10, y: headY - headR * 1.6))
    robe.addCurve(to: CGPoint(x: footX + height * 0.24, y: footY),
                  control1: CGPoint(x: footX + height * 0.18, y: footY + height * 0.38),
                  control2: CGPoint(x: footX + height * 0.22, y: footY + height * 0.14))
    robe.addLine(to: CGPoint(x: footX - height * 0.24, y: footY))
    robe.addCurve(to: CGPoint(x: footX - height * 0.10, y: headY - headR * 1.6),
                  control1: CGPoint(x: footX - height * 0.22, y: footY + height * 0.14),
                  control2: CGPoint(x: footX - height * 0.18, y: footY + height * 0.38))
    robe.closeSubpath()
    ctx.addPath(robe)
    ctx.fillPath()
    if staff {
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(max(4, height * 0.045))
        ctx.setLineCap(.round)
        ctx.move(to: CGPoint(x: footX + height * 0.26, y: footY - 4))
        ctx.addLine(to: CGPoint(x: footX + height * 0.19, y: footY + height * 0.92))
        ctx.strokePath()
    }
}

traveler(footX: 432, footY: 292, height: 104, staff: true)
traveler(footX: 588, footY: 352, height: 84, staff: false)

// Open Scripture at the foundation
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 28,
              color: NSColor(calibratedWhite: 0, alpha: 0.34).cgColor)
let page = NSColor(calibratedRed: 0.984, green: 0.942, blue: 0.840, alpha: 1)
ctx.setFillColor(page.cgColor)
let leftPage = CGMutablePath()
leftPage.move(to: CGPoint(x: 214, y: 222))
leftPage.addCurve(to: CGPoint(x: 504, y: 278), control1: CGPoint(x: 320, y: 256), control2: CGPoint(x: 424, y: 278))
leftPage.addLine(to: CGPoint(x: 504, y: 98))
leftPage.addCurve(to: CGPoint(x: 214, y: 74), control1: CGPoint(x: 410, y: 126), control2: CGPoint(x: 300, y: 82))
leftPage.closeSubpath()
ctx.addPath(leftPage); ctx.fillPath()
let rightPage = CGMutablePath()
rightPage.move(to: CGPoint(x: 520, y: 278))
rightPage.addCurve(to: CGPoint(x: 810, y: 222), control1: CGPoint(x: 600, y: 278), control2: CGPoint(x: 704, y: 256))
rightPage.addLine(to: CGPoint(x: 810, y: 74))
rightPage.addCurve(to: CGPoint(x: 520, y: 98), control1: CGPoint(x: 724, y: 82), control2: CGPoint(x: 614, y: 126))
rightPage.closeSubpath()
ctx.addPath(rightPage); ctx.fillPath()
ctx.restoreGState()

ctx.setFillColor(NSColor(calibratedRed: 0.760, green: 0.590, blue: 0.330, alpha: 1).cgColor)
ctx.fill(CGRect(x: 504, y: 94, width: 16, height: 188))
ctx.setFillColor(NSColor(calibratedRed: 0.640, green: 0.470, blue: 0.240, alpha: 0.55).cgColor)
ctx.fill(CGRect(x: 214, y: 66, width: 596, height: 8))

ctx.setStrokeColor(NSColor(calibratedRed: 0.44, green: 0.32, blue: 0.18, alpha: 0.22).cgColor)
ctx.setLineWidth(4)
for i in 0..<4 {
    let y = 196 - CGFloat(i) * 24
    ctx.move(to: CGPoint(x: 266, y: y)); ctx.addLine(to: CGPoint(x: 452, y: y + 8)); ctx.strokePath()
    ctx.move(to: CGPoint(x: 572, y: y + 8)); ctx.addLine(to: CGPoint(x: 758, y: y)); ctx.strokePath()
}

// Inner border
ctx.setStrokeColor(NSColor(calibratedRed: 1.0, green: 0.88, blue: 0.62, alpha: 0.18).cgColor)
ctx.setLineWidth(3)
ctx.addPath(CGPath(roundedRect: tile.insetBy(dx: 8, dy: 8), cornerWidth: 210, cornerHeight: 210, transform: nil))
ctx.strokePath()

ctx.restoreGState()
image.unlockFocus()

let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
let png = rep.representation(using: .png, properties: [:])!
try png.write(to: URL(fileURLWithPath: "Resources/AppIcon-1024.png"))
print("wrote Emmaus icon")
