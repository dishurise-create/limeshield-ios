// Turns a folder of slide PNGs into a 1080x1920 MP4 for YouTube Shorts (and
// Reels/X), each slide centred on the Lime Shield background for a few seconds.
// Uses only Apple frameworks, so nothing extra needs installing.
//
//   swift slides_to_video.swift SLIDE_DIR OUTPUT.mp4 [seconds_per_slide]
import AVFoundation
import AppKit
import CoreVideo

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("usage: swift slides_to_video.swift SLIDE_DIR OUTPUT.mp4 [seconds_per_slide]")
    exit(1)
}
let dir = URL(fileURLWithPath: args[1])
let out = URL(fileURLWithPath: args[2])
let secondsPerSlide = args.count > 3 ? Double(args[3]) ?? 3.5 : 3.5
let fps: Int32 = 30
let size = CGSize(width: 1080, height: 1920)

let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
    .filter { $0.pathExtension.lowercased() == "png" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
guard !files.isEmpty else { print("no PNGs in \(dir.path)"); exit(1) }

try? FileManager.default.removeItem(at: out)
let writer = try AVAssetWriter(outputURL: out, fileType: .mp4)
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

func frame(for url: URL) -> CVPixelBuffer {
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
    if let img = NSImage(contentsOf: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
        let scale = size.width / CGFloat(img.width)
        let h = CGFloat(img.height) * scale
        ctx.draw(img, in: CGRect(x: 0, y: (size.height - h) / 2, width: size.width, height: h))
    }
    CVPixelBufferUnlockBaseAddress(pb, [])
    return pb
}

let framesPerSlide = Int(secondsPerSlide * Double(fps))
var frameIndex: Int64 = 0
for file in files {
    let pb = frame(for: file)
    for _ in 0..<framesPerSlide {
        while !input.isReadyForMoreMediaData { usleep(1000) }
        adaptor.append(pb, withPresentationTime: CMTime(value: frameIndex, timescale: fps))
        frameIndex += 1
    }
}
input.markAsFinished()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
print(writer.status == .completed ? out.path : "failed: \(String(describing: writer.error))")
