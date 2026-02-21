import SwiftData
import SwiftUI
internal import Combine

struct TestMetrics: Codable {
    var totalResponses: Int
    var correctResponses: Int
    var incorrectResponses: Int
    var averageResponseTime: TimeInterval?
}

@Model
final class ParticipantResult: Identifiable {
    @Attribute(.unique) var id: UUID
    var userName: String
    var createdAt: Date
    var test1: TestMetrics?
    var test2: TestMetrics?
    var test3: TestMetrics?
    var test4: TestMetrics?
    var test5: TestMetrics?
    var test6: TestMetrics?
    var test7: TestMetrics?

    init(id: UUID = UUID(), userName: String, createdAt: Date = .now) {
        self.id = id
        self.userName = userName
        self.createdAt = createdAt
    }
}

final class ResultsStore: ObservableObject {
    @AppStorage("userName") var userName: String = ""
    @AppStorage("activeResultID") private var activeResultIDValue: String = ""

    var activeResultID: UUID? {
        get { UUID(uuidString: activeResultIDValue) }
        set { activeResultIDValue = newValue?.uuidString ?? "" }
    }

    func beginNewSession(in context: ModelContext, userName: String) -> ParticipantResult {
        let participant = ParticipantResult(userName: userName.isEmpty ? "Unknown" : userName)
        context.insert(participant)
        try? context.save()
        activeResultID = participant.id
        return participant
    }

    func activeParticipant(in context: ModelContext) -> ParticipantResult? {
        guard let id = activeResultID else { return nil }
        let descriptor = FetchDescriptor<ParticipantResult>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }
}
