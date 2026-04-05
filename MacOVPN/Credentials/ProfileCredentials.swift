import Foundation

struct ProfileCredentials: Codable, Equatable, Sendable {
    let username: String
    let password: String
}

protocol ProfileCredentialStoring {
    func loadCredentials(for profileID: UUID) throws -> ProfileCredentials?
    func saveCredentials(_ credentials: ProfileCredentials, for profileID: UUID) throws
    func removeCredentials(for profileID: UUID) throws
}
