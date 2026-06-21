import SwiftUI

/// SF Symbol → SkipUI-supported name mapper (Skip pitfall #44).
///
/// SkipUI maps only ~66 SF Symbol names to Material icons; anything else renders as a
/// warning-triangle placeholder. This returns a supported, semantically-close name for
/// the symbols the menus/chrome use. (The in-game node sprites are drawn with Shapes,
/// not SF Symbols, so they're unaffected.)
///
/// NOTE: these are Material substitutes, not pixel-identical to the iOS SF Symbols —
/// exact icon parity would need bundled custom vector assets (a later polish step).
func sfSym(_ name: String) -> String {
    switch name {
    case "flag.fill":              return "location.fill"        // CAMPAIGN
    case "scope":                  return "plus.circle.fill"     // PROTOCOL (reticle)
    case "cpu.fill":               return "wrench.fill"          // CYBERDECK (upgrades)
    case "paintpalette.fill":      return "star.fill"            // COSMETICS
    case "trophy.fill":            return "list.bullet"          // TOP RUNS (leaderboard)
    case "book.closed.fill":       return "info.circle.fill"     // CODEX (reference)
    case "bitcoinsign.circle.fill": return "plus.circle.fill"    // Credits
    case "checkmark.seal.fill":    return "checkmark.circle.fill" // ACQUIRED flash
    // Already supported by SkipUI (passthrough): play.fill, calendar, gearshape.fill,
    // checkmark.circle.fill, lock.fill, star.fill, heart.fill, etc.
    default:                       return name
    }
}
