import Foundation
import simd

struct GridMeasurement: Identifiable, Hashable {
    let id: String
    let planeID: UUID
    let ix: Int
    let iz: Int
    let position: SIMD3<Float>
    var levelDB: Double
    var coherence: Double
    var timestamp: Date
}

@MainActor
final class MeasurementStore: ObservableObject {
    @Published var values: [String: GridMeasurement] = [:]
    @Published var minDisplayDB: Double = 40
    @Published var maxDisplayDB: Double = 90
    @Published var overlayOpacity: Double = 0.48

    func key(planeID: UUID, ix: Int, iz: Int) -> String { "\(planeID.uuidString)-\(ix)-\(iz)" }
    func save(_ measurement: GridMeasurement) { values[measurement.id] = measurement }
    func clear() { values.removeAll() }
}
