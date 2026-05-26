import Foundation

enum ClockState: String, Codable {
    case idle, running, paused, waiting
}

struct ClockStatus: Codable, Equatable {
    let status: ClockState
    let startTimestamp: Int64?
    let pauseTimestamp: Int64?
    let workTimeElapsedSeconds: Int
    let breakElapsedSeconds: Int
    let accumulatedBreakSeconds: Int
    let waitSeconds: Int?
    let isBusinessTripActive: Bool?

    var startDate: Date? { startTimestamp.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) } }
    var pauseDate: Date? { pauseTimestamp.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) } }

    func toWorkStatus() -> WorkStatus {
        switch status {
        case .idle:
            return .idle
        case .running:
            return .running(startedAt: startDate)
        case .paused:
            return .paused(startedAt: startDate, pausedAt: pauseDate)
        case .waiting:
            return .waiting(startedAt: startDate)
        }
    }
}
