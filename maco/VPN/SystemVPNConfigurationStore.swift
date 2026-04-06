import Foundation
import NetworkExtension

struct SystemVPNConfigurationReconcileResult: Equatable {
    let createdCount: Int
    let updatedCount: Int
    let removedCount: Int
}

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

    func reconcile(
        profiles: [ProfileRecord],
        completion: @escaping (Result<SystemVPNConfigurationReconcileResult, Error>) -> Void
    ) {
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let managers else {
                DispatchQueue.main.async { completion(.failure(SystemVPNConfigurationStoreError.failedToLoadPreferences)) }
                return
            }

            self.reconcileLoadedManagers(managers, profiles: profiles, completion: completion)
        }
    }

    private func reconcileLoadedManagers(
        _ managers: [NETunnelProviderManager],
        profiles: [ProfileRecord],
        completion: @escaping (Result<SystemVPNConfigurationReconcileResult, Error>) -> Void
    ) {
        var managersByProfileID: [UUID: NETunnelProviderManager] = [:]
        var orphanedManagers: [NETunnelProviderManager] = []

        for manager in managers {
            guard isManagedByApp(manager) else {
                continue
            }

            guard let payload = payload(for: manager) else {
                orphanedManagers.append(manager)
                continue
            }

            if managersByProfileID[payload.profileID] == nil {
                managersByProfileID[payload.profileID] = manager
            } else {
                orphanedManagers.append(manager)
            }
        }

        let desiredProfiles = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
        for payloadManager in managersByProfileID {
            if desiredProfiles[payloadManager.key] == nil {
                orphanedManagers.append(payloadManager.value)
            }
        }

        let group = DispatchGroup()
        let stateQueue = DispatchQueue(label: "com.macovpn.vpn.configuration.state")
        var createdCount = 0
        var updatedCount = 0
        var removedCount = 0
        var firstError: Error?

        func record(error: Error) {
            stateQueue.sync {
                if firstError == nil {
                    firstError = error
                }
            }
        }

        for profile in profiles {
            if let manager = managersByProfileID[profile.id] {
                if needsUpdate(manager, for: profile) {
                    group.enter()
                    update(manager: manager, for: profile) { result in
                        switch result {
                        case .success:
                            stateQueue.sync { updatedCount += 1 }
                        case .failure(let error):
                            record(error: error)
                        }
                        group.leave()
                    }
                }
            } else {
                group.enter()
                createManager(for: profile) { result in
                    switch result {
                    case .success:
                        stateQueue.sync { createdCount += 1 }
                    case .failure(let error):
                        record(error: error)
                    }
                    group.leave()
                }
            }
        }

        for manager in orphanedManagers {
            group.enter()
            remove(manager: manager) { result in
                switch result {
                case .success:
                    stateQueue.sync { removedCount += 1 }
                case .failure(let error):
                    record(error: error)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if let firstError {
                completion(.failure(firstError))
            } else {
                completion(.success(SystemVPNConfigurationReconcileResult(
                    createdCount: createdCount,
                    updatedCount: updatedCount,
                    removedCount: removedCount
                )))
            }
        }
    }

    private func createManager(
        for profile: ProfileRecord,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let manager = makeManager(for: profile)
        save(manager: manager, completion: completion)
    }

    private func update(
        manager: NETunnelProviderManager,
        for profile: ProfileRecord,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        configure(manager: manager, for: profile)
        save(manager: manager, completion: completion)
    }

    private func remove(
        manager: NETunnelProviderManager,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        manager.removeFromPreferences { error in
            if let error {
                completion(.failure(error))
                return
            }
            completion(.success(()))
        }
    }

    private func save(
        manager: NETunnelProviderManager,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        manager.saveToPreferences { error in
            if let error {
                completion(.failure(error))
                return
            }
            completion(.success(()))
        }
    }

    private func makeManager(for profile: ProfileRecord) -> NETunnelProviderManager {
        let manager = NETunnelProviderManager()
        configure(manager: manager, for: profile)
        return manager
    }

    private func configure(manager: NETunnelProviderManager, for profile: ProfileRecord) {
        let protocolConfiguration = NETunnelProviderProtocol()
        protocolConfiguration.providerBundleIdentifier = providerBundleIdentifier
        protocolConfiguration.providerConfiguration = payload(for: profile).providerConfiguration
        protocolConfiguration.serverAddress = profile.displayName

        manager.localizedDescription = profile.displayName
        manager.protocolConfiguration = protocolConfiguration
        manager.isEnabled = true
    }

    private func needsUpdate(_ manager: NETunnelProviderManager, for profile: ProfileRecord) -> Bool {
        guard let payload = payload(for: manager) else {
            return true
        }

        guard payload.profileID == profile.id,
              payload.profileDirectoryPath == profile.directoryURL().path,
              payload.profileConfigPath == ProfilePaths.profileFileURL(in: profile.directoryURL()).path
        else {
            return true
        }

        guard let protocolConfiguration = manager.protocolConfiguration as? NETunnelProviderProtocol else {
            return true
        }

        return protocolConfiguration.providerBundleIdentifier != providerBundleIdentifier
            || protocolConfiguration.serverAddress != profile.displayName
            || manager.localizedDescription != profile.displayName
            || manager.isEnabled == false
    }

    private func payload(for profile: ProfileRecord) -> VPNProviderPayload {
        let directoryURL = profile.directoryURL()
        return VPNProviderPayload(
            profileID: profile.id,
            profileDirectoryPath: directoryURL.path,
            profileConfigPath: ProfilePaths.profileFileURL(in: directoryURL).path
        )
    }

    private func payload(for manager: NETunnelProviderManager) -> VPNProviderPayload? {
        guard let protocolConfiguration = manager.protocolConfiguration as? NETunnelProviderProtocol else {
            return nil
        }
        return VPNProviderPayload(providerConfiguration: protocolConfiguration.providerConfiguration)
    }

    private func isManagedByApp(_ manager: NETunnelProviderManager) -> Bool {
        guard let protocolConfiguration = manager.protocolConfiguration as? NETunnelProviderProtocol,
              let providerConfiguration = protocolConfiguration.providerConfiguration
        else {
            return false
        }

        return providerConfiguration[VPNProviderPayload.managedByAppKey] as? Bool == true
    }
}
