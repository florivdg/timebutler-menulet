import Foundation

enum HTMLScraper {
    // The Timebutler dashboard renders a `<div id="time-clock" data-paused=… data-running=…
    // data-dauersec=… data-pausesec=…>` widget. Those attributes are the source of truth for
    // session state — the human-readable status sentences are filled in later by JS and are
    // not present in the HTML we fetch via URLSession.
    //
    // Returns nil if the widget is missing entirely (caller normalizes that to `.loggedIn`).
    // Never returns `.loggedOut` — that's determined by URLSession redirect detection
    // in TimebutlerClient.
    static func parseStatus(from html: String) -> WorkStatus? {
        guard html.range(of: #"id="time-clock""#, options: .regularExpression) != nil else {
            return nil
        }

        func attr(_ name: String) -> String? {
            let pattern = "\(name)=\"([^\"]*)\""
            guard let re = try? NSRegularExpression(pattern: pattern),
                  let m = re.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                  m.numberOfRanges >= 2,
                  let r = Range(m.range(at: 1), in: html) else { return nil }
            return String(html[r])
        }

        let paused = attr("data-paused") == "1"
        let running = attr("data-running") == "1"
        let dauersec = Int(attr("data-dauersec") ?? "") ?? 0
        let pausesec = Int(attr("data-pausesec") ?? "") ?? 0
        let now = Date()

        if paused {
            let since = pausesec > 0 ? now.addingTimeInterval(-Double(pausesec)) : nil
            return .paused(since: since)
        }
        if running {
            let total = dauersec + pausesec
            let since = total > 0 ? now.addingTimeInterval(-Double(total)) : nil
            return .working(since: since)
        }
        return .checkedOut
    }
}
