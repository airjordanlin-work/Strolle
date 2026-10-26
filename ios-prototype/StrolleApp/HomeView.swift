import SwiftUI
import FamilyControls

/// The calm surface: set up Screen Time, choose apps, see pass state.
struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var rewards: RewardStore
    @State private var pickerShown = false
    @State private var draft = FamilyActivitySelection()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Pick the apps you scroll too much. Opening one asks you a quick SAT question first.")
                        .font(.system(.title3, design: .serif))
                        .padding(.vertical, 8)
                }

                Section("Progress") {
                    XPBar(level: rewards.level, dailyXP: rewards.dailyXP, progress: rewards.dailyProgress)
                    HStack {
                        StreakFlame(days: rewards.dayStreak)
                        Text("day streak")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }

                Section("Screen Time") {
                    if model.authorized {
                        Label("Access granted", systemImage: "checkmark.circle")
                    } else {
                        Button("Allow Screen Time access") {
                            Task { await model.requestAuthorization() }
                        }
                        .frame(minHeight: 56)
                    }
                    if let err = model.authError {
                        Text(err).font(.footnote).foregroundStyle(.secondary)
                    }
                }

                if model.authorized {
                    Section("Gated apps") {
                        let s = model.selection
                        Text("\(s.applicationTokens.count) apps, \(s.categoryTokens.count) categories, \(s.webDomainTokens.count) sites")
                        Button("Choose apps") {
                            draft = model.selection
                            pickerShown = true
                        }
                        .frame(minHeight: 56)
                    }

                    Section("Pass") {
                        TimelineView(.periodic(from: .now, by: 1)) { ctx in
                            if let exp = model.passExpiresAt, exp > ctx.date {
                                Text("Open for \(exp, style: .relative)")
                            } else {
                                Text("Gated apps are shielded")
                            }
                        }
                        Button("Lock now") { model.lockNow() }
                            .frame(minHeight: 56)
                        Button("Practice a question") { model.startGate(appName: nil) }
                            .frame(minHeight: 56)
                    }
                }
            }
            .navigationTitle("Strolle")
            .familyActivityPicker(isPresented: $pickerShown, selection: $draft)
            .onChange(of: pickerShown) { shown in
                if !shown { model.saveSelection(draft) }
            }
        }
    }
}
