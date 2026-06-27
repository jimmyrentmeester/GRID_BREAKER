import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

// Social/OG share card for GRID_BREAKER — 1200×630, neon theme. Opaque PNG.
let W = 1200, H = 630
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
typealias RGB = (Double, Double, Double)
let cyan: RGB = (0.20, 0.95, 1.00), magenta: RGB = (1.00, 0.20, 0.80), gold: RGB = (1.00, 0.82, 0.25)
func col(_ c: RGB, _ a: Double = 1) -> CGColor { CGColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: a) }

// bg
let bg = CGGradient(colorsSpace: cs, colors: [col((0.06, 0.07, 0.13)), col((0.012, 0.012, 0.03))] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(bg, startCenter: CGPoint(x: W / 2, y: H / 2), startRadius: 0,
                       endCenter: CGPoint(x: W / 2, y: H / 2), endRadius: Double(W) * 0.62, options: [])
// grid lines
ctx.setStrokeColor(col((0.47, 0.35, 0.78), 0.10)); ctx.setLineWidth(1.5)
for x in stride(from: 0, through: W, by: 48) { ctx.move(to: CGPoint(x: x, y: 0)); ctx.addLine(to: CGPoint(x: x, y: H)) }
for y in stride(from: 0, through: H, by: 48) { ctx.move(to: CGPoint(x: 0, y: y)); ctx.addLine(to: CGPoint(x: W, y: y)) }
ctx.strokePath()

func text(_ s: String, font: String, size: Double, _ c: RGB, x: Double, y: Double, glow: Double, center: Bool) {
    let f = CTFontCreateWithName(font as CFString, size, nil)
    let line = CTLineCreateWithAttributedString(CFAttributedStringCreate(nil, s as CFString,
        [kCTFontAttributeName: f, kCTForegroundColorAttributeName: col(c)] as CFDictionary)!)
    var a: CGFloat = 0, d: CGFloat = 0, l: CGFloat = 0
    let w = CGFloat(CTLineGetTypographicBounds(line, &a, &d, &l))
    ctx.saveGState(); ctx.setShadow(offset: .zero, blur: CGFloat(glow), color: col(c, 0.95))
    ctx.textPosition = CGPoint(x: center ? Double(W) / 2 - Double(w) / 2 : x, y: y)
    CTLineDraw(line, ctx); ctx.restoreGState()
}

// chevron + cursor mark (echoes the app icon), top-centred
let cy = 446.0
ctx.saveGState(); ctx.setShadow(offset: .zero, blur: 26, color: col(cyan, 0.9))
ctx.setStrokeColor(col(cyan)); ctx.setLineWidth(20); ctx.setLineCap(.round); ctx.setLineJoin(.round)
ctx.move(to: CGPoint(x: 540, y: cy + 44)); ctx.addLine(to: CGPoint(x: 584, y: cy)); ctx.addLine(to: CGPoint(x: 540, y: cy - 44)); ctx.strokePath()
ctx.restoreGState()
ctx.saveGState(); ctx.setShadow(offset: .zero, blur: 30, color: col(magenta))
ctx.addPath(CGPath(roundedRect: CGRect(x: 604, y: cy - 26, width: 56, height: 56), cornerWidth: 8, cornerHeight: 8, transform: nil))
ctx.setFillColor(col(magenta)); ctx.fillPath(); ctx.restoreGState()

text("GRID_BREAKER", font: "Menlo-Bold", size: 132, cyan, x: 0, y: 232, glow: 40, center: true)
text("// NEON REFLEX GRID-HACKING", font: "Menlo-Bold", size: 40, magenta, x: 0, y: 150, glow: 20, center: true)
text("ENDLESS · CAMPAIGN · PROTOCOL · DAILY   —   NO ADS · NO TRACKING", font: "Menlo", size: 26, gold, x: 0, y: 84, glow: 12, center: true)

// vignette
let v = CGGradient(colorsSpace: cs, colors: [col((0, 0, 0), 0), col((0, 0, 0), 0.5)] as CFArray, locations: [0.5, 1])!
ctx.drawRadialGradient(v, startCenter: CGPoint(x: W / 2, y: H / 2), startRadius: 0,
                       endCenter: CGPoint(x: W / 2, y: H / 2), endRadius: Double(W) * 0.62, options: [])

let url = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/og.png")
let dst = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dst, ctx.makeImage()!, nil); CGImageDestinationFinalize(dst)
print("wrote \(url.path)")
