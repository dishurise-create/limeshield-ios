import SwiftUI

// MARK: - Shield buddy

/// Lime Shield's character: the shield from the icon with a face. It blinks and
/// bobs gently, and its expression follows what the app is doing. Drawn in code,
/// coloured from the accent picked in Settings.
struct ShieldBuddy: View {
    enum Mood { case happy, wow, thinking }

    var mood: Mood = .happy
    var size: CGFloat = 80

    @Environment(\.brandTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 0 = open, 1 = shut. Animated, so the lid closes and opens smoothly.
    @State private var lid: CGFloat = 0
    /// Where the pupils look, from -1 to 1 on each axis.
    @State private var gaze: CGSize = .zero
    @State private var bob = false

    var body: some View {
        ZStack {
            ShieldShape()
                .fill(theme.bright)
                .shadow(color: theme.bright.opacity(0.55), radius: size * 0.18)
            ShieldShape()
                .fill(Color.white.opacity(0.22))
                .scaleEffect(0.8)
                .offset(y: -size * 0.03)
            face
        }
        .frame(width: size, height: size * 1.12)
        .offset(y: bob ? -size * 0.04 : size * 0.02)
        .accessibilityHidden(true)
        .onChange(of: mood) { _, _ in
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { gaze = restingGaze }
        }
        .task {
            gaze = restingGaze
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { bob = true }
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await blinkLoop() }
                group.addTask { await lookLoop() }
            }
        }
    }

    /// Where the eyes settle for each mood: thinking looks up and to the side,
    /// surprised looks straight out, happy looks slightly down at the screen.
    private var restingGaze: CGSize {
        switch mood {
        case .thinking: return CGSize(width: 0.55, height: -0.6)
        case .wow:      return .zero
        case .happy:    return CGSize(width: 0, height: 0.25)
        }
    }

    /// Blinks at uneven intervals, sometimes twice in a row, like a person.
    /// Closing is quick and opening a little slower.
    @MainActor private func blinkLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Double.random(in: 2.2...5.0)))
            let times = Double.random(in: 0...1) < 0.2 ? 2 : 1
            for _ in 0..<times {
                withAnimation(.easeIn(duration: 0.07)) { lid = 1 }
                try? await Task.sleep(for: .milliseconds(80))
                withAnimation(.easeOut(duration: 0.14)) { lid = 0 }
                try? await Task.sleep(for: .milliseconds(170))
            }
        }
    }

    /// Glances somewhere new, holds it for a moment, then drifts back to the
    /// resting point. Springs make each eye movement ease in and settle.
    @MainActor private func lookLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Double.random(in: 1.4...3.2)))
            let target = CGSize(width: .random(in: -0.9...0.9), height: .random(in: -0.6...0.7))
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { gaze = target }
            try? await Task.sleep(for: .seconds(Double.random(in: 0.7...1.6)))
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { gaze = restingGaze }
        }
    }

    private var face: some View {
        let eye = size * 0.17
        let eyeHeight = eye * 1.2
        return VStack(spacing: size * 0.07) {
            HStack(spacing: size * 0.2) {
                ForEach(0..<2, id: \.self) { _ in
                    ZStack {
                        Capsule().fill(.white)
                        Circle().fill(theme.deep)
                            .frame(width: eye * 0.52)
                            // Pupils move within the white, and both eyes move together.
                            .offset(x: gaze.width * eye * 0.22, y: gaze.height * eyeHeight * 0.22)
                    }
                    .frame(width: eye, height: eyeHeight)
                    .clipShape(Capsule())
                    // The lid squashes the whole eye towards a line.
                    .scaleEffect(x: 1, y: max(0.1, 1 - lid * 0.9), anchor: .center)
                }
            }
            mouth
        }
        .offset(y: -size * 0.06)
    }

    @ViewBuilder private var mouth: some View {
        switch mood {
        case .wow:
            Ellipse().fill(theme.deep).frame(width: size * 0.15, height: size * 0.19)
        case .thinking:
            Capsule().fill(theme.deep).frame(width: size * 0.18, height: size * 0.045)
        case .happy:
            SmileShape()
                .stroke(theme.deep, style: StrokeStyle(lineWidth: size * 0.06, lineCap: .round))
                .frame(width: size * 0.32, height: size * 0.12)
        }
    }
}

struct ShieldShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.16),
                       control: CGPoint(x: r.maxX * 0.85, y: r.minY + r.height * 0.02))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.5))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY),
                       control: CGPoint(x: r.maxX, y: r.minY + r.height * 0.82))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.5),
                       control: CGPoint(x: r.minX, y: r.minY + r.height * 0.82))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.16))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.minY),
                       control: CGPoint(x: r.maxX * 0.15, y: r.minY + r.height * 0.02))
        p.closeSubpath()
        return p
    }
}

private struct SmileShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY), control: CGPoint(x: r.midX, y: r.maxY * 1.6))
        return p
    }
}

/// Speech bubble with a small tail pointing left, towards the buddy.
struct BuddyBubble<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BrandCard(radius: 20))
            .overlay(alignment: .topLeading) {
                Triangle()
                    .fill(Brand.card)
                    .frame(width: 14, height: 16)
                    .offset(x: -11, y: 22)
            }
    }
}

private struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX, y: r.midY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Confetti

/// A short burst of falling confetti. Doesn't block taps. Shown when the home
/// screen's flagged total goes up. Each piece is a plain view with a normal
/// SwiftUI animation (no frame timer), so it draws reliably right after other
/// screens close.
struct ConfettiView: View {
    private struct Piece: Identifiable {
        let id = UUID()
        let x: CGFloat, drift: CGFloat, spin: Double, size: CGFloat
        let delay: Double, duration: Double, color: Color
    }

    @Environment(\.brandTheme) private var theme
    @State private var pieces: [Piece] = []
    @State private var fallen = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(pieces) { p in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(p.color)
                        .frame(width: p.size, height: p.size * 2)
                        .rotationEffect(.degrees(fallen ? p.spin : 0))
                        .position(x: p.x * geo.size.width + (fallen ? p.drift : 0),
                                  y: fallen ? geo.size.height + 40 : -30)
                        .opacity(fallen ? 0 : 1)
                        .animation(.easeIn(duration: p.duration).delay(p.delay), value: fallen)
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .onAppear {
            let colors: [Color] = [theme.bright, theme.color, .orange, .yellow, .pink, .blue]
            pieces = (0..<80).map { _ in
                Piece(x: .random(in: 0...1), drift: .random(in: -70...70), spin: .random(in: -540...540),
                      size: .random(in: 5...9), delay: .random(in: 0...0.5),
                      duration: .random(in: 1.8...2.8), color: colors.randomElement()!)
            }
            // Next run loop, so the pieces are on screen at the top before falling.
            DispatchQueue.main.async { fallen = true }
        }
    }
}

// MARK: - Bill X-ray (shown right after a scan)

/// Redraws the scanned bill as clean paper, sweeps a glowing beam down it and
/// lights up the lines behind each finding, then the buddy pops up with what it
/// found. Built from the parsed lines, so no photo is kept.
struct ScanRevealView: View {
    let analysis: BillAnalysis
    let onDone: () -> Void

    private enum Phase { case scanning, found }

    @Environment(\.brandTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: Phase = .scanning
    @State private var lit = 0
    @State private var beam: CGFloat = 0
    @State private var flaggedLit = 0

    private struct Row: Identifiable {
        let id = UUID()
        let text: String
        let amount: String
        let color: Color?
    }

    private var rows: [Row] {
        let evidence = analysis.issues.flatMap { issue in issue.evidence.map { ($0.lowercased(), issue.severity) } }
        func flag(_ line: BillLine) -> Color? {
            let desc = line.desc.lowercased().trimmingCharacters(in: .whitespaces)
            guard desc.count >= 3 else { return nil }
            return evidence.first { $0.0.contains(desc) }?.1.color
        }
        let all = analysis.bill.lines
        let flaggedIDs = Set(all.filter { flag($0) != nil }.map(\.id))
        var picked = all.filter { flaggedIDs.contains($0.id) }
        for line in all where picked.count < 8 && !flaggedIDs.contains(line.id) { picked.append(line) }
        let order = Dictionary(uniqueKeysWithValues: all.enumerated().map { ($1.id, $0) })
        picked.sort { (order[$0.id] ?? 0) < (order[$1.id] ?? 0) }
        var out = picked.prefix(8).map {
            Row(text: String($0.desc.prefix(22)).uppercased(), amount: $0.amount?.usd ?? "", color: flag($0))
        }
        if let total = analysis.bill.totals.totalCharges ?? analysis.bill.totals.amountDue {
            let mathIssue = analysis.issues.contains { $0.ruleID.hasPrefix("math") }
            out.append(Row(text: "TOTAL", amount: total.usd, color: mathIssue ? IssueSeverity.likelyError.color : nil))
        }
        return out
    }

    var body: some View {
        let rows = rows
        VStack(spacing: 24) {
            Spacer(minLength: 0)
            if phase == .found {
                VStack(spacing: 12) {
                    ShieldBuddy(mood: buddyMood, size: 96)
                    Text(foundTitle)
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(Brand.ink)
                        .multilineTextAlignment(.center)
                    Text(foundSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .transition(.scale(scale: 0.4).combined(with: .opacity))
            } else {
                Text("Reading your bill…")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(Brand.ink)
            }

            paper(rows)
                .scaleEffect(phase == .found ? 0.82 : 1)

            if phase == .found {
                Button(action: onDone) {
                    Text("See the overview").font(.headline)
                }
                .buttonStyle(BrandButtonStyle())
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .sensoryFeedback(.impact(weight: .light), trigger: flaggedLit)
        .sensoryFeedback(.success, trigger: phase == .found)
        .task { await run(rows) }
    }

    private func paper(_ rows: [Row]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                let on = index < lit
                HStack {
                    Text(row.text).lineLimit(1)
                    Spacer()
                    Text(row.amount)
                }
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.75))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background {
                    if let color = row.color, on {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(color, lineWidth: 2.5)
                            .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.12)))
                            .shadow(color: color.opacity(0.8), radius: 8)
                            .transition(.opacity.combined(with: .scale(scale: 1.08)))
                    }
                }
            }
        }
        .padding(14)
        .background(BrandCard(radius: 16))
        .overlay(alignment: .top) {
            if phase == .scanning && !reduceMotion {
                GeometryReader { geo in
                    Rectangle()
                        .fill(theme.bright)
                        .frame(height: 3)
                        .shadow(color: theme.bright, radius: 10)
                        .shadow(color: theme.bright.opacity(0.7), radius: 22)
                        .offset(y: beam * geo.size.height)
                }
            }
        }
    }

    private var buddyMood: ShieldBuddy.Mood {
        analysis.issues.isEmpty ? .happy : .wow
    }

    private var foundTitle: String {
        if analysis.bill.kind == .insurerEOB { return "This looks like an EOB" }
        if analysis.issues.contains(where: { $0.ruleID == "multiple_bills" }) { return "That's more than one bill" }
        let n = analysis.issues.count
        if n == 0 { return "Looks clean!" }
        return "I found \(n) thing\(n == 1 ? "" : "s") to look at!"
    }

    private var foundSubtitle: String {
        if analysis.bill.kind == .insurerEOB { return "An insurer's statement isn't a bill. I'll explain." }
        if analysis.issues.isEmpty { return "Nothing suspicious on this bill." }
        return "Tap me on the next screen and I'll walk you through each one."
    }

    private func run(_ rows: [Row]) async {
        if reduceMotion {
            lit = rows.count
            phase = .found
            return
        }
        let step = 1.6 / Double(max(rows.count, 1))
        withAnimation(.linear(duration: 1.6)) { beam = 1 }
        for index in rows.indices {
            try? await Task.sleep(for: .seconds(step))
            withAnimation(.spring(duration: 0.3)) { lit = index + 1 }
            if rows[index].color != nil { flaggedLit += 1 }
        }
        try? await Task.sleep(for: .milliseconds(450))
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { phase = .found }
    }
}

// MARK: - Buddy walkthrough (from the overview)

/// The buddy explains each finding one at a time, in plain words, with what to
/// ask and a button to put it on the to-do list.
struct BuddyWalkthroughView: View {
    let analysis: BillAnalysis
    let onSetState: (BillIssue, FindingState?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var page = 0
    @State private var added: Set<String> = []

    private var issues: [BillIssue] {
        analysis.issues.sorted {
            if $0.severity.rank != $1.severity.rank { return $0.severity.rank < $1.severity.rank }
            return ($0.estimatedImpact ?? 0) > ($1.estimatedImpact ?? 0)
        }
    }

    var body: some View {
        let issues = issues
        NavigationStack {
            VStack(spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    ShieldBuddy(mood: .happy, size: 64)
                    BuddyBubble {
                        Text(line(for: issues[page], index: page, of: issues.count))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Brand.ink)
                    }
                }
                .padding(.horizontal, 20)

                TabView(selection: $page) {
                    ForEach(Array(issues.enumerated()), id: \.element.id) { index, issue in
                        card(issue).tag(index).padding(.horizontal, 20)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 6) {
                    ForEach(issues.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? AnyShapeStyle(Brand.fill) : AnyShapeStyle(Color.secondary.opacity(0.3)))
                            .frame(width: i == page ? 22 : 8, height: 8)
                    }
                }
                .animation(.spring(duration: 0.3), value: page)

                Button {
                    if page < issues.count - 1 { withAnimation { page += 1 } } else { dismiss() }
                } label: {
                    Text(page < issues.count - 1 ? "Next" : "Done").font(.headline)
                }
                .buttonStyle(BrandButtonStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            .padding(.top, 8)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("\(page + 1) of \(issues.count)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } }
            }
            .sensoryFeedback(.selection, trigger: page)
        }
    }

    private func line(for issue: BillIssue, index: Int, of count: Int) -> String {
        let opener: String
        switch issue.severity {
        case .likelyError:    opener = "This one is a math problem."
        case .worthChecking:  opener = "This one is worth a question."
        case .knowYourRights: opener = "This one is good to know."
        }
        return index == count - 1 && count > 1 ? opener + " Last one!" : opener
    }

    private func card(_ issue: BillIssue) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Pill(text: issue.severity.title, color: issue.severity.color)
                    if let impact = issue.estimatedImpact, impact > 0 {
                        Pill(text: impact.usd, color: Color.accentColor)
                    }
                }
                Text(issue.title)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(Brand.ink)
                Text(issue.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if let first = issue.evidence.first {
                    Text(first)
                        .font(.caption.monospaced())
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.tertiarySystemFill)))
                }
                if issue.severity != .knowYourRights {
                    VStack(alignment: .leading, spacing: 6) {
                        SectionLabel(text: "What to ask", count: nil)
                        Text(issue.action).font(.callout.weight(.medium)).foregroundStyle(Brand.ink)
                    }
                    let isAdded = added.contains(issue.stateKey) || analysis.state(for: issue) == .todo
                    Button {
                        added.insert(issue.stateKey)
                        onSetState(issue, .todo)
                    } label: {
                        Label(isAdded ? "On your list" : "Add to my list",
                              systemImage: isAdded ? "checkmark.circle.fill" : "plus.circle")
                            .font(.subheadline.weight(.bold))
                    }
                    .disabled(isAdded)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BrandCard(radius: 24))
            .padding(.vertical, 6)
        }
    }
}
