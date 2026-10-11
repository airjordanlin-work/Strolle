import Foundation

/// Mirrors the schema of `app/assets/questions.json`, which the Xcode
/// project bundles directly so there is one question file, not two.
struct Question: Decodable, Identifiable, Equatable {
    enum Tier: String, Decodable { case gate, session }

    let id: String
    let section: String
    let skill: String
    let tier: Tier
    let stem: String
    let choices: [String]
    let correctIndex: Int
    let explanation: String?

    enum CodingKeys: String, CodingKey {
        case id, section, skill, tier, stem, choices, explanation
        case correctIndex = "correct_index"
    }
}

enum QuestionBank {
    /// Only gate-tier items are ever served at the gate (README, design
    /// principle 2). A malformed file fails loudly rather than silently
    /// leaving the gate empty.
    static func loadGatePool(bundle: Bundle = .main) -> [Question] {
        guard let url = bundle.url(forResource: "questions", withExtension: "json") else {
            fatalError("questions.json is not in the app bundle.")
        }
        do {
            let all = try JSONDecoder().decode([Question].self, from: Data(contentsOf: url))
            for q in all where !(0..<q.choices.count).contains(q.correctIndex) {
                fatalError("Question \(q.id) has an out-of-range correct_index.")
            }
            return all.filter { $0.tier == .gate }
        } catch {
            fatalError("questions.json failed to parse: \(error)")
        }
    }
}
