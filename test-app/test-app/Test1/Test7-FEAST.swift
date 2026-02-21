//
//  Test7-FEAST.swift
//  Kacka
//
//  Created by Kryštof Sláma on 23.12.2025.
//

import SwiftData
import SwiftUI
internal import Combine

struct Test7View: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: NavigationRouter
    @EnvironmentObject private var resultsStore: ResultsStore
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = DistanceTaskViewModel()
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
        }
        .navigationBarBackButtonHidden()
    }

    private var mainContent: some View {
        VStack(alignment: .center) {
            Text("FEAST Estimate distances and directions")
                .font(.system(size: 48)).bold()
                .padding(.bottom, 16)
            Text("The task is to judge the distance and determine the relative position of the objects.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .font(.title3)
            Text("All questions have same refrence distance as in the picture below.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .font(.title3)
            Spacer()
            
            if testStarted {
                VStack(spacing: 16) {
                    Text("Use the navigation image to answer each question. The next prompt appears immediately after you respond.")
                        .multilineTextAlignment(.center)
                    
                    if let question = viewModel.currentQuestion {
                        HStack {
                            Image("Test4.1")
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
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Question \(viewModel.currentQuestionIndex + 1) of \(viewModel.totalQuestions)")
                                    .font(.title3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Text(question.prompt)
                                    .font(.title2)
                                    .bold()
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                VStack(spacing: 12) {
                                    ForEach(Array(question.options.enumerated()), id: \.0) { index, option in
                                        Button(action: {
                                            viewModel.handleSelection(index)
                                        }) {
                                            HStack {
                                                Text(option)
                                                    .font(.title2)
                                                    .bold()
                                                Spacer()
                                            }
                                            .padding()
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.accentColor)
                                        .disabled(viewModel.showResults)
                                    }
                                }
                                Spacer()
                            }
                        }
                    } else {
                        Text("No questions available. Add more to the view model to continue.")
                            .foregroundStyle(.secondary)
                    }
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
                                    .frame(width: geometry.size.width * CGFloat(viewModel.timeRemaining / DistanceTaskViewModel.totalDuration))
                                    .animation(.easeInOut(duration: 0.3), value: viewModel.timeRemaining)
                            }
                        }
                        .frame(height: 12)
                    }
                }
            } else {
                Image("Test4.1")
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 500)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.accentColor.opacity(0.35), lineWidth: 2)
                    )
                
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

            Button(action: goToResults) {
                Text("View results")
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

// MARK: - Completion handling
private extension Test7View {
    func recordResultIfNeeded() {
        guard viewModel.showResults, !hasRecordedResult else { return }
        guard let participant = resultsStore.activeParticipant(in: modelContext) else { return }

        participant.test7 = TestMetrics(
            totalResponses: viewModel.totalResponses,
            correctResponses: viewModel.correctResponses,
            incorrectResponses: viewModel.incorrectResponses,
            averageResponseTime: viewModel.averageResponseTime
        )

        try? modelContext.save()
        hasRecordedResult = true
    }

    func goToResults() {
        recordResultIfNeeded()
        router.path = [.results]
    }
}

// MARK: - View model
final class DistanceTaskViewModel: ObservableObject {
    @Published private(set) var questions: [DistanceQuestion]
    @Published private(set) var currentQuestionIndex: Int = 0
    @Published private(set) var selectedOptionIndex: Int? = nil
    @Published var lastSelectionWasCorrect: Bool? = nil
    @Published var timeRemaining: TimeInterval = totalDuration
    @Published var showResults = false

    private var sessionEndDate: Date?
    static let totalDuration: TimeInterval = 240 //360
    @Published private(set) var correctResponses = 0
    @Published private(set) var incorrectResponses = 0
    @Published private(set) var totalResponses = 0

    
    
    @Published var displayedText: String?
    @Published var showingPrompt = false
    private var scheduledWorkItem: DispatchWorkItem?
    var tickTimer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
    
    private var responseTimes: [TimeInterval] = []
    private var questionStartTime: Date?

    init(questions: [DistanceQuestion] = DistanceQuestion.defaultQuestions) {
        self.questions = questions
    }

    var currentQuestion: DistanceQuestion? {
        guard currentQuestionIndex < questions.count else { return nil }
        return questions[currentQuestionIndex]
    }

    var totalQuestions: Int { questions.count }

    var averageResponseTime: TimeInterval? {
        guard !responseTimes.isEmpty else { return nil }
        let total = responseTimes.reduce(0, +)
        return total / Double(responseTimes.count)
    }

    func start() {
        guard !questions.isEmpty else {
            showResults = true
            return
        }

        currentQuestionIndex = 0
        lastSelectionWasCorrect = nil
        selectedOptionIndex = nil
        showResults = false
        correctResponses = 0
        incorrectResponses = 0
        totalResponses = 0
        responseTimes.removeAll()
        questionStartTime = Date()
        
        timeRemaining = Self.totalDuration
        sessionEndDate = Date().addingTimeInterval(Self.totalDuration)
    }

    func tick() {
        guard let sessionEndDate else { return }
        let remaining = max(0, sessionEndDate.timeIntervalSinceNow)
        timeRemaining = remaining

        if remaining <= 0 {
            finishSession()
        }
    }
    
    private func finishSession() {
        cancelScheduledWork()
        showResults = true
        showingPrompt = false
        displayedText = nil
    }
    
    private func cancelScheduledWork() {
        scheduledWorkItem?.cancel()
        scheduledWorkItem = nil
    }
    
    
    
    
    func handleSelection(_ index: Int) {
        guard !showResults, let question = currentQuestion, selectedOptionIndex == nil else { return }

        totalResponses += 1
        selectedOptionIndex = index

        if let start = questionStartTime {
            responseTimes.append(Date().timeIntervalSince(start))
        }

        let isCorrect = index == question.correctIndex
        lastSelectionWasCorrect = isCorrect

        if isCorrect {
            correctResponses += 1
        } else {
            incorrectResponses += 1
        }

        advanceToNextQuestion()
    }

    func buttonTint(for index: Int) -> Color {
        guard let last = lastSelectionWasCorrect, let selected = selectedOptionIndex else {
            return .accentColor
        }

        if index == selected {
            return last ? .green : .red
        }

        return .accentColor
    }

    private func advanceToNextQuestion() {
        if currentQuestionIndex + 1 < questions.count {
            let nextIndex = currentQuestionIndex + 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                guard !self.showResults else { return }
                self.currentQuestionIndex = nextIndex
                self.lastSelectionWasCorrect = nil
                self.selectedOptionIndex = nil
                self.questionStartTime = Date()
            }
        } else {
            showResults = true
        }
    }
}

struct DistanceQuestion: Identifiable {
    let id = UUID()
    let prompt: String
    let options: [String]
    let correctIndex: Int

    static let defaultQuestions: [DistanceQuestion] = [
        DistanceQuestion(
            prompt: "The distance from aircraft 32 to point Kilo is:",
            options: ["10 NM", "5 NM", "7 NM", "12 NM"],
            correctIndex: 0
        ),
        DistanceQuestion(
            prompt: "The distance from aircraft 71 to aircraft 44 is:",
            options: ["10 NM", "14 NM", "21 NM", "15 NM"],
            correctIndex: 3
        ),
        DistanceQuestion(
            prompt: "The distance from aircraft 19 to point Kilo is:",
            options: ["6 NM", "3,5 NM", "7 NM", "3 NM"],
            correctIndex: 1
        ),
        DistanceQuestion(
            prompt: "The quickest way for aircraft 71 to get to point Kilo is:",
            options: ["Turn right to heading 045", "Turn left to heading 045", "Turn right to heading 090", "None of the above answers"],
            correctIndex: 1
        ),
        DistanceQuestion(
            prompt: "The quickest way for aircraft 66 to get to point Xray is:",
            options: ["Turn left to heading 270", "Turn left to heading 090", "Turn right to heading 270", "Turn right to heading 090"],
            correctIndex: 2
        ),
        DistanceQuestion(
            prompt: "The quickest way for aircraft 44 to get to point Golf is:",
            options: ["Turn right to heading 225", "Turn left to heading 275", "Turn left to heading 180", "Turn right to heading 180"],
            correctIndex: 0
        ),
        DistanceQuestion(
            prompt: "The quickest way for aircraft 71 to get to point Xray is:",
            options: ["Turn right to heading 360", "Turn left to heading 360", "Answers A and B are both correct", "None of the above answers"],
            correctIndex: 2
        ),
        DistanceQuestion(
            prompt: "The quickest way for aircraft 19 to get to point Golf is:",
            options: ["Turn left to heading 090", "Turn left to heading 135", "Turn right to heading 135,", "None of the above answers"],
            correctIndex: 1
        ),
        DistanceQuestion(
            prompt: "The quickest way for aircraft 66 to get to point Kilo is:",
            options: ["Turn left to heading 135", "Turn right to heading 135", "Turn right to heading 225", "Turn left to heading 225"],
            correctIndex: 2
        ),
        DistanceQuestion(
            prompt: "The quickest way for aircraft 32 to get to point Golf is:",
            options: ["Turn right to heading 070", "Turn right to heading 90", "Turn left to heading 090", "Turn left to heading 135"],
            correctIndex: 0
        )
    ]
}

#Preview {
    Test7View()
        .frame(width: 1000, height: 1000)
        .environmentObject(NavigationRouter())
        .environmentObject(ResultsStore())
}
