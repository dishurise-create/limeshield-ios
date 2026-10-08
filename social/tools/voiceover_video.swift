// Makes a 1080x1920 vertical video from slide PNGs with a computer voiceover
// and matching subtitles. Each slide stays on screen while its narration is
// read. Uses macOS's built-in `say` voices and Apple frameworks only.
//
//   swift voiceover_video.swift SLIDE_DIR NARRATION.json OUTPUT.mp4
//
// NARRATION.json is a JSON array with one string per slide, in slide order:
//   ["Your hospital bill is mostly codes.", "Step one: ask for the itemized bill.", ...]
//
// Voice: the best installed English voice is picked automatically. Download a
// natural one in System Settings > Accessibility > Spoken Content > System
// Voice > Manage Voices (e.g. "Ava (Premium)"). Override with LS_VOICE=Name.
import AVFoundation
import AppKit
import CoreVideo

let args = CommandLine.arguments
guard args.count == 4 else {
    print("usage: swift voiceover_video.swift SLIDE_DIR NARRATION.json OUTPUT.mp4")
    exit(1)
}
let slideDir = URL(fileURLWithPath: args[1])
let narration = try JSONDecoder().decode([String].self,
                                         from: Data(contentsOf: URL(fileURLWithPath: args[2])))
let output = URL(fileURLWithPath: args[3])
let size = CGSize(width: 1080, height: 1920)
let fps: Int32 = 30
let tail = 0.5   // pause after each slide's narration, seconds

let slides = try FileManager.default.contentsOfDirectory(at: slideDir, includingPropertiesForKeys: nil)
    .filter { $0.pathExtension.lowercased() == "png" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
guard slides.count == narration.count else {
    print("need one narration line per slide: \(slides.count) slides, \(narration.count) lines")
    exit(1)
}

// MARK: Voice

func run(_ path: String, _ arguments: [String]) -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: path)
    p.arguments = arguments
    let pipe = Pipe()
    p.standardOutput = pipe
    try? p.run()
    p.waitUntilExit()
    return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
}

func pickVoice() -> String {
    if let chosen = ProcessInfo.processInfo.environment["LS_VOICE"] { return chosen }
    let installed = run("/usr/bin/say", ["-v", "?"])
    let preferred = ["Ava (Premium)", "Zoe (Premium)", "Evan (Premium)", "Nathan (Premium)",
                     "Ava (Enhanced)", "Zoe (Enhanced)", "Evan (Enhanced)", "Samantha (Enhanced)",
                     "Samantha"]
    return preferred.first { installed.contains($0 + " ") } ?? "Samantha"
}
let voice = pickVoice()
print("voice: \(voice)")

let work = FileManager.default.temporaryDirectory.appendingPathComponent("ls-voiceover-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: work) }

var clips: [URL] = []
var durations: [Double] = []
for (i, text) in narration.enumerated() {
    let clip = work.appendingPathComponent("\(i).aiff")
    _ = run("/usr/bin/say", ["-v", voice, "-r", "185", "-o", clip.path, text])
    let seconds = CMTimeGetSeconds(AVURLAsset(url: clip).duration)
    clips.append(clip)
    durations.append((seconds.isFinite && seconds > 0 ? seconds : 2) + tail)
}

// MARK: Subtitles: short phrases, timed by word count within each slide

struct Cue { let start: Double; let end: Double; let text: String }
var cues: [Cue] = []
var slideStart = 0.0
for (i, text) in narration.enumerated() {
    let words = text.split(separator: " ").map(String.init)
    var chunks: [[String]] = []
    for w in words {
        if chunks.isEmpty || chunks[chunks.count - 1].count >= 5 { chunks.append([w]) }
        else { chunks[chunks.count - 1].append(w) }
    }
    let speaking = durations[i] - tail
    var t = slideStart
    for chunk in chunks {
        let len = speaking * Double(chunk.count) / Double(max(words.count, 1))
        cues.append(Cue(start: t, end: t + len, text: chunk.joined(separator: " ")))
        t += len
    }
    slideStart += durations[i]
}

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

let totalFrames = Int((durations.reduce(0, +) * Double(fps)).rounded(.up))
var lastKey = ""
var current: CVPixelBuffer?
var boundaries: [Double] = []
var acc = 0.0
for d in durations { acc += d; boundaries.append(acc) }
for f in 0..<totalFrames {
    let t = Double(f) / Double(fps)
    let slideIndex = min(boundaries.firstIndex { t < $0 } ?? slides.count - 1, slides.count - 1)
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
var at = CMTime.zero
for (i, clip) in clips.enumerated() {
    let asset = AVURLAsset(url: clip)
    if let track = asset.tracks(withMediaType: .audio).first {
        try audioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: asset.duration), of: track, at: at)
    }
    at = CMTimeAdd(at, CMTime(seconds: durations[i], preferredTimescale: 600))
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
    print(String(format: "length: %.1f s", durations.reduce(0, +)))
} else {
    print("export failed: \(String(describing: export.error))")
    exit(1)
}
