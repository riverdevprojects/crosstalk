import Foundation

@MainActor
final class GameStore: ObservableObject {
    @Published var state = GameState()
    @Published var activePlayerId: String?
    @Published var network = MPCSession()
    let pack: WordPack = WordPackLoader.load()

    init() {
        network.configure { [weak self] message in self?.receive(message) }
    }
    var activePlayer: Player? { state.players.first { $0.id == activePlayerId } }
    var isHost: Bool { network.mode == .hosting || network.mode == .offline }

    func send(_ action: GameAction) {
        if isHost {
            GameEngine.reduce(&state, action)
            if activePlayerId == nil { activePlayerId = state.players.first?.id }
            network.send(.state(state))
        } else {
            network.send(.action(action))
        }
    }

    func receive(_ message: NetworkMessage) {
        switch message {
        case .action(let action):
            guard isHost else { return }
            send(action)
        case .state(let newState):
            guard !isHost else { return }
            state = newState
        }
    }

    func hostGame(name: String) {
        let id = activePlayerId ?? UUID().uuidString
        activePlayerId = id
        network.host()
        send(.upsertPlayer(Player(id: id, name: name, team: .A)))
    }

    func joinGame(name: String) {
        let id = activePlayerId ?? UUID().uuidString
        activePlayerId = id
        let player = Player(id: id, name: name, team: .A)
        network.join(player: player)
        state.players = [player]
    }

    func startOrNextRound() {
        if state.status == .lobby { applyCaptainCategoryChoice() }
        let themed = pack.words.filter { ($0.theme ?? "signal") == state.config.themeId }
        let themedCategory = themed.filter { state.config.category == "Everything" || $0.category == state.config.category }
        let categoryAnyTheme = pack.words.filter { state.config.category == "Everything" || $0.category == state.config.category }
        let pools = [themedCategory, themed, categoryAnyTheme, pack.words]
        for pool in pools {
            if let word = pool.shuffled().first(where: { !state.usedSignals.contains($0.signal) }) { send(.startRound(word)); return }
        }
    }

    func randomizeCaptainsAndTeams() {
        guard isHost, state.players.count >= 4 else { return }
        let shuffled = state.players.shuffled()
        let captainA = shuffled[0].id, captainB = shuffled[1].id
        var updated: [Player] = []
        for (index, var player) in shuffled.enumerated() {
            if player.id == captainA { player.team = .A }
            else if player.id == captainB { player.team = .B }
            else { player.team = index % 2 == 0 ? .A : .B }
            updated.append(player)
        }
        send(.setLobbyPlayers(updated))
        send(.setCaptains([.A: captainA, .B: captainB]))
    }

    func captainTeam(for playerId: String?) -> TeamId? { state.captainIds.first { $0.value == playerId }.map(\.key) }
    func isCaptain(_ player: Player) -> Bool { state.captainIds[player.team] == player.id }

    private func applyCaptainCategoryChoice() {
        let a = state.teamCategoryVotes[.A]
        let b = state.teamCategoryVotes[.B]
        let chosen: String
        if let a, let b { chosen = a == b ? a : [a, b].randomElement()! }
        else { chosen = a ?? b ?? state.config.category }
        state.config.category = chosen
    }

    func teamName(_ team: TeamId) -> String { state.config.teamNames[team] ?? "Team \(team.rawValue)" }
    func playerName(_ id: String?) -> String { state.players.first { $0.id == id }?.name ?? "—" }
    func team(_ id: TeamId) -> TeamState? { state.teams[id] }
    func receiverTeamForDecision() -> TeamId? { guard let r = state.round else { return nil }; return r.phase == .opposingDecision ? (r.clueingTeam == .A ? .B : .A) : r.phase == .owningDecision ? r.clueingTeam : nil }
    func isReceiver(_ player: Player) -> Bool { state.teams[player.team]?.receiverId == player.id }
    func activeTransmitterId() -> String? { guard let r = state.round, let t = state.teams[r.clueingTeam], !t.transmitterOrder.isEmpty else { return nil }; return t.transmitterOrder[t.rotationIndex] }
}

enum WordPackLoader {
    static func load() -> WordPack {
        guard let url = Bundle.main.url(forResource: "party-core", withExtension: "json"), let data = try? Data(contentsOf: url), let pack = try? JSONDecoder().decode(WordPack.self, from: data) else {
            return WordPack(id: "party-core", name: "Party Core", words: [WordEntry(signal: "peanut butter", accepted: ["peanutbutter", "peanut-butter"], difficulty: 1, category: "Food", theme: "signal")])
        }
        return pack
    }
}
