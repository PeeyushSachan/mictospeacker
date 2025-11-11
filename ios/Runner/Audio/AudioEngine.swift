import AVFoundation

struct EqBandParam: Codable { let freq: Int; let gainDb: Double }
struct DspParams: Codable {
    let eq: [EqBandParam]
    let pitch: Double
    let formant: Int
    let reverb: Bool
    let reverbWet: Double
    let echo: Bool
    let echoDelayMs: Int
    let echoFeedback: Double
    let volume: Double
}

class AudioEngineIOS {
    static let shared = AudioEngineIOS()
    private let engine = AVAudioEngine()
    private let eqNode = AVAudioUnitEQ(numberOfBands: 5)
    private let pitchNode = AVAudioUnitTimePitch()
    private let reverbNode = AVAudioUnitReverb()
    private let delayNode = AVAudioUnitDelay()
    private var tapInstalled = false
    private var levelCallback: ((Double)->Void)?

    func setLevelCallback(_ cb: @escaping (Double)->Void) { levelCallback = cb }

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setPreferredIOBufferDuration(0.005)
        try session.setActive(true)

        let input = engine.inputNode
        let mainMixer = engine.mainMixerNode

        // EQ bands center freqs
        let freqs: [Float] = [60, 230, 910, 3600, 14000]
        for (i, b) in eqNode.bands.enumerated() {
            b.filterType = .parametric
            b.frequency = freqs[i]
            b.bandwidth = 1.0
            b.gain = 0
            b.bypass = false
        }

        reverbNode.loadFactoryPreset(.mediumRoom)
        reverbNode.wetDryMix = 0
        delayNode.delayTime = 0.24
        delayNode.feedback = 35
        pitchNode.rate = 1.0
        pitchNode.pitch = 0 // cents

        engine.attach(eqNode)
        engine.attach(pitchNode)
        engine.attach(reverbNode)
        engine.attach(delayNode)

        // input -> eq -> pitch -> reverb -> delay -> mixer -> output
        let format = input.inputFormat(forBus: 0)
        engine.connect(input, to: eqNode, format: format)
        engine.connect(eqNode, to: pitchNode, format: format)
        engine.connect(pitchNode, to: reverbNode, format: format)
        engine.connect(reverbNode, to: delayNode, format: format)
        engine.connect(delayNode, to: mainMixer, format: format)

        if !tapInstalled {
            mainMixer.installTap(onBus: 0, bufferSize: 1024, format: mainMixer.outputFormat(forBus: 0)) { [weak self] buf, _ in
                guard let ch = buf.floatChannelData?.pointee else { return }
                let n = Int(buf.frameLength)
                var sum: Float = 0
                for i in 0..<n { let s = ch[i]; sum += s*s }
                let rms = min(max(Double(sqrt(sum/Float(n))), 0), 1)
                self?.levelCallback?(rms)
            }
            tapInstalled = true
        }

        if !engine.isRunning {
            try engine.start()
        }
    }

    func stop() {
        engine.pause()
    }

    func apply(_ p: DspParams) {
        // EQ gains
        let freqs: [Float] = [60, 230, 910, 3600, 14000]
        for (i, band) in eqNode.bands.enumerated() {
            band.frequency = freqs[i]
            band.gain = Float(p.eq[i].gainDb)
        }
        // Pitch: 1.0x = 0 cents; 2.0x ≈ +1200 cents
        pitchNode.pitch = Float(1200.0 * log2(p.pitch))
        // Reverb
        reverbNode.wetDryMix = p.reverb ? Float(p.reverbWet * 100.0) : 0
        // Echo
        delayNode.delayTime = p.echo ? Double(p.echoDelayMs) / 1000.0 : 0
        delayNode.feedback = p.echo ? Float(p.echoFeedback * 100.0) : 0
        // Volume (post-fader)
        engine.mainMixerNode.outputVolume = Float(p.volume)
    }
}

private func log2(_ x: Double) -> Double { return Darwin.log2(x) }
