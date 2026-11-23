import SwiftUI

@main
struct LoverOrderApp: App {
    @UIApplicationDelegateAdaptor(LoverAppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .task {
                    await appState.bootstrap()
                }
                .onOpenURL { url in
                    appState.handleOpenURL(url)
                }
        }
    }
}
