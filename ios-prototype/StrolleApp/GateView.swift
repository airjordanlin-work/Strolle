import SwiftUI

/// The quiz the shield sends the user to. Seen many times a day, often
/// mid-frustration: calm, fast, high contrast, and never framed as a
/// failure. A wrong answer still lets the user in.
struct GateView: View {
    @EnvironmentObject private var model: AppModel
    let session: GateSession

    @State private var question: Question?
    @State private var shownAt = Date.now
    @State private var answered = 0
    @State private var picked: Int?
    @State private var lastResult: AnswerResult = .correct
    @State private var nudge: String?
    @State private var served: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            if let q = question {
                Text(q.stem)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(q.choices.indices, id: \.self) { i in
                    choiceButton(q, i)
                }

                if let nudge {
                    Text(nudge).font(.callout).foregroundStyle(.secondary)
                }

                if picked != nil {
                    feedback(q)
                    Button(action: advance) {
                        Text(answered >= session.questionsOwed ? "Continue" : "Next question")
                            .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            Spacer()
        }
        .padding(24)
        .onAppear(perform: serve)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.appName.map { "Before \($0)" } ?? "Quick question")
                .font(.headline)
            Text("Question \(min(answered + 1, session.questionsOwed)) of \(session.questionsOwed)")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private func choiceButton(_ q: Question, _ i: Int) -> some View {
        let isAnswer = picked != nil && i == q.correctIndex
        let isPicked = picked == i
        return Button { choose(q, i) } label: {
            HStack {
                Text(q.choices[i]).multilineTextAlignment(.leading)
                Spacer()
                if isAnswer { Image(systemName: "checkmark") }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isAnswer ? Color.accentColor.opacity(0.18)
                          : isPicked ? Color.secondary.opacity(0.18)
                          : Color.secondary.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
        .disabled(picked != nil)
    }

    @ViewBuilder
    private func feedback(_ q: Question) -> some View {
        if lastResult == .incorrect, let e = q.explanation {
            Text(e).font(.callout).padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))
        } else if lastResult == .correct {
            Text("Nice.").font(.callout).foregroundStyle(.secondary)
        }
    }

    private func choose(_ q: Question, _ i: Int) {
        let elapsed = Date.now.timeIntervalSince(shownAt)
        let result = model.rules.classify(correct: i == q.correctIndex, answeredAfter: elapsed)
        if result == .tooFast {
            // Discarded, not scored: no rep, no pass. Same question again.
            nudge = "That was quick. Give it one more read."
            shownAt = .now
            return
        }
        nudge = nil
        picked = i
        lastResult = result
        answered += 1
        model.queue.record(q.id, correct: result == .correct)
    }

    private func advance() {
        if answered >= session.questionsOwed {
            model.finishGate(lastResult: lastResult)
        } else {
            serve()
        }
    }

    private func serve() {
        picked = nil
        nudge = nil
        question = model.queue.nextDue(pool: model.pool, excluding: served)
        if let id = question?.id { served.insert(id) }
        shownAt = .now
    }
}
