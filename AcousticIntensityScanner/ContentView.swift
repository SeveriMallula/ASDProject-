import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var measurements: MeasurementStore
    @StateObject private var audio = AudioIntensityEngine()
    @State private var spacing = 0.25
    @State private var status = "Point the camera at the measurement surface"
    @State private var selectedPoint: SelectedGridPoint?
    @State private var audioRunning = false
    @State private var errorText: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            ARScannerView(measurements: measurements, spacing: spacing, status: $status, selectedPoint: $selectedPoint)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Acoustic Intensity Scanner").font(.headline)
                        Text(status).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(measurements.values.count) measured").font(.caption.monospacedDigit())
                }

                Picker("Grid", selection: $spacing) {
                    Text("10 cm").tag(0.10)
                    Text("25 cm").tag(0.25)
                    Text("50 cm").tag(0.50)
                }.pickerStyle(.segmented)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(audioRunning ? audio.status : "Audio stopped").font(.caption)
                        Text("Input: \(audio.channelCount) ch • \(Int(audio.sampleRate)) Hz").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(audioRunning ? "Stop audio" : "Start audio") { toggleAudio() }.buttonStyle(.bordered)
                }

                Button { measureCurrentPoint() } label: {
                    Label("Measure current grid point", systemImage: "waveform.badge.mic")
                        .frame(maxWidth: .infinity).padding(.vertical, 5)
                }.buttonStyle(.borderedProminent).disabled(!audioRunning || selectedPoint == nil)

                HStack {
                    Text("Transparent jet overlay")
                    Slider(value: $measurements.overlayOpacity, in: 0.15...0.80)
                    Button("Clear") { measurements.clear() }.font(.caption)
                }

                Text("EXPERIMENTAL: displayed dB is an engineering visualization. True sound-intensity results require validated independent microphone channels, spacing, amplitude calibration and phase calibration.")
                    .font(.caption2).foregroundStyle(.secondary)

                if let errorText { Text(errorText).font(.caption).foregroundStyle(.red) }
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .padding()
        }
        .onDisappear { audio.stop() }
    }

    private func toggleAudio() {
        if audioRunning { audio.stop(); audioRunning = false }
        else {
            do { try audio.start(); audioRunning = true; errorText = nil }
            catch { errorText = error.localizedDescription }
        }
    }

    private func measureCurrentPoint() {
        guard let p = selectedPoint else { return }
        guard let result = audio.snapshot(duration: 1.0) else { errorText = "Collecting audio — try again after about one second."; return }
        let id = measurements.key(planeID: p.planeID, ix: p.ix, iz: p.iz)
        measurements.save(GridMeasurement(id: id, planeID: p.planeID, ix: p.ix, iz: p.iz, position: p.position, levelDB: result.levelDB, coherence: result.coherence, timestamp: Date()))
        errorText = nil
    }
}
