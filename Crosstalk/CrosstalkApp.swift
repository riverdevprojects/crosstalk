import SwiftUI

@main
struct CrosstalkApp: App {
    @StateObject private var store = GameStore()
    var body: some Scene {
        WindowGroup { ContentView().environmentObject(store) }
    }
}
