// Turns a folder of numbered PNG frames into an MP4 at a fixed frame rate.
// Uses only Apple frameworks, so nothing extra needs installing.
//
//   swift frames_to_video.swift FRAME_DIR OUTPUT.mp4 [fps]
import AVFoundation
import AppKit
import CoreVideo

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("usage: swift frames_to_video.swift FRAME_DIR OUTPUT.mp4 [fps]")
    exit(1)
}
let dir = URL(fileURLWithPath: args[1])
let out = URL(fileURLWithPath: args[2])
let fps = Int32(args.count > 3 ? Int(args[3]) ?? 30 : 30)

let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
    .filter { $0.pathExtension.lowercased() == "png" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
guard let first = files.first, let firstImage = NSImage(contentsOf: first),
      let firstCG = firstImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    print("no PNG frames in \(dir.path)"); exit(1)
}
let size = CGSize(width: firstCG.width, height: firstCG.height)

try? FileManager.default.removeItem(at: out)
let writer = try AVAssetWriter(outputURL: out, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: size.width, AVVideoHeightKey: size.height,
    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 8_000_000],
])
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
    kCVPixelBufferWidthKey as String: size.width, kCVPixelBufferHeightKey as String: size.height,
])
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime: .zero)

func buffer(for cg: CGImage) -> CVPixelBuffer? {
    var pb: CVPixelBuffer?
    CVPixelBufferCreate(nil, Int(size.width), Int(size.height), kCVPixelFormatType_32ARGB, nil, &pb)
    guard let pb else { return nil }
    CVPixelBufferLockBaseAddress(pb, [])
    let ctx = CGContext(data: CVPixelBufferGetBaseAddress(pb), width: Int(size.width), height: Int(size.height),
                        bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pb),
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
    ctx?.draw(cg, in: CGRect(origin: .zero, size: size))
    CVPixelBufferUnlockBaseAddress(pb, [])
    return pb
}

for (i, file) in files.enumerated() {
    guard let img = NSImage(contentsOf: file),
          let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil),
          let pb = buffer(for: cg) else { continue }
    while !input.isReadyForMoreMediaData { usleep(2000) }
    adaptor.append(pb, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: fps))
}
input.markAsFinished()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
print("wrote \(out.path) (\(files.count) frames, \(fps) fps)")
