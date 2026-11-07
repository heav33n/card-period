#if canImport(SwiftUI)
import SwiftUI

@main struct CardPeriodApp: App {
    @StateObject private var store = CardStore()
    var body: some Scene { WindowGroup { HomeView().environmentObject(store) } }
}

#endif
