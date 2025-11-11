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
    let voicePreset: String
}

class AudioEngineIOS {
    static let shared = AudioEngineIOS()
    private let engine = AVAudioEngine()
    private let eqNode = AVAudioUnitEQ(numberOfBands: 5)
    private let pitchNode = AVAudioUnitTimePitch()
    private let distortionNode = AVAudioUnitDistortion()
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
        delayNode.wetDryMix = 0
        pitchNode.rate = 1.0
        pitchNode.pitch = 0 // cents
        distortionNode.loadFactoryPreset(.drumsBitBrush)
        distortionNode.wetDryMix = 0
        distortionNode.preGain = 0
        distortionNode.bypass = true

        engine.attach(eqNode)
        engine.attach(pitchNode)
        engine.attach(distortionNode)
        engine.attach(reverbNode)
        engine.attach(delayNode)

        // input -> eq -> pitch -> reverb -> delay -> mixer -> output
        let format = input.inputFormat(forBus: 0)
        engine.connect(input, to: eqNode, format: format)
        engine.connect(eqNode, to: pitchNode, format: format)
        engine.connect(pitchNode, to: distortionNode, format: format)
        engine.connect(distortionNode, to: reverbNode, format: format)
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
        delayNode.wetDryMix = p.echo ? 35 : 0
        // Volume (post-fader)
        engine.mainMixerNode.outputVolume = Float(p.volume)
        applyVoicePreset(p.voicePreset)
    }

    private func applyVoicePreset(_ raw: String) {
        let preset = VoicePreset(rawValue: raw) ?? .normal
        switch preset {
        case .normal:
            distortionNode.bypass = true
            distortionNode.wetDryMix = 0
            distortionNode.preGain = 0
        case .child:
            distortionNode.bypass = false
            distortionNode.loadFactoryPreset(.multiCellphoneConcert)
            distortionNode.preGain = -6
            distortionNode.wetDryMix = 12
        case .funny:
            distortionNode.bypass = false
            distortionNode.loadFactoryPreset(.multiCellphoneConcert)
            distortionNode.preGain = -3
            distortionNode.ringModMix = 50
            distortionNode.wetDryMix = 25
        case .robot:
            distortionNode.bypass = false
            distortionNode.loadFactoryPreset(.speechAlienChatter)
            distortionNode.preGain = -8
            distortionNode.ringModMix = 65
            distortionNode.wetDryMix = 45
        case .deep:
            distortionNode.bypass = false
            distortionNode.loadFactoryPreset(.drumsBitBrush)
            distortionNode.preGain = -10
            distortionNode.wetDryMix = 15
        case .alien:
            distortionNode.bypass = false
            distortionNode.loadFactoryPreset(.multiBrokenSpeaker)
            distortionNode.preGain = -4
            distortionNode.ringModMix = 70
            distortionNode.wetDryMix = 40
        }
    }
}

private enum VoicePreset: String {
    case normal, child, funny, robot, deep, alien
}

private func log2(_ x: Double) -> Double { return Darwin.log2(x) }
