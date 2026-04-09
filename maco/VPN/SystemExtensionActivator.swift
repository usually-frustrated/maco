import SystemExtensions
import os.log

private let log = OSLog(subsystem: "frustrated.maco.app", category: "SystemExtension")

/// Installs and activates the packet tunnel system extension on first launch.
/// The user will be prompted to approve it in System Settings → Privacy & Security
/// the first time, and on subsequent launches it silently confirms the extension
/// is already active.
final class SystemExtensionActivator: NSObject {
    static let shared = SystemExtensionActivator()
    private static let extensionIdentifier = "frustrated.maco.app.packet-tunnel"

    func activate() {
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: Self.extensionIdentifier,
            queue: .main
        )
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
        os_log("Submitted system extension activation request", log: log, type: .info)
    }
}

extension SystemExtensionActivator: OSSystemExtensionRequestDelegate {
    func request(
        _ request: OSSystemExtensionRequest,
        didFinishWithResult result: OSSystemExtensionRequest.Result
    ) {
        switch result {
        case .completed:
            os_log("System extension activated", log: log, type: .info)
        case .willCompleteAfterReboot:
            os_log("System extension will activate after reboot", log: log, type: .info)
        @unknown default:
            os_log("System extension activation finished with unknown result", log: log, type: .info)
        }
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        os_log("System extension activation failed: %{public}@", log: log, type: .error, error.localizedDescription)
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        // The system has already shown the user a prompt in System Settings →
        // Privacy & Security. Nothing extra needed here, but we could surface
        // a notification or menu bar badge to guide the user there.
        os_log("System extension needs user approval in System Settings", log: log, type: .info)
    }

    func request(
        _ request: OSSystemExtensionRequest,
        actionForReplacingExtension existing: OSSystemExtensionProperties,
        withExtension ext: OSSystemExtensionProperties
    ) -> OSSystemExtensionRequest.ReplacementAction {
        // Always replace with the bundled version so updates take effect.
        return .replace
    }
}
