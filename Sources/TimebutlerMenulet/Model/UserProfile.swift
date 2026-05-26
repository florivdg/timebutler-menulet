import Foundation

struct UserProfile: Codable, Equatable {
    let firstName: String?
    let lastName: String?
    let email: String?

    var displayName: String {
        let parts = [firstName, lastName].compactMap { $0?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if !parts.isEmpty { return parts.joined(separator: " ") }
        return email ?? ""
    }
}
