import SwiftUI

/// Daily-streak flame with a count. Greyed out at zero.
struct StreakFlame: View {
    let days: Int
    @State private var bump = false

    var body: some View {
        Label("\(days)", systemImage: "flame.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(days > 0 ? Color.orange : Color.secondary)
            .scaleEffect(bump ? 1.25 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: bump)
            .onChange(of: days) { _ in
                bump = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { bump = false }
            }
            .accessibilityLabel("\(days) day streak")
    }
}

/// Combo multiplier chip, shown from a run of 2 correct answers.
struct ComboBadge: View {
    let combo: Int

    var body: some View {
        if combo >= 2 {
            let mult = RewardRules.multiplier(forCombo: combo)
            HStack(spacing: 4) {
                Text("\(combo) in a row")
                if mult > 1 { Text("x" + String(format: "%g", mult)).fontWeight(.bold) }
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Capsule().fill(Color.green.opacity(0.18)))
            .transition(.scale.combined(with: .opacity))
        }
    }
}

/// Daily XP bar with the level on the left.
struct XPBar: View {
    let level: Int
    let dailyXP: Int
    let progress: Double

    var body: some View {
        HStack(spacing: 10) {
            Text("Lv \(level)").font(.caption.weight(.bold))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15))
                    Capsule().fill(Color.accentColor)
                        .frame(width: max(8, geo.size.width * progress))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 8)
            Text("\(dailyXP)/\(RewardRules.dailyGoalXP) XP").font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Level \(level), \(dailyXP) of \(RewardRules.dailyGoalXP) daily XP")
    }
}

/// "+20 XP", with "x1.5" when a combo applies. Rises and fades in place.
struct XPPop: View {
    let reward: AnswerReward
    @State private var shown = false

    var body: some View {
        HStack(spacing: 6) {
            Text("+\(reward.xp) XP").fontWeight(.bold)
            if reward.multiplier > 1 { Text("x" + String(format: "%g", reward.multiplier)) }
        }
        .font(.headline)
        .foregroundStyle(Color.green)
        .opacity(shown ? 1 : 0)
        .offset(y: shown ? 0 : 10)
        .onAppear { withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { shown = true } }
    }
}

/// A short burst of dots. Skipped entirely under Reduce Motion by the caller.
struct ConfettiBurst: View {
    private struct Piece: Identifiable {
        let id = UUID()
        let angle = Double.random(in: 0..<(2 * .pi))
        let distance = CGFloat.random(in: 50...130)
        let size = CGFloat.random(in: 5...9)
        let color = [Color.green, .orange, .yellow, .blue, .pink].randomElement()!
    }
    private let pieces = (0..<22).map { _ in Piece() }
    @State private var go = false

    var body: some View {
        ZStack {
            ForEach(pieces) { p in
                Circle().fill(p.color)
                    .frame(width: p.size, height: p.size)
                    .offset(x: go ? cos(p.angle) * p.distance : 0,
                            y: go ? sin(p.angle) * p.distance : 0)
                    .opacity(go ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .onAppear { withAnimation(.easeOut(duration: 0.9)) { go = true } }
    }
}

/// Full-screen earned-time moment shown after the last owed question,
/// right before the pass is granted. The minutes are whatever `PassRules`
/// returns; this view only presents them.
struct UnlockedMoment: View {
    let minutes: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shownMinutes = 0
    @State private var popped = false

    var body: some View {
        ZStack {
            Rectangle().fill(.regularMaterial).ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Color.green)
                    .scaleEffect(popped ? 1 : 0.4)
                Text("+\(shownMinutes) min")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text("unlocked").font(.title3).foregroundStyle(.secondary)
            }
            if !reduceMotion { ConfettiBurst() }
        }
        .transition(.opacity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(minutes) minutes unlocked")
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) { popped = true }
            withAnimation(.easeOut(duration: 0.7).delay(0.15)) { shownMinutes = minutes }
        }
    }
}
