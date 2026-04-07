import Foundation

struct ProfileImportWarning: Codable, Equatable, Sendable {
    let line: Int
    let directive: String
    let message: String
}
