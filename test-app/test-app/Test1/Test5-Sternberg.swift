//
//  Test5-Sternberg.swift
//  Kacka
//
//  Created by Kryštof Sláma on 23.12.2025.
//

import SwiftData
import SwiftUI
internal import Combine

struct Test5View: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: NavigationRouter
    @EnvironmentObject private var resultsStore: ResultsStore
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = MemoryTaskViewModel()
    @State private var hasRecordedResult = false
    @State private var testStarted = false
    private let preparationHint = "Preping memory..."
    private let introSequence: [MemoryItem] = [
        MemoryItem(value: "SAS", category: .callsign),
        MemoryItem(value: "DLH", category: .callsign),
        MemoryItem(value: "KLM", category: .callsign),
        MemoryItem(value: "RYR", category: .callsign)
    ]

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
        } .navigationBarBackButtonHidden()
    }

    private var mainContent: some View {
        VStack(alignment: .center) {
            Text("Sternberg Test - Yes / No")
                .font(.system(size: 48)).bold()
                .padding(.bottom, 16)
            VStack(spacing: 4) {
                Text("You will see a sequence of 4 items (airline callsigns, airports, or aircraft types).")
                    .multilineTextAlignment(.center)
                    .font(.title3)
                Text("Each item is shown for 3 seconds. After a 1-second pause, a new item appears.")
                    .multilineTextAlignment(.center)
                    .font(.title3)
                Text("Decide if the new item was part of the preceding sequence and answer as quickly as possible.")
                    .multilineTextAlignment(.center)
                    .font(.title3)
            }
            .multilineTextAlignment(.center)

            Spacer()

            if testStarted {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 120)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.accentColor.opacity(0.4), lineWidth: 2)
                            )
                        
                        if let sequence = viewModel.displayedSequence {
                            SequenceDisplay(sequence: sequence)
                        } else if let text = viewModel.displayedText {
                            Text(text)
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                                .transition(.opacity.combined(with: .scale))
                        } else {
                            Text("\(viewModel.showingPrompt ? "Was this in the sequence?" : preparationHint)")
                                .foregroundStyle(.secondary)
                        }
                    }
                // Yes/No
                HStack(spacing: 16) {
                    Button(action: { viewModel.handleResponse(isPresent: true) }) {
                        Text("Yes")
                            .font(.title2).bold()
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(!viewModel.showingPrompt || viewModel.showResults)
                    
                    Button(action: { viewModel.handleResponse(isPresent: false) }) {
                        Text("No")
                            .font(.title2).bold()
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(!viewModel.showingPrompt || viewModel.showResults)
                }
                // Time
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
                                .frame(width: geometry.size.width * CGFloat(viewModel.timeRemaining / MemoryTaskViewModel.totalDuration))
                                .animation(.easeInOut(duration: 0.3), value: viewModel.timeRemaining)
                        }
                    }
                    .frame(height: 12)
                }
                // Correct
                if let lastCorrect = viewModel.lastResponseWasCorrect {
                    Text(lastCorrect ? "Correct" : "Incorrect")
                        .font(.headline)
                        .foregroundStyle(lastCorrect ? .green : .red)
                }
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.accentColor.opacity(0.4), lineWidth: 2)
                        )
                    
                    if let sequence = viewModel.displayedSequence {
                        SequenceDisplay(sequence: sequence)
                    } else if let text = viewModel.displayedText {
                        Text(text)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .transition(.opacity.combined(with: .scale))
                    } else {
                        SequenceDisplay(sequence: introSequence)
                    }
                }
                // Yes/No
                HStack(spacing: 16) {
                    Button(action: { viewModel.handleResponse(isPresent: true) }) {
                        Text("Yes")
                            .font(.title2).bold()
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(!viewModel.showingPrompt || viewModel.showResults)
                    
                    Button(action: { viewModel.handleResponse(isPresent: false) }) {
                        Text("No")
                            .font(.title2).bold()
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(!viewModel.showingPrompt || viewModel.showResults)
                }
                // Button
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

            Button(action: goToNextTest) {
                Text("Continue to Sternberg Test II")
                    .font(.title)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .frame(maxWidth: 320)
        .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial))
    }
}

private struct SequenceDisplay: View {
    let sequence: [MemoryItem]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(sequence, id: \.value) { item in
                Text(item.value)
                    .font(.title2.bold())
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.15)))
            }
        }
        .padding(.horizontal)
        .transition(.opacity.combined(with: .scale))
    }
}

// MARK: - View model

final class MemoryTaskViewModel: ObservableObject {
    @Published var displayedText: String?
    @Published fileprivate var displayedSequence: [MemoryItem]?
    @Published var currentCategoryLabel: String = ""
    @Published var showingPrompt = false
    @Published var timeRemaining: TimeInterval = totalDuration
    @Published var showResults = false
    @Published var lastResponseWasCorrect: Bool? = nil

    @Published private(set) var correctResponses = 0
    @Published private(set) var incorrectResponses = 0
    @Published private(set) var totalResponses = 0

    private var sessionEndDate: Date?
    private var responseTimes: [TimeInterval] = []
    private var trialStartTime: Date?
    private var currentSequence: [MemoryItem] = []
    private var promptItem: MemoryItem?
    private var scheduledWorkItem: DispatchWorkItem?

    static let totalDuration: TimeInterval = 90 //180
    static let itemDisplayDuration: TimeInterval = 3
    static let pauseDuration: TimeInterval = 1

    var tickTimer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    var averageResponseTime: TimeInterval? {
        guard !responseTimes.isEmpty else { return nil }
        let total = responseTimes.reduce(0, +)
        return total / Double(responseTimes.count)
    }

    func start() {
        cancelScheduledWork()
        correctResponses = 0
        incorrectResponses = 0
        totalResponses = 0
        responseTimes.removeAll()
        showResults = false
        lastResponseWasCorrect = nil
        displayedText = nil
        displayedSequence = nil
        showingPrompt = false

        timeRemaining = Self.totalDuration
        sessionEndDate = Date().addingTimeInterval(Self.totalDuration)

        beginNewTrial()
    }

    func tick() {
        guard let sessionEndDate else { return }
        let remaining = max(0, sessionEndDate.timeIntervalSinceNow)
        timeRemaining = remaining

        if remaining <= 0 {
            finishSession()
        }
    }

    func handleResponse(isPresent: Bool) {
        guard showingPrompt, let currentPrompt = promptItem else { return }

        totalResponses += 1
        let isCorrect = currentSequence.contains(currentPrompt) == isPresent
        lastResponseWasCorrect = isCorrect

        if isCorrect {
            correctResponses += 1
        } else {
            incorrectResponses += 1
        }

        if let start = trialStartTime {
            responseTimes.append(Date().timeIntervalSince(start))
        }

        showingPrompt = false
        displayedText = nil
        promptItem = nil

        if timeRemaining <= 0 {
            finishSession()
        } else {
            beginNewTrial()
        }
    }

    // MARK: - Trial management

    private func beginNewTrial() {
        guard !showResults else { return }
        cancelScheduledWork()
        currentSequence = MemoryItem.randomSequence(count: 4)
        promptItem = nil
        lastResponseWasCorrect = nil
        displayedSequence = currentSequence
        showingPrompt = false

        if let firstCategory = currentSequence.first?.category {
            currentCategoryLabel = firstCategory.displayName
        }

        scheduleWork(after: Self.itemDisplayDuration) { [weak self] in
            self?.prepareForPrompt()
        }
    }

    private func prepareForPrompt() {
        guard !showResults else { return }
        displayedSequence = nil
        displayedText = nil
        currentCategoryLabel = "Pause"

        scheduleWork(after: Self.pauseDuration) { [weak self] in
            self?.presentPrompt()
        }
    }

    private func presentPrompt() {
        guard !showResults else { return }
        showingPrompt = true
        promptItem = MemoryItem.randomPrompt(from: currentSequence)
        displayedText = promptItem?.value
        currentCategoryLabel = promptItem?.category.displayName ?? ""
        trialStartTime = Date()
    }

    private func finishSession() {
        cancelScheduledWork()
        showResults = true
        showingPrompt = false
        displayedText = nil
    }

    private func scheduleWork(after delay: TimeInterval, action: @escaping () -> Void) {
        cancelScheduledWork()
        let work = DispatchWorkItem(block: action)
        scheduledWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func cancelScheduledWork() {
        scheduledWorkItem?.cancel()
        scheduledWorkItem = nil
    }
}

// MARK: - Completion handling

private extension Test5View {
    func recordResultIfNeeded() {
        guard viewModel.showResults, !hasRecordedResult else { return }

        guard let participant = resultsStore.activeParticipant(in: modelContext) else { return }

        participant.test5 = TestMetrics(
            totalResponses: viewModel.totalResponses,
            correctResponses: viewModel.correctResponses,
            incorrectResponses: viewModel.incorrectResponses,
            averageResponseTime: viewModel.averageResponseTime
        )

        try? modelContext.save()
        hasRecordedResult = true
    }

    func goToNextTest() {
        recordResultIfNeeded()
        router.go(to: .test6)
    }
}

#Preview {
    Test5View()
        .frame(width: 1000, height: 1000)
        .environmentObject(NavigationRouter())
        .environmentObject(ResultsStore())
}
