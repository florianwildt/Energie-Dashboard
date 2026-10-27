import SwiftUI

@main
struct HausenergieApp: App {
    @State private var store = EnergyStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(\.locale, Locale(identifier: "de_DE"))
                .tint(Theme.mint)
                .preferredColorScheme(store.settings.appearance == "dark" ? .dark : store.settings.appearance == "light" ? .light : nil)
                .task(id: RefreshSession(active: scenePhase == .active, demo: store.settings.demoMode)) {
                    if scenePhase == .active {
                        PerformanceLog.shared.setActive(true)
                        await store.run()
                    } else {
                        PerformanceLog.shared.setActive(false)
                        await store.flushPersistence()
                    }
                }
        }
    }
}

private struct RefreshSession: Hashable {
    var active: Bool
    var demo: Bool
}
