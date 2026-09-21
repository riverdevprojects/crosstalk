import Foundation
import MultipeerConnectivity
import UIKit

private let serviceType = "ctalk-game"
private let protocolVersion = "2"

enum NetworkMessage: Codable {
    case hello(Player)
    case action(GameAction, revision: Int)
    case state(GameState)
    case error(String)
    case leave
    case removed(String)
}

@MainActor
final class MPCSession: NSObject, ObservableObject {
    @Published var mode: NetworkMode = .offline
    @Published var connectedNames: [String] = []
    @Published var statusText = "Not connected"
    @Published var roomCode = ""
    @Published var connectionError: String?
    @Published var hostDisconnected = false
    private var joinCode: String?
    private var hostPeer: MCPeerID?
    private let peerID = MCPeerID(displayName: UIDevice.current.name)
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var timeout: Task<Void, Never>?
    private var onMessage: ((NetworkMessage, MCPeerID) -> Void)?
    private var onDisconnect: ((MCPeerID) -> Void)?
    private var pendingJoinPlayer: Player?

    var connectedPeers: [MCPeerID] { session?.connectedPeers ?? [] }
    func isHostPeer(_ peer: MCPeerID) -> Bool { peer == hostPeer }

    func configure(onMessage: @escaping (NetworkMessage, MCPeerID) -> Void,
                   onDisconnect: @escaping (MCPeerID) -> Void) {
        self.onMessage = onMessage
        self.onDisconnect = onDisconnect
    }

    private func makeSession() {
        let next = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        next.delegate = self
        session = next
    }

    func host(code: String) {
        stop()
        makeSession()
        mode = .hosting
        roomCode = code
        advertiser = MCNearbyServiceAdvertiser(peer: peerID,
            discoveryInfo: ["code": code, "version": protocolVersion], serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        statusText = "Room open • share the code"
    }

    func join(player: Player, code: String) {
        stop()
        guard InputRules.validRoomCode(code) else {
            connectionError = "Enter the four-character code shown on the host's phone."
            return
        }
        makeSession()
        pendingJoinPlayer = player
        joinCode = code
        roomCode = code
        mode = .joining
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        statusText = "Searching for room \(code)…"
        timeout = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 20_000_000_000) } catch { return }
            guard let self, !Task.isCancelled else { return }
            self.failJoin("Could not join the room. Check the code, keep the host nearby, and allow Local Network access in Settings. Then retry.")
        }
    }

    // Called only after the host has acknowledged registration with a snapshot.
    func joined() {
        timeout?.cancel(); timeout = nil
        connectionError = nil
        hostDisconnected = false
    }

    func failJoin(_ message: String) {
        let wasDisconnected = hostDisconnected
        stop()
        mode = .joining
        connectionError = message
        hostDisconnected = wasDisconnected
        statusText = message
    }

    func stop() {
        timeout?.cancel(); timeout = nil
        advertiser?.stopAdvertisingPeer(); advertiser = nil
        browser?.stopBrowsingForPeers(); browser = nil
        let old = session
        session = nil // Ignore queued callbacks from previous rooms/sessions.
        old?.delegate = nil
        old?.disconnect()
        connectedNames = []
        pendingJoinPlayer = nil
        joinCode = nil
        hostPeer = nil
        mode = .offline
        connectionError = nil
        hostDisconnected = false
        roomCode = ""
        statusText = "Not connected"
    }

    @discardableResult
    func send(_ message: NetworkMessage, to peer: MCPeerID? = nil) -> Bool {
        guard let session else { return false }
        let peers = peer.map { [$0] } ?? (mode == .joining ? hostPeer.map { [$0] } ?? [] : connectedPeers)
        guard !peers.isEmpty, peers.allSatisfy({ connectedPeers.contains($0) }) else { return false }
        do {
            try session.send(JSONEncoder().encode(message), toPeers: peers, with: .reliable)
            return true
        } catch {
            connectionError = "Could not send the update. Check the connection and retry."
            return false
        }
    }
}

extension MPCSession: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
                               withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in
            let valid = self.advertiser === advertiser && self.mode == .hosting &&
                context == Data("\(protocolVersion):\(self.roomCode)".utf8) && self.connectedPeers.count < 7
            invitationHandler(valid, valid ? self.session : nil)
        }
    }
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        Task { @MainActor in
            guard self.advertiser === advertiser else { return }
            self.connectionError = "Cannot open the room. Enable Local Network access in Settings, then leave and create a new room."
        }
    }
}

extension MPCSession: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        let code = info?["code"], version = info?["version"]
        Task { @MainActor in
            guard self.browser === browser, let wanted = self.joinCode, code == wanted,
                  self.hostPeer == nil, let session = self.session else { return }
            guard version == protocolVersion else {
                self.failJoin("The host has a different app version. Update all phones and try again.")
                return
            }
            self.hostPeer = peerID
            browser.stopBrowsingForPeers()
            browser.invitePeer(peerID, to: session, withContext: Data("\(protocolVersion):\(wanted)".utf8), timeout: 10)
        }
    }
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        Task { @MainActor in
            guard self.browser === browser else { return }
            self.failJoin("Cannot search for rooms. Enable Local Network access in Settings, then retry.")
        }
    }
}

extension MPCSession: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            guard self.session === session else { return }
            self.connectedNames = session.connectedPeers.map(\.displayName)
            switch state {
            case .connected:
                self.statusText = "Connected: \(peerID.displayName)"
                if self.mode == .joining, peerID == self.hostPeer, let player = self.pendingJoinPlayer {
                    self.send(.hello(player), to: peerID)
                }
            case .connecting: self.statusText = "Connecting to \(peerID.displayName)…"
            case .notConnected:
                self.statusText = "Disconnected from \(peerID.displayName)"
                if self.mode == .joining, peerID == self.hostPeer {
                    self.hostDisconnected = true
                    self.failJoin("The host disconnected. Ask them to reopen the lobby, then rejoin or leave the room.")
                }
                self.onDisconnect?(peerID)
            @unknown default: break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard data.count <= 1_000_000, let message = try? JSONDecoder().decode(NetworkMessage.self, from: data) else { return }
        Task { @MainActor in
            guard self.session === session, session.connectedPeers.contains(peerID) else { return }
            self.onMessage?(message, peerID)
        }
    }
    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
