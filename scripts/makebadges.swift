import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

// Generates the 13 Game Center achievement badges (1024×1024, opaque) in the
// GRID_BREAKER neon style: dark radial card + accent-coloured frame + one glyph.
// IDs match GameCenterService.swift (file name == the part after "ach.").

let S = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
typealias RGB = (Double, Double, Double)
let cyan: RGB = (0.20, 0.95, 1.00)
let magenta: RGB = (1.00, 0.20, 0.80)
let gold: RGB = (1.00, 0.82, 0.25)
let green: RGB = (0.55, 1.00, 0.30)

func col(_ c: RGB, _ a: Double = 1) -> CGColor { CGColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: a) }
func mix(_ c: RGB, _ t: Double) -> RGB { (c.0 + (1 - c.0) * t, c.1 + (1 - c.1) * t, c.2 + (1 - c.2) * t) }

func newCtx() -> CGContext {
    CGContext(data: nil, width: S, height: S, bitsPerComponent: 8, bytesPerRow: 0,
              space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
}

func P(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }
let mid = 512.0

// MARK: text (CoreText, centred)
func text(_ ctx: CGContext, _ s: String, size: Double, _ c: RGB, cx: Double, cy: Double, glow: Bool = true) {
    let font = CTFontCreateWithName("Menlo-Bold" as CFString, size, nil)
    let attrs = [kCTFontAttributeName: font, kCTForegroundColorAttributeName: col(c)] as CFDictionary
    let line = CTLineCreateWithAttributedString(CFAttributedStringCreate(nil, s as CFString, attrs)!)
    var asc: CGFloat = 0, desc: CGFloat = 0, lead: CGFloat = 0
    let w = CGFloat(CTLineGetTypographicBounds(line, &asc, &desc, &lead))
    ctx.saveGState()
    if glow { ctx.setShadow(offset: .zero, blur: 38, color: col(c, 0.95)) }
    ctx.textPosition = CGPoint(x: CGFloat(cx) - w / 2, y: CGFloat(cy) - (asc - desc) / 2)
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

// MARK: shared frame
func frame(_ ctx: CGContext, _ accent: RGB) {
    let bg = CGGradient(colorsSpace: cs, colors: [col((0.07, 0.08, 0.14)), col((0.012, 0.012, 0.03))] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(bg, startCenter: P(mid, mid), startRadius: 0, endCenter: P(mid, mid), endRadius: CGFloat(S) * 0.72, options: [])
    // faint accent wash behind the glyph
    let wash = CGGradient(colorsSpace: cs, colors: [col(accent, 0.16), col(accent, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(wash, startCenter: P(mid, mid), startRadius: 0, endCenter: P(mid, mid), endRadius: 360, options: [])
    // rounded-card border
    let inset = 104.0, r = CGRect(x: inset, y: inset, width: Double(S) - 2 * inset, height: Double(S) - 2 * inset)
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 34, color: col(accent, 0.9))
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: 66, cornerHeight: 66, transform: nil))
    ctx.setStrokeColor(col(accent)); ctx.setLineWidth(13); ctx.strokePath()
    ctx.restoreGState()
    // inner hairline
    let r2 = r.insetBy(dx: 18, dy: 18)
    ctx.addPath(CGPath(roundedRect: r2, cornerWidth: 54, cornerHeight: 54, transform: nil))
    ctx.setStrokeColor(col(accent, 0.25)); ctx.setLineWidth(3); ctx.strokePath()
}

func vignette(_ ctx: CGContext) {
    let v = CGGradient(colorsSpace: cs, colors: [col((0, 0, 0), 0), col((0, 0, 0), 0.5)] as CFArray, locations: [0.55, 1])!
    ctx.drawRadialGradient(v, startCenter: P(mid, mid), startRadius: 0, endCenter: P(mid, mid), endRadius: CGFloat(S) * 0.74, options: [])
}

func glow(_ ctx: CGContext, _ c: RGB, _ blur: Double, _ body: () -> Void) {
    ctx.saveGState(); ctx.setShadow(offset: .zero, blur: CGFloat(blur), color: col(c, 0.95)); body(); ctx.restoreGState()
}

// MARK: glyphs
func flame(_ ctx: CGContext, _ c: RGB, scale: Double = 1, dx: Double = 0, dy: Double = 0) {
    func body(_ s: Double) -> CGMutablePath {
        func pt(_ x: Double, _ y: Double) -> CGPoint { P(mid + (x - mid) * scale * s + dx, 512 + (y - 512) * scale * s + dy) }
        let p = CGMutablePath()
        p.move(to: pt(512, 770))                                             // tip
        p.addCurve(to: pt(640, 430), control1: pt(560, 690), control2: pt(648, 560))
        p.addCurve(to: pt(512, 318), control1: pt(632, 360), control2: pt(576, 318))  // round base
        p.addCurve(to: pt(384, 430), control1: pt(448, 318), control2: pt(392, 360))
        p.addCurve(to: pt(512, 770), control1: pt(376, 560), control2: pt(464, 690))
        return p
    }
    glow(ctx, c, 46) { ctx.addPath(body(1)); ctx.setFillColor(col(c)); ctx.fillPath() }
    ctx.addPath(body(0.5)); ctx.setFillColor(col(mix(c, 0.55))); ctx.fillPath()  // hot core
}

func bolt(_ ctx: CGContext, _ c: RGB, scale: Double = 1, dy: Double = 0) {
    func pt(_ x: Double, _ y: Double) -> CGPoint { P(mid + (x - mid) * scale, 512 + (y - 512) * scale + dy) }
    let pts = [(556, 716), (452, 540), (520, 540), (470, 304), (574, 504), (506, 504)]
        .map { pt(Double($0.0), Double($0.1)) }
    let p = CGMutablePath(); p.addLines(between: pts); p.closeSubpath()
    glow(ctx, c, 44) { ctx.addPath(p); ctx.setFillColor(col(c)); ctx.fillPath() }
}

func shield(_ ctx: CGContext, _ c: RGB) {
    let p = CGMutablePath()
    p.move(to: P(380, 700)); p.addLine(to: P(644, 700)); p.addLine(to: P(644, 520))
    p.addQuadCurve(to: P(512, 300), control: P(644, 372))
    p.addQuadCurve(to: P(380, 520), control: P(380, 372))
    p.closeSubpath()
    glow(ctx, c, 40) { ctx.addPath(p); ctx.setStrokeColor(col(c)); ctx.setLineWidth(22); ctx.setLineJoin(.round); ctx.strokePath() }
    ctx.addPath(p); ctx.setFillColor(col(c, 0.10)); ctx.fillPath()
    // check
    let ck = CGMutablePath(); ck.addLines(between: [P(452, 512), P(498, 460), P(588, 600)])
    glow(ctx, c, 30) { ctx.addPath(ck); ctx.setStrokeColor(col(c)); ctx.setLineWidth(26); ctx.setLineCap(.round); ctx.setLineJoin(.round); ctx.strokePath() }
}

func diamond(_ ctx: CGContext, _ c: RGB) {
    let d = CGMutablePath(); d.addLines(between: [P(512, 748), P(708, 512), P(512, 276), P(316, 512)]); d.closeSubpath()
    glow(ctx, c, 40) { ctx.addPath(d); ctx.setStrokeColor(col(c)); ctx.setLineWidth(20); ctx.setLineJoin(.round); ctx.strokePath() }
    ctx.addPath(d); ctx.setFillColor(col(c, 0.10)); ctx.fillPath()
    bolt(ctx, mix(c, 0.35), scale: 0.58)
}

func grid(_ ctx: CGContext, _ c: RGB) {
    let cell = 80.0, gap = 26.0, n = 4
    let span = Double(n) * cell + Double(n - 1) * gap
    let x0 = mid - span / 2, y0 = mid - span / 2
    for row in 0..<n { for c2 in 0..<n {
        let x = x0 + Double(c2) * (cell + gap), y = y0 + Double(row) * (cell + gap)
        let corner = (row == 0 || row == n - 1) && (c2 == 0 || c2 == n - 1)
        let a = corner ? 1.0 : 0.42
        glow(ctx, c, corner ? 26 : 10) {
            ctx.addPath(CGPath(roundedRect: CGRect(x: x, y: y, width: cell, height: cell), cornerWidth: 14, cornerHeight: 14, transform: nil))
            ctx.setFillColor(col(c, a)); ctx.fillPath()
        }
    } }
}

func hexagon(_ ctx: CGContext, _ c: RGB, r: Double = 210) {
    let p = CGMutablePath()
    for i in 0..<6 {
        let ang = (-90.0 + 60.0 * Double(i)) * .pi / 180
        let pt = P(mid + r * cos(ang), mid + r * sin(ang))
        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
    }
    p.closeSubpath()
    glow(ctx, c, 40) { ctx.addPath(p); ctx.setStrokeColor(col(c)); ctx.setLineWidth(20); ctx.setLineJoin(.round); ctx.strokePath() }
    ctx.addPath(p); ctx.setFillColor(col(c, 0.12)); ctx.fillPath()
}

func maxbars(_ ctx: CGContext, _ c: RGB) {
    let w = 78.0, gap = 40.0, bottom = 440.0
    let heights = [140.0, 220.0, 308.0]
    let span = 3 * w + 2 * gap, x0 = mid - span / 2
    for (i, h) in heights.enumerated() {
        let x = x0 + Double(i) * (w + gap)
        let a = 0.4 + 0.3 * Double(i)
        glow(ctx, c, 18 + 8 * Double(i)) {
            ctx.addPath(CGPath(roundedRect: CGRect(x: x, y: bottom, width: w, height: h), cornerWidth: 14, cornerHeight: 14, transform: nil))
            ctx.setFillColor(col(c, a)); ctx.fillPath()
        }
    }
    // up-chevron above tallest
    let cx = x0 + 2 * (w + gap) + w / 2, ty = bottom + heights[2]
    let ch = CGMutablePath(); ch.addLines(between: [P(cx - 46, ty + 36), P(cx, ty + 96), P(cx + 46, ty + 36)])
    glow(ctx, c, 26) { ctx.addPath(ch); ctx.setStrokeColor(col(c)); ctx.setLineWidth(22); ctx.setLineCap(.round); ctx.setLineJoin(.round); ctx.strokePath() }
}

// MARK: badge table  (filename, accent, render)
let badges: [(String, RGB, (CGContext, RGB) -> Void)] = [
    ("firstfever", gold, { c, a in flame(c, a) }),
    ("feverloop", gold, { c, a in flame(c, a, scale: 0.86, dy: 18); text(c, "×3", size: 168, mix(a, 0.1), cx: 660, cy: 360) }),
    ("streak25", cyan, { c, a in bolt(c, a, scale: 0.74, dy: 120); text(c, "25", size: 250, a, cx: 512, cy: 396) }),
    ("failsafe", gold, { c, a in shield(c, a) }),
    ("toolbelt", magenta, { c, a in diamond(c, a) }),
    ("grid4x4", cyan, { c, a in grid(c, a) }),
    ("score100", cyan, { c, a in text(c, "100", size: 280, a, cx: 512, cy: 512) }),
    ("score250", magenta, { c, a in text(c, "250", size: 280, a, cx: 512, cy: 512) }),
    ("score500", gold, { c, a in text(c, "500", size: 280, a, cx: 512, cy: 512) }),
    ("core1", cyan, { c, a in hexagon(c, a); text(c, "1", size: 240, a, cx: 512, cy: 512) }),
    ("core5", magenta, { c, a in hexagon(c, a); text(c, "5", size: 240, a, cx: 512, cy: 512) }),
    ("core10", gold, { c, a in hexagon(c, a, r: 230); text(c, "10", size: 220, a, cx: 512, cy: 512) }),
    ("maxtrack", green, { c, a in maxbars(c, a); text(c, "MAX", size: 132, a, cx: 512, cy: 348) }),
]

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/badges"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func save(_ img: CGImage, _ path: String) {
    let url = URL(fileURLWithPath: path)
    let d = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, img, nil); CGImageDestinationFinalize(d)
}

var images: [CGImage] = []
for (name, accent, render) in badges {
    let ctx = newCtx()
    frame(ctx, accent)
    render(ctx, accent)
    vignette(ctx)
    let img = ctx.makeImage()!
    images.append(img)
    save(img, "\(outDir)/\(name).png")
}

// contact sheet 4×4 @256 for quick visual QA
let cc = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
cc.setFillColor(col((0, 0, 0))); cc.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
for (i, img) in images.enumerated() {
    let cx = i % 4, cy = i / 4
    cc.draw(img, in: CGRect(x: cx * 256, y: 1024 - (cy + 1) * 256, width: 256, height: 256))
}
save(cc.makeImage()!, "\(outDir)/_contact.png")
print("wrote \(images.count) badges + _contact.png to \(outDir)")
