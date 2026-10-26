import SwiftUI

/// The quiz the shield sends the user to. Seen many times a day, often
/// mid-frustration: calm, fast, high contrast, and never framed as a
/// failure. A wrong answer still lets the user in.
///
/// Rewards (XP, combo, streak, the "+N min unlocked" moment) are cosmetic
/// and scaled by difficulty, never by speed. A correct answer advances by
/// itself after a beat, so answering is one tap; a miss waits so the
/// explanation can be read.
struct GateView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var rewards: RewardStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let session: GateSession

    @State private var question: Question?
    @State private var shownAt = Date.now
    @State private var answered = 0
    @State private var picked: Int?
    @State private var lastResult: AnswerResult = .correct
    @State private var reward: AnswerReward?
    @State private var nudge: String?
    @State private var served: Set<String> = []
    @State private var unlocked = false
    @State private var autoAdvance: Task<Void, Never>?
    @StateObject private var feedback = GateFeedback()

    var body: some View {
        ZStack {
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
                        answerFeedback(q)
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

            if reward?.correct == true, !reduceMotion, !unlocked {
                ConfettiBurst().id(answered)
            }
            if unlocked {
                UnlockedMoment(minutes: Int(model.rules.passLength(for: lastResult) / 60))
            }
        }
        .onAppear(perform: serve)
        .onDisappear { autoAdvance?.cancel() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(session.appName.map { "Before \($0)" } ?? "Quick question")
                    .font(.headline)
                Spacer()
                StreakFlame(days: rewards.dayStreak)
            }
            HStack {
                Text("Question \(min(answered + 1, session.questionsOwed)) of \(session.questionsOwed)")
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                ComboBadge(combo: rewards.state.combo)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: rewards.state.combo)
            }
            XPBar(level: rewards.level, dailyXP: rewards.dailyXP, progress: rewards.dailyProgress)
        }
    }

    private func choiceButton(_ q: Question, _ i: Int) -> some View {
        let isAnswer = picked != nil && i == q.correctIndex
        let isPicked = picked == i
        let missed = isPicked && !isAnswer
        return Button { choose(q, i) } label: {
            HStack {
                Text(q.choices[i]).multilineTextAlignment(.leading)
                Spacer()
                if isAnswer { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.green) }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isAnswer ? Color.green.opacity(0.2)
                          : missed ? Color.orange.opacity(0.18)
                          : Color.secondary.opacity(0.08))
            )
            .scaleEffect(isAnswer && isPicked && !reduceMotion ? 1.03 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: picked)
        }
        .buttonStyle(.plain)
        .disabled(picked != nil)
    }

    @ViewBuilder
    private func answerFeedback(_ q: Question) -> some View {
        if lastResult == .incorrect {
            VStack(alignment: .leading, spacing: 8) {
                Text("Not quite").font(.headline)
                if let e = q.explanation { Text(e).font(.callout) }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))
        } else if lastResult == .correct, let reward {
            XPPop(reward: reward)
            if let level = reward.newLevel {
                Text("Level \(level)").font(.subheadline.weight(.semibold))
            } else if reward.dailyGoalReached {
                Text("Daily goal reached").font(.subheadline.weight(.semibold))
            }
        }
    }

    private func choose(_ q: Question, _ i: Int) {
        let elapsed = Date.now.timeIntervalSince(shownAt)
        let result = model.rules.classify(correct: i == q.correctIndex, answeredAfter: elapsed)
        if result == .tooFast {
            // Discarded, not scored: no rep, no pass, no XP. Same question again.
            nudge = "That was quick. Give it one more read."
            shownAt = .now
            return
        }
        nudge = nil
        picked = i
        lastResult = result
        answered += 1
        model.queue.record(q.id, correct: result == .correct)

        let r = rewards.record(correct: result == .correct, difficulty: q.difficulty)
        reward = r
        feedback.play(r)

        // One tap per question on a hit. Skipped for VoiceOver users, who
        // need time to hear the result.
        if result == .correct, !UIAccessibility.isVoiceOverRunning {
            autoAdvance = Task {
                try? await Task.sleep(nanoseconds: 1_100_000_000)
                if !Task.isCancelled { advance() }
            }
        }
    }

    private func advance() {
        autoAdvance?.cancel()
        guard !unlocked else { return }
        if answered >= session.questionsOwed {
            finish()
        } else {
            serve()
        }
    }

    /// Show the earned-time moment, then hand over to the model, which
    /// grants the pass (and dismisses this view). The length is unchanged;
    /// this only presents it.
    private func finish() {
        withAnimation { unlocked = true }
        feedback.unlocked()
        let result = lastResult
        Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            model.finishGate(lastResult: result)
        }
    }

    private func serve() {
        picked = nil
        nudge = nil
        reward = nil
        question = model.queue.nextDue(pool: model.pool, excluding: served)
        if let id = question?.id { served.insert(id) }
        shownAt = .now
    }
}
