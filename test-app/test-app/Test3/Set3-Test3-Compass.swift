//
//  Test3-Compass.swift
//  Kacka
//
//  Created by Kryštof Sláma on 23.12.2025.
//

import SwiftData
import SwiftUI
internal import Combine

struct Set3Test3View: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: NavigationRouter
    @EnvironmentObject private var resultsStore: ResultsStore
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = CompassLetterTaskViewModel()
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
            Text("Stroop Test - Compass II")
                .font(.system(size: 48)).bold()
                .padding(.bottom, 16)
            Text("A letter appears on the target compass. Ignore the letter's position and press the arrow key matching the letter (S, Z, J, or V).")
                .multilineTextAlignment(.center)
                .font(.title3)
            Spacer()
            
            if testStarted {
                Spacer()
                HStack(spacing: 32) {
                    Spacer()
                    compassColumn(title: "Reference", pointer: viewModel.currentDirection, isReference: true, isNavod: false, displayedLetter: nil)
                    Spacer()
                    compassColumn(title: "Target", pointer: viewModel.currentDirection, isReference: false, isNavod: false, displayedLetter: viewModel.currentLetter?.rawValue)
                    Spacer()
                    Spacer()
                    Spacer()
                }
                Spacer()

                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Time remaining: \(Int(viewModel.timeRemaining))s")
                        .font(.subheadline)
                        .monospacedDigit()
                        .onAppear(perform: viewModel.start)

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.2))
                            Capsule()
                                .fill(Color.accentColor)
                                .frame(width: geometry.size.width * CGFloat(viewModel.timeRemaining / CompassLetterTaskViewModel.totalDuration))
                                .animation(.easeInOut(duration: 0.3), value: viewModel.timeRemaining)
                        }
                    }
                    .frame(height: 12)
                }
            } else {
                HStack(spacing: 32) {
                    Spacer()
                    compassColumn(title: "Reference", pointer: viewModel.currentDirection, isReference: true, isNavod: false, displayedLetter: nil)
                    Spacer()
                    compassColumn(title: "Target", pointer: viewModel.currentDirection, isReference: false, isNavod: true, displayedLetter: "S")
                    Spacer()
                    Spacer()
                    Spacer()
                }
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.testStarted.toggle()
                    }
                } label: {
                    Text("Begin")
                        .font(.title)
                        .bold()
                        .padding(4)
                }.foregroundStyle(.green)
            }
        }.padding(32)
    }

    private func compassColumn(title: String, pointer: CompassDirection?, isReference: Bool, isNavod: Bool, displayedLetter: String?) -> some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.headline)
            if isReference {
                CompassGraphic(centerLabel: nil, isReference: isReference, isNavod: isNavod, pointerDir: pointer, displayedLetter: displayedLetter)
                    .frame(width: 150, height: 150)
            } else {
                CompassGraphic(centerLabel: nil, isReference: isReference, isNavod: isNavod, pointerDir: pointer, displayedLetter: displayedLetter)
                    .frame(width: 400, height: 400)
            }
        }
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
                Text("Continue to Stroop Test III")
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
final class Set3CompassLetterTaskViewModel: ObservableObject {
    @Published var currentDirection: CompassDirection? = nil
    @Published var currentLetter: CompassDirection? = nil
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

    static let totalDuration: TimeInterval = 10 //60 //120  // Test cas

    var tickTimer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

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
        guard let expected = currentLetter else { return }

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
        currentDirection = nil
        currentLetter = nil
        scheduleNextTrial()
    }

    private func presentNewTrial() {
        guard !showResults else { return }
        nextTrialWorkItem?.cancel()
        currentDirection = CompassDirection.allCases.randomElement()
        currentLetter = CompassDirection.allCases.randomElement()
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
        currentDirection = nil
        currentLetter = nil
    }
}
*/
// MARK: - Completion handling

private extension Set3Test3View {
    func recordResultIfNeeded() {
        guard viewModel.showResults, !hasRecordedResult else { return }

        guard let participant = resultsStore.activeParticipant(in: modelContext) else { return }

        participant.test3 = TestMetrics(
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
        router.go(to: .set3Test4)
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

// MARK: - Preview

#Preview {
    Set3Test3View()
        .frame(width: 1000, height: 1000)
        .environmentObject(NavigationRouter())
        .environmentObject(ResultsStore())
}
