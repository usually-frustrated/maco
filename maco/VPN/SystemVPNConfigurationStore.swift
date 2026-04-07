import Foundation
import NetworkExtension

enum SystemVPNConfigurationStoreError: Error, LocalizedError {
    case failedToLoadPreferences

    var errorDescription: String? {
        switch self {
        case .failedToLoadPreferences:
            return "Could not load VPN configurations from preferences."
        }
    }
}

final class SystemVPNConfigurationStore {
    private let providerBundleIdentifier: String

    init(providerBundleIdentifier: String = "com.macovpn.app.packet-tunnel") {
        self.providerBundleIdentifier = providerBundleIdentifier
    }

    func addProfile(
        displayName: String,
        configContent: String,
        completion: @escaping (Result<UUID, Error>) -> Void
    ) {
        let profileID = UUID()
        let manager = makeManager(
            profileID: profileID,
            displayName: displayName,
            configContent: configContent
        )
        save(manager: manager) { result in
            switch result {
            case .success:
                DispatchQueue.main.async { completion(.success(profileID)) }
            case .failure(let error):
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    func removeProfile(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let managers else {
                DispatchQueue.main.async {
                    completion(.failure(SystemVPNConfigurationStoreError.failedToLoadPreferences))
                }
                return
            }

            guard let manager = managers.first(where: { self.payload(for: $0)?.profileID == id }) else {
                DispatchQueue.main.async { completion(.success(())) }
                return
            }

            self.remove(manager: manager, completion: completion)
        }
    }

    private func remove(
        manager: NETunnelProviderManager,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        manager.removeFromPreferences { error in
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            DispatchQueue.main.async { completion(.success(())) }
        }
    }

    private func save(
        manager: NETunnelProviderManager,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        manager.saveToPreferences { error in
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            DispatchQueue.main.async { completion(.success(())) }
        }
    }

    private func makeManager(
        profileID: UUID,
        displayName: String,
        configContent: String
    ) -> NETunnelProviderManager {
        let manager = NETunnelProviderManager()
        configure(
            manager: manager,
            profileID: profileID,
            displayName: displayName,
            configContent: configContent
        )
        return manager
    }

    private func configure(
        manager: NETunnelProviderManager,
        profileID: UUID,
        displayName: String,
        configContent: String
    ) {
        let protocolConfiguration = NETunnelProviderProtocol()
        protocolConfiguration.providerBundleIdentifier = providerBundleIdentifier
        protocolConfiguration.providerConfiguration = VPNProviderPayload(
            profileID: profileID,
            displayName: displayName,
            configContent: configContent
        ).providerConfiguration
        protocolConfiguration.serverAddress = displayName

        manager.localizedDescription = displayName
        manager.protocolConfiguration = protocolConfiguration
        manager.isEnabled = true
    }

    private func payload(for manager: NETunnelProviderManager) -> VPNProviderPayload? {
        guard let protocolConfiguration = manager.protocolConfiguration as? NETunnelProviderProtocol else {
            return nil
        }
        return VPNProviderPayload(providerConfiguration: protocolConfiguration.providerConfiguration)
    }
}
