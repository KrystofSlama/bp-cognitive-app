//
//  Test4-RWY.swift
//  Kacka
//
//  Created by Kryštof Sláma on 23.12.2025.
//

import SwiftData
import SwiftUI
internal import Combine

struct Set2Test4View: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: NavigationRouter
    @EnvironmentObject private var resultsStore: ResultsStore
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = RunwayTaskViewModel()
    @State private var hasRecordedResult = false
    @State private var testStarted = false

    var body: some View {
        ZStack {
            mainContent
                .padding()
                .onReceive(viewModel.tickTimer) { _ in
                    viewModel.tick()
                }
                .onChange(of: viewModel.showResults) { isComplete in
                    guard isComplete else { return }
                    recordResultIfNeeded()
                }

            ArrowKeyHandlingView { direction in
                guard testStarted else { return }
                viewModel.handleSelection(direction)
            }
            .allowsHitTesting(false)

            if viewModel.showResults {
                resultsOverlay
            }
        }
        .navigationBarBackButtonHidden()
    }

    private var mainContent: some View {
        VStack(alignment: .center) {
            Text("Stroop Test - Runway (RWY)")
                .font(.system(size: 48)).bold()
                .padding(.bottom, 16)
            VStack(spacing: 6) {
                Text("Runway graphics show a heading number and an arrow. Ignore the visual arrow and respond using the keyboard arrow that matches the runway heading (e.g., 18 is ↓, 09 is →).")
                    .multilineTextAlignment(.center)
                    .font(.title3)
                Text("Use ↑ for North (S), ↓ for South (J), ← for West (Z), and → for East (V).")
                    .multilineTextAlignment(.center)
                    .font(.title3)
            }
            Spacer()

            if testStarted {
                if let stimulus = viewModel.currentStimulus {
                    runwayCard(for: stimulus)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 200)
                        .overlay(
                            Text("Preparing next runway…")
                                .foregroundStyle(.secondary)
                        )
                }
                Spacer()
                
                
                // Timer
                VStack(alignment: .leading, spacing: 4) {
                    Text("Time remaining: \(Int(viewModel.timeRemaining))s")
                        .font(.subheadline)
                        .monospacedDigit()
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.2))
                            Capsule()
                                .fill(Color.accentColor)
                                .frame(width: geometry.size.width * CGFloat(viewModel.timeRemaining / RunwayTaskViewModel.totalDuration))
                                .animation(.easeInOut(duration: 0.3), value: viewModel.timeRemaining)
                        }
                    }
                    .frame(height: 12)
                }
            } else {
                if let preview = RunwayTaskViewModel.stimuli.first {
                    runwayCard(for: preview)
                        .frame(maxHeight: 280)
                }
                
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { testStarted = true }
                    viewModel.start()
                } label: {
                    Text("Begin")
                        .font(.title)
                        .bold()
                        .padding(4)
                }
                .foregroundStyle(.green)
            }
        }.padding(32)
    }

    private func runwayCard(for stimulus: RunwayStimulus) -> some View {
        VStack(spacing: 12) {
            Image(stimulus.imageName)
                .resizable()
                .scaledToFit()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.accentColor.opacity(0.35), lineWidth: 2)
                )
        }
    }

    private var directionPad: some View {
        VStack(spacing: 12) {
            Text("Respond with arrows")
                .font(.headline)

            HStack(spacing: 16) {
                Spacer()
                directionButton(direction: .z, systemName: "arrow.left.circle.fill")
                Spacer()
                directionButton(direction: .s, systemName: "arrow.up.circle.fill")
                Spacer()
                directionButton(direction: .j, systemName: "arrow.down.circle.fill")
                Spacer()
                directionButton(direction: .v, systemName: "arrow.right.circle.fill")
                Spacer()
            }
        }
    }

    private func directionButton(direction: CompassDirection, systemName: String) -> some View {
        Button {
            viewModel.handleSelection(direction)
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 44, weight: .bold))
                .frame(width: 100, height: 80)
        }
        .buttonStyle(.borderedProminent)
        .tint(.accentColor)
        .disabled(viewModel.showResults)
    }

    private var resultsOverlay: some View {
        VStack(spacing: 8) {
            Text("Results")
                .font(.largeTitle)
                .bold()

            VStack(alignment: .leading, spacing: 2) {
                Text("Total responses: \(viewModel.totalResponses)")
                    .font(.title3)
                Text("Correct responses: \(viewModel.correctResponses)")
                    .font(.title3)
                Text("Incorrect responses: \(viewModel.incorrectResponses)")
                    .font(.title3)
                if let average = viewModel.averageResponseTime {
                    Text(String(format: "Average response time: %.0f ms", average * 1000))
                        .font(.title3)
                } else {
                    Text("Average response time: n/a")
                        .font(.title3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: proceedToNextTest) {
                Text("Continue to FEAST Test")
                    .font(.title)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .frame(maxWidth: 300)
        .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial))
    }
}

// MARK: - View model
/*
final class Set2RunwayTaskViewModel: ObservableObject {
    @Published var currentStimulus: RunwayStimulus? = nil
    @Published var timeRemaining: TimeInterval = totalDuration
    @Published var showResults = false
    @Published var lastResponseWasCorrect: Bool? = nil

    @Published private(set) var correctResponses = 0
    @Published private(set) var incorrectResponses = 0
    @Published private(set) var totalResponses = 0

    private var sessionEndDate: Date?
    private var responseTimes: [TimeInterval] = []
    private var trialStartTime: Date?
    private var nextTrialWorkItem: DispatchWorkItem?

    static let totalDuration: TimeInterval = 60

    var tickTimer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    static let stimuli: [RunwayStimulus] = [
        RunwayStimulus(imageName: "RWY_00", headingNumber: 0),
        RunwayStimulus(imageName: "RWY_09", headingNumber: 9),
        RunwayStimulus(imageName: "RWY_18", headingNumber: 18),
        RunwayStimulus(imageName: "RWY_27", headingNumber: 27),
        RunwayStimulus(imageName: "RWY_00_2", headingNumber: 0),
        RunwayStimulus(imageName: "RWY_09_2", headingNumber: 9),
        RunwayStimulus(imageName: "RWY_18_2", headingNumber: 18),
        RunwayStimulus(imageName: "RWY_27_2", headingNumber: 27),
        RunwayStimulus(imageName: "RWY_00_3", headingNumber: 0),
        RunwayStimulus(imageName: "RWY_09_3", headingNumber: 9),
        RunwayStimulus(imageName: "RWY_18_3", headingNumber: 18),
        RunwayStimulus(imageName: "RWY_27_3", headingNumber: 27),
    ]

    var averageResponseTime: TimeInterval? {
        guard !responseTimes.isEmpty else { return nil }
        let total = responseTimes.reduce(0, +)
        return total / Double(responseTimes.count)
    }

    func start() {
        nextTrialWorkItem?.cancel()
        correctResponses = 0
        incorrectResponses = 0
        totalResponses = 0
        responseTimes.removeAll()
        showResults = false
        lastResponseWasCorrect = nil

        timeRemaining = Self.totalDuration
        sessionEndDate = Date().addingTimeInterval(Self.totalDuration)
        presentNewTrial()
    }

    func tick() {
        guard let sessionEndDate else { return }
        let remaining = max(0, sessionEndDate.timeIntervalSinceNow)
        timeRemaining = remaining

        if remaining <= 0 {
            finishSession()
        }
    }

    func handleSelection(_ direction: CompassDirection) {
        guard !showResults else { return }
        guard let expected = currentStimulus?.expectedDirection else { return }

        totalResponses += 1

        let now = Date()
        if let start = trialStartTime {
            responseTimes.append(now.timeIntervalSince(start))
        }

        if direction == expected {
            correctResponses += 1
            lastResponseWasCorrect = true
        } else {
            incorrectResponses += 1
            lastResponseWasCorrect = false
        }

        trialStartTime = nil
        currentStimulus = nil
        scheduleNextTrial()
    }

    private func presentNewTrial() {
        guard !showResults else { return }
        nextTrialWorkItem?.cancel()
        guard let stimulus = Self.stimuli.randomElement() else {
            finishSession()
            return
        }
        currentStimulus = stimulus
        trialStartTime = Date()
    }

    private func scheduleNextTrial() {
        nextTrialWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            presentNewTrial()
        }

        nextTrialWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    private func finishSession() {
        nextTrialWorkItem?.cancel()
        showResults = true
        currentStimulus = nil
    }
}
*/
// MARK: - Models
/*
struct RunwayStimulus: Identifiable {
    let id = UUID()
    let imageName: String
    let headingNumber: Int

    var headingDegrees: Int { headingNumber * 10 }

    var expectedDirection: CompassDirection? {
        CompassDirection(headingDegrees: headingDegrees)
    }
}
*/
// MARK: - Completion handling

private extension Set2Test4View {
    func recordResultIfNeeded() {
        guard viewModel.showResults, !hasRecordedResult else { return }

        guard let participant = resultsStore.activeParticipant(in: modelContext) else { return }

        participant.test4 = TestMetrics(
            totalResponses: viewModel.totalResponses,
            correctResponses: viewModel.correctResponses,
            incorrectResponses: viewModel.incorrectResponses,
            averageResponseTime: viewModel.averageResponseTime
        )

        try? modelContext.save()
        hasRecordedResult = true
    }

    func proceedToNextTest() {
        recordResultIfNeeded()
        router.go(to: .set2Test7)
    }
}

// MARK: - Keyboard capture

private struct ArrowKeyHandlingView: View {
    var onArrowPress: (CompassDirection) -> Void

    var body: some View {
        Representable(onArrowPress: onArrowPress)
            .frame(width: 0, height: 0)
    }

    #if canImport(UIKit)
    private struct Representable: UIViewRepresentable {
        var onArrowPress: (CompassDirection) -> Void

        func makeUIView(context: Context) -> ArrowKeyCaptureView {
            let view = ArrowKeyCaptureView()
            view.onArrowPress = onArrowPress
            return view
        }

        func updateUIView(_ uiView: ArrowKeyCaptureView, context: Context) {}
    }

    private final class ArrowKeyCaptureView: UIView {
        var onArrowPress: ((CompassDirection) -> Void)?

        override var canBecomeFirstResponder: Bool { true }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            becomeFirstResponder()
        }

        override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            for press in presses {
                guard let keyCode = press.key?.keyCode else { continue }
                switch keyCode {
                case .keyboardUpArrow:
                    onArrowPress?(.s)
                case .keyboardDownArrow:
                    onArrowPress?(.j)
                case .keyboardLeftArrow:
                    onArrowPress?(.z)
                case .keyboardRightArrow:
                    onArrowPress?(.v)
                default:
                    break
                }
            }
            super.pressesBegan(presses, with: event)
        }
    }
    #elseif canImport(AppKit)
    private struct Representable: NSViewRepresentable {
        var onArrowPress: (CompassDirection) -> Void

        func makeNSView(context: Context) -> ArrowKeyCaptureView {
            let view = ArrowKeyCaptureView()
            view.onArrowPress = onArrowPress
            DispatchQueue.main.async {
                view.window?.makeFirstResponder(view)
            }
            return view
        }

        func updateNSView(_ nsView: ArrowKeyCaptureView, context: Context) {}
    }

    private final class ArrowKeyCaptureView: NSView {
        var onArrowPress: ((CompassDirection) -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            switch event.keyCode {
            case 126:
                onArrowPress?(.s)
            case 125:
                onArrowPress?(.j)
            case 123:
                onArrowPress?(.z)
            case 124:
                onArrowPress?(.v)
            default:
                break
            }
        }
    }
    #endif
}

// MARK: - Utilities
/*
extension CompassDirection {
    init?(headingDegrees: Int) {
        let normalized = (Double(headingDegrees).truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360)
        let sector = Int((normalized + 45) / 90) % 4

        switch sector {
        case 0: self = .s
        case 1: self = .v
        case 2: self = .j
        case 3: self = .z
        default: return nil
        }
    }
}
*/
// MARK: - Preview

#Preview {
    Set2Test4View()
        .frame(width: 1000, height: 1000)
        .environmentObject(NavigationRouter())
        .environmentObject(ResultsStore())
}
