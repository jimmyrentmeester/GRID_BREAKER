import Foundation
import AVFoundation

/// Programmatic synth audio — sharp analog SFX + a looping darksynth pulse
/// (brief §10.6). No audio assets: everything is rendered into PCM buffers at
/// launch and played via AVAudioEngine. Defensive throughout — if audio fails to
/// start, the game plays on silently (it never throws into the game loop).
///
/// Shared singleton: audio is a global service; the game/menu just call `play`.
@MainActor
final class AudioEngine {
    static let shared = AudioEngine()

    /// One-shot SFX, each traced to a real game event (mirrors the juice layer).
    enum SFX { case decode, decodeBig, breach, miss, bomb, fever, gameOver, uiTap }

    private let engine = AVAudioEngine()
    private let music = AVAudioPlayerNode()
    private var sfxPool: [AVAudioPlayerNode] = []
    private var sfxIndex = 0
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var buffers: [SFX: AVAudioPCMBuffer] = [:]
    private var musicBuffer: AVAudioPCMBuffer?

    private(set) var isRunning = false
    /// Master toggle (persisted in settings). Stops/starts the music loop.
    var enabled = true {
        didSet {
            guard oldValue != enabled else { return }
            if enabled { startMusicIfNeeded() } else { music.stop() }
        }
    }

    private var sampleRate: Double { format.sampleRate }

    // MARK: Lifecycle

    /// Configure the audio session, build buffers and start the engine. Idempotent.
    func start() {
        guard !isRunning else { return }
        #if canImport(UIKit)
        // .ambient: respects the ring/silent switch and mixes politely — standard
        // for a casual arcade game.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif

        buildBuffers()

        for _ in 0..<6 {                       // pool so rapid SFX overlap
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            sfxPool.append(node)
        }
        engine.attach(music)
        engine.connect(music, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.9

        engine.prepare()
        do {
            try engine.start()
            isRunning = true
            sfxPool.forEach { $0.play() }
            if enabled { startMusicIfNeeded() }
        } catch {
            isRunning = false      // game continues silently
        }
    }

    // MARK: Playback

    func play(_ sfx: SFX) {
        guard isRunning, enabled, let buffer = buffers[sfx] else { return }
        let node = sfxPool[sfxIndex]
        sfxIndex = (sfxIndex + 1) % sfxPool.count
        node.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
    }

    private func startMusicIfNeeded() {
        guard isRunning, enabled, let loop = musicBuffer else { return }
        music.stop()
        music.scheduleBuffer(loop, at: nil, options: .loops, completionHandler: nil)
        music.play()
    }

    // MARK: Synthesis helpers

    private func buffer(seconds: Double, _ fill: (_ i: Int, _ t: Double) -> Float) -> AVAudioPCMBuffer {
        let frames = max(1, Int(sampleRate * seconds))
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))!
        buf.frameLength = AVAudioFrameCount(frames)
        let ptr = buf.floatChannelData![0]
        for i in 0..<frames { ptr[i] = fill(i, Double(i) / sampleRate) }
        return buf
    }

    private func sine(_ f: Double, _ t: Double) -> Double { sin(2 * .pi * f * t) }
    private func saw(_ f: Double, _ t: Double) -> Double { 2 * ((t * f).truncatingRemainder(dividingBy: 1)) - 1 }
    private func square(_ f: Double, _ t: Double) -> Double { sine(f, t) >= 0 ? 1 : -1 }
    private func decayEnv(_ t: Double, _ tau: Double) -> Double { exp(-t / tau) }
    private func noise() -> Double { Double.random(in: -1...1) }

    private func buildBuffers() {
        // Bright electrical discharge: upward chirp + crisp sine + a touch of noise.
        buffers[.decode] = buffer(seconds: 0.10) { _, t in
            let f = 900 + 2600 * t
            let body = self.sine(f, t) * self.decayEnv(t, 0.035)
            let spark = self.noise() * self.decayEnv(t, 0.012)
            return Float((body * 0.32 + spark * 0.12))
        }
        // Heavier discharge for armored kills — lower, punchier, a beat longer.
        buffers[.decodeBig] = buffer(seconds: 0.16) { _, t in
            let f = 500 + 1400 * t
            let body = (self.sine(f, t) + 0.5 * self.saw(f * 0.5, t)) * self.decayEnv(t, 0.06)
            let spark = self.noise() * self.decayEnv(t, 0.02)
            return Float((body * 0.30 + spark * 0.12))
        }
        // Soft tick when an armored shell breaches.
        buffers[.breach] = buffer(seconds: 0.06) { _, t in
            Float((self.square(2200, t) * self.decayEnv(t, 0.012) * 0.18))
        }
        // Muted analog glitch on a miss — dull downward blip + noise.
        buffers[.miss] = buffer(seconds: 0.14) { _, t in
            let f = 320 - 160 * t
            let body = self.square(f, t) * self.decayEnv(t, 0.05)
            let grit = self.noise() * self.decayEnv(t, 0.03)
            return Float((body * 0.18 + grit * 0.10))
        }
        // Firewall detonation: low rumble + downward noise sweep.
        buffers[.bomb] = buffer(seconds: 0.55) { _, t in
            let rumble = self.sine(70 + 30 * self.decayEnv(t, 0.2), t) * self.decayEnv(t, 0.28)
            let blast = self.noise() * self.decayEnv(t, 0.18)
            return Float((rumble * 0.35 + blast * 0.30) * min(1, t * 60)) // tiny attack
        }
        // Fever sting: bright rising arpeggio.
        buffers[.fever] = buffer(seconds: 0.45) { _, t in
            let steps = [440.0, 587.33, 659.25, 880.0]
            let idx = min(steps.count - 1, Int(t / 0.11))
            let f = steps[idx]
            let local = t - Double(idx) * 0.11
            return Float((self.saw(f, t) * 0.5 + self.sine(f * 2, t) * 0.5) * self.decayEnv(local, 0.09) * 0.22)
        }
        // Game over: descending minor tone.
        buffers[.gameOver] = buffer(seconds: 0.7) { _, t in
            let f = 330 * pow(2.0, -t * 1.2)
            return Float((self.saw(f, t) * 0.5 + self.sine(f, t) * 0.5) * self.decayEnv(t, 0.4) * 0.24)
        }
        // Subtle UI blip.
        buffers[.uiTap] = buffer(seconds: 0.05) { _, t in
            Float((self.sine(1200, t) * self.decayEnv(t, 0.02) * 0.14))
        }

        musicBuffer = buildMusicLoop()
    }

    /// A driving darksynth pulse (~130 BPM, A-minor): a sawtooth bass on every
    /// eighth note + a sparse high arp, rendered into one looping buffer.
    private func buildMusicLoop() -> AVAudioPCMBuffer {
        let bpm = 130.0
        let step = 60.0 / bpm / 2          // eighth note
        let bass = [110.0, 110, 87.31, 87.31, 98.0, 98, 130.81, 110] // A A F F G G C A
        let arp  = [440.0, 0, 523.25, 0, 587.33, 0, 659.25, 0]
        let steps = bass.count
        let total = step * Double(steps)

        return buffer(seconds: total) { _, t in
            let s = min(steps - 1, Int(t / step))
            let local = t - Double(s) * step
            var v = 0.0
            // Bass — plucky saw with a quick decay.
            v += self.saw(bass[s], t) * self.decayEnv(local, 0.16) * 0.16
            // Sub sine for weight.
            v += self.sine(bass[s] / 2, t) * self.decayEnv(local, 0.20) * 0.10
            // Sparse arp lead.
            if arp[s] > 0 {
                v += (self.sine(arp[s], t) * 0.6 + self.saw(arp[s], t) * 0.4) * self.decayEnv(local, 0.10) * 0.07
            }
            return Float(max(-1, min(1, v)))
        }
    }
}
