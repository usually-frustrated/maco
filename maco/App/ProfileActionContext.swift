import Foundation

final class ProfileActionContext: NSObject {
    let id: UUID
    let displayName: String
    let savedUsername: String?

    init(id: UUID, displayName: String, savedUsername: String?) {
        self.id = id
        self.displayName = displayName
        self.savedUsername = savedUsername
    }
}
