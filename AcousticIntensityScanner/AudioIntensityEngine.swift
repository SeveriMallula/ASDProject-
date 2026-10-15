import AVFoundation
import Accelerate

final class AudioIntensityEngine: ObservableObject {
    @Published private(set) var status = "Audio idle"
    @Published private(set) var channelCount = 0
    @Published private(set) var sampleRate = 0.0
    @Published private(set) var lastBroadbandDB = 0.0
    @Published private(set) var lastCoherence = 0.0

    private let engine = AVAudioEngine()
    private var samples1: [Float] = []
    private var samples2: [Float] = []
    private let lock = NSLock()

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [])
        try session.setPreferredSampleRate(48_000)
        try session.setActive(true)
        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        sampleRate = format.sampleRate
        channelCount = Int(format.channelCount)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in self?.consume(buffer) }
        engine.prepare()
        try engine.start()
        status = channelCount >= 2 ? "Stereo input active" : "Mono input active — phase intensity unavailable"
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false)
        status = "Audio idle"
    }

    private func consume(_ buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData else { return }
        let frames = Int(buffer.frameLength)
        lock.lock()
        samples1.append(contentsOf: UnsafeBufferPointer(start: data[0], count: frames))
        if buffer.format.channelCount >= 2 { samples2.append(contentsOf: UnsafeBufferPointer(start: data[1], count: frames)) }
        let maxSamples = Int(max(sampleRate, 48_000) * 6.0)
        if samples1.count > maxSamples { samples1.removeFirst(samples1.count - maxSamples) }
        if samples2.count > maxSamples { samples2.removeFirst(samples2.count - maxSamples) }
        lock.unlock()
    }

    func snapshot(duration: Double = 1.0) -> (levelDB: Double, coherence: Double)? {
        lock.lock(); defer { lock.unlock() }
        let nWanted = max(1024, Int(sampleRate * duration))
        guard samples1.count >= nWanted else { return nil }
        let a = Array(samples1.suffix(nWanted))
        var meanSquare: Float = 0
        vDSP_measqv(a, 1, &meanSquare, vDSP_Length(a.count))
        let rms = sqrt(max(meanSquare, 1e-20))
        let level = 20.0 * log10(Double(rms) / 0.00002)
        var coherence = 0.0
        if channelCount >= 2, samples2.count >= nWanted {
            let b = Array(samples2.suffix(nWanted))
            var dot: Float = 0, aa: Float = 0, bb: Float = 0
            vDSP_dotpr(a, 1, b, 1, &dot, vDSP_Length(a.count))
            vDSP_svesq(a, 1, &aa, vDSP_Length(a.count))
            vDSP_svesq(b, 1, &bb, vDSP_Length(b.count))
            let denom = sqrt(Double(max(aa * bb, 1e-30)))
            let corr = denom > 0 ? Double(dot) / denom : 0
            coherence = min(1, max(0, corr * corr))
        }
        DispatchQueue.main.async { self.lastBroadbandDB = level; self.lastCoherence = coherence }
        return (level, coherence)
    }
}
