import Foundation
import CoreGraphics
import CoreText
import CoreImage
import ImageIO
import UniformTypeIdentifiers

// Instagram cards for GRID_BREAKER. Opaque PNG.
// Usage: maketeaser <out.png> <W> <H> [soon|now] [shotPath]
//   mode  "soon" = COMING SOON · "now" = OUT NOW
//   shotPath (optional) = a gameplay screenshot → full-bleed "key art" layout
let args = CommandLine.arguments
let outPath = args.count > 1 ? args[1] : "/tmp/teaser.png"
let W = args.count > 3 ? Int(args[2])! : 1080
let H = args.count > 3 ? Int(args[3])! : 1080
let mode = args.count > 4 ? args[4] : "soon"
let isLive = mode == "now"
let shotPath: String? = args.count > 5 ? args[5] : nil

let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
typealias RGB = (Double, Double, Double)
let cyan: RGB = (0.20, 0.95, 1.00), magenta: RGB = (1.00, 0.20, 0.80), gold: RGB = (1.00, 0.82, 0.25), dim: RGB = (0.78, 0.82, 0.92)
let black: RGB = (0, 0, 0)
func col(_ c: RGB, _ a: Double = 1) -> CGColor { CGColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: a) }
let cx = Double(W) / 2, cyc = Double(H) / 2
func loadImage(_ p: String) -> CGImage? {
    guard let s = CGImageSourceCreateWithURL(URL(fileURLWithPath: p) as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(s, 0, nil)
}
func blurred(_ img: CGImage, radius: Double) -> CGImage {
    let ci = CIImage(cgImage: img).clampedToExtent()
    guard let f = CIFilter(name: "CIGaussianBlur") else { return img }
    f.setValue(ci, forKey: kCIInputImageKey); f.setValue(radius, forKey: kCIInputRadiusKey)
    guard let out = f.outputImage else { return img }
    return CIContext().createCGImage(out, from: CIImage(cgImage: img).extent) ?? img
}
let shot = shotPath.flatMap(loadImage)
let keyArt = shot != nil

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
func measureW(_ s: String, _ font: String, _ size: Double) -> Double {
    let f = CTFontCreateWithName(font as CFString, size, nil)
    let line = CTLineCreateWithAttributedString(CFAttributedStringCreate(nil, s as CFString, [kCTFontAttributeName: f] as CFDictionary)!)
    var a: CGFloat = 0, d: CGFloat = 0, l: CGFloat = 0
    return Double(CTLineGetTypographicBounds(line, &a, &d, &l))
}

// MARK: background
if let raw = shot {
    // teaser = a *glimpse* (heavily blurred); out-now = full sharp reveal
    let img = isLive ? raw : blurred(raw, radius: Double(raw.width) * 0.035)
    // aspect-fill the gameplay screenshot, then dark scrims top + bottom for legibility
    let iw = Double(img.width), ih = Double(img.height), scale = max(Double(W) / iw, Double(H) / ih)
    let dw = iw * scale, dh = ih * scale
    ctx.draw(img, in: CGRect(x: (Double(W) - dw) / 2, y: (Double(H) - dh) / 2, width: dw, height: dh))
    let top = CGGradient(colorsSpace: cs, colors: [col(black, 0.92), col(black, 0)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(top, start: CGPoint(x: 0, y: H), end: CGPoint(x: 0, y: Double(H) * 0.58), options: [.drawsBeforeStartLocation])
    let bot = CGGradient(colorsSpace: cs, colors: [col(black, 0.94), col(black, 0)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bot, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: Double(H) * 0.46), options: [.drawsBeforeStartLocation])
    ctx.setFillColor(col(black, 0.12)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))  // slight overall dim
} else {
    let bg = CGGradient(colorsSpace: cs, colors: [col((0.06, 0.07, 0.13)), col((0.012, 0.012, 0.03))] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(bg, startCenter: CGPoint(x: cx, y: cyc), startRadius: 0, endCenter: CGPoint(x: cx, y: cyc), endRadius: Double(max(W, H)) * 0.62, options: [])
    ctx.setStrokeColor(col((0.47, 0.35, 0.78), 0.10)); ctx.setLineWidth(1.5)
    for x in stride(from: 0, through: W, by: 54) { ctx.move(to: CGPoint(x: x, y: 0)); ctx.addLine(to: CGPoint(x: x, y: H)) }
    for y in stride(from: 0, through: H, by: 54) { ctx.move(to: CGPoint(x: 0, y: y)); ctx.addLine(to: CGPoint(x: W, y: y)) }
    ctx.strokePath()
}

// layout fractions differ: key-art pushes text to top/bottom, clean centers it
let yWord = keyArt ? 0.875 : 0.525
let yTag  = keyArt ? 0.812 : 0.435
let yPill = keyArt ? 0.150 : 0.305
let yFoot = keyArt ? 0.070 : 0.135

// chevron + cursor mark (clean layout only)
if !keyArt {
    let mY = Double(H) * 0.70, ms = Double(W) / 1080.0
    ctx.saveGState(); ctx.setShadow(offset: .zero, blur: 26, color: col(cyan, 0.9))
    ctx.setStrokeColor(col(cyan)); ctx.setLineWidth(20 * ms); ctx.setLineCap(.round); ctx.setLineJoin(.round)
    ctx.move(to: CGPoint(x: cx - 64 * ms, y: mY + 46 * ms)); ctx.addLine(to: CGPoint(x: cx - 20 * ms, y: mY)); ctx.addLine(to: CGPoint(x: cx - 64 * ms, y: mY - 46 * ms)); ctx.strokePath()
    ctx.restoreGState()
    ctx.saveGState(); ctx.setShadow(offset: .zero, blur: 30, color: col(magenta))
    ctx.addPath(CGPath(roundedRect: CGRect(x: cx + 6 * ms, y: mY - 28 * ms, width: 56 * ms, height: 56 * ms), cornerWidth: 8, cornerHeight: 8, transform: nil))
    ctx.setFillColor(col(magenta)); ctx.fillPath(); ctx.restoreGState()
}

// wide-audience lines (family/friends/colleagues) — warm, not gamer jargon
let tagline = isLive ? "// my new iPhone game" : "// something I've been building"
text("GRID_BREAKER", "Menlo-Bold", Double(W) * 0.107, cyan, yFrac: yWord, glow: 42)
text(tagline, "Menlo-Bold", Double(W) * 0.030, magenta, yFrac: yTag, glow: 20)

// status pill — COMING SOON (outline) or OUT NOW (filled)
let pillLabel = isLive ? "OUT NOW" : "COMING SOON"
let pillSize = Double(W) * 0.040, pw = measureW(pillLabel, "Menlo-Bold", pillSize)
let padX = 44.0, padY = 26.0, pillW = pw + padX * 2, pillH = pillSize + padY * 2, pillY = Double(H) * yPill
ctx.saveGState(); ctx.setShadow(offset: .zero, blur: isLive ? 34 : 24, color: col(gold, isLive ? 1 : 0.8))
ctx.addPath(CGPath(roundedRect: CGRect(x: cx - pillW / 2, y: pillY - pillH / 2, width: pillW, height: pillH), cornerWidth: pillH / 2, cornerHeight: pillH / 2, transform: nil))
if isLive { ctx.setFillColor(col(gold)); ctx.fillPath() } else { ctx.setStrokeColor(col(gold)); ctx.setLineWidth(4); ctx.strokePath() }
ctx.restoreGState()
text(pillLabel, "Menlo-Bold", pillSize, isLive ? (0.04, 0.05, 0.10) : gold, yFrac: yPill, glow: isLive ? 0 : 14)

// out-now spells out what it is + where; teaser stays vague (the secret) → no footer
let footer = isLive ? "A FREE GAME FOR iPHONE  ·  ON THE APP STORE" : ""
if !footer.isEmpty { text(footer, "Menlo", Double(W) * 0.0225, dim, yFrac: yFoot, glow: 8) }

// neon border frame (key-art only — frames the bleed)
if keyArt {
    ctx.addPath(CGPath(roundedRect: CGRect(x: 16, y: 16, width: W - 32, height: H - 32), cornerWidth: 30, cornerHeight: 30, transform: nil))
    ctx.setStrokeColor(col(cyan, 0.45)); ctx.setLineWidth(5); ctx.strokePath()
} else {
    let v = CGGradient(colorsSpace: cs, colors: [col(black, 0), col(black, 0.5)] as CFArray, locations: [0.5, 1])!
    ctx.drawRadialGradient(v, startCenter: CGPoint(x: cx, y: cyc), startRadius: 0, endCenter: CGPoint(x: cx, y: cyc), endRadius: Double(max(W, H)) * 0.64, options: [])
}

let url = URL(fileURLWithPath: outPath)
let dst = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dst, ctx.makeImage()!, nil); CGImageDestinationFinalize(dst)
print("wrote \(outPath) (\(W)x\(H))\(keyArt ? " key-art" : "")")
