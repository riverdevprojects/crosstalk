import Foundation

@MainActor
final class GameStore: ObservableObject {
    @Published var state = GameState()
    @Published var activePlayerId: String?
    let pack: WordPack = WordPackLoader.load()
    var activePlayer: Player? { state.players.first { $0.id == activePlayerId } }
    func send(_ action: GameAction) { GameEngine.reduce(&state, action); if activePlayerId == nil { activePlayerId = state.players.first?.id } }
    func startOrNextRound() { if let word = pack.words.first(where: { !state.usedSignals.contains($0.signal) }) { send(.startRound(word)) } }
    func playerName(_ id: String?) -> String { state.players.first { $0.id == id }?.name ?? "—" }
    func team(_ id: TeamId) -> TeamState? { state.teams[id] }
    func receiverTeamForDecision() -> TeamId? { guard let r = state.round else { return nil }; return r.phase == .opposingDecision ? (r.clueingTeam == .A ? .B : .A) : r.phase == .owningDecision ? r.clueingTeam : nil }
    func isReceiver(_ player: Player) -> Bool { state.teams[player.team]?.receiverId == player.id }
    func activeTransmitterId() -> String? { guard let r = state.round, let t = state.teams[r.clueingTeam], !t.transmitterOrder.isEmpty else { return nil }; return t.transmitterOrder[t.rotationIndex] }
}

enum WordPackLoader {
    static func load() -> WordPack {
        guard let url = Bundle.main.url(forResource: "party-core", withExtension: "json"), let data = try? Data(contentsOf: url), let pack = try? JSONDecoder().decode(WordPack.self, from: data) else {
            return WordPack(id: "party-core", name: "Party Core", words: [WordEntry(signal: "peanut butter", accepted: ["peanutbutter", "peanut-butter"], difficulty: 1)])
        }
        return pack
    }
}
