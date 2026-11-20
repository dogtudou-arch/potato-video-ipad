import SwiftUI

@main
struct PotatoVideoApp: App {
    @StateObject private var store = VideoStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .task { _ = await DeviceManagement.shared.canUse() }
        }
    }
}
