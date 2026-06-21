import Foundation

/// The result of a finished session, surfaced to the game-over screen.
/// Lives in the Core layer because `GameStore` (persistence) produces it.
struct SessionOutcome: Equatable {
    let creditsEarned: Int
    let isHighScore: Bool
}
