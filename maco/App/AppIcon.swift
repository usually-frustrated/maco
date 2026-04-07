import AppKit

enum AppIcon {
    static let resourceName = "AppIcon"

    static var applicationImage: NSImage {
        if let image = loadImage(named: resourceName) {
            return image
        }
        return NSApp.applicationIconImage
    }

    static var menuBarImage: NSImage {
        let image = applicationImage.copy() as? NSImage ?? applicationImage
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = false
        return image
    }

    static func installAsApplicationIcon() {
        NSApp.applicationIconImage = applicationImage
    }

    private static func loadImage(named name: String) -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "icns") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}
