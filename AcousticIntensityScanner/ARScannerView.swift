import SwiftUI
import ARKit
import RealityKit
import UIKit

struct SelectedGridPoint: Equatable {
    let planeID: UUID
    let ix: Int
    let iz: Int
    let position: SIMD3<Float>
}

struct ARScannerView: UIViewRepresentable {
    @ObservedObject var measurements: MeasurementStore
    let spacing: Double
    @Binding var status: String
    @Binding var selectedPoint: SelectedGridPoint?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        view.environment.sceneUnderstanding.options.insert(.occlusion)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) { config.sceneReconstruction = .mesh }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) { config.frameSemantics.insert(.sceneDepth) }
        view.session.delegate = context.coordinator
        view.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        context.coordinator.view = view
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.refresh()
    }

    final class Coordinator: NSObject, ARSessionDelegate {
        var parent: ARScannerView
        weak var view: ARView?
        var planes: [UUID: ARPlaneAnchor] = [:]
        var rendered: [UUID: AnchorEntity] = [:]
        private var lastRefresh = Date.distantPast

        init(_ parent: ARScannerView) { self.parent = parent }

        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) { ingest(anchors) }
        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) { ingest(anchors) }
        func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
            for anchor in anchors {
                planes.removeValue(forKey: anchor.identifier)
                if let entity = rendered.removeValue(forKey: anchor.identifier) { view?.scene.removeAnchor(entity) }
            }
        }

        private func ingest(_ anchors: [ARAnchor]) {
            for anchor in anchors { if let plane = anchor as? ARPlaneAnchor { planes[plane.identifier] = plane } }
            guard Date().timeIntervalSince(lastRefresh) > 0.15 else { return }
            lastRefresh = Date()
            DispatchQueue.main.async { self.refresh() }
        }

        func refresh() {
            guard let view else { return }
            for (_, entity) in rendered { view.scene.removeAnchor(entity) }
            rendered.removeAll()
            let step = Float(parent.spacing)
            guard step > 0 else { return }
            var closest: (point: SelectedGridPoint, distance: Float)?
            let camera = view.cameraTransform.translation

            for (id, plane) in planes {
                let anchor = AnchorEntity(world: plane.transform)
                let width = max(plane.extent.x, step)
                let depth = max(plane.extent.z, step)
                let countX = min(80, max(1, Int(width / step)))
                let countZ = min(80, max(1, Int(depth / step)))
                for ix in 0..<countX {
                    for iz in 0..<countZ {
                        let localX = plane.center.x - width / 2 + (Float(ix) + 0.5) * step
                        let localZ = plane.center.z - depth / 2 + (Float(iz) + 0.5) * step
                        let local = SIMD3<Float>(localX, 0.006, localZ)
                        let world4 = plane.transform * SIMD4<Float>(local.x, local.y, local.z, 1)
                        let world = SIMD3<Float>(world4.x, world4.y, world4.z)
                        let point = SelectedGridPoint(planeID: id, ix: ix, iz: iz, position: world)
                        let key = parent.measurements.key(planeID: id, ix: ix, iz: iz)
                        let isMeasured = parent.measurements.values[key] != nil
                        let mesh = MeshResource.generateBox(size: [step * 0.92, 0.004, step * 0.92], cornerRadius: 0.004)
                        let material: SimpleMaterial
                        if let m = parent.measurements.values[key] {
                            let c = Self.jetColor(value: m.levelDB, min: parent.measurements.minDisplayDB, max: parent.measurements.maxDisplayDB, alpha: parent.measurements.overlayOpacity)
                            material = SimpleMaterial(color: c, roughness: 1, isMetallic: false)
                        } else {
                            material = SimpleMaterial(color: UIColor(white: 0.85, alpha: 0.10), roughness: 1, isMetallic: false)
                        }
                        let cell = ModelEntity(mesh: mesh, materials: [material])
                        cell.position = local
                        anchor.addChild(cell)
                        if !isMeasured {
                            let d = simd_distance(world, camera)
                            if closest == nil || d < closest!.distance { closest = (point, d) }
                        }
                    }
                }
                view.scene.addAnchor(anchor)
                rendered[id] = anchor
            }
            parent.selectedPoint = closest?.point
            parent.status = planes.isEmpty ? "Move the phone slowly to detect a surface…" : "Surface detected • \(planes.count) plane(s)"
        }

        static func jetColor(value: Double, min: Double, max: Double, alpha: Double) -> UIColor {
            let denom = Swift.max(max - min, 0.001)
            let x = Swift.min(1, Swift.max(0, (value - min) / denom))
            func clamp(_ v: Double) -> CGFloat { CGFloat(Swift.min(1, Swift.max(0, v))) }
            let r = clamp(1.5 - abs(4.0 * x - 3.0))
            let g = clamp(1.5 - abs(4.0 * x - 2.0))
            let b = clamp(1.5 - abs(4.0 * x - 1.0))
            return UIColor(red: r, green: g, blue: b, alpha: CGFloat(alpha))
        }
    }
}
