import Foundation

// Arbeitszeitgesetz §4 (Germany): minimum rest break by total worked time.
//   ≤ 6 h      : no break required
//   > 6 h ≤ 9 h: 30 minutes
//   > 9 h      : 45 minutes
enum BreakRules {
    static let tier1Threshold = 6 * 3600
    static let tier1Required = 30 * 60
    static let tier2Threshold = 9 * 3600
    static let tier2Required = 45 * 60

    static func requiredBreakSeconds(workedSeconds: Int) -> Int {
        if workedSeconds <= tier1Threshold { return 0 }
        if workedSeconds <= tier2Threshold { return tier1Required }
        return tier2Required
    }

    static func shortfallSeconds(workedSeconds: Int, accumulatedBreakSeconds: Int) -> Int {
        max(0, requiredBreakSeconds(workedSeconds: workedSeconds) - accumulatedBreakSeconds)
    }

    static func shortfallSeconds(from status: ClockStatus) -> Int {
        shortfallSeconds(
            workedSeconds: status.workTimeElapsedSeconds,
            accumulatedBreakSeconds: status.accumulatedBreakSeconds
        )
    }
}
