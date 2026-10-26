import SwiftUI
import UserNotifications

@main
struct StrolleApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = AppModel()
    @StateObject private var rewards = RewardStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(model)
                .environmentObject(rewards)
                .fullScreenCover(item: $model.gate) { session in
                    GateView(session: session)
                        .environmentObject(model)
                        .environmentObject(rewards)
                        .interactiveDismissDisabled()
                }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active { model.onForeground() }
        }
    }
}
