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
    /// Decode hit rendered at rising pitches — `play(.decode, step:)` walks up this
    /// as the combo climbs, so chained decodes sound like an ascending arpeggio.
    private var decodeSteps: [AVAudioPCMBuffer] = []

    private(set) var isRunning = false
    /// Master toggle (persisted in settings). Stops/starts SFX and the music.
    var enabled = true {
        didSet {
            guard oldValue != enabled else { return }
            musicPlayer.setEnabled(enabled)
        }
    }
    /// Independent channel volumes (0…1), persisted in settings. SFX defaults a
    /// little quieter than music so hits don't dominate the mix.
    var sfxVolume: Double = 0.7 { didSet { applySfxVolume() } }
    var musicVolume: Double = 0.85 { didSet { musicPlayer.setVolume(musicVolume) } }

    private func applySfxVolume() {
        let v = Float(max(0, min(1, sfxVolume)))
        sfxPool.forEach { $0.volume = v }
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
        applySfxVolume()                       // per-channel SFX level

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
        musicPlayer.setVolume(musicVolume)
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

    /// `step` selects the decode pitch (clamped to the top of the run); ignored by
    /// every other SFX. Lets a decode chain ascend musically with the combo.
    func play(_ sfx: SFX, step: Int = 0) {
        guard isRunning, enabled else { return }
        let buffer: AVAudioPCMBuffer?
        if sfx == .decode, !decodeSteps.isEmpty {
            buffer = decodeSteps[min(max(0, step), decodeSteps.count - 1)]
        } else {
            buffer = buffers[sfx]
        }
        guard let buffer else { return }
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

    /// A short FM "blip" — a carrier phase-modulated by a sibling oscillator, with a
    /// quick downward pitch glide. The FM gives a clean metallic/digital timbre
    /// (on-theme for "decrypting") that's far more musical than a raw chirp.
    private func fmBlip(_ f: Double, _ t: Double,
                        glide: Double, index: Double, ratio: Double, decay: Double) -> Double {
        let fT = f * (1 + glide * decayEnv(t, 0.012))            // pluck: starts sharp, settles
        let mod = sine(f * ratio, t) * decayEnv(t, decay * 0.6)  // modulator fades faster
        let carrier = sin(2 * .pi * fT * t + index * mod)
        return carrier * decayEnv(t, decay)
    }

    private func buildBuffers() {
        // Decode hit: a punchy FM "data-blip" — a click transient for tactility, an
        // FM body for a clean digital pluck, and a high sparkle. Rendered at a rising
        // A-minor-pentatonic run so chained decodes climb (see `play(_:step:)`).
        let decodeScale: [Double] = [440, 523.25, 587.33, 659.25, 783.99, 880]  // A4→A5 pentatonic
        decodeSteps = decodeScale.map { f in
            buffer(seconds: 0.11) { _, t in
                let click = self.noise() * self.decayEnv(t, 0.0035)
                let body = self.fmBlip(f, t, glide: 0.12, index: 2.2, ratio: 2.01, decay: 0.05)
                let sparkle = self.sine(f * 3, t) * self.decayEnv(t, 0.02)
                return Float(click * 0.22 + body * 0.5 + sparkle * 0.12)
            }
        }
        buffers[.decode] = decodeSteps.first    // fallback for step-less callers
        // Armored kill: heavier, lower decrypt — a sub thump under a fatter FM body
        // and a crisp click. Distinct "weight" vs. the standard hit.
        buffers[.decodeBig] = buffer(seconds: 0.18) { _, t in
            let f = 330.0                                   // E4 — meaty but not muddy
            let click = self.noise() * self.decayEnv(t, 0.004)
            let sub = self.sine(f * 0.5, t) * self.decayEnv(t, 0.11)
            let body = self.fmBlip(f, t, glide: 0.10, index: 3.2, ratio: 1.5, decay: 0.09)
            return Float(click * 0.24 + body * 0.42 + sub * 0.36)
        }
        // Armored shell breach: a clean metallic FM tick (the shell cracking).
        buffers[.breach] = buffer(seconds: 0.07) { _, t in
            Float(self.fmBlip(1568, t, glide: 0.0, index: 1.4, ratio: 2.5, decay: 0.018) * 0.2)
        }
        // Miss: a low, downward-bending FM "denied" blip with a little grit — same
        // FM family as the hits but dark and dropping (G3, subharmonic ratio).
        buffers[.miss] = buffer(seconds: 0.16) { _, t in
            let body = self.fmBlip(196, t, glide: 0.45, index: 1.1, ratio: 0.5, decay: 0.06)
            let grit = self.noise() * self.decayEnv(t, 0.045)
            return Float(body * 0.22 + grit * 0.10)
        }
        // Firewall detonation: a sub boom + a dissonant metallic FM crash (tritone
        // ratio = alarm) + a noise blast. Heavier and more "digital" than a rumble.
        buffers[.bomb] = buffer(seconds: 0.55) { _, t in
            let sub = self.sine(55 + 40 * self.decayEnv(t, 0.15), t) * self.decayEnv(t, 0.30)
            let crash = self.fmBlip(140, t, glide: 0.6, index: 4.0, ratio: 1.414, decay: 0.22)
            let blast = self.noise() * self.decayEnv(t, 0.16)
            return Float((sub * 0.34 + crash * 0.18 + blast * 0.26) * min(1, t * 60)) // tiny attack
        }
        // Fever sting: a bright ascending FM arpeggio (the decrypt "breaks open").
        buffers[.fever] = buffer(seconds: 0.5) { _, t in
            let steps = [523.25, 698.46, 880.0, 1046.5]   // C5 F5 A5 C6 — bright, rising
            let idx = min(steps.count - 1, Int(t / 0.11))
            let f = steps[idx]
            let local = t - Double(idx) * 0.11
            let body = self.fmBlip(f, local, glide: 0.05, index: 2.4, ratio: 2.0, decay: 0.10)
            let shimmer = self.sine(f * 2, t) * self.decayEnv(local, 0.05)
            return Float((body * 0.5 + shimmer * 0.16) * 0.5)
        }
        // Game over: a slow descending FM minor fall (connection lost).
        buffers[.gameOver] = buffer(seconds: 0.8) { _, t in
            let f = 392 * pow(2.0, -t * 1.1)
            let mod = self.sine(f * 1.5, t) * self.decayEnv(t, 0.35)
            let carrier = sin(2 * .pi * f * t + 1.8 * mod)
            let body = (carrier * 0.6 + self.saw(f, t) * 0.3) * self.decayEnv(t, 0.45)
            return Float(body * 0.24)
        }
        // Subtle UI blip: a clean, quiet member of the FM family.
        buffers[.uiTap] = buffer(seconds: 0.06) { _, t in
            Float(self.fmBlip(1318.5, t, glide: 0.06, index: 1.2, ratio: 2.0, decay: 0.013) * 0.14)
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
    private var volume: Float = 0.85

    /// Set the music level (0…1); applies live and to future tracks.
    func setVolume(_ v: Double) {
        volume = Float(max(0, min(1, v)))
        player?.volume = volume
    }

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
            p.volume = volume
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
