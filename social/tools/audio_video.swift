// Makes a 1080x1920 vertical video from slide PNGs and a recorded narration
// (e.g. an ElevenLabs mp3), with subtitles. Same look as voiceover_video.swift,
// but the timing comes from TIMING.json instead of the `say` voice.
//
//   swift audio_video.swift SLIDE_DIR NARRATION.mp3 TIMING.json OUTPUT.mp4
//
// TIMING.json:
//   {"slide_starts": [0, 5.3, 14.2, ...],          // seconds, one per slide
//    "cues": [[0.0, 1.5, "Before you pay"], ...],  // optional subtitles: start, end, text
//    "audio_tail": 0.7}                             // optional hold after the audio ends
import AVFoundation
import AppKit
import CoreVideo

let args = CommandLine.arguments
guard args.count == 5 else {
    print("usage: swift audio_video.swift SLIDE_DIR NARRATION.mp3 TIMING.json OUTPUT.mp4")
    exit(1)
}
struct Timing: Decodable {
    let slide_starts: [Double]
    let cues: [[CueField]]?
    let audio_tail: Double?
}
enum CueField: Decodable {
    case number(Double), text(String)
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let d = try? c.decode(Double.self) { self = .number(d) } else { self = .text(try c.decode(String.self)) }
    }
}
let slideDir = URL(fileURLWithPath: args[1])
let audioURL = URL(fileURLWithPath: args[2])
let timing = try JSONDecoder().decode(Timing.self, from: Data(contentsOf: URL(fileURLWithPath: args[3])))
let output = URL(fileURLWithPath: args[4])
let size = CGSize(width: 1080, height: 1920)
let fps: Int32 = 30

let slides = try FileManager.default.contentsOfDirectory(at: slideDir, includingPropertiesForKeys: nil)
    .filter { $0.pathExtension.lowercased() == "png" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
guard slides.count == timing.slide_starts.count else {
    print("need one slide start per slide: \(slides.count) slides, \(timing.slide_starts.count) starts")
    exit(1)
}

struct Cue { let start: Double; let end: Double; let text: String }
let cues: [Cue] = (timing.cues ?? []).compactMap { f in
    guard f.count == 3, case .number(let s) = f[0], case .number(let e) = f[1], case .text(let t) = f[2] else { return nil }
    return Cue(start: s, end: e, text: t)
}

let audioAsset = AVURLAsset(url: audioURL)
let audioSeconds = CMTimeGetSeconds(audioAsset.duration)
let total = audioSeconds + (timing.audio_tail ?? 0.5)

let work = FileManager.default.temporaryDirectory.appendingPathComponent("ls-audiovideo-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: work) }

// MARK: Silent video with subtitles

let silent = work.appendingPathComponent("silent.mp4")
let writer = try AVAssetWriter(outputURL: silent, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: size.width, AVVideoHeightKey: size.height,
])
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
    kCVPixelBufferWidthKey as String: size.width, kCVPixelBufferHeightKey as String: size.height,
])
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime: .zero)

let slideImages = slides.map { NSImage(contentsOf: $0)?.cgImage(forProposedRect: nil, context: nil, hints: nil) }
let subtitleFont = NSFont.systemFont(ofSize: 58, weight: .bold)

func frame(slide: CGImage?, subtitle: String?) -> CVPixelBuffer {
    var buffer: CVPixelBuffer?
    CVPixelBufferCreate(nil, Int(size.width), Int(size.height), kCVPixelFormatType_32ARGB, nil, &buffer)
    let pb = buffer!
    CVPixelBufferLockBaseAddress(pb, [])
    let ctx = CGContext(data: CVPixelBufferGetBaseAddress(pb), width: Int(size.width), height: Int(size.height),
                        bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pb),
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
    ctx.setFillColor(CGColor(red: 13/255, green: 15/255, blue: 18/255, alpha: 1))
    ctx.fill(CGRect(origin: .zero, size: size))
    // Slide sits a little high, leaving room for subtitles underneath.
    var slideBottom = 0.0
    if let img = slide {
        let h = CGFloat(img.height) * size.width / CGFloat(img.width)
        slideBottom = size.height - h - 140
        ctx.draw(img, in: CGRect(x: 0, y: slideBottom, width: size.width, height: h))
    }
    if let text = subtitle, !text.isEmpty {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: subtitleFont, .foregroundColor: NSColor.white, .paragraphStyle: para,
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let box = str.boundingRect(with: CGSize(width: 900, height: 400),
                                   options: [.usesLineFragmentOrigin])
        let boxH = box.height + 36
        let y = max(60, slideBottom / 2 - boxH / 2)
        let rect = CGRect(x: (size.width - box.width) / 2 - 30, y: y, width: box.width + 60, height: boxH)
        NSColor(calibratedWhite: 0, alpha: 0.75).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 22, yRadius: 22).fill()
        str.draw(with: CGRect(x: (size.width - 900) / 2, y: y + 18, width: 900, height: box.height),
                 options: [.usesLineFragmentOrigin])
        NSGraphicsContext.restoreGraphicsState()
    }
    CVPixelBufferUnlockBaseAddress(pb, [])
    return pb
}

let totalFrames = Int((total * Double(fps)).rounded(.up))
var lastKey = ""
var current: CVPixelBuffer?
for f in 0..<totalFrames {
    let t = Double(f) / Double(fps)
    let slideIndex = max(0, (timing.slide_starts.lastIndex { t >= $0 } ?? 0))
    let cue = cues.first { t >= $0.start && t < $0.end }?.text
    let key = "\(slideIndex)|\(cue ?? "")"
    if key != lastKey || current == nil {
        current = frame(slide: slideImages[slideIndex], subtitle: cue)
        lastKey = key
    }
    while !input.isReadyForMoreMediaData { usleep(1000) }
    adaptor.append(current!, withPresentationTime: CMTime(value: Int64(f), timescale: fps))
}
input.markAsFinished()
let written = DispatchSemaphore(value: 0)
writer.finishWriting { written.signal() }
written.wait()
guard writer.status == .completed else { print("video failed: \(String(describing: writer.error))"); exit(1) }

// MARK: Add the narration track

let composition = AVMutableComposition()
let videoAsset = AVURLAsset(url: silent)
let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
try videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: videoAsset.duration),
                               of: videoAsset.tracks(withMediaType: .video)[0], at: .zero)
let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
if let track = audioAsset.tracks(withMediaType: .audio).first {
    try audioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: audioAsset.duration), of: track, at: .zero)
}

try? FileManager.default.removeItem(at: output)
let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)!
export.outputURL = output
export.outputFileType = .mp4
let exported = DispatchSemaphore(value: 0)
export.exportAsynchronously { exported.signal() }
exported.wait()
if export.status == .completed {
    print(output.path)
    print(String(format: "length: %.1f s", total))
} else {
    print("export failed: \(String(describing: export.error))")
    exit(1)
}
