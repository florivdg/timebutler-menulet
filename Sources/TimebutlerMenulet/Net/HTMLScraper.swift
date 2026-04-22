import Foundation

enum HTMLScraper {
    // Returns an activity state if the HTML contains a clear marker.
    // Never returns `.loggedOut` — that's determined by URLSession redirect detection
    // in TimebutlerClient. Returning nil means "logged in, couldn't parse activity".
    static func parseStatus(from html: String) -> WorkStatus? {
        let lower = html.lowercased()

        // "Gestartet um HH:MM" — currently working with known start time.
        if let re = try? NSRegularExpression(pattern: #"gestartet um\s+(\d{1,2}):(\d{2})"#,
                                             options: [.caseInsensitive]),
           let m = re.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
           m.numberOfRanges >= 3,
           let hRange = Range(m.range(at: 1), in: lower),
           let mRange = Range(m.range(at: 2), in: lower),
           let hour = Int(lower[hRange]),
           let minute = Int(lower[mRange]) {
            let cal = Calendar.current
            let today = cal.startOfDay(for: Date())
            let start = cal.date(bySettingHour: hour, minute: minute, second: 0, of: today)
            return .working(since: start)
        }

        let working = ["arbeitszeit läuft", "stempeluhr läuft", "laufende arbeitszeit",
                       "checked in", "clock running", "clock is running"]
        let paused  = ["pausiert", "auf pause", "pause läuft", "currently on break",
                       "break running", "break in progress"]
        let out     = ["nicht eingecheckt", "ausgecheckt", "noch nicht eingecheckt",
                       "clock stopped", "not clocked in", "not checked in",
                       "keine laufende arbeitszeit"]

        if working.contains(where: { lower.contains($0) }) { return .working(since: nil) }
        if paused.contains(where:  { lower.contains($0) }) { return .paused(since: nil) }
        if out.contains(where:     { lower.contains($0) }) { return .checkedOut }
        return nil
    }
}
