import Foundation

// MARK: - SFX (same cases as iOS)

enum SFX {
    case decode, decodeArmored, decodeBig, decodeWorm
    case breach, miss, bomb, fever, gameOver, ramLow
    case uiTap, purchase
}

// MARK: - Audio engine (Android AudioTrack synth — M3)
//
// The iOS AudioEngine synthesises SFX into PCM and plays them via AVAudioEngine. Here
// the SAME synth math renders each SFX once into a 16-bit PCM `[Int16]` at start(), and
// playback uses Android's `android.media.AudioTrack` (a fresh MODE_STATIC track per shot
// so rapid hits overlap). The synth (sine/saw/LPF/FM/soft-clip) is ported faithfully;
// only the playback layer is rewritten. Music (player MP3s) isn't ported — no bundled
// tracks. Build-verified; actual sound needs a physical device (the emulator runs silent).

final class AudioEngine: @unchecked Sendable {
    static let shared = AudioEngine()
    private init() {}

    var enabled = true
    var musicVolume = 0.85
    var sfxVolume = 0.7

    private let sampleRate = 44_100.0
    private var pcm: [SFX: [Int16]] = [:]
    private var decodeSteps: [[Int16]] = []
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        // Synthesise the 12 SFX off the main thread — ~500k DSP samples would otherwise
        // block first paint (and risk an ANR) at launch. play() reads pcm defensively
        // (nil until ready → silent), so early taps just miss the (sub-second) warm-up.
        Task.detached(priority: .utility) { [weak self] in
            self?.renderAll()
        }
    }

    func play(_ sfx: SFX, step: Int = 0) {
        guard enabled, started else { return }
        var samples: [Int16]? = nil
        if sfx == .decode && !decodeSteps.isEmpty {
            var s = step
            if s < 0 { s = 0 }
            if s >= decodeSteps.count { s = decodeSteps.count - 1 }
            samples = decodeSteps[s]
        } else {
            samples = pcm[sfx]
        }
        guard let buf = samples else { return }
        playPCM(buf)
    }

    // MARK: Synth helpers (faithful to iOS; Skip-safe arithmetic)

    private func frac(_ x: Double) -> Double { x - floor(x) }     // replaces truncatingRemainder (#50)
    private func sine(_ f: Double, _ t: Double) -> Double { sin(2.0 * Double.pi * f * t) }
    private func saw(_ f: Double, _ t: Double) -> Double { 2.0 * frac(t * f) - 1.0 }
    private func square(_ f: Double, _ t: Double) -> Double { sine(f, t) >= 0.0 ? 1.0 : -1.0 }
    private func decayEnv(_ t: Double, _ tau: Double) -> Double { exp(-t / tau) }
    private func softClip(_ x: Double) -> Double { tanh(1.5 * x) }
    private func detSaw(_ f: Double, _ t: Double) -> Double {
        (saw(f * (1.0 - 0.006), t) + saw(f * (1.0 + 0.006), t)) * 0.5
    }
    private func fmBlip(_ f: Double, _ t: Double, glide: Double, index: Double, ratio: Double, decay: Double) -> Double {
        let fT = f * (1.0 + glide * decayEnv(t, 0.012))
        let mod = sine(f * ratio, t) * decayEnv(t, decay * 0.6)
        return sin(2.0 * Double.pi * fT * t + index * mod) * decayEnv(t, decay)
    }

    /// Deterministic white-noise via the engine's Skip-safe SeededRNG (SkipLib has no
    /// Double.random; a hand-rolled LCG hits UInt64-literal cast issues, #53).
    private var noiseRNG = SeededRNG(seed: UInt64(9_876_543_210))
    private func noise() -> Double { noiseRNG.uniform() * 2.0 - 1.0 }

    /// One-pole low-pass with per-sample cutoff (the "dark pluck" filter).
    private final class LowPass {
        private var y = 0.0
        private let sr: Double
        init(_ sr: Double) { self.sr = sr }
        func step(_ x: Double, _ cutoff: Double) -> Double {
            let c = cutoff < 20.0 ? 20.0 : cutoff
            let a = 1.0 - exp(-2.0 * Double.pi * c / sr)
            y += a * (x - y)
            return y
        }
    }

    /// Render `seconds` of audio via `fill(t)` into 16-bit PCM.
    private func render(_ seconds: Double, _ fill: (Double) -> Double) -> [Int16] {
        var frames = Int(sampleRate * seconds)
        if frames < 1 { frames = 1 }
        var out = [Int16](repeating: 0, count: frames)
        var i = 0
        while i < frames {
            let t = Double(i) / sampleRate
            var v = fill(t)
            if v > 1.0 { v = 1.0 }
            if v < -1.0 { v = -1.0 }
            out[i] = Int16(v * 32000.0)
            i += 1
        }
        return out
    }

    // MARK: Build all SFX (ported from iOS buildBuffers)

    private func renderAll() {
        let sr = sampleRate

        // Decode hit up a rising minor run (filter opens per step).
        let decodeScale: [Double] = [220.0, 261.63, 293.66, 329.63, 392.0, 440.0, 523.25, 587.33]
        decodeSteps = []
        var stepIdx = 0
        for f in decodeScale {
            let lp = LowPass(sr)
            let baseCut = 700.0 + 350.0 * Double(stepIdx)
            let buf = render(0.16) { t in
                let x = self.detSaw(f, t) * self.decayEnv(t, 0.055) * 0.55
                      + self.sine(f / 2.0, t) * self.decayEnv(t, 0.07) * 0.35
                      + self.noise() * self.decayEnv(t, 0.004) * 0.25
                let cut = baseCut * (0.35 + 0.65 * self.decayEnv(t, 0.03))
                return self.softClip(lp.step(x, cut) * 1.6) * 0.6
            }
            decodeSteps.append(buf)
            stepIdx += 1
        }
        if let first = decodeSteps.first { pcm[.decode] = first }

        let lpWorm = LowPass(sr)
        pcm[.decodeWorm] = render(0.18) { t in
            let wob = 1.0 + 0.06 * self.sine(28, t)
            let mt = t / 0.10 < 1.0 ? t / 0.10 : 1.0
            let f = (180.0 + 140.0 * mt) * wob
            let x = self.detSaw(f, t) * self.decayEnv(t, 0.07) * 0.6
                  + self.noise() * self.decayEnv(t, 0.004) * 0.2
            let cut = 900.0 * (0.4 + 0.6 * self.decayEnv(t, 0.05))
            return self.softClip(lpWorm.step(x, cut) * 1.6) * 0.55
        }

        let lpBig = LowPass(sr)
        pcm[.decodeBig] = render(0.26) { t in
            let fsub = 55.0 + 45.0 * self.decayEnv(t, 0.05)
            let sub = self.sine(fsub, t) * self.decayEnv(t, 0.16) * 0.5
            let stab = self.detSaw(110, t) * self.decayEnv(t, 0.09) * 0.45
            let ping = self.fmBlip(440, t, glide: 0.05, index: 2.5, ratio: 1.5, decay: 0.05) * 0.15
            let cut = 1200.0 * (0.35 + 0.65 * self.decayEnv(t, 0.05))
            return self.softClip((sub + lpBig.step(stab, cut) + ping) * 1.3) * 0.6
        }

        let lpBreach = LowPass(sr)
        pcm[.breach] = render(0.10) { t in
            let thunk = self.sine(185.0 * (1.0 + 0.3 * self.decayEnv(t, 0.010)), t) * self.decayEnv(t, 0.04) * 0.55
            let snap = self.noise() * self.decayEnv(t, 0.012) * 0.35
            let cut = 2500.0 * self.decayEnv(t, 0.03) + 300.0
            return self.softClip(lpBreach.step(thunk + snap, cut) * 1.4) * 0.5
        }

        let lpArm = LowPass(sr)
        pcm[.decodeArmored] = render(0.22) { t in
            let stab = self.detSaw(220, t) * self.decayEnv(t, 0.08) * 0.55
            let sub = self.sine(110, t) * self.decayEnv(t, 0.12) * 0.30
            let tick = self.noise() * self.decayEnv(t, 0.003) * 0.2
            let mt = t / 0.06 < 1.0 ? t / 0.06 : 1.0
            let cut = 500.0 + 1700.0 * mt * self.decayEnv(t, 0.10)
            return self.softClip(lpArm.step(stab + tick, cut) * 1.6 + sub) * 0.6
        }

        let lpMiss = LowPass(sr)
        pcm[.miss] = render(0.18) { t in
            let f = 98.0 * pow(2.0, -t * 2.0)
            let x = self.square(f, t) * self.decayEnv(t, 0.07) * 0.30
                  + self.noise() * self.decayEnv(t, 0.05) * 0.12
            return self.softClip(lpMiss.step(x, 700.0) * 1.5) * 0.5
        }

        let lpBomb = LowPass(sr)
        pcm[.bomb] = render(0.60) { t in
            let sub = self.sine(48.0 + 50.0 * self.decayEnv(t, 0.12), t) * self.decayEnv(t, 0.32) * 0.5
            let crash = (self.detSaw(130, t) * 0.35 + self.detSaw(184, t) * 0.25) * self.decayEnv(t, 0.20)
            let blast = self.noise() * self.decayEnv(t, 0.14) * 0.35
            let cut = 300.0 + 2700.0 * self.decayEnv(t, 0.12)
            let atk = t * 80.0 < 1.0 ? t * 80.0 : 1.0
            return self.softClip((sub + lpBomb.step(crash + blast, cut)) * 1.4) * 0.62 * atk
        }

        let lpFever = LowPass(sr)
        let feverSteps: [Double] = [220.0, 261.63, 329.63, 440.0]
        pcm[.fever] = render(0.55) { t in
            var idx = Int(t / 0.13)
            if idx > feverSteps.count - 1 { idx = feverSteps.count - 1 }
            let local = t - Double(idx) * 0.13
            let stab = self.detSaw(feverSteps[idx], t) * self.decayEnv(local, 0.09) * 0.5
            let sw = t / 0.55 < 1.0 ? t / 0.55 : 1.0
            let sub = self.sine(110, t) * 0.18 * sw
            let cut = 600.0 + 1800.0 * sw
            return self.softClip(lpFever.step(stab, cut) * 1.5 + sub) * 0.5
        }

        let lpGO = LowPass(sr)
        pcm[.gameOver] = render(0.95) { t in
            let f = 196.0 * pow(2.0, -2.2 * t * t)
            let x = self.detSaw(f, t) * 0.5 + self.sine(f / 2.0, t) * 0.3
                  + self.noise() * self.decayEnv(t, 0.3) * 0.05
            let cut = 1400.0 * pow(2.0, -2.0 * t)
            return self.softClip(lpGO.step(x, cut) * 1.4) * self.decayEnv(t, 0.50) * 0.55
        }

        let lpTap = LowPass(sr)
        pcm[.uiTap] = render(0.05) { t in
            let x = self.sine(660, t) * self.decayEnv(t, 0.012) * 0.6
                  + self.noise() * self.decayEnv(t, 0.002) * 0.2
            return self.softClip(lpTap.step(x, 1800.0) * 1.4) * 0.30
        }

        let lpRam = LowPass(sr)
        pcm[.ramLow] = render(0.22) { t in
            let lt = t < 0.11 ? t : t - 0.11
            let x = self.detSaw(147, t) * self.decayEnv(lt, 0.035) * 0.6
                  + self.sine(73.5, t) * self.decayEnv(lt, 0.05) * 0.3
            let cut = 900.0 * self.decayEnv(lt, 0.04) + 200.0
            return self.softClip(lpRam.step(x, cut) * 1.5) * 0.45
        }

        let lpBuy = LowPass(sr)
        pcm[.purchase] = render(0.45) { t in
            var out = 0.0
            if t >= 0.0 {
                let lt = t
                out += self.detSaw(220, t) * self.decayEnv(lt, 0.10) * 0.45
                     + self.sine(110, t) * self.decayEnv(lt, 0.12) * 0.25
            }
            if t >= 0.18 {
                let lt = t - 0.18
                out += self.detSaw(330, t) * self.decayEnv(lt, 0.10) * 0.45
                     + self.sine(165, t) * self.decayEnv(lt, 0.12) * 0.25
            }
            let cut = 1500.0 * (0.4 + 0.6 * self.decayEnv(self.frac(t / 0.18) * 0.18, 0.06))
            return self.softClip(lpBuy.step(out, cut) * 1.4) * 0.5
        }
    }

    // MARK: Playback (Android AudioTrack)

    private func playPCM(_ samples: [Int16]) {
        #if SKIP
        let vol = sfxVolume < 0.0 ? 0.0 : (sfxVolume > 1.0 ? 1.0 : sfxVolume)
        let sizeBytes = samples.count * 2
        let track = android.media.AudioTrack(
            android.media.AudioManager.STREAM_MUSIC,
            44100,
            android.media.AudioFormat.CHANNEL_OUT_MONO,
            android.media.AudioFormat.ENCODING_PCM_16BIT,
            sizeBytes,
            android.media.AudioTrack.MODE_STATIC)
        // Copy into a primitive ShortArray for AudioTrack.write.
        let arr = ShortArray(samples.count)
        var i = 0
        while i < samples.count { arr[i] = samples[i]; i += 1 }
        track.write(arr, 0, samples.count)
        track.setVolume(Float(vol))
        track.play()
        #endif
    }
}

// MARK: - Haptics (Android Vibrator — M3)

/// Light/medium/rigid/soft impacts + success/error, mapped to Android VibrationEffects.
/// Context comes from `ProcessInfo.processInfo.androidContext` (Skip exposes it).
enum Haptics {
    nonisolated(unsafe) static var enabled = true

    enum Impact { case light, medium, rigid, soft }

    static func impact(_ kind: Impact) {
        guard enabled else { return }
        let ms: Int = kind == .light ? 10 : (kind == .soft ? 14 : (kind == .medium ? 22 : 30))
        vibrate(ms)
    }
    static func success() { guard enabled else { return }; vibrate(18) }
    static func error()   { guard enabled else { return }; vibrate(40) }

    private static func vibrate(_ ms: Int) {
        #if SKIP
        let ctx = ProcessInfo.processInfo.androidContext
        let vib = ctx.getSystemService(android.content.Context.VIBRATOR_SERVICE) as? android.os.Vibrator
        if let vib = vib {
            let effect = android.os.VibrationEffect.createOneShot(Int64(ms), android.os.VibrationEffect.DEFAULT_AMPLITUDE)
            vib.vibrate(effect)
        }
        #endif
    }
}
