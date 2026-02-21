import SwiftData
import SwiftUI

struct ResultsView: View {
    @EnvironmentObject private var resultsStore: ResultsStore
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ParticipantResult.createdAt, order: .reverse) private var savedResults: [ParticipantResult]

    var body: some View {
        List {
            if savedResults.isEmpty {
                Section {
                    Text("No results saved yet.")
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack {
                    Section {
                        ForEach(savedResults) { participant in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .center, spacing: 16) {
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(participant.userName)
                                            .font(.largeTitle)
                                            .bold()
                                        Text(participant.createdAt, style: .date)
                                            .font(.subheadline)
                                    }
                                    Spacer()
                                    Divider()
                                    resultCard(title: "Choice", metrics: participant.test1)
                                    Divider()
                                    resultCard(title: "Compass I", metrics: participant.test2)
                                    Divider()
                                    resultCard(title: "Compass II", metrics: participant.test3)
                                    Divider()
                                    resultCard(title: "RWY", metrics: participant.test4)
                                    Divider()
                                    resultCard(title: "Sternberg I", metrics: participant.test5)
                                    Divider()
                                    resultCard(title: "Sternberg II", metrics: participant.test6)
                                    Divider()
                                    resultCard(title: "FEAST", metrics: participant.test7)
                                }
                                Divider()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                        }
                    }
                    Spacer()
                    Button("Clear all") {
                        clearAllResults()
                    }
                }
            }
        }
        .navigationTitle("Results")
    }

    private func resultCard(title: String, metrics: TestMetrics?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)

            if let metrics {
                Text("Total: \(metrics.totalResponses)  Correct: \(metrics.correctResponses)  Incorrect: \(metrics.incorrectResponses)")
                    .font(.subheadline)
                if let average = metrics.averageResponseTime {
                    Text(String(format: "Average response time: %.0f ms", average * 1000))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No data")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
        }
        .frame(maxWidth: 200, alignment: .leading)
    }
    private func clearAllResults() {
        savedResults.forEach { modelContext.delete($0) }
        try? modelContext.save()
        resultsStore.activeResultID = nil
    }
}

#Preview {
    ResultsView()
        .environmentObject(ResultsStore())
}
