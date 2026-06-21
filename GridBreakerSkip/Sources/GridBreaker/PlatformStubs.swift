import Foundation

// MARK: - Platform service stubs (Android)
//
// The iOS app drives audio (AVAudioEngine), haptics (UIKit) and Game Center (GameKit)
// through these singletons. On Android:
//   • Audio + haptics are no-ops for now — real synth via AudioTrack is M3.
//   • Game Center has no Android equivalent (M5): every call is a no-op, exactly like
//     the iOS "player declined auth" path. Local high scores still work via GameStore.
// Keeping the same API surface means the ported views/engine compile unchanged.

/// Sound effects (same cases as iOS so ported call-sites match). No-op until M3.
enum SFX {
    case decode, decodeArmored, decodeBig, decodeWorm
    case breach, miss, bomb, fever, gameOver, ramLow
    case uiTap, purchase
}

final class AudioEngine: @unchecked Sendable {
    static let shared = AudioEngine()
    private init() {}

    var enabled = true
    var musicVolume = 0.85
    var sfxVolume = 0.7

    func start() {}
    func play(_ sfx: SFX, step: Int = 0) {}
}

/// Haptics — no-op stub (Android Vibrator integration is M3).
enum Haptics {
    nonisolated(unsafe) static var enabled = true
}

// MARK: - Game Center (no Android equivalent — all no-ops)

enum GCRunMode {
    case endless, daily, campaign, protocolMode
}

/// Run/meta achievements (same cases as iOS so reportRunEnd/report compile).
enum GCAchievement {
    case firstDecode, fever, cleanStreak, fullGrid, campaignCleared
    case score50, score100, score250
    case firstCore, comboMaster, allCores
}

final class GameCenterService: @unchecked Sendable {
    static let shared = GameCenterService()
    private init() {}

    var menuVisible = false

    func authenticate(onAuthenticated: (() -> Void)? = nil) {}        // no GC on Android
    func syncMeta(campaignProgress: Int, deck: Cyberdeck) {}
    func submitBacklog(endlessBest: Int, dailyBest: Int) {}
    func report(_ achievement: GCAchievement) {}
    func reportRunEnd(_ snapshot: SessionSnapshot, mode: GCRunMode) {}
}
