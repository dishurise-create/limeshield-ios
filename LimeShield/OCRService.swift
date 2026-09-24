import Foundation
import SwiftUI
// @preconcurrency: Vision's request types predate Swift concurrency and aren't marked
// Sendable, which makes the compiler warn about the background dispatch below. The work
// is confined to a single closure, so the warnings are noise rather than a real hazard.
@preconcurrency import Vision
import VisionKit
import UIKit

// MARK: - OCR output

struct OCRWord: Sendable {
    let text: String
    let box: CGRect   // Vision normalized coordinates (origin bottom-left)
}

// MARK: - Text recognition

enum OCRService {

    /// Runs on-device text recognition on scanned pages. Nothing leaves the phone.
    static func recognize(images: [UIImage]) async throws -> [[OCRWord]] {
        var pages: [[OCRWord]] = []
        for image in images {
            guard let cgImage = image.cgImage else { continue }
            let words: [OCRWord] = try await withCheckedThrowingContinuation { continuation in
                let request = VNRecognizeTextRequest { request, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                    let words = observations.compactMap { obs -> OCRWord? in
                        guard let candidate = obs.topCandidates(1).first else { return nil }
                        return OCRWord(text: candidate.string, box: obs.boundingBox)
                    }
                    continuation.resume(returning: words)
                }
                request.recognitionLevel = .accurate
                // Language correction off: it "fixes" billing codes and amounts.
                request.usesLanguageCorrection = false
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                DispatchQueue.global(qos: .userInitiated).async {
                    do { try handler.perform([request]) }
                    catch { continuation.resume(throwing: error) }
                }
            }
            pages.append(words)
        }
        return pages
    }
}

// MARK: - Document camera (paper bills)

struct DocumentScannerView: UIViewControllerRepresentable {
    var completion: ([UIImage]) -> Void
    @Environment(\.dismiss) private var dismiss

    static var isAvailable: Bool {
        VNDocumentCameraViewController.isSupported
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion, dismiss: { dismiss() })
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let completion: ([UIImage]) -> Void
        let dismiss: () -> Void

        init(completion: @escaping ([UIImage]) -> Void, dismiss: @escaping () -> Void) {
            self.completion = completion
            self.dismiss = dismiss
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            for index in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: index))
            }
            dismiss()
            completion(images)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            dismiss()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            dismiss()
        }
    }
}
