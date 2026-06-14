import Foundation
import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Cut social assets from a video. Usage:
//   makeclip <video> <clipStart> <clipDur> <gifStart> <gifDur> <outDir>
// Produces: clip-story.mp4 (vertical, with audio), clip-square.gif (center-cropped),
//           clip-frame.png (a preview frame for QA).
let a = CommandLine.arguments
let videoPath = a.count > 1 ? a[1] : "docs/preview/app-preview-promo-886x1920.mov"
let clipStart = a.count > 2 ? Double(a[2])! : 10
let clipDur   = a.count > 3 ? Double(a[3])! : 8
let gifStart  = a.count > 4 ? Double(a[4])! : 11
let gifDur    = a.count > 5 ? Double(a[5])! : 5
let outDir    = a.count > 6 ? a[6] : "docs/marketing/social"

let asset = AVURLAsset(url: URL(fileURLWithPath: videoPath))
let total = CMTimeGetSeconds(asset.duration)
print("video duration: \(String(format: "%.1f", total))s")

// MARK: trimmed vertical clip (keeps audio) → mp4
let clipURL = URL(fileURLWithPath: "\(outDir)/clip-story.mp4")
try? FileManager.default.removeItem(at: clipURL)
if let ex = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) {
    ex.outputURL = clipURL
    ex.outputFileType = .mp4
    let start = CMTime(seconds: min(clipStart, max(0, total - clipDur)), preferredTimescale: 600)
    ex.timeRange = CMTimeRange(start: start, duration: CMTime(seconds: clipDur, preferredTimescale: 600))
    let sem = DispatchSemaphore(value: 0)
    ex.exportAsynchronously { sem.signal() }
    sem.wait()
    print("clip-story.mp4: \(ex.status == .completed ? "ok" : "FAILED \(String(describing: ex.error))")")
}

// MARK: square center-cropped GIF (no audio)
let gen = AVAssetImageGenerator(asset: asset)
gen.appliesPreferredTrackTransform = true
gen.requestedTimeToleranceBefore = .zero
gen.requestedTimeToleranceAfter = .zero
let fps = 12.0, out = 540
let frameCount = Int(gifDur * fps)
let gifURL = URL(fileURLWithPath: "\(outDir)/clip-square.gif")
guard let dst = CGImageDestinationCreateWithURL(gifURL as CFURL, UTType.gif.identifier as CFString, frameCount, nil) else { exit(1) }
CGImageDestinationSetProperties(dst, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
let frameProps = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / fps]] as CFDictionary
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
var savedPreview = false
for i in 0..<frameCount {
    let t = CMTime(seconds: gifStart + Double(i) / fps, preferredTimescale: 600)
    guard let full = try? gen.copyCGImage(at: t, actualTime: nil) else { continue }
    let w = full.width, h = full.height, side = min(w, h)
    let crop = CGRect(x: (w - side) / 2, y: (h - side) / 2, width: side, height: side)
    guard let sq = full.cropping(to: crop) else { continue }
    let ctx = CGContext(data: nil, width: out, height: out, bitsPerComponent: 8, bytesPerRow: 0,
                        space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.draw(sq, in: CGRect(x: 0, y: 0, width: out, height: out))
    guard let frame = ctx.makeImage() else { continue }
    CGImageDestinationAddImage(dst, frame, frameProps)
    if !savedPreview {
        let p = URL(fileURLWithPath: "/tmp/clip-frame.png")
        if let pd = CGImageDestinationCreateWithURL(p as CFURL, UTType.png.identifier as CFString, 1, nil) {
            CGImageDestinationAddImage(pd, frame, nil); CGImageDestinationFinalize(pd)
        }
        savedPreview = true
    }
}
print("clip-square.gif: \(CGImageDestinationFinalize(dst) ? "ok (\(frameCount) frames)" : "FAILED")")
