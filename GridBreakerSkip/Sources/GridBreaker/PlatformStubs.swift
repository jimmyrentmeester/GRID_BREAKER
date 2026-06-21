import Foundation

// MARK: - Platform service stubs (Android)
//
// The iOS app drives audio (AVAudioEngine), haptics (UIKit) and Game Center (GameKit)
// through these singletons. On Android:
//   • Audio + haptics are no-ops for now — real synth via AudioTrack is M3.
//   • Game Center has no Android equivalent (M5): every call is a no-op, exactly like
//     the iOS "player declined auth" path. Local high scores still work via GameStore.
// Keeping the same API surface means the ported views/engine compile unchanged.

// AudioEngine, SFX and Haptics now live in Audio.swift (real Android AudioTrack synth
// + Vibrator, M3). Game Center remains a no-op stub here (no Android equivalent, M5).

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
