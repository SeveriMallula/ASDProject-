import SwiftUI

@main
struct AcousticIntensityScannerApp: App {
    @StateObject private var measurements = MeasurementStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(measurements)
        }
    }
}
