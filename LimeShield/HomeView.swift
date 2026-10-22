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
    /// Shown full screen right after a scan, before the overview opens.
    @State private var revealAnalysis: BillAnalysis?
    @State private var pendingAnalysis: BillAnalysis?
    @State private var nextUp: NextUp?
    /// The flagged total the user last saw on this screen. -1 until first set, so
    /// updating the app doesn't celebrate everything at once.
    @AppStorage("lastSeenFlagged") private var lastSeenFlagged: Double = -1
    @State private var displayedFlagged: Double = 0
    @State private var flaggedDelta: Double = 0
    @State private var celebrate = false
    @State private var glow = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The finding the buddy suggests starting with.
    struct NextUp: Identifiable, Hashable {
        let analysisID: UUID
        let issue: BillIssue
        var id: String { analysisID.uuidString + issue.stateKey }
    }

    private var hasScans: Bool { store.billCount > 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    buddyGreeting
                    if hasScans { resultsHero } else { privacyBadge }
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
            .brandBackground()
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
            .navigationDestination(item: $nextUp) { target in
                nextUpDetail(target)
            }
            .onAppear(perform: refreshFlagged)
        }
        .overlay {
            if celebrate { ConfettiView().transition(.opacity) }
        }
        .sensoryFeedback(.success, trigger: celebrate) { _, new in new }
        .fullScreenCover(item: $revealAnalysis, onDismiss: {
            if let analysis = pendingAnalysis {
                pendingAnalysis = nil
                newAnalysis = analysis
            }
        }) { analysis in
            ScanRevealView(analysis: analysis) {
                pendingAnalysis = analysis
                revealAnalysis = nil
            }
            .environmentObject(settings)
            .environment(\.brandTheme, settings.accentTheme)
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

    // MARK: Buddy greeting

    /// The buddy says what to do next. With open to-do items it offers the most
    /// valuable one; otherwise it nudges towards scanning.
    private var buddyGreeting: some View {
        HStack(alignment: .top, spacing: 14) {
            ShieldBuddy(mood: greetingMood, size: 68)
                .padding(.top, 4)
            BuddyBubble {
                VStack(alignment: .leading, spacing: 10) {
                    Text(greetingText)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Brand.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if let target = suggestedNextUp {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("NEXT UP")
                                .font(.caption2.weight(.heavy))
                                .tracking(0.6)
                                .foregroundStyle(settings.accentColor)
                            Text(target.issue.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(2)
                            if let analysis = store.analyses.first(where: { $0.id == target.analysisID }) {
                                Text(analysis.title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Button {
                            nextUp = target
                        } label: {
                            Label("Show me what to say", systemImage: "bubble.left.and.text.bubble.right")
                                .font(.subheadline.weight(.bold))
                        }
                        .buttonStyle(BrandButtonStyle())
                    }
                }
            }
        }
        .padding(.top, 6)
    }

    /// Highest-value finding still on a to-do list.
    private var suggestedNextUp: NextUp? {
        let todos = store.analyses.filter { !$0.isSample }.flatMap { analysis in
            analysis.todoIssues.map { NextUp(analysisID: analysis.id, issue: $0) }
        }
        return todos.max { ($0.issue.estimatedImpact ?? 0) < ($1.issue.estimatedImpact ?? 0) }
    }

    private var greetingMood: ShieldBuddy.Mood { .happy }

    /// To-do items on real bills only; the sample bill is a demo.
    private var openTodos: Int {
        store.analyses.filter { !$0.isSample }.reduce(0) { $0 + $1.todoIssues.count }
    }

    private var greetingText: String {
        let open = openTodos
        if open > 0 {
            let amount = suggestedNextUp?.issue.estimatedImpact.map { " Want to start with \($0.usd)?" } ?? " Want to start?"
            return "You've got \(open) thing\(open == 1 ? "" : "s") to raise." + amount
        }
        if hasScans { return "All caught up! Scan the next bill when it arrives and I'll check it." }
        return "Hi! I'm your bill buddy. Snap a photo of a medical bill and I'll check it for you."
    }

    @ViewBuilder
    private func nextUpDetail(_ target: NextUp) -> some View {
        if let analysis = store.analyses.first(where: { $0.id == target.analysisID }) {
            IssueDetailView(
                issue: target.issue,
                state: analysis.state(for: target.issue),
                onSetState: { newState in
                    var updated = analysis
                    updated.setState(newState, for: target.issue)
                    store.update(updated)
                })
        }
    }

    // MARK: Flagged total

    /// Counts the total up from what the user last saw, with confetti, whenever it
    /// has grown since their last visit to this screen.
    private func refreshFlagged() {
        let total = store.totalFlagged
        defer { lastSeenFlagged = total }
        guard lastSeenFlagged >= 0, total > lastSeenFlagged + 0.5 else {
            displayedFlagged = total
            flaggedDelta = 0
            return
        }
        flaggedDelta = total - lastSeenFlagged
        displayedFlagged = lastSeenFlagged
        guard !reduceMotion else { displayedFlagged = total; return }
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.easeOut(duration: 1.2)) { displayedFlagged = total }
            withAnimation { celebrate = true }
            try? await Task.sleep(for: .seconds(3))
            withAnimation { celebrate = false }
        }
    }

    /// Once there is history, the logo shrinks and the numbers take the space.
    private var resultsHero: some View {
        VStack(spacing: 6) {
            Text("Flagged so far")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Brand.ink)

            Text(displayedFlagged.usd)
                .font(.system(size: 50, weight: .heavy, design: .rounded))
                .foregroundStyle(settings.accentColor)
                .contentTransition(.numericText(value: displayedFlagged))
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            if flaggedDelta > 0 {
                Text("+ \(flaggedDelta.usd)")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(Brand.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(settings.accentColor.opacity(0.18)))
            }

            HStack(spacing: 6) {
                Text("across \(store.billCount) bill\(store.billCount == 1 ? "" : "s")")
                if openTodos > 0 {
                    Text("·")
                    Text("\(openTodos) still to raise")
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
            BrandCard(radius: 20)
        )
    }

    private var privacyBadge: some View {
        Label(Disclaimers.privacy, systemImage: "lock.fill")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(settings.accentColor.opacity(0.16)))
            .foregroundStyle(Brand.ink)
    }

    // MARK: Scan target

    /// A viewfinder rather than a button, so the main action looks like the thing
    /// it actually does.
    private var scanCard: some View {
        Button {
            startScan()
        } label: {
            ZStack {
                BrandCard(radius: 26)

                ViewfinderCorners(inset: 14, length: 34, radius: 22)
                    .stroke(settings.accentColor, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))

                VStack(spacing: 12) {
                    let colors = Brand.buttonColors(for: settings.accentTheme)
                    ZStack {
                        // Slow breathing glow behind the button.
                        Circle()
                            .fill(colors.fill.opacity(0.35))
                            .frame(width: 96, height: 96)
                            .blur(radius: 14)
                            .scaleEffect(glow ? 1.15 : 0.85)
                            .opacity(glow ? 1 : 0.55)
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(colors.text)
                            .frame(width: 74, height: 74)
                            .background(Circle().fill(colors.fill))
                            .shadow(color: colors.fill.opacity(0.5), radius: 12, x: 0, y: 5)
                    }
                    .onAppear {
                        guard !reduceMotion else { return }
                        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { glow = true }
                    }
                    Text("Scan a bill")
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(Brand.ink)
                    Text("Photograph each page")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 230)
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
                Text(title).font(.subheadline.weight(.bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                BrandCard(radius: 20)
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
            BrandCard(radius: 20)
        )
    }

    private func stepRow(_ number: Int, _ title: String) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.subheadline.weight(.heavy))
                .frame(width: 30, height: 30)
                .background(Circle().fill(Brand.buttonColors(for: settings.accentTheme).fill))
                .foregroundStyle(Brand.buttonColors(for: settings.accentTheme).text)
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
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
        // An insurer EOB, or two bills photographed together, is turned away rather
        // than analysed, so it shouldn't use up one of the free scans.
        let wasAnalysed = bill.kind != .insurerEOB && bill.multipleBillsDetected != true
        if countsAgainstFreeTier && wasAnalysed { purchases.recordScan() }
        revealAnalysis = analysis
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
