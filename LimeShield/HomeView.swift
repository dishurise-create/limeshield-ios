import SwiftUI
import PhotosUI
import UIKit

struct HomeView: View {
    @EnvironmentObject private var store: AnalysisStore
    @EnvironmentObject private var purchases: PurchaseManager
    @EnvironmentObject private var settings: AppSettings

    @State private var showScanner = false
    @State private var showPhotoPicker = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var isProcessing = false
    @State private var newAnalysis: BillAnalysis?
    @State private var showPaywall = false
    @State private var errorMessage: String?

    private var hasScans: Bool { store.billCount > 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    if hasScans {
                        // The mark stays on the page once there is history too, just
                        // smaller, so the screen still reads as Lime Shield rather
                        // than as a bare number.
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 72, height: 72)
                            .accessibilityHidden(true)
                        resultsHero
                    } else {
                        firstRunHero
                    }
                    scanCard
                    secondaryRow
                    if !hasScans { steps }
                    if let note = quotaNote {
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Lime Shield")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") }
                }
            }
            .navigationDestination(item: $newAnalysis) { analysis in
                AnalysisView(analysis: analysis)
            }
        }
        .sheet(isPresented: $showScanner) {
            DocumentScannerView { images in
                Task { await process(images: images) }
            }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItems,
                      maxSelectionCount: 4, matching: .images)
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await processPhotoItems(items) }
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .overlay { if isProcessing { processingOverlay } }
        .alert("Couldn't read that scan",
               isPresented: Binding(get: { errorMessage != nil },
                                    set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: Hero, first run

    private var firstRunHero: some View {
        VStack(spacing: 14) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)

            Text("Know what to question\nbefore you pay.")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            privacyBadge
        }
        .padding(.top, 6)
    }

    /// Once there is history, the logo shrinks and the numbers take the space.
    private var resultsHero: some View {
        VStack(spacing: 6) {
            Text("Flagged so far")
                .font(.caption.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)

            Text(store.totalFlagged.usd)
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .foregroundStyle(settings.accentColor)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            HStack(spacing: 6) {
                Text("across \(store.billCount) bill\(store.billCount == 1 ? "" : "s")")
                if store.openTodoCount > 0 {
                    Text("·")
                    Text("\(store.openTodoCount) still to raise")
                        .foregroundStyle(settings.accentColor)
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            privacyBadge.padding(.top, 10)
        }
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var privacyBadge: some View {
        Label(Disclaimers.privacy, systemImage: "lock.fill")
            .font(.caption.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(settings.accentColor.opacity(0.14)))
            .foregroundStyle(settings.accentColor)
    }

    // MARK: Scan target

    /// A viewfinder rather than a button, so the main action looks like the thing
    /// it actually does.
    private var scanCard: some View {
        Button {
            startScan()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(settings.accentColor.opacity(0.10))

                ViewfinderCorners(inset: 14, length: 34, radius: 22)
                    .stroke(settings.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))

                VStack(spacing: 10) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 40, weight: .regular))
                    Text("Scan a bill")
                        .font(.title3.weight(.semibold))
                    Text("Photograph each page")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(settings.accentColor)
            }
            .frame(height: 190)
        }
        .buttonStyle(.plain)
    }

    private var secondaryRow: some View {
        HStack(spacing: 12) {
            secondaryButton("Photos", "photo.on.rectangle") {
                guard purchases.canScan else { showPaywall = true; return }
                showPhotoPicker = true
            }
            secondaryButton("Sample", "doc.text") {
                Task { await processSample() }
            }
        }
    }

    private func secondaryButton(_ title: String, _ icon: String,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.subheadline)
                Text(title).font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(settings.accentColor)
    }

    // MARK: First-run explainer

    private var steps: some View {
        VStack(spacing: 0) {
            stepRow(1, "Photograph the bill")
            Divider().opacity(0.4)
            stepRow(2, "See what to question")
            Divider().opacity(0.4)
            stepRow(3, "Send the letter")
        }
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func stepRow(_ number: Int, _ title: String) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .frame(width: 22, height: 22)
                .background(Circle().fill(settings.accentColor.opacity(0.16)))
                .foregroundStyle(settings.accentColor)
            Text(title).font(.subheadline)
            Spacer()
        }
        .padding(.vertical, 13)
    }

    private var quotaNote: String? {
        guard purchases.isConfigured, !purchases.isPro else { return nil }
        let left = purchases.freeScansRemaining
        if left > 0 { return "\(left) free scan\(left == 1 ? "" : "s") left" }
        return "Free scans used. Pro unlocks unlimited."
    }

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView().controlSize(.large)
                Text("Reading your bill").font(.headline)
                Text(Disclaimers.privacy)
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(28)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.regularMaterial))
        }
    }

    // MARK: Processing

    private func startScan() {
        guard purchases.canScan else { showPaywall = true; return }
        if DocumentScannerView.isAvailable { showScanner = true }
        else { showPhotoPicker = true }
    }

    private func process(images: [UIImage]) async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            let pages = try await OCRService.recognize(images: images)
            let wordCount = pages.reduce(0) { $0 + $1.count }
            guard wordCount >= 5 else {
                errorMessage = "Not enough readable text found. Try better lighting and hold the phone flat over the bill."
                return
            }
            let bill = BillParser.parse(pages: pages)
            finish(bill: bill)
        } catch {
            errorMessage = "Text recognition failed: \(error.localizedDescription)"
        }
    }

    private func processPhotoItems(_ items: [PhotosPickerItem]) async {
        var images: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }
        photoItems = []
        guard !images.isEmpty else { return }
        await process(images: images)
    }

    private func processSample() async {
        isProcessing = true
        try? await Task.sleep(nanoseconds: 600_000_000)
        let bill = BillParser.parse(text: SampleBill.text)
        isProcessing = false
        finish(bill: bill, title: "Sample bill", countsAgainstFreeTier: false)
    }

    private func finish(bill: Bill, title: String? = nil, countsAgainstFreeTier: Bool = true) {
        let issues = RulesEngine.analyze(bill)
        let analysis = BillAnalysis(
            title: title ?? bill.providerName ?? "Scanned bill",
            bill: bill,
            issues: issues)
        store.add(analysis)
        if countsAgainstFreeTier { purchases.recordScan() }
        newAnalysis = analysis
    }
}

// MARK: - Viewfinder

/// Four corner brackets, drawn as one path. Echoes the camera framing people already
/// associate with scanning, and matches the corners on the app icon.
struct ViewfinderCorners: Shape {
    var inset: CGFloat = 14
    var length: CGFloat = 34
    var radius: CGFloat = 22

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        let c = min(radius, min(r.width, r.height) / 2)
        var path = Path()

        // Top left
        path.move(to: CGPoint(x: r.minX, y: r.minY + c + length))
        path.addLine(to: CGPoint(x: r.minX, y: r.minY + c))
        path.addArc(center: CGPoint(x: r.minX + c, y: r.minY + c), radius: c,
                    startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.addLine(to: CGPoint(x: r.minX + c + length, y: r.minY))

        // Top right
        path.move(to: CGPoint(x: r.maxX - c - length, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX - c, y: r.minY))
        path.addArc(center: CGPoint(x: r.maxX - c, y: r.minY + c), radius: c,
                    startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY + c + length))

        // Bottom right
        path.move(to: CGPoint(x: r.maxX, y: r.maxY - c - length))
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY - c))
        path.addArc(center: CGPoint(x: r.maxX - c, y: r.maxY - c), radius: c,
                    startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: r.maxX - c - length, y: r.maxY))

        // Bottom left
        path.move(to: CGPoint(x: r.minX + c + length, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX + c, y: r.maxY))
        path.addArc(center: CGPoint(x: r.minX + c, y: r.maxY - c), radius: c,
                    startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: r.minX, y: r.maxY - c - length))

        return path
    }
}
