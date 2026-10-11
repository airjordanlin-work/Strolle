import Foundation

/// Swift port of `app/lib/data/review_queue.dart`, persisted locally.
/// Same interval math: x2.5 on correct, reset to 10 minutes on wrong,
/// capped at one week. Keep the two in step.
struct ReviewItem: Codable {
    let questionId: String
    var dueAt: Date
    var intervalMinutes: Int
    var consecutiveCorrect: Int
}

final class ReviewQueue {
    private static let growthFactor = 2.5
    private static let resetIntervalMinutes = 10
    private static let capMinutes = 60 * 24 * 7
    private static let storageKey = "reviewQueue"

    private var items: [String: ReviewItem]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([String: ReviewItem].self, from: data) {
            items = decoded
        } else {
            items = [:]
        }
    }

    func record(_ questionId: String, correct: Bool, now: Date = .now) {
        var item = items[questionId] ?? ReviewItem(
            questionId: questionId, dueAt: now,
            intervalMinutes: Self.resetIntervalMinutes, consecutiveCorrect: 0)

        if correct {
            item.consecutiveCorrect += 1
            let grown = Int((Double(item.intervalMinutes) * Self.growthFactor).rounded())
            item.intervalMinutes = min(grown, Self.capMinutes)
        } else {
            item.consecutiveCorrect = 0
            item.intervalMinutes = Self.resetIntervalMinutes
        }
        item.dueAt = now.addingTimeInterval(TimeInterval(item.intervalMinutes * 60))
        items[questionId] = item
        save()
    }

    /// Most overdue item; else something unseen; else whatever is due
    /// soonest, so the gate always has something to serve.
    func nextDue(now: Date = .now, pool: [Question], excluding: Set<String> = []) -> Question? {
        let candidates = pool.filter { !excluding.contains($0.id) }
        let usable = candidates.isEmpty ? pool : candidates
        guard !usable.isEmpty else { return nil }
        let byId = Dictionary(uniqueKeysWithValues: usable.map { ($0.id, $0) })

        let due = items.values.filter { $0.dueAt <= now && byId[$0.questionId] != nil }
            .sorted { $0.dueAt < $1.dueAt }
        if let first = due.first { return byId[first.questionId] }

        if let unseen = usable.first(where: { items[$0.id] == nil }) { return unseen }

        let soonest = items.values.filter { byId[$0.questionId] != nil }
            .sorted { $0.dueAt < $1.dueAt }.first
        return soonest.flatMap { byId[$0.questionId] } ?? usable.first
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(items), forKey: Self.storageKey)
    }
}
