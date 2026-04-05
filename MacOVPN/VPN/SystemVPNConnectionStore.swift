import Foundation
import NetworkExtension

final class SystemVPNConnectionStore {
    typealias StatusChangeHandler = (_ profileID: UUID, _ state: VPNConnectionState, _ disconnectError: String?) -> Void

    private let statusChangeHandler: StatusChangeHandler?
    private var managersByProfileID: [UUID: NETunnelProviderManager] = [:]
    private var statesByProfileID: [UUID: VPNConnectionState] = [:]
    private var observerTokensByProfileID: [UUID: NSObjectProtocol] = [:]

    init(statusChangeHandler: StatusChangeHandler? = nil) {
        self.statusChangeHandler = statusChangeHandler
    }

    func synchronize(completion: @escaping (Result<Void, Error>) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let managers else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(
                        domain: "MacOVPN.VPN",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Could not load VPN configurations."]
                    )))
                }
                return
            }

            self.rebuildCache(with: self.managedManagers(from: managers))
            DispatchQueue.main.async { completion(.success(())) }
        }
    }

    func connectionState(for profileID: UUID) -> VPNConnectionState? {
        statesByProfileID[profileID]
    }

    func connect(profileID: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        perform(profileID: profileID, completion: completion) { manager in
            do {
                try manager.connection.startVPNTunnel()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func disconnect(profileID: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        perform(profileID: profileID, completion: completion) { manager in
            manager.connection.stopVPNTunnel()
            completion(.success(()))
        }
    }

    private func perform(
        profileID: UUID,
        completion: @escaping (Result<Void, Error>) -> Void,
        action: @escaping (NETunnelProviderManager) -> Void
    ) {
        synchronize { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success:
                guard let manager = self.managersByProfileID[profileID] else {
                    completion(.failure(NSError(
                        domain: "MacOVPN.VPN",
                        code: 3,
                        userInfo: [NSLocalizedDescriptionKey: "No VPN configuration exists for this profile."]
                    )))
                    return
                }
                action(manager)
            }
        }
    }

    private func rebuildCache(with managers: [NETunnelProviderManager]) {
        for token in observerTokensByProfileID.values {
            NotificationCenter.default.removeObserver(token)
        }

        observerTokensByProfileID.removeAll()
        managersByProfileID.removeAll()
        statesByProfileID.removeAll(keepingCapacity: true)

        for manager in managers {
            guard let payload = VPNProviderPayload(providerConfiguration: (manager.protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration) else {
                continue
            }

            managersByProfileID[payload.profileID] = manager
            statesByProfileID[payload.profileID] = VPNConnectionState(status: manager.connection.status)

            let token = NotificationCenter.default.addObserver(
                forName: .NEVPNStatusDidChange,
                object: manager.connection,
                queue: .main
            ) { [weak self] _ in
                self?.handleStatusChange(for: payload.profileID)
            }
            observerTokensByProfileID[payload.profileID] = token
        }
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

    private func handleStatusChange(for profileID: UUID) {
        guard let manager = managersByProfileID[profileID] else { return }

        let currentState = VPNConnectionState(status: manager.connection.status)

        if currentState == .disconnected {
            manager.connection.fetchLastDisconnectError { [weak self, statusChangeHandler] error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    let nextState: VPNConnectionState = if let error {
                        .failed(error.localizedDescription)
                    } else {
                        .disconnected
                    }
                    let oldState = self.statesByProfileID[profileID]
                    guard oldState != nextState else { return }
                    self.statesByProfileID[profileID] = nextState
                    statusChangeHandler?(profileID, nextState, error?.localizedDescription)
                }
            }
        } else {
            let oldState = statesByProfileID[profileID]
            guard oldState != currentState else { return }
            statesByProfileID[profileID] = currentState
            statusChangeHandler?(profileID, currentState, nil)
        }
    }
}
