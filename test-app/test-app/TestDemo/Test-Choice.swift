//
//  Test1-Choice.swift
//  Kacka
//
//  Created by Kryštof Sláma on 23.12.2025.
//

import SwiftData
import SwiftUI
internal import Combine

struct DemoTest1View: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: NavigationRouter
    @EnvironmentObject private var resultsStore: ResultsStore
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = DemoChoiceTaskViewModel()
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
            
            KeyPressHandlingView { key in
                viewModel.handleKeyPress(key)
            }
            .allowsHitTesting(false)
            
            if viewModel.showResults {
                resultsOverlay
            }
        }.navigationBarBackButtonHidden()
    }

    private var mainContent: some View {
        VStack(alignment: .center) {
            Text("Choice Reaction Time task")
                    .font(.system(size: 48)).bold()
                    .padding(.bottom, 16)
            Text("In the following task, you see four white boxes on the screen. In one of them a cross is presented. Press the corresponding key as fast as possible.")
                .multilineTextAlignment(.center)
                .font(.title3)
            Spacer()
        
            if testStarted {
                Spacer()
                VStack(spacing: 8) {
                    labeledRow(title: "On screen", content: {
                        boxesRow(highlightedIndex: viewModel.targetIndex)
                    })
                    
                    labeledRow(title: "Press Key", content: {
                        boxesRow(labels: DemoChoiceTaskViewModel.keyOrder)
                    })
                }
                
                Spacer()
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Time remaining: \(Int(viewModel.timeRemaining))s")
                        .font(.subheadline)
                        .monospacedDigit()
                        .onAppear {
                            viewModel.start()
                        }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.2))
                            Capsule()
                                .fill(Color.accentColor)
                                .frame(width: geometry.size.width * CGFloat(viewModel.timeRemaining / DemoChoiceTaskViewModel.totalDuration))
                                .animation(.easeInOut(duration: 0.3), value: viewModel.timeRemaining)
                        }
                    }
                    .frame(height: 12)
                }
            } else {
                VStack(spacing: 8) {
                    labeledRow(title: "On screen", content: {
                        boxesRow(highlightedIndex: 2)
                    })
                    
                    labeledRow(title: "Press Key", content: {
                        boxesRow(labels: DemoChoiceTaskViewModel.keyOrder)
                    })
                }
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { self.testStarted.toggle() }
                } label: {
                    Text("Begin")
                        .font(.title).bold()
                        .padding(4)
                }.foregroundStyle(.green)
            }
        }.padding(32)
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
                Text("Continue to Stroop Test")
                    .font(.title)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .frame(maxWidth: 300)
        .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial))
    }

    private func boxesRow(highlightedIndex: Int? = nil, labels: [String] = ["", "", "", ""]) -> some View {
        HStack(spacing: 12) {
            ForEach(Array(labels.enumerated()), id: \.0) { index, label in
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.white.opacity(0.6), lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(index == highlightedIndex ? Color.yellow.opacity(0.6) : Color.clear)
                    )
                    .overlay(
                        Text(index == highlightedIndex ? "X" : label)
                            .font(.largeTitle).bold()
                            .foregroundStyle(.primary)
                    )
                    .frame(width: 64, height: 64)
            }
        }
    }

    private func labeledRow<Content: View>(title: String, content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Spacer()
            Text(title)
                .font(.headline)
            content()
            Spacer()
            Spacer()
        }
    }

    private func recordResultIfNeeded() {
        guard viewModel.showResults, !hasRecordedResult else { return }

        guard let participant = resultsStore.activeParticipant(in: modelContext) else { return }

        participant.test1 = TestMetrics(
            totalResponses: viewModel.totalResponses,
            correctResponses: viewModel.correctResponses,
            incorrectResponses: viewModel.incorrectResponses,
            averageResponseTime: viewModel.averageResponseTime
        )

        try? modelContext.save()
        hasRecordedResult = true
    }

    private func proceedToNextTest() {
        recordResultIfNeeded()
        router.go(to: .demoTest2)
    }
}

// MARK: - View model
final class DemoChoiceTaskViewModel: ObservableObject {
    @Published var targetIndex: Int? = nil
    @Published var timeRemaining: TimeInterval = totalDuration
    @Published var showResults = false
    @Published var lastResponseWasCorrect: Bool? = nil

    @Published private(set) var correctResponses = 0
    @Published private(set) var incorrectResponses = 0
    @Published private(set) var totalResponses = 0

    private var sessionEndDate: Date?
    private var responseTimes: [TimeInterval] = []
    private var trialStartTime: Date?
    private var nextTargetWorkItem: DispatchWorkItem?

    static let keyOrder = ["X", "C", "B", "N"]
    static let totalDuration: TimeInterval = 15

    var tickTimer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    var averageResponseTime: TimeInterval? {
        guard !responseTimes.isEmpty else { return nil }
        let total = responseTimes.reduce(0, +)
        return total / Double(responseTimes.count)
    }

    func start() {
        nextTargetWorkItem?.cancel()
        correctResponses = 0
        incorrectResponses = 0
        totalResponses = 0
        responseTimes.removeAll()
        showResults = false
        lastResponseWasCorrect = nil

        timeRemaining = Self.totalDuration
        sessionEndDate = Date().addingTimeInterval(Self.totalDuration)
        presentNewTarget()
    }

    func tick() {
        guard let sessionEndDate else { return }
        let remaining = max(0, sessionEndDate.timeIntervalSinceNow)
        timeRemaining = remaining

        if remaining <= 0 {
            finishSession()
        }
    }

    func handleKeyPress(_ key: String) {
        guard !showResults else { return }
        guard let expectedIndex = targetIndex else { return }

        let mapping: [String: Int] = ["x": 0, "c": 1, "b": 2, "n": 3]
        guard let pressedIndex = mapping[key.lowercased()] else { return }

        totalResponses += 1

        let now = Date()
        if let start = trialStartTime {
            responseTimes.append(now.timeIntervalSince(start))
        }

        if pressedIndex == expectedIndex {
            correctResponses += 1
            lastResponseWasCorrect = true
        } else {
            incorrectResponses += 1
            lastResponseWasCorrect = false
        }

        targetIndex = nil
        trialStartTime = nil
        scheduleNextTarget()
    }

    private func presentNewTarget() {
        guard !showResults else { return }
        nextTargetWorkItem?.cancel()
        targetIndex = Int.random(in: 0..<Self.keyOrder.count)
        trialStartTime = Date()
    }

    private func scheduleNextTarget() {
        nextTargetWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            presentNewTarget()
        }

        nextTargetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    private func finishSession() {
        nextTargetWorkItem?.cancel()
        showResults = true
        targetIndex = nil
    }
}


// MARK: - Keyboard capture
private struct KeyPressHandlingView: View {
    var onKeyPress: (String) -> Void

    var body: some View {
        Representable(onKeyPress: onKeyPress)
            .frame(width: 0, height: 0)
    }

    #if canImport(UIKit)
    private struct Representable: UIViewRepresentable {
        var onKeyPress: (String) -> Void

        func makeUIView(context: Context) -> KeyCaptureView {
            let view = KeyCaptureView()
            view.onKeyPress = onKeyPress
            return view
        }

        func updateUIView(_ uiView: KeyCaptureView, context: Context) {}
    }

    private final class KeyCaptureView: UIView {
        var onKeyPress: ((String) -> Void)?

        override var canBecomeFirstResponder: Bool { true }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            becomeFirstResponder()
        }

        override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            for press in presses {
                if let key = press.key?.charactersIgnoringModifiers, !key.isEmpty {
                    onKeyPress?(key)
                }
            }
            super.pressesBegan(presses, with: event)
        }
    }
    #elseif canImport(AppKit)
    private struct Representable: NSViewRepresentable {
        var onKeyPress: (String) -> Void

        func makeNSView(context: Context) -> KeyCaptureView {
            let view = KeyCaptureView()
            view.onKeyPress = onKeyPress
            DispatchQueue.main.async {
                view.window?.makeFirstResponder(view)
            }
            return view
        }

        func updateNSView(_ nsView: KeyCaptureView, context: Context) {}
    }

    private final class KeyCaptureView: NSView {
        var onKeyPress: ((String) -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            if let characters = event.charactersIgnoringModifiers, !characters.isEmpty {
                onKeyPress?(characters)
            }
        }
    }
    #endif
}

// MARK: - Preview
#Preview {
    DemoTest1View()
        .frame(width: 1000, height: 1000)
        .environmentObject(NavigationRouter())
        .environmentObject(ResultsStore())
}
