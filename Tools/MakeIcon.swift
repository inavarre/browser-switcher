// Renders the BrowserSwitcher app icon into the AppIcon asset catalog.
//
// A white stem (the incoming link) forks into a turquoise and a pink branch,
// each ending in a glowing node (the two browsers), on a deep indigo tile.
//
// Regenerate from the repository root with:
//   swiftc -O Tools/MakeIcon.swift -o "$TMPDIR/makeicon" && "$TMPDIR/makeicon"

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let outputDir = URL(fileURLWithPath: "BrowserSwitcher/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
let pixelSizes = [16, 32, 64, 128, 256, 512, 1024]

let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func gradient(_ colors: [CGColor]) -> CGGradient {
    CGGradient(colorsSpace: sRGB, colors: colors as CFArray, locations: nil)!
}

enum Palette {
    static let turquoise = 0x2DE2D0 as UInt32
    static let turquoiseDeep = 0x0FB2C4 as UInt32
    static let pink = 0xFF62AA as UInt32
    static let pinkDeep = 0xEC2F7E as UInt32
    static let inkTop = 0x2B2654 as UInt32
    static let inkBottom = 0x131127 as UInt32
    static let stem = 0xF7F5FF as UInt32
}

/// Draws in a 1024×1024, y-down design space. `scale` converts to device pixels,
/// which shadows need because Core Graphics doesn't apply the CTM to them.
func drawIcon(in ctx: CGContext, scale: CGFloat, detailed: Bool) {
    // macOS icon grid: 824pt tile centered on a 1024pt canvas.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

    // Tile with a soft drop shadow.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12 * scale), blur: 28 * scale, color: color(0x000000, 0.35))
    ctx.addPath(tilePath)
    ctx.setFillColor(color(Palette.inkBottom))
    ctx.fillPath()
    ctx.restoreGState()

    // Background: indigo gradient with faint turquoise / pink glows and a top sheen.
    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    ctx.drawLinearGradient(
        gradient([color(Palette.inkTop), color(Palette.inkBottom)]),
        start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 924), options: []
    )
    for (hex, center) in [(Palette.turquoise, CGPoint(x: 250, y: 230)), (Palette.pink, CGPoint(x: 780, y: 230))] {
        ctx.drawRadialGradient(
            gradient([color(hex, 0.30), color(hex, 0)]),
            startCenter: center, startRadius: 0, endCenter: center, endRadius: 500, options: []
        )
    }
    if detailed {
        ctx.drawLinearGradient(
            gradient([color(0xFFFFFF, 0.10), color(0xFFFFFF, 0)]),
            start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 440), options: []
        )
    }
    ctx.restoreGState()

    if detailed {
        ctx.saveGState()
        ctx.addPath(CGPath(roundedRect: tile.insetBy(dx: 2, dy: 2), cornerWidth: 183, cornerHeight: 183, transform: nil))
        ctx.setStrokeColor(color(0xFFFFFF, 0.12))
        ctx.setLineWidth(4)
        ctx.strokePath()
        ctx.restoreGState()
    }

    // The fork.
    let base = CGPoint(x: 512, y: 790)
    let split = CGPoint(x: 512, y: 585)
    let lineWidth: CGFloat = 80
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    func branch(to end: CGPoint, light: UInt32, deep: UInt32) {
        let path = CGMutablePath()
        path.move(to: split)
        path.addCurve(
            to: end,
            control1: CGPoint(x: split.x, y: split.y - 160),
            control2: CGPoint(x: end.x, y: end.y + 180)
        )

        // Glow pass (solid stroke + colored shadow), then the gradient on top.
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: (detailed ? 46 : 18) * scale, color: color(light, 0.55))
        ctx.addPath(path)
        ctx.setLineWidth(lineWidth)
        ctx.setStrokeColor(color(deep))
        ctx.strokePath()
        ctx.restoreGState()

        ctx.saveGState()
        ctx.addPath(path)
        ctx.setLineWidth(lineWidth)
        ctx.replacePathWithStrokedPath()
        ctx.clip()
        ctx.drawLinearGradient(
            gradient([color(Palette.stem), color(light), color(deep)]),
            start: split, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
        ctx.restoreGState()
    }

    func node(at center: CGPoint, light: UInt32, deep: UInt32) {
        let outer = CGRect(x: center.x - 76, y: center.y - 76, width: 152, height: 152)
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: (detailed ? 60 : 20) * scale, color: color(light, 0.7))
        ctx.setFillColor(color(deep))
        ctx.fillEllipse(in: outer)
        ctx.restoreGState()

        ctx.saveGState()
        ctx.addEllipse(in: outer)
        ctx.clip()
        ctx.drawLinearGradient(
            gradient([color(light), color(deep)]),
            start: CGPoint(x: center.x, y: center.y - 76), end: CGPoint(x: center.x, y: center.y + 76), options: []
        )
        ctx.restoreGState()

        // Hollow center so each node reads as a "destination".
        ctx.setFillColor(color(Palette.inkBottom))
        ctx.fillEllipse(in: CGRect(x: center.x - 30, y: center.y - 30, width: 60, height: 60))
    }

    func strokeStem() {
        ctx.move(to: base)
        ctx.addLine(to: split)
        ctx.setLineWidth(lineWidth)
        ctx.setStrokeColor(color(Palette.stem))
        ctx.strokePath()
    }

    // Stem glow goes underneath the branches so it doesn't haze the junction.
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: (detailed ? 30 : 10) * scale, color: color(0xFFFFFF, 0.3))
    strokeStem()
    ctx.restoreGState()

    let left = CGPoint(x: 316, y: 320)
    let right = CGPoint(x: 708, y: 320)
    branch(to: left, light: Palette.turquoise, deep: Palette.turquoiseDeep)
    branch(to: right, light: Palette.pink, deep: Palette.pinkDeep)

    // Square top end meets the branches (which start vertical at `split`) flush.
    ctx.saveGState()
    ctx.setLineCap(.butt)
    strokeStem()
    ctx.restoreGState()

    node(at: left, light: Palette.turquoise, deep: Palette.turquoiseDeep)
    node(at: right, light: Palette.pink, deep: Palette.pinkDeep)

    // Origin dot for the incoming link.
    ctx.setFillColor(color(Palette.stem))
    ctx.fillEllipse(in: CGRect(x: base.x - 54, y: base.y - 54, width: 108, height: 108))
}

func render(pixels: Int) throws {
    guard let ctx = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { throw CocoaError(.fileWriteUnknown) }

    let scale = CGFloat(pixels) / 1024
    ctx.translateBy(x: 0, y: CGFloat(pixels))
    ctx.scaleBy(x: scale, y: -scale)
    ctx.interpolationQuality = .high
    drawIcon(in: ctx, scale: scale, detailed: pixels >= 64)

    let url = outputDir.appendingPathComponent("icon_\(pixels).png")
    guard let image = ctx.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw CocoaError(.fileWriteUnknown) }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    print("wrote \(url.path)")
}

try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
for pixels in pixelSizes {
    try render(pixels: pixels)
}
