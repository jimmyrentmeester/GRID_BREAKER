import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

// Instagram cards for GRID_BREAKER. Usage: maketeaser <out.png> <W> <H> [soon|now]
// Neon theme — opaque PNG. mode "soon" = COMING SOON, "now" = OUT NOW (launch).
let args = CommandLine.arguments
let outPath = args.count > 1 ? args[1] : "/tmp/teaser.png"
let W = args.count > 3 ? Int(args[2])! : 1080
let H = args.count > 3 ? Int(args[3])! : 1080
let mode = args.count > 4 ? args[4] : "soon"
let isLive = mode == "now"
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
typealias RGB = (Double, Double, Double)
let cyan: RGB = (0.20, 0.95, 1.00), magenta: RGB = (1.00, 0.20, 0.80), gold: RGB = (1.00, 0.82, 0.25), dim: RGB = (0.62, 0.66, 0.78)
func col(_ c: RGB, _ a: Double = 1) -> CGColor { CGColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: a) }
let cx = Double(W) / 2, cyc = Double(H) / 2

// background
let bg = CGGradient(colorsSpace: cs, colors: [col((0.06, 0.07, 0.13)), col((0.012, 0.012, 0.03))] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(bg, startCenter: CGPoint(x: cx, y: cyc), startRadius: 0, endCenter: CGPoint(x: cx, y: cyc), endRadius: Double(max(W, H)) * 0.62, options: [])
ctx.setStrokeColor(col((0.47, 0.35, 0.78), 0.10)); ctx.setLineWidth(1.5)
for x in stride(from: 0, through: W, by: 54) { ctx.move(to: CGPoint(x: x, y: 0)); ctx.addLine(to: CGPoint(x: x, y: H)) }
for y in stride(from: 0, through: H, by: 54) { ctx.move(to: CGPoint(x: 0, y: y)); ctx.addLine(to: CGPoint(x: W, y: y)) }
ctx.strokePath()

func measure(_ s: String, _ font: String, _ size: Double) -> (CTLine, Double, Double, Double) {
    let f = CTFontCreateWithName(font as CFString, size, nil)
    let line = CTLineCreateWithAttributedString(CFAttributedStringCreate(nil, s as CFString,
        [kCTFontAttributeName: f, kCTForegroundColorAttributeName: col((1, 1, 1))] as CFDictionary)!)
    var a: CGFloat = 0, d: CGFloat = 0, l: CGFloat = 0
    let w = CGFloat(CTLineGetTypographicBounds(line, &a, &d, &l))
    return (line, Double(w), Double(a), Double(d))
}
func text(_ s: String, _ font: String, _ size: Double, _ c: RGB, yFrac: Double, glow: Double) {
    let f = CTFontCreateWithName(font as CFString, size, nil)
    let line = CTLineCreateWithAttributedString(CFAttributedStringCreate(nil, s as CFString,
        [kCTFontAttributeName: f, kCTForegroundColorAttributeName: col(c)] as CFDictionary)!)
    var a: CGFloat = 0, d: CGFloat = 0, l: CGFloat = 0
    let w = CGFloat(CTLineGetTypographicBounds(line, &a, &d, &l))
    ctx.saveGState(); ctx.setShadow(offset: .zero, blur: CGFloat(glow), color: col(c, 0.95))
    ctx.textPosition = CGPoint(x: cx - Double(w) / 2, y: Double(H) * yFrac - Double(a - d) / 2)
    CTLineDraw(line, ctx); ctx.restoreGState()
}

// chevron + cursor mark
let mY = Double(H) * 0.70, ms = Double(W) / 1080.0 * 1.0
ctx.saveGState(); ctx.setShadow(offset: .zero, blur: 26, color: col(cyan, 0.9))
ctx.setStrokeColor(col(cyan)); ctx.setLineWidth(20 * ms); ctx.setLineCap(.round); ctx.setLineJoin(.round)
ctx.move(to: CGPoint(x: cx - 64 * ms, y: mY + 46 * ms)); ctx.addLine(to: CGPoint(x: cx - 20 * ms, y: mY)); ctx.addLine(to: CGPoint(x: cx - 64 * ms, y: mY - 46 * ms)); ctx.strokePath()
ctx.restoreGState()
ctx.saveGState(); ctx.setShadow(offset: .zero, blur: 30, color: col(magenta))
ctx.addPath(CGPath(roundedRect: CGRect(x: cx + 6 * ms, y: mY - 28 * ms, width: 56 * ms, height: 56 * ms), cornerWidth: 8, cornerHeight: 8, transform: nil))
ctx.setFillColor(col(magenta)); ctx.fillPath(); ctx.restoreGState()

text("GRID_BREAKER", "Menlo-Bold", Double(W) * 0.107, cyan, yFrac: 0.525, glow: 42)
text("// NEON REFLEX GRID-HACKING", "Menlo-Bold", Double(W) * 0.030, magenta, yFrac: 0.435, glow: 20)

// status pill — COMING SOON (outline) or OUT NOW (filled, celebratory)
let pillLabel = isLive ? "OUT NOW" : "COMING SOON"
let pillSize = Double(W) * 0.040, (_, pw, _, _) = measure(pillLabel, "Menlo-Bold", pillSize)
let padX = 44.0, padY = 26.0, pillW = pw + padX * 2, pillH = pillSize + padY * 2, pillY = Double(H) * 0.305
ctx.saveGState(); ctx.setShadow(offset: .zero, blur: isLive ? 34 : 24, color: col(gold, isLive ? 1 : 0.8))
ctx.addPath(CGPath(roundedRect: CGRect(x: cx - pillW / 2, y: pillY - pillH / 2, width: pillW, height: pillH), cornerWidth: pillH / 2, cornerHeight: pillH / 2, transform: nil))
if isLive { ctx.setFillColor(col(gold)); ctx.fillPath() } else { ctx.setStrokeColor(col(gold)); ctx.setLineWidth(4); ctx.strokePath() }
ctx.restoreGState()
text(pillLabel, "Menlo-Bold", pillSize, isLive ? (0.04, 0.05, 0.10) : gold, yFrac: 0.305, glow: isLive ? 0 : 14)

let footer = isLive ? "FREE ON THE APP STORE  ·  NO ADS · NO TRACKING" : "iOS  ·  FREE  ·  NO ADS  ·  NO TRACKING"
text(footer, "Menlo", Double(W) * 0.0225, dim, yFrac: 0.135, glow: 8)

// vignette
let v = CGGradient(colorsSpace: cs, colors: [col((0, 0, 0), 0), col((0, 0, 0), 0.5)] as CFArray, locations: [0.5, 1])!
ctx.drawRadialGradient(v, startCenter: CGPoint(x: cx, y: cyc), startRadius: 0, endCenter: CGPoint(x: cx, y: cyc), endRadius: Double(max(W, H)) * 0.64, options: [])

let url = URL(fileURLWithPath: outPath)
let dst = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dst, ctx.makeImage()!, nil); CGImageDestinationFinalize(dst)
print("wrote \(outPath) (\(W)x\(H))")
