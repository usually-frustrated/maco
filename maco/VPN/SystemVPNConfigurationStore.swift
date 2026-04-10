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
    private static let errorDomain = "maco.VPN"
    private let providerBundleIdentifier: String

    init(providerBundleIdentifier: String = "frustrated.maco.app.macopackettunnel") {
        self.providerBundleIdentifier = providerBundleIdentifier
    }

    func addProfile(
        displayName: String,
        configContent: String,
        completion: @escaping (Result<UUID, Error>) -> Void
    ) {
        let profileID = UUID()
        let manager = makeManager(profileID: profileID, displayName: displayName, configContent: configContent)
        save(manager: manager, profileID: profileID) { result in
            completion(result.map { profileID })
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
        profileID: UUID,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        manager.saveToPreferences { error in
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            self.waitForSavedManager(profileID: profileID, attemptsRemaining: 5, completion: completion)
        }
    }

    private func waitForSavedManager(
        profileID: UUID,
        attemptsRemaining: Int,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
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

            let saved = self.managedManagers(from: managers).contains {
                self.payload(for: $0)?.profileID == profileID
            }

            guard saved else {
                guard attemptsRemaining > 0 else {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(
                            domain: Self.errorDomain,
                            code: 4,
                            userInfo: [NSLocalizedDescriptionKey: "The VPN configuration was saved, but macOS did not expose it back through preferences."]
                        )))
                    }
                    return
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.waitForSavedManager(
                        profileID: profileID,
                        attemptsRemaining: attemptsRemaining - 1,
                        completion: completion
                    )
                }
                return
            }

            DispatchQueue.main.async { completion(.success(())) }
        }
    }

    private func makeManager(profileID: UUID, displayName: String, configContent: String) -> NETunnelProviderManager {
        let manager = NETunnelProviderManager()
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
        return manager
    }

    private func managedManagers(from managers: [NETunnelProviderManager]) -> [NETunnelProviderManager] {
        managers.compactMap { manager in
            guard let protocolConfiguration = manager.protocolConfiguration as? NETunnelProviderProtocol,
                  let providerConfiguration = protocolConfiguration.providerConfiguration,
                  providerConfiguration[VPNProviderPayload.managedByAppKey] as? Bool == true
            else {
                return nil
            }
            return manager
        }
    }

    private func payload(for manager: NETunnelProviderManager) -> VPNProviderPayload? {
        guard let protocolConfiguration = manager.protocolConfiguration as? NETunnelProviderProtocol else {
            return nil
        }
        return VPNProviderPayload(providerConfiguration: protocolConfiguration.providerConfiguration)
    }
}
