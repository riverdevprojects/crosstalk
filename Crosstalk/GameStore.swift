import Foundation
import Combine
import MultipeerConnectivity

@MainActor
final class GameStore: ObservableObject {
    @Published var state = GameState()
    @Published var activePlayerId: String?
    @Published var errorMessage: String?
    @Published private(set) var syncMessage: String?
    let network: any RoomNetwork
    let pack: WordPack
    private var networkChanges: AnyCancellable?
    private var peerPlayers: [MCPeerID: String] = [:]
    private var pendingSnapshots: [MCPeerID: Int] = [:]
    private var snapshotRetry: Task<Void, Never>?
    private var retryAttempts = 0
    private var lastJoin: (name: String, code: String)?

    init(network: (any RoomNetwork)? = nil, pack: WordPack? = nil) {
        self.network = network ?? MPCSession()
        self.pack = pack ?? WordPackLoader.load()
        networkChanges = self.network.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
        self.network.configure(onMessage: { [weak self] message, peer in self?.receive(message, from: peer) },
                          onDisconnect: { [weak self] peer in self?.disconnected(peer) })
    }
    var activePlayer: Player? { state.players.first { $0.id == activePlayerId } }
    var isHost: Bool { network.mode == .hosting || network.mode == .offline }
    var availableWords: [WordEntry] { WordSelection.available(in: pack, state: state) }

    var canCompleteMatch: Bool { WordSelection.canCompleteMatch(in: pack, config: state.config) }

    func wordCount(for themeId: String) -> Int { pack.words.filter { $0.theme == themeId }.count }

    @discardableResult
    func send(_ action: GameAction) -> Bool {
        guard let id = activePlayerId,
              ActionAuthorization.allows(action, playerId: id, isHost: isHost, state: state) else { return false }
        if case .clueGiven(let clue) = action,
           let error = InputRules.clueError(clue, answers: state.round?.acceptedAnswers ?? [state.round?.signal ?? ""]) {
            errorMessage = error; return false
        }
        if isHost {
            if case .startRound = action, !canCompleteMatch {
                errorMessage = "This theme needs at least \(state.config.roundsToWin * 2 - 1) unique words for this match. Choose another theme or a shorter match."
                return false
            }
            apply(action)
        } else if !network.send(.action(action, revision: state.revision)) {
            syncMessage = "Your action was not sent. Check the connection and try again."
            return false
        }
        return true
    }

    private func apply(_ action: GameAction) {
        let before = state
        GameEngine.reduce(&state, action)
        guard state != before else { return }
        state.revision = before.revision + 1
        broadcast()
    }

    private func broadcast() {
        for peer in peerPlayers.keys where network.connectedPeers.contains(peer) {
            sendSnapshot(to: peer)
        }
    }

    private func sendSnapshot(to peer: MCPeerID) {
        guard let id = peerPlayers[peer], network.connectedPeers.contains(peer) else { return }
        pendingSnapshots[peer] = state.revision
        if !network.send(.state(state.visible(to: id)), to: peer) {
            syncMessage = "An update could not reach a player. Retrying…"
        }
        scheduleSnapshotRetry()
    }

    private func scheduleSnapshotRetry() {
        guard snapshotRetry == nil, !pendingSnapshots.isEmpty, retryAttempts < 8 else { return }
        snapshotRetry = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 2_000_000_000) } catch { return }
            guard let self, !Task.isCancelled else { return }
            self.snapshotRetry = nil
            self.retryPendingSnapshots()
        }
    }

    // Retries snapshots only; replaying a guess or pass could spend a second turn.
    func retryPendingSnapshots() {
        guard isHost else { return }
        retryAttempts += 1
        for peer in Array(pendingSnapshots.keys) {
            if peerPlayers[peer] == nil || !network.connectedPeers.contains(peer) {
                pendingSnapshots.removeValue(forKey: peer)
            } else {
                sendSnapshot(to: peer)
            }
        }
        if pendingSnapshots.isEmpty {
            clearSnapshotRetry()
        } else {
            syncMessage = retryAttempts >= 8
                ? "A player has not received the latest game. Check their connection and tap Sync game."
                : "Waiting for players to receive the latest game. Retrying…"
            scheduleSnapshotRetry()
        }
    }

    private func clearSnapshotRetry() {
        snapshotRetry?.cancel(); snapshotRetry = nil
        retryAttempts = 0
        syncMessage = nil
    }

    func syncGame() {
        if isHost {
            retryAttempts = 0
            broadcast()
        } else {
            syncMessage = network.send(.requestState)
                ? "Requesting the latest game…"
                : "Could not request an update. Check the connection and tap Sync game again."
        }
    }

    func receive(_ message: NetworkMessage, from peer: MCPeerID) {
        switch message {
        case .hello(let player):
            guard isHost else { return }
            if peerPlayers[peer] != nil {
                sendSnapshot(to: peer)
                return
            }
            guard state.status == .lobby, state.players.count < 8,
                  !state.players.contains(where: { $0.id == player.id }),
                  InputRules.validName(player.name), !player.id.isEmpty, player.id.count <= 64 else {
                network.send(.error("Cannot join this room. The host must be in the lobby with a free player slot. Leave and try again."), to: peer)
                return
            }
            peerPlayers[peer] = player.id
            apply(.upsertPlayer(player))
        case .action(let action, let revision):
            guard isHost, let id = peerPlayers[peer] else { return }
            guard revision == state.revision,
                  ActionAuthorization.allows(action, playerId: id, isHost: false, state: state) else {
                network.send(.error("The game changed or that action is not yours. Check the current screen and try again."), to: peer)
                sendSnapshot(to: peer)
                return
            }
            if case .clueGiven(let clue) = action,
               let error = InputRules.clueError(clue, answers: state.round?.acceptedAnswers ?? []) {
                network.send(.error(error), to: peer); return
            }
            apply(action)
        case .state(let newState):
            guard !isHost, network.isHostPeer(peer), newState.revision >= state.revision else { return }
            guard let id = activePlayerId, newState.players.contains(where: { $0.id == id }) else { return }
            state = newState
            syncMessage = nil
            network.joined()
            network.send(.acknowledge(revision: newState.revision), to: peer)
        case .acknowledge(let revision):
            guard isHost, peerPlayers[peer] != nil,
                  let expected = pendingSnapshots[peer], revision == expected else { return }
            pendingSnapshots.removeValue(forKey: peer)
            if pendingSnapshots.isEmpty { clearSnapshotRetry() }
        case .requestState:
            guard isHost, peerPlayers[peer] != nil else { return }
            retryAttempts = 0
            sendSnapshot(to: peer)
        case .error(let message):
            guard !isHost, network.isHostPeer(peer) else { return }
            errorMessage = message
            if state.players.count <= 1 { network.failJoin(message) }
        case .removed(let message):
            guard !isHost, network.isHostPeer(peer) else { return }
            state = GameState()
            network.failJoin(message)
        case .leave:
            guard isHost else { return }
            disconnected(peer)
        }
    }

    func removePlayer(_ id: String) {
        guard isHost, state.status == .lobby, id != activePlayerId else { return }
        if let peer = peerPlayers.first(where: { $0.value == id })?.key {
            peerPlayers.removeValue(forKey: peer)
            pendingSnapshots.removeValue(forKey: peer)
            if pendingSnapshots.isEmpty { clearSnapshotRetry() }
            network.send(.removed("The host removed you from the room. Ask before rejoining."), to: peer)
        }
        apply(.removePlayer(id))
    }

    private func disconnected(_ peer: MCPeerID) {
        guard isHost, let id = peerPlayers.removeValue(forKey: peer) else { return }
        pendingSnapshots.removeValue(forKey: peer)
        if pendingSnapshots.isEmpty { clearSnapshotRetry() }
        let name = playerName(id)
        let wasPlaying = state.status != .lobby
        // Return everyone to a usable lobby rather than leave an unplayable turn.
        // A rejoining player receives a fresh role only when the host starts again.
        if wasPlaying { GameEngine.reduce(&state, .reset) }
        GameEngine.reduce(&state, .removePlayer(id))
        state.notice = wasPlaying ? "\(name) disconnected. The match was reset. Wait for them to rejoin or rebalance teams and start again." : "\(name) left the room."
        state.revision += 1
        broadcast()
    }

    static func makeRoomCode() -> String {
        let chars = Array(InputRules.roomAlphabet)
        return String((0..<4).map { _ in chars.randomElement()! })
    }

    func hostGame(name: String) {
        guard InputRules.validName(name) else { errorMessage = "Enter a name of 1–32 characters."; return }
        leaveRoom()
        let player = Player(name: name.trimmingCharacters(in: .whitespacesAndNewlines), team: .A)
        activePlayerId = player.id
        network.host(code: Self.makeRoomCode())
        apply(.upsertPlayer(player))
    }

    func joinGame(name: String, code: String) {
        guard InputRules.validName(name), InputRules.validRoomCode(code.uppercased()) else {
            errorMessage = "Enter a name of 1–32 characters and the four-character room code."; return
        }
        clearSnapshotRetry()
        pendingSnapshots = [:]
        peerPlayers = [:]
        errorMessage = nil
        lastJoin = (name, code.uppercased())
        let player = Player(name: name.trimmingCharacters(in: .whitespacesAndNewlines), team: .A)
        activePlayerId = player.id
        state = GameState(players: [player])
        network.join(player: player, code: code.uppercased())
    }

    func retryJoin() {
        guard let lastJoin else { return }
        joinGame(name: lastJoin.name, code: lastJoin.code)
    }

    func leaveRoom() {
        if network.mode == .joining { network.send(.leave) }
        clearSnapshotRetry()
        pendingSnapshots = [:]
        network.stop()
        peerPlayers = [:]
        state = GameState()
        activePlayerId = nil
        lastJoin = nil
        errorMessage = nil
    }

    func startOrNextRound() {
        guard isHost else { return }
        guard state.status != .lobby || canCompleteMatch else {
            errorMessage = "This theme needs at least \(state.config.roundsToWin * 2 - 1) unique words for this match. Choose another theme or a shorter match."
            return
        }
        guard let word = availableWords.randomElement() else {
            errorMessage = "No unused words remain in this theme. Return to the lobby and choose another theme."
            return
        }
        send(state.status == .lobby ? .startRound(word) : .nextRound(word))
    }

    func teamName(_ team: TeamId) -> String { state.config.teamNames[team] ?? "Team \(team.rawValue)" }
    func playerName(_ id: String?) -> String { state.players.first { $0.id == id }?.name ?? "—" }
    func team(_ id: TeamId) -> TeamState? { state.teams[id] }
    func receiverTeamForDecision() -> TeamId? { guard let r = state.round else { return nil }; return r.phase == .opposingDecision ? (r.clueingTeam == .A ? .B : .A) : r.phase == .owningDecision ? r.clueingTeam : nil }
    func isReceiver(_ player: Player) -> Bool { state.teams[player.team]?.receiverId == player.id }
    func activeTransmitterId() -> String? {
        guard let r = state.round, let t = state.teams[r.clueingTeam], t.transmitterOrder.indices.contains(t.rotationIndex) else { return nil }
        return t.transmitterOrder[t.rotationIndex]
    }
}

enum WordPackLoader {
    static func load() -> WordPack {
        guard let url = Bundle.main.url(forResource: "party-core", withExtension: "json"),
              let data = try? Data(contentsOf: url), let pack = try? JSONDecoder().decode(WordPack.self, from: data) else {
            // Surface the empty pool rather than silently repeat a fallback answer.
            return WordPack(id: "party-core", name: "Unavailable", words: [])
        }
        return pack
    }
}
