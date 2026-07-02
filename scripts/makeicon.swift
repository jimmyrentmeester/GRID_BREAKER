import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// GRID_BREAKER app icon generator (opaque 1024², App Store rejects alpha).
//   swift makeicon.swift [classic|gold] [outputPath]
// `gold` renders the Monolith prestige variant (earned at 16/16 cores): the same
// composition — recognition stays — in the Monolith Gold palette family.
let style = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "classic"
let outPath = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "/tmp/icon_final.png"

let S = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: S, height: S, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func col(_ r: Double,_ g: Double,_ b: Double,_ a: Double = 1) -> CGColor { CGColor(srgbRed:r,green:g,blue:b,alpha:a) }

// Palette per style: (chevron, cursor block, block highlight, bg top, bg bottom)
let gold = style == "gold"
let stroke   = gold ? (1.00,0.83,0.30) : (0.20,0.95,1.00)   // chevron: rich gold / cyan
let block    = gold ? (1.00,0.95,0.75) : (1.00,0.20,0.80)   // cursor: champagne / magenta
let blockHi  = gold ? (1.00,0.70,0.20,0.40) : (1.00,0.75,0.95,0.35)
let bgTop    = gold ? (0.09,0.065,0.02) : (0.05,0.06,0.12)
let bgBottom = gold ? (0.03,0.02,0.005) : (0.012,0.012,0.03)

let mid = CGFloat(S)/2
// bg
let g = CGGradient(colorsSpace: cs, colors: [col(bgTop.0,bgTop.1,bgTop.2), col(bgBottom.0,bgBottom.1,bgBottom.2)] as CFArray, locations: [0,1])!
ctx.drawRadialGradient(g, startCenter: .init(x:mid,y:mid), startRadius: 0, endCenter: .init(x:mid,y:mid), endRadius: CGFloat(S)*0.72, options: [])
// chevron ">" — centered, bold
let cx = 318.0, tip = 522.0, top = 300.0, bot = 724.0, midY = 512.0
ctx.saveGState(); ctx.setShadow(offset:.zero, blur: 46, color: col(stroke.0,stroke.1,stroke.2,0.95))
ctx.setStrokeColor(col(stroke.0,stroke.1,stroke.2,1)); ctx.setLineWidth(66); ctx.setLineCap(.round); ctx.setLineJoin(.round)
ctx.move(to:.init(x:cx,y:top)); ctx.addLine(to:.init(x:tip,y:midY)); ctx.addLine(to:.init(x:cx,y:bot)); ctx.strokePath(); ctx.restoreGState()
// cursor block — vertically centered with chevron
let bx = 585.0, bw = 162.0
ctx.saveGState(); ctx.setShadow(offset:.zero, blur: 56, color: col(block.0,block.1,block.2,1))
ctx.addPath(CGPath(roundedRect: .init(x: bx, y: midY-bw/2, width: bw, height: bw), cornerWidth: 18, cornerHeight: 18, transform: nil))
ctx.setFillColor(col(block.0,block.1,block.2,1)); ctx.fillPath(); ctx.restoreGState()
// tiny inner highlight on the cursor for depth
ctx.addPath(CGPath(roundedRect: .init(x: bx+24, y: midY-bw/2+24, width: bw-48, height: bw-48), cornerWidth: 10, cornerHeight: 10, transform: nil))
ctx.setFillColor(col(blockHi.0,blockHi.1,blockHi.2,blockHi.3)); ctx.fillPath()
// vignette
let v = CGGradient(colorsSpace: cs, colors: [col(0,0,0,0), col(0,0,0,0.5)] as CFArray, locations: [0.55,1])!
ctx.drawRadialGradient(v, startCenter: .init(x:mid,y:mid), startRadius: 0, endCenter: .init(x:mid,y:mid), endRadius: CGFloat(S)*0.72, options: [])
let img = ctx.makeImage()!
let url = URL(fileURLWithPath: outPath)
let d = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(d, img, nil); CGImageDestinationFinalize(d)
print("wrote \(outPath) style:\(style) alpha:\(img.alphaInfo.rawValue)")
