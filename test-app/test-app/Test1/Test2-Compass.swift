//
//  Test2-Compass.swift
//  Kacka
//
//  Created by Kryštof Sláma on 23.12.2025.
//

import SwiftData
import SwiftUI
internal import Combine

struct Test2View: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: NavigationRouter
    @EnvironmentObject private var resultsStore: ResultsStore
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = CompassTaskViewModel()
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

            if viewModel.showResults {
                resultsOverlay
            }
        }.navigationBarBackButtonHidden()
    }

    private var mainContent: some View {
        VStack(alignment: .center) {
            Text("Stroop Test - Compass I")
                .font(.system(size: 48)).bold()
                .padding(.bottom, 16)
            Text("A pointer appears on the right compass. Ignore the displayed letter and click the direction the pointer shows (S, Z, J, or V).")
                .multilineTextAlignment(.center)
                .font(.title3)
            Text("(In reference image is right answer V)")
                .multilineTextAlignment(.center)
                .font(.title3)
            Spacer()
            
            if testStarted {
                Spacer()
                HStack(spacing: 32) {
                    Spacer()
                    compassColumn(title: "Reference", pointer: viewModel.currentDirection, isReference: true, isNavod: false, centerLabel: nil)
                    Spacer()
                    compassColumn(title: "Target", pointer: viewModel.currentDirection, isReference: false, isNavod: false, centerLabel: viewModel.currentLetter?.rawValue)
                    Spacer()
                    Spacer()
                    Spacer()
                }
                Spacer()
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 12) {
                        Spacer()
                        ForEach(CompassDirection.allCases, id: \.self) { direction in
                            Button(action: {
                                viewModel.handleSelection(direction)
                            }) {
                                Text(direction.rawValue)
                                    .font(.title3).bold()
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .frame(minWidth: 64)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.accentColor)
                            .disabled(viewModel.showResults)
                        }
                        Spacer()
                    }
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
                                .frame(width: geometry.size.width * CGFloat(viewModel.timeRemaining / CompassTaskViewModel.totalDuration))
                                .animation(.easeInOut(duration: 0.3), value: viewModel.timeRemaining)
                        }
                    }
                    .frame(height: 12)
                }
            } else {
                HStack(spacing: 32) {
                    Spacer()
                    compassColumn(title: "Reference", pointer: viewModel.currentDirection, isReference: true, isNavod: false, centerLabel: nil)
                    Spacer()
                    compassColumn(title: "Target", pointer: viewModel.currentDirection, isReference: false, isNavod: true, centerLabel: "S")
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

    private func compassColumn(title: String, pointer: CompassDirection?, isReference: Bool, isNavod: Bool, centerLabel: String?) -> some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.headline)
            if isReference {
                CompassGraphic(centerLabel: centerLabel, isReference: isReference, isNavod: isNavod, pointerDir: pointer)
                    .frame(width: 150, height: 150)
            } else {
                CompassGraphic(centerLabel: centerLabel, isReference: isReference, isNavod: isNavod, pointerDir: pointer)
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
                Text("Continue to Stroop Test II")
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

final class CompassTaskViewModel: ObservableObject {
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

    static let totalDuration: TimeInterval = 60 //60 //120  // Test cas

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
        guard let expected = currentDirection else { return }

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

// MARK: - Models & graphics

enum CompassDirection: String, CaseIterable, Equatable {
    case s = "S" // sever
    case z = "Z" // západ
    case j = "J" // jih
    case v = "V" // východ

    var unitPoint: CGPoint {
        switch self {
        case .s: return CGPoint(x: 0, y: -1)
        case .z: return CGPoint(x: -1, y: 0)
        case .j: return CGPoint(x: 0, y: 1)
        case .v: return CGPoint(x: 1, y: 0)
        }
    }
}
// MARK: - Completion handling

private extension Test2View {
    func recordResultIfNeeded() {
        guard viewModel.showResults, !hasRecordedResult else { return }

        guard let participant = resultsStore.activeParticipant(in: modelContext) else { return }

        participant.test2 = TestMetrics(
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
        router.go(to: .test3)
    }
}

struct CompassGraphic: View {
    var centerLabel: String?
    var isReference: Bool?
    var isNavod: Bool?
    var pointerDir: CompassDirection?
    var displayedLetter: String? = nil
    let directions = ["S", "Z", "V", "J"]
    
    private let letterOffsets: [CompassDirection: CGPoint] = [
        .s: CGPoint(x: 0, y: -1.3),
        .z: CGPoint(x: -1.3, y: 0),
        .j: CGPoint(x: 0, y: 1.3),
        .v: CGPoint(x: 1.3, y: 0)
    ]
    private let letterOffsetsNavod: [CompassDirection: CGPoint] = [
        .s: CGPoint(x: -1.2, y: 0)
    ]
    
    var body: some View {
        if isReference! {
            GeometryReader { proxy in
                let size = min(proxy.size.width, proxy.size.height)
                let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
                let radius = size / 2 - 12
                
                ZStack {
                    crossLines(center: center, length: radius)
                        .stroke(Color.primary.opacity(0.8), lineWidth: 3)
                    
                    ForEach(Array(letterOffsets.keys), id: \.self) { direction in
                        let offset = letterOffsets[direction] ?? .zero
                        Text(direction.rawValue)
                            .font(.title2).bold()
                            .foregroundStyle(Color.red)
                            .position(x: center.x + offset.x * (radius - 8),
                                      y: center.y + offset.y * (radius - 8))
                    }
                }
            }
        } else if isNavod! {
            GeometryReader { proxy in
                let size = min(proxy.size.width, proxy.size.height)
                let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
                let radius = size / 2 - 12
                
                ZStack {
                    crossLines(center: center, length: radius)
                        .stroke(Color.primary.opacity(0.8), lineWidth: 3)
                    
                    ForEach(Array(letterOffsetsNavod.keys), id: \.self) { direction in
                        let offset = letterOffsets[direction] ?? .zero
                        Text(direction.rawValue)
                            .font(.title).bold()
                            .foregroundStyle(Color.red)
                            .position(x: center.x + 1.1 * (radius - 8),
                                      y: center.y + 0 * (radius - 8))
                    }
                }
            }
        } else {
            GeometryReader { proxy in
                let size = min(proxy.size.width, proxy.size.height)
                let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
                let radius = size / 2 - 12
                
                ZStack {
                    crossLines(center: center, length: radius)
                        .stroke(Color.primary.opacity(0.8), lineWidth: 3)
                    
                    if let pointerDir {
                        let letter = displayedLetter ?? directions.randomElement() ?? "S"
                        if pointerDir.rawValue == "S" {
                            Text(letter)
                                .font(.largeTitle).bold()
                                .foregroundStyle(.red)
                                .position(x: center.x, y: center.y - 200)
                        } else if pointerDir.rawValue == "J" {
                            Text(letter)
                                .font(.largeTitle).bold()
                                .foregroundStyle(.red)
                                .position(x: center.x, y: center.y + 200)
                        } else if pointerDir.rawValue == "Z" {
                            Text(letter)
                                .font(.largeTitle).bold()
                                .foregroundStyle(.red)
                                .position(x: center.x - 200, y: center.y)
                        } else if pointerDir.rawValue == "V" {
                            Text(letter)
                                .font(.largeTitle).bold()
                                .foregroundStyle(.red)
                                .position(x: center.x + 200, y: center.y)
                        }
                    }
                }
            }
        }
    }
    private func crossLines(center: CGPoint, length: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: center.x - length, y: center.y))
        path.addLine(to: CGPoint(x: center.x + length, y: center.y))
        path.move(to: CGPoint(x: center.x, y: center.y - length))
        path.addLine(to: CGPoint(x: center.x, y: center.y + length))
        return path
    }
    private func pointerPath(center: CGPoint, radius: CGFloat, direction: CompassDirection) -> Path {
        var path = Path()
        let vector = direction.unitPoint
        let endPoint = CGPoint(x: center.x + vector.x * radius, y: center.y + vector.y * radius)
        path.move(to: center)
        path.addLine(to: endPoint)
        
        let arrowSize: CGFloat = 10
        let perpendicular = CGPoint(x: -vector.y, y: vector.x)
        let tipLeft = CGPoint(x: endPoint.x - vector.x * arrowSize + perpendicular.x * arrowSize * 0.6,
                              y: endPoint.y - vector.y * arrowSize + perpendicular.y * arrowSize * 0.6)
        let tipRight = CGPoint(x: endPoint.x - vector.x * arrowSize - perpendicular.x * arrowSize * 0.6,
                               y: endPoint.y - vector.y * arrowSize - perpendicular.y * arrowSize * 0.6)
        
        path.move(to: tipLeft)
        path.addLine(to: endPoint)
        path.addLine(to: tipRight)
        return path
    }
}

// MARK: - Preview

#Preview {
    Test2View()
        .frame(width: 1000, height: 1000)
        .environmentObject(NavigationRouter())
        .environmentObject(ResultsStore())
}
