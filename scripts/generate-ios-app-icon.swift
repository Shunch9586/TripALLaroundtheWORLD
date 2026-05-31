import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconSetURL = root
    .appendingPathComponent("ios/TravelItinerary/Assets.xcassets/AppIcon.appiconset", isDirectory: true)

try FileManager.default.createDirectory(at: iconSetURL, withIntermediateDirectories: true)

struct IconImage {
    let idiom: String
    let size: String
    let scale: String
    let filename: String
    let pixels: Int
}

let images: [IconImage] = [
    .init(idiom: "iphone", size: "20x20", scale: "2x", filename: "Icon-20@2x.png", pixels: 40),
    .init(idiom: "iphone", size: "20x20", scale: "3x", filename: "Icon-20@3x.png", pixels: 60),
    .init(idiom: "iphone", size: "29x29", scale: "2x", filename: "Icon-29@2x.png", pixels: 58),
    .init(idiom: "iphone", size: "29x29", scale: "3x", filename: "Icon-29@3x.png", pixels: 87),
    .init(idiom: "iphone", size: "40x40", scale: "2x", filename: "Icon-40@2x.png", pixels: 80),
    .init(idiom: "iphone", size: "40x40", scale: "3x", filename: "Icon-40@3x.png", pixels: 120),
    .init(idiom: "iphone", size: "60x60", scale: "2x", filename: "Icon-60@2x.png", pixels: 120),
    .init(idiom: "iphone", size: "60x60", scale: "3x", filename: "Icon-60@3x.png", pixels: 180),
    .init(idiom: "ipad", size: "20x20", scale: "1x", filename: "Icon-20.png", pixels: 20),
    .init(idiom: "ipad", size: "20x20", scale: "2x", filename: "Icon-20-ipad@2x.png", pixels: 40),
    .init(idiom: "ipad", size: "29x29", scale: "1x", filename: "Icon-29.png", pixels: 29),
    .init(idiom: "ipad", size: "29x29", scale: "2x", filename: "Icon-29-ipad@2x.png", pixels: 58),
    .init(idiom: "ipad", size: "40x40", scale: "1x", filename: "Icon-40.png", pixels: 40),
    .init(idiom: "ipad", size: "40x40", scale: "2x", filename: "Icon-40-ipad@2x.png", pixels: 80),
    .init(idiom: "ipad", size: "76x76", scale: "1x", filename: "Icon-76.png", pixels: 76),
    .init(idiom: "ipad", size: "76x76", scale: "2x", filename: "Icon-76@2x.png", pixels: 152),
    .init(idiom: "ipad", size: "83.5x83.5", scale: "2x", filename: "Icon-83.5@2x.png", pixels: 167),
    .init(idiom: "ios-marketing", size: "1024x1024", scale: "1x", filename: "Icon-1024.png", pixels: 1024),
]

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
}

func drawIcon(size: Int) -> NSImage {
    let canvas = CGFloat(size)
    let image = NSImage(size: NSSize(width: canvas, height: canvas))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: canvas, height: canvas)
    let background = NSGradient(colors: [
        color(0.04, 0.10, 0.13),
        color(0.03, 0.07, 0.09),
        color(0.04, 0.09, 0.09),
    ])!
    background.draw(in: rect, angle: 250)

    let glow = NSBezierPath(ovalIn: NSRect(x: -canvas * 0.26, y: canvas * 0.54, width: canvas * 0.86, height: canvas * 0.86))
    color(0.34, 0.78, 0.83, 0.30).setFill()
    glow.fill()

    let amberGlow = NSBezierPath(ovalIn: NSRect(x: canvas * 0.56, y: canvas * 0.60, width: canvas * 0.42, height: canvas * 0.42))
    color(1.00, 0.71, 0.36, 0.24).setFill()
    amberGlow.fill()

    let cardRect = NSRect(x: canvas * 0.20, y: canvas * 0.24, width: canvas * 0.60, height: canvas * 0.52)
    let card = NSBezierPath(roundedRect: cardRect, xRadius: canvas * 0.085, yRadius: canvas * 0.085)
    color(0.07, 0.15, 0.19, 0.98).setFill()
    card.fill()
    color(0.62, 0.87, 0.89, 0.36).setStroke()
    card.lineWidth = max(2, canvas * 0.012)
    card.stroke()

    let spine = NSBezierPath(roundedRect: NSRect(x: canvas * 0.485, y: canvas * 0.27, width: canvas * 0.03, height: canvas * 0.46), xRadius: canvas * 0.014, yRadius: canvas * 0.014)
    color(0.45, 0.88, 0.92, 0.36).setFill()
    spine.fill()

    let route = NSBezierPath()
    route.move(to: NSPoint(x: canvas * 0.28, y: canvas * 0.44))
    route.curve(
        to: NSPoint(x: canvas * 0.72, y: canvas * 0.55),
        controlPoint1: NSPoint(x: canvas * 0.38, y: canvas * 0.72),
        controlPoint2: NSPoint(x: canvas * 0.58, y: canvas * 0.30)
    )
    color(0.45, 0.88, 0.92).setStroke()
    route.lineWidth = max(3, canvas * 0.027)
    route.lineCapStyle = .round
    route.stroke()

    let pin = NSBezierPath(ovalIn: NSRect(x: canvas * 0.66, y: canvas * 0.50, width: canvas * 0.105, height: canvas * 0.105))
    color(1.00, 0.71, 0.36).setFill()
    pin.fill()

    let dayRect = NSBezierPath(roundedRect: NSRect(x: canvas * 0.30, y: canvas * 0.58, width: canvas * 0.18, height: canvas * 0.072), xRadius: canvas * 0.028, yRadius: canvas * 0.028)
    color(0.45, 0.88, 0.92).setFill()
    dayRect.fill()

    let plane = NSBezierPath()
    plane.move(to: NSPoint(x: canvas * 0.66, y: canvas * 0.78))
    plane.line(to: NSPoint(x: canvas * 0.43, y: canvas * 0.67))
    plane.curve(
        to: NSPoint(x: canvas * 0.49, y: canvas * 0.76),
        controlPoint1: NSPoint(x: canvas * 0.42, y: canvas * 0.71),
        controlPoint2: NSPoint(x: canvas * 0.45, y: canvas * 0.75)
    )
    plane.line(to: NSPoint(x: canvas * 0.56, y: canvas * 0.78))
    plane.line(to: NSPoint(x: canvas * 0.49, y: canvas * 0.86))
    plane.curve(
        to: NSPoint(x: canvas * 0.58, y: canvas * 0.84),
        controlPoint1: NSPoint(x: canvas * 0.52, y: canvas * 0.88),
        controlPoint2: NSPoint(x: canvas * 0.56, y: canvas * 0.85)
    )
    plane.line(to: NSPoint(x: canvas * 0.66, y: canvas * 0.80))
    plane.close()
    color(0.45, 0.88, 0.92).setFill()
    plane.fill()

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL, pixels: Int) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGeneration", code: 1)
    }
    try png.write(to: url)
}

for item in images {
    let image = drawIcon(size: item.pixels)
    try writePNG(image, to: iconSetURL.appendingPathComponent(item.filename), pixels: item.pixels)
}

let contents = """
{
  "images": [
\(images.map { image in
    """
    {
      "idiom": "\(image.idiom)",
      "size": "\(image.size)",
      "scale": "\(image.scale)",
      "filename": "\(image.filename)"
    }
    """
}.joined(separator: ",\n"))
  ],
  "info": {
    "author": "xcode",
    "version": 1
  }
}
"""

try contents.write(to: iconSetURL.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
