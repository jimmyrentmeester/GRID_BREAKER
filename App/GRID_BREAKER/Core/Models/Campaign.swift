import Foundation

/// One campaign "data core" — a hand-tuned **time-attack** level: reach
/// `targetScore` before the `timeBudget`-second RAM countdown runs out.
/// `difficultyBias` offsets the engine's difficulty scaling so later cores run at
/// a faster, busier pace (more decode opportunities, less margin for error).
/// Pure data; the engine and UI read it.
struct DataCore: Identifiable, Sendable, Equatable {
    let id: Int            // 1-based core number / order
    let name: String
    let targetScore: Int
    let timeBudget: TimeInterval
    let difficultyBias: Int
}

enum Campaign {
    /// The hand-tuned ladder (rising target + pace, generous→tight clock). Tuned
    /// with the headless realistic-player sim so early cores are clearable on a
    /// starter deck and later ones demand precision and/or Cyberdeck upgrades.
    static let cores: [DataCore] = [
        DataCore(id: 1,  name: "Sector-7 Cache",      targetScore: 15, timeBudget: 30, difficultyBias: 30),
        DataCore(id: 2,  name: "Public Grid Relay",   targetScore: 22, timeBudget: 30, difficultyBias: 60),
        DataCore(id: 3,  name: "Cold Storage Node",   targetScore: 30, timeBudget: 32, difficultyBias: 100),
        DataCore(id: 4,  name: "Sentinel Subnet",     targetScore: 40, timeBudget: 32, difficultyBias: 150),
        DataCore(id: 5,  name: "Ice Wall",            targetScore: 52, timeBudget: 35, difficultyBias: 210),
        DataCore(id: 6,  name: "Black Market Ledger", targetScore: 64, timeBudget: 35, difficultyBias: 280),
        DataCore(id: 7,  name: "Daemon Foundry",      targetScore: 78, timeBudget: 38, difficultyBias: 360),
        DataCore(id: 8,  name: "Quarantine Vault",    targetScore: 92, timeBudget: 38, difficultyBias: 450),
        DataCore(id: 9,  name: "Black ICE Core",      targetScore: 108, timeBudget: 40, difficultyBias: 560),
        DataCore(id: 10, name: "The Monolith",        targetScore: 130, timeBudget: 42, difficultyBias: 700),
    ]

    static func core(id: Int) -> DataCore? { cores.first { $0.id == id } }
    static var count: Int { cores.count }
}
