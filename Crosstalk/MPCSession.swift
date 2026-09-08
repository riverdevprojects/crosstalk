import Foundation
import MultipeerConnectivity
import UIKit

private let serviceType = "ctalk-game"

enum NetworkMessage: Codable {
    case action(GameAction)
    case state(GameState)
}

@MainActor
final class MPCSession: NSObject, ObservableObject {
    @Published var mode: NetworkMode = .offline
    @Published var connectedNames: [String] = []
    @Published var statusText = "Not connected"
    @Published var roomCode = ""
    private var joinCode: String?

    private let peerID = MCPeerID(displayName: UIDevice.current.name)
    private lazy var session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var onMessage: ((NetworkMessage) -> Void)?
    var pendingJoinPlayer: Player?

    func configure(onMessage: @escaping (NetworkMessage) -> Void) {
        self.onMessage = onMessage
        session.delegate = self
    }

    func host(code: String) {
        stop()
        mode = .hosting
        roomCode = code
        joinCode = nil
        session.delegate = self
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: ["code": code], serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        statusText = "Room open • share the code"
    }

    func join(player: Player, code: String) {
        stop()
        pendingJoinPlayer = player
        joinCode = code
        mode = .joining
        session.delegate = self
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        statusText = "Searching for room \(code)…"
    }

    func stop() {
        advertiser?.stopAdvertisingPeer(); advertiser = nil
        browser?.stopBrowsingForPeers(); browser = nil
        session.disconnect()
        connectedNames = []
    }

    func send(_ message: NetworkMessage) {
        guard !session.connectedPeers.isEmpty, let data = try? JSONEncoder().encode(message) else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }
}

extension MPCSession: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in invitationHandler(true, self.session) }
    }
}

extension MPCSession: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        let peerCode = info?["code"]
        Task { @MainActor in
            // Only connect to the host advertising the code this player typed in.
            guard let wanted = self.joinCode else { return }
            guard peerCode == wanted else { return }
            browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 10)
        }
    }
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}

extension MPCSession: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            self.connectedNames = session.connectedPeers.map(\.displayName)
            switch state {
            case .connected:
                self.statusText = "Connected: \(peerID.displayName)"
                if self.mode == .joining, let p = self.pendingJoinPlayer { self.send(.action(.upsertPlayer(p))) }
            case .connecting: self.statusText = "Connecting to \(peerID.displayName)…"
            case .notConnected: self.statusText = "Disconnected from \(peerID.displayName)"
            @unknown default: self.statusText = "Connection changed"
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = try? JSONDecoder().decode(NetworkMessage.self, from: data) else { return }
        Task { @MainActor in self.onMessage?(message) }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
