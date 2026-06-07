import Foundation
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

/// Game audio. SFX are synthesized into PCM buffers and played via AVAudioEngine.
/// Music is the player's own MP3s (see `MusicPlayer`) — drop files into the
/// bundled `Music/` folder. Defensive throughout — if audio fails to start, the
/// game plays on silently (it never throws into the game loop).
///
/// Shared singleton: audio is a global service; the game/menu just call `play`.
@MainActor
final class AudioEngine {
    static let shared = AudioEngine()

    /// One-shot SFX, each traced to a real game event (mirrors the juice layer).
    enum SFX { case decode, decodeBig, breach, miss, bomb, fever, gameOver, uiTap }

    private let engine = AVAudioEngine()
    private let musicPlayer = MusicPlayer()
    private var sfxPool: [AVAudioPlayerNode] = []
    private var sfxIndex = 0
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var buffers: [SFX: AVAudioPCMBuffer] = [:]

    private(set) var isRunning = false
    /// Master toggle (persisted in settings). Stops/starts SFX and the music.
    var enabled = true {
        didSet {
            guard oldValue != enabled else { return }
            musicPlayer.setEnabled(enabled)
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
        engine.mainMixerNode.outputVolume = 0.9

        engine.prepare()
        do {
            try engine.start()
            isRunning = true
            sfxPool.forEach { $0.play() }
        } catch {
            isRunning = false      // game continues silently
        }

        // Music is independent of the SFX engine (plays the player's MP3s).
        musicPlayer.loadTracks()
        musicPlayer.setEnabled(enabled)

        registerObservers()
    }

    /// Self-heal: recover audio after an interruption / route or config change /
    /// returning to the foreground. Safe to call any time (idempotent-ish).
    func resume() {
        guard isRunning else { start(); return }
        #if canImport(UIKit)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        if !engine.isRunning {
            engine.prepare()
            try? engine.start()
        }
        if engine.isRunning {
            sfxPool.forEach { if !$0.isPlaying { $0.play() } }
        }
        musicPlayer.resume()
    }

    // MARK: Resilience

    private func registerObservers() {
        let nc = NotificationCenter.default
        // The SFX engine stops itself on a route/config change — restart it.
        nc.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.resume() }
        }
        #if canImport(UIKit)
        // Audio-session interruption (calls, other apps, system sounds): resume on end.
        nc.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .ended else { return }
            MainActor.assumeIsolated { self?.resume() }
        }
        // Returning to the foreground is a reliable moment to re-check audio.
        nc.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.resume() }
        }
        #endif
    }

    // MARK: Playback

    func play(_ sfx: SFX) {
        guard isRunning, enabled, let buffer = buffers[sfx] else { return }
        let node = sfxPool[sfxIndex]
        sfxIndex = (sfxIndex + 1) % sfxPool.count
        node.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
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
    }
}

// MARK: - Music (player-supplied MP3s)

/// Plays the player's own background music from MP3 files bundled in the app's
/// `Music/` folder. Drop any number of `.mp3` files in there and rebuild — no
/// code changes needed. On each launch the tracks are shuffled (so a random one
/// starts), and when a track finishes the next in the shuffled order plays;
/// after the last, the list reshuffles and continues.
///
/// Uses AVAudioPlayer (not the SFX AVAudioEngine) — simplest path for file
/// playback + a "finished" callback. NSObject for the delegate. Created and used
/// on the main thread; the finish callback also fires on the main run loop.
final class MusicPlayer: NSObject, AVAudioPlayerDelegate {
    private var queue: [URL] = []
    private var index = 0
    private var player: AVAudioPlayer?
    private var enabled = true

    /// Discover bundled tracks and shuffle them (random first track per launch).
    func loadTracks() {
        var urls = Bundle.main.urls(forResourcesWithExtension: "mp3", subdirectory: "Music") ?? []
        if urls.isEmpty {
            // Fallback: MP3s added loose to the bundle (not in the Music folder).
            urls = Bundle.main.urls(forResourcesWithExtension: "mp3", subdirectory: nil) ?? []
        }
        queue = urls.shuffled()
        index = 0
    }

    func setEnabled(_ on: Bool) {
        enabled = on
        if on { play() } else { stop() }
    }

    /// Start playing if enabled and not already playing.
    func play() {
        guard enabled, player == nil else { return }
        playCurrent()
    }

    func stop() {
        player?.stop()
        player = nil
    }

    /// Resume after an interruption: replay if paused, or start the next track if
    /// the player was torn down. No-op if music is off or already playing.
    func resume() {
        guard enabled else { return }
        if let p = player {
            if !p.isPlaying { p.play() }
        } else {
            playCurrent()
        }
    }

    private func playCurrent() {
        guard !queue.isEmpty else { return }          // no MP3s bundled yet
        if index >= queue.count { queue.shuffle(); index = 0 }   // wrap → reshuffle
        do {
            let p = try AVAudioPlayer(contentsOf: queue[index])
            p.delegate = self
            p.prepareToPlay()
            p.play()
            player = p
        } catch {
            // Skip an unreadable file and try the next one.
            index += 1
            if index < queue.count { playCurrent() }
        }
    }

    /// A track finished → advance to the next (reshuffles after the last).
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.player = nil
        guard enabled else { return }
        index += 1
        playCurrent()
    }
}
