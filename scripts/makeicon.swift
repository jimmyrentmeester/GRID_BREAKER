import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let S = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: S, height: S, bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func c(_ r: Double,_ g: Double,_ b: Double,_ a: Double = 1) -> CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: a) }
let cyan = (0.20, 0.95, 1.00), magenta = (1.00, 0.20, 0.80), purple = (0.45, 0.25, 0.85)
let mid = CGFloat(S)/2

// background radial gradient
let bg = CGGradient(colorsSpace: cs, colors: [c(0.06,0.07,0.14), c(0.012,0.012,0.03)] as CFArray, locations: [0,1])!
ctx.drawRadialGradient(bg, startCenter: CGPoint(x: mid, y: mid), startRadius: 0,
                       endCenter: CGPoint(x: mid, y: mid), endRadius: CGFloat(S)*0.72, options: [])

// faint full grid
ctx.setLineWidth(2)
ctx.setStrokeColor(c(purple.0, purple.1, purple.2, 0.16))
let step = 128.0
var x = 0.0; while x <= Double(S) { ctx.move(to: .init(x: x, y: 0)); ctx.addLine(to: .init(x: x, y: Double(S))); x += step }
var y = 0.0; while y <= Double(S) { ctx.move(to: .init(x: 0, y: y)); ctx.addLine(to: .init(x: Double(S), y: y)); y += step }
ctx.strokePath()

// central 3x3 neon grid
let cell = 196.0, gap = 34.0
let gridW = cell*3 + gap*2
let ox = (Double(S) - gridW)/2, oy = (Double(S) - gridW)/2
func cellRect(_ col: Int,_ row: Int) -> CGRect {
    CGRect(x: ox + Double(col)*(cell+gap), y: oy + Double(row)*(cell+gap), width: cell, height: cell)
}
func rounded(_ r: CGRect,_ rad: CGFloat) -> CGPath { CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil) }

// outer 8 cells: cyan neon outline + soft fill, with glow
for row in 0..<3 { for col in 0..<3 {
    if row == 1 && col == 1 { continue }
    let r = cellRect(col,row)
    let p = rounded(r, 34)
    // glow pass
    ctx.saveGState(); ctx.setShadow(offset: .zero, blur: 34, color: c(cyan.0,cyan.1,cyan.2,0.9))
    ctx.addPath(p); ctx.setStrokeColor(c(cyan.0,cyan.1,cyan.2,0.95)); ctx.setLineWidth(7); ctx.strokePath()
    ctx.restoreGState()
    // faint fill
    ctx.addPath(p); ctx.setFillColor(c(cyan.0,cyan.1,cyan.2, 0.07)); ctx.fillPath()
}}

// center cell: BREACHED — hot magenta/white burst + radiating cracks
let cr = cellRect(1,1)
let cc = CGPoint(x: cr.midX, y: cr.midY)
// magenta glow fill
ctx.saveGState(); ctx.setShadow(offset: .zero, blur: 60, color: c(magenta.0,magenta.1,magenta.2,1.0))
ctx.addPath(rounded(cr, 34)); ctx.setFillColor(c(magenta.0,magenta.1,magenta.2,0.30)); ctx.fillPath(); ctx.restoreGState()
ctx.addPath(rounded(cr, 34)); ctx.setStrokeColor(c(magenta.0,magenta.1,magenta.2,1.0)); ctx.setLineWidth(8); ctx.strokePath()
// radiating cracks (burst)
ctx.saveGState(); ctx.setShadow(offset: .zero, blur: 26, color: c(1,1,1,0.9))
ctx.setStrokeColor(c(1,1,1,0.9)); ctx.setLineWidth(8); ctx.setLineCap(.round)
let spikes = 7
for i in 0..<spikes {
    let a = Double(i)/Double(spikes) * 2 * .pi + 0.3
    let long = (i%2==0); let r1 = 16.0; let r2 = long ? 300.0 : 92.0
    ctx.move(to: .init(x: cc.x + cos(a)*r1, y: cc.y + sin(a)*r1))
    ctx.addLine(to: .init(x: cc.x + cos(a)*r2, y: cc.y + sin(a)*r2))
}
ctx.strokePath()
// white-hot core
ctx.setShadow(offset: .zero, blur: 40, color: c(1,1,1,1))
ctx.addPath(CGPath(ellipseIn: CGRect(x: cc.x-26, y: cc.y-26, width: 52, height: 52), transform: nil))
ctx.setFillColor(c(1,1,1,1)); ctx.fillPath(); ctx.restoreGState()

// vignette
let vg = CGGradient(colorsSpace: cs, colors: [c(0,0,0,0), c(0,0,0,0.55)] as CFArray, locations: [0.55, 1])!
ctx.drawRadialGradient(vg, startCenter: .init(x: mid,y: mid), startRadius: 0, endCenter: .init(x: mid,y: mid), endRadius: CGFloat(S)*0.72, options: [])

let img = ctx.makeImage()!
let url = URL(fileURLWithPath: "/tmp/icon_new.png")
let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, img, nil)
CGImageDestinationFinalize(dest)
print("wrote /tmp/icon_new.png alpha:\(img.alphaInfo.rawValue)")
