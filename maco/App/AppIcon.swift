import AppKit

enum AppIcon {
    static let resourceName = "AppIcon"

    static var applicationImage: NSImage {
        if let image = NSImage(named: NSImage.Name(resourceName)) {
            return image
        }
        return NSApp.applicationIconImage
    }

    static func installAsApplicationIcon() {
        NSApp.applicationIconImage = applicationImage
    }
}
