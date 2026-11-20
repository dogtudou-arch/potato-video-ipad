import SwiftUI

@main
struct PotatoVideoApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = VideoStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .task {
                    while !Task.isCancelled {
                        _ = await DeviceManagement.shared.canUse(force: true)
                        try? await Task.sleep(nanoseconds: 600_000_000_000)
                    }
                }
                .onChange(of: scenePhase) { phase in
                    guard phase == .active || phase == .background else { return }
                    UserDefaults.standard.set(phase == .active ? "foreground" : "background", forKey: "management_presence")
                    Task { _ = await DeviceManagement.shared.canUse(force: true) }
                }
        }
    }
}
