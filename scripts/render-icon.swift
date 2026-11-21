import AppKit

// BiliX icon: white background, pink television/play mark and orbit.
let size = 1024
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
    isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0
), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("Cannot allocate icon bitmap")
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
defer { NSGraphicsContext.restoreGraphicsState() }
let canvas = NSRect(x: 0, y: 0, width: size, height: size)
NSColor.white.setFill()
canvas.fill()

func pink(_ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: 0.99, green: 0.31, blue: 0.51, alpha: a)
}
func roundedStroke(_ rect: NSRect, radius: CGFloat, width: CGFloat) {
    let p = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    p.lineWidth = width
    p.lineCapStyle = .round
    pink().setStroke()
    p.stroke()
}

// Antennas
for (x1, y1, x2, y2) in [(424.0, 727.0, 365.0, 810.0), (601.0, 727.0, 663.0, 810.0)] {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: CGFloat(x1), y: CGFloat(y1)))
    path.line(to: NSPoint(x: CGFloat(x2), y: CGFloat(y2)))
    path.lineWidth = 55
    path.lineCapStyle = .round
    pink().setStroke()
    path.stroke()
}

// Television outline
roundedStroke(NSRect(x: 258, y: 253, width: 508, height: 477), radius: 130, width: 76)

// Play triangle
let play = NSBezierPath()
play.move(to: NSPoint(x: 453, y: 387))
play.line(to: NSPoint(x: 453, y: 572))
play.curve(to: NSPoint(x: 496, y: 589), controlPoint1: NSPoint(x: 453, y: 600), controlPoint2: NSPoint(x: 479, y: 600))
play.line(to: NSPoint(x: 644, y: 499))
play.curve(to: NSPoint(x: 644, y: 459), controlPoint1: NSPoint(x: 669, y: 485), controlPoint2: NSPoint(x: 669, y: 473))
play.line(to: NSPoint(x: 496, y: 370))
play.curve(to: NSPoint(x: 453, y: 387), controlPoint1: NSPoint(x: 479, y: 360), controlPoint2: NSPoint(x: 453, y: 367))
play.close()
pink().setFill()
play.fill()

// Slanted orbit, drawn over the television
let orbit = NSBezierPath()
orbit.move(to: NSPoint(x: 235, y: 360))
orbit.curve(to: NSPoint(x: 780, y: 480), controlPoint1: NSPoint(x: 330, y: 270), controlPoint2: NSPoint(x: 675, y: 400))
orbit.curve(to: NSPoint(x: 810, y: 610), controlPoint1: NSPoint(x: 890, y: 570), controlPoint2: NSPoint(x: 865, y: 615))
orbit.lineWidth = 34
orbit.lineCapStyle = .round
pink(0.70).setStroke()
orbit.stroke()

context.flushGraphics()
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Cannot render icon")
}
let destination = "BiliX/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
try FileManager.default.createDirectory(atPath: (destination as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
try png.write(to: URL(fileURLWithPath: destination))
