import SwiftUI
import UserNotifications

@main
struct StrolleApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(model)
                .fullScreenCover(item: $model.gate) { session in
                    GateView(session: session)
                        .environmentObject(model)
                        .interactiveDismissDisabled()
                }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active { model.onForeground() }
        }
    }
}
