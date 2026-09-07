import SwiftUI
import UIKit

@main
struct CrosstalkApp: App {
    @StateObject private var store = GameStore()

    init() {
        // Party games die when phones auto-lock mid-round.
        UIApplication.shared.isIdleTimerDisabled = true
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        }
    }
}
