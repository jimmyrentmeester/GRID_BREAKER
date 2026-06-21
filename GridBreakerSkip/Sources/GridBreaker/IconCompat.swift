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
    case "arrow.clockwise":        return "arrow.clockwise.circle" // replay (supported variant)
    case "speaker.wave.2.fill":    return "bell.fill"            // SOUND on
    case "speaker.slash.fill":     return "bell"                 // SOUND off
    case "music.note":             return "bell.fill"            // MUSIC
    case "waveform":               return "line.3.horizontal"    // EFFECTS
    case "iphone.radiowaves.left.and.right": return "phone.fill" // HAPTICS
    case "graduationcap":          return "info.circle.fill"     // HOW TO PLAY
    case "trash":                  return "trash"                // RESET (supported)
    // Codex reference glyphs (SF Symbols are Apple-only → Material substitutes):
    case "circle.grid.cross.fill": return "plus.circle.fill"     // DAEMON
    case "lock.shield.fill":       return "lock.fill"            // ARMORED
    case "square.stack.3d.up.fill": return "star.fill"           // DATA CACHE
    case "scribble.variable":      return "location.fill"        // WORM
    case "snowflake":              return "star.fill"            // FREEZE
    case "bolt.fill":              return "play.fill"            // OVERCLOCK / FEVER
    case "wind":                   return "arrow.clockwise.circle" // PURGE
    case "memorychip.fill":        return "wrench.fill"          // RAM CLOCK
    case "flame.fill":             return "heart.fill"           // CLEAN STREAK
    case "square.grid.4x3.fill":   return "list.bullet"          // GRID EXPANSION
    case "list.number":            return "list.bullet"          // DAEMON SET
    case "hexagon.fill":           return "exclamationmark.triangle.fill" // INTRUSION
    case "square.dashed":          return "exclamationmark.triangle"      // DMZ PURGE
    case "nosign":                 return "xmark"                // trail "None"
    // Already supported by SkipUI (passthrough): play.fill, calendar, gearshape.fill,
    // checkmark.circle.fill, lock.fill, star.fill, heart.fill, etc.
    default:                       return name
    }
}
