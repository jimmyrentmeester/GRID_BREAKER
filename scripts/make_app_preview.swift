import AVFoundation
import QuartzCore
import CoreText
import CoreGraphics
import Foundation

// GRID_BREAKER — App Store App Preview builder (native AVFoundation, no ffmpeg).
// In : raw simulator capture (1320x2868, ~50fps VFR, no audio)
// Out: 886x1920, constant 30fps, H.264 + AAC, neon captions + music bed, +faststart.
//
// Captions are PRE-RENDERED to transparent PNGs via CoreText (CATextLayer does not
// rasterize text in a headless offline AVVideoCompositionCoreAnimationTool render);
// image layers composite reliably and animate opacity for timed fades.

let args = CommandLine.arguments
let RAW   = args.count > 1 ? args[1] : "docs/preview/gameplay-v1.3-raw.mov"
let MUSIC = args.count > 2 ? args[2] : "App/GRID_BREAKER/Music/Arcade_Fever.mp3"
let OUT   = args.count > 3 ? args[3] : "docs/preview/app-preview-promo-886x1920.mov"
let TRIM_START = args.count > 6 ? Double(args[6]) ?? 11.0 : 11.0
let CLIP_DUR   = 24.0

// Render size defaults to the iPhone 6.9"/6.5" App Preview spec; pass W H to override
// (e.g. 1200 1600 for the 13"/12.9" iPad App Preview). Captions scale with width.
let RENDER = CGSize(width: args.count > 4 ? Double(args[4]) ?? 886 : 886,
                    height: args.count > 5 ? Double(args[5]) ?? 1920 : 1920)
let capScale = RENDER.width / 886.0
let FPS: Int32 = 30
let cs = CGColorSpace(name: CGColorSpace.sRGB)!

let cyan: CGColor = CGColor(srgbRed: 0.30, green: 0.97, blue: 1.00, alpha: 1)
let gold: CGColor = CGColor(srgbRed: 1.00, green: 0.78, blue: 0.27, alpha: 1)

struct Caption { let s: String; let t1: Double; let t2: Double; let c: CGColor; let size: CGFloat; let yf: CGFloat; let big: Bool }
let captions: [Caption] = [
    Caption(s: "BREACH THE GRID",        t1: 0.8,  t2: 3.8,  c: gold, size: 76, yf: 0.13, big: false),
    Caption(s: "TAP · DECODE · SURVIVE", t1: 4.5,  t2: 8.0,  c: cyan, size: 60, yf: 0.13, big: false),
    Caption(s: "CHAIN YOUR STREAK",      t1: 9.0,  t2: 12.5, c: gold, size: 72, yf: 0.13, big: false),
    Caption(s: "THE GRID GROWS",         t1: 15.8, t2: 18.8, c: cyan, size: 76, yf: 0.13, big: false),
    Caption(s: "JACK IN",                t1: 20.3, t2: 23.7, c: cyan, size: 150, yf: 0.5, big: true),
]

func fail(_ m: String) -> Never { FileHandle.standardError.write(Data((m + "\n").utf8)); exit(1) }

// Pre-render a centered neon caption to a transparent CGImage (2x for crispness).
func renderCaption(_ s: String, fontSize: CGFloat, color: CGColor, glow: CGFloat) -> CGImage {
    let scale: CGFloat = 2
    let W = Int(RENDER.width * scale)
    let H = Int((fontSize + glow * 2 + 24) * scale)
    let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                        space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: scale, y: scale)
    let font = CTFontCreateWithName("Menlo-Bold" as CFString, fontSize, nil)
    let attr = CFAttributedStringCreate(nil, s as CFString,
        [kCTFontAttributeName: font, kCTForegroundColorAttributeName: color] as CFDictionary)!
    let line = CTLineCreateWithAttributedString(attr)
    var a: CGFloat = 0, d: CGFloat = 0, l: CGFloat = 0
    let tw = CGFloat(CTLineGetTypographicBounds(line, &a, &d, &l))
    let chPts = CGFloat(H) / scale
    let x = (RENDER.width - tw) / 2
    let y = (chPts - (a + d)) / 2 + d
    // glow pass + crisp pass
    ctx.setShadow(offset: .zero, blur: glow, color: color.copy(alpha: 0.95))
    ctx.textPosition = CGPoint(x: x, y: y); CTLineDraw(line, ctx)
    ctx.setShadow(offset: .zero, blur: glow * 0.5, color: color.copy(alpha: 0.9))
    ctx.textPosition = CGPoint(x: x, y: y); CTLineDraw(line, ctx)
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    ctx.textPosition = CGPoint(x: x, y: y); CTLineDraw(line, ctx)
    return ctx.makeImage()!
}

// Pre-render a bottom scrim gradient (black → clear) for caption legibility.
func renderScrim() -> CGImage {
    let W = Int(RENDER.width), H = Int(RENDER.height)
    let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                        space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let band = RENDER.height * 0.30
    let grad = CGGradient(colorsSpace: cs,
        colors: [CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.80),
                 CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0)] as CFArray,
        locations: [0, 1])!
    // origin bottom-left: opaque at y=0 (bottom), clear at y=band
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: band), options: [])
    return ctx.makeImage()!
}

let rawURL = URL(fileURLWithPath: RAW)
let musicURL = URL(fileURLWithPath: MUSIC)
let outURL = URL(fileURLWithPath: OUT)
try? FileManager.default.removeItem(at: outURL)

let src = AVURLAsset(url: rawURL)
let music = AVURLAsset(url: musicURL)
let comp = AVMutableComposition()

let sem = DispatchSemaphore(value: 0)
Task {
    do {
        guard let srcV = try await src.loadTracks(withMediaType: .video).first else { fail("no video track") }
        let vTrack = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
        let start = CMTime(seconds: TRIM_START, preferredTimescale: 600)
        let dur   = CMTime(seconds: CLIP_DUR,   preferredTimescale: 600)
        try vTrack.insertTimeRange(CMTimeRange(start: start, duration: dur), of: srcV, at: .zero)
        let natural = try await srcV.load(.naturalSize)

        // music + fades
        let mix = AVMutableAudioMix()
        if let srcA = try await music.loadTracks(withMediaType: .audio).first {
            let aTrack = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
            let mDur = try await music.load(.duration)
            let take = min(CLIP_DUR, CMTimeGetSeconds(mDur))
            try aTrack.insertTimeRange(CMTimeRange(start: .zero, duration: CMTime(seconds: take, preferredTimescale: 600)), of: srcA, at: .zero)
            let p = AVMutableAudioMixInputParameters(track: aTrack)
            p.setVolumeRamp(fromStartVolume: 0, toEndVolume: 0.85, timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 0.6, preferredTimescale: 600)))
            p.setVolumeRamp(fromStartVolume: 0.85, toEndVolume: 0, timeRange: CMTimeRange(start: CMTime(seconds: take - 1.8, preferredTimescale: 600), duration: CMTime(seconds: 1.8, preferredTimescale: 600)))
            mix.inputParameters = [p]
        }

        // video composition: scale source → RENDER (aspect-fill, centered)
        let vc = AVMutableVideoComposition()
        vc.renderSize = RENDER
        vc.frameDuration = CMTime(value: 1, timescale: FPS)
        let instr = AVMutableVideoCompositionInstruction()
        instr.timeRange = CMTimeRange(start: .zero, duration: dur)
        let li = AVMutableVideoCompositionLayerInstruction(assetTrack: vTrack)
        let scale = max(RENDER.width / natural.width, RENDER.height / natural.height)
        let tx = (RENDER.width  - natural.width  * scale) / 2
        let ty = (RENDER.height - natural.height * scale) / 2
        li.setTransform(CGAffineTransform(scaleX: scale, y: scale).concatenating(CGAffineTransform(translationX: tx, y: ty)), at: .zero)
        instr.layerInstructions = [li]
        vc.instructions = [instr]

        // overlay layers
        let parent = CALayer(); parent.frame = CGRect(origin: .zero, size: RENDER)
        let videoLayer = CALayer(); videoLayer.frame = CGRect(origin: .zero, size: RENDER)
        parent.addSublayer(videoLayer)

        let scrim = CALayer()
        scrim.frame = CGRect(origin: .zero, size: RENDER)
        scrim.contents = renderScrim()
        parent.addSublayer(scrim)

        for cap in captions {
            let glow: CGFloat = (cap.big ? 30 : 18) * capScale
            let img = renderCaption(cap.s, fontSize: cap.size * capScale, color: cap.c, glow: glow)
            let layer = CALayer()
            let hPts = CGFloat(img.height) / 2     // image is 2x
            let cy = RENDER.height * cap.yf
            layer.frame = CGRect(x: 0, y: cy - hPts / 2, width: RENDER.width, height: hPts)
            layer.contents = img
            layer.contentsGravity = .resizeAspect

            let total = cap.t2 - cap.t1, fade = 0.3
            let anim = CAKeyframeAnimation(keyPath: "opacity")
            anim.values = [0, 1, 1, 0]
            anim.keyTimes = [0, NSNumber(value: fade / total), NSNumber(value: (total - fade) / total), 1]
            anim.beginTime = AVCoreAnimationBeginTimeAtZero + cap.t1
            anim.duration = total
            anim.isRemovedOnCompletion = false
            anim.fillMode = .both
            layer.opacity = 0
            layer.add(anim, forKey: "opacity")
            parent.addSublayer(layer)
        }

        vc.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parent)

        guard let ex = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality) else { fail("no export session") }
        ex.videoComposition = vc
        ex.audioMix = mix
        ex.outputURL = outURL
        ex.outputFileType = .mov
        ex.shouldOptimizeForNetworkUse = true
        await ex.export()
        if ex.status == .completed { print("OK wrote \(OUT)") }
        else { fail("export failed: \(ex.status.rawValue) \(String(describing: ex.error))") }
    } catch { fail("error: \(error)") }
    sem.signal()
}
sem.wait()
