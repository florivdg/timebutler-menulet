import Foundation

enum SnifferScript {
    static let content: String = {
        if let url = Bundle.module.url(forResource: "sniffer", withExtension: "js"),
           let s = try? String(contentsOf: url, encoding: .utf8) {
            return s
        }
        return ""
    }()
}
