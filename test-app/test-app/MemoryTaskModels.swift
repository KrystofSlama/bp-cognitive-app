import Foundation

struct MemoryItem: Equatable {
    let value: String
    let category: MemoryCategory

    static func randomSequence(count: Int) -> [MemoryItem] {
        let category = MemoryCategory.allCases.randomElement() ?? .callsign
        let pool = category.items.shuffled()
        let selection = Array(pool.prefix(count))
        return selection.map { MemoryItem(value: $0, category: category) }
    }

    static func randomPrompt(from sequence: [MemoryItem]) -> MemoryItem {
        guard let category = sequence.first?.category else {
            return MemoryItem(value: MemoryCategory.callsign.items.randomElement() ?? "---", category: .callsign)
        }

        let useSequenceItem = Bool.random()
        if useSequenceItem, let item = sequence.randomElement() {
            return item
        }

        let options = category.items.filter { candidate in
            !sequence.contains(where: { $0.value == candidate })
        }

        let fallback = category.items.randomElement() ?? "---"
        return MemoryItem(value: options.randomElement() ?? fallback, category: category)
    }
}

enum MemoryCategory: CaseIterable {
    case callsign
    case airport
    case aircraft

    var displayName: String {
        switch self {
        case .callsign:
            return "Callsigns"
        case .airport:
            return "Airports"
        case .aircraft:
            return "Aircraft types"
        }
    }

    var items: [String] {
        switch self {
        case .callsign:
            return ["CSA", "EZY", "RYR", "UAE", "DLH", "BAW", "AFR", "KLM", "SAS", "QTR"]
        case .airport:
            return ["PRG", "DXB", "LHR", "IST", "MAD", "CDG", "FRA", "JFK", "LAX", "SIN"]
        case .aircraft:
            return ["A320", "B737", "A350", "B787", "B777", "A321", "A220", "E195", "A330", "ATR72"]
        }
    }
}
