import Foundation

enum GameAction: Codable { case addPlayer(String), upsertPlayer(Player), renamePlayer(String, String), setPlayerTeam(String, TeamId), removePlayer(String), assignTeams, setTeamName(TeamId, String), voteTheme(String, String), setTheme(String), setCategory(String), setRoundsToWin(Int), setMaxStatics(Int), startRound(WordEntry), allReady, clueGiven(String), receiverPass(TeamId), receiverGuess(TeamId, String), nextRound(WordEntry), reset }

enum GuessMatcher {
    static func normalize(_ input: String) -> String {
        var s = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        for a in ["the ", "an ", "a "] where s.hasPrefix(a) { s.removeFirst(a.count); break }
        return s.filter { $0.isLetter || $0.isNumber }
    }
    static func isCorrect(_ guess: String, accepted: [String]) -> Bool {
        let g = normalize(guess); guard !g.isEmpty else { return false }
        for answer in accepted.map(normalize) {
            if g == answer || singulars(g).contains(answer) || singulars(answer).contains(g) { return true }
            if max(g.count, answer.count) > 5 && levenshtein(g, answer) <= 1 { return true }
        }
        return false
    }
    static func singulars(_ s: String) -> Set<String> {
        var out: Set<String> = [s]
        if s.hasSuffix("ies"), s.count > 3 { out.insert(String(s.dropLast(3)) + "y") }
        if s.hasSuffix("es"), s.count > 2 { out.insert(String(s.dropLast(2))) }
        if s.hasSuffix("s"), s.count > 1 { out.insert(String(s.dropLast())) }
        return out
    }
    static func levenshtein(_ a: String, _ b: String) -> Int {
        let aa = Array(a), bb = Array(b); var prev = Array(0...bb.count)
        for i in 1...aa.count { var row = [i] + Array(repeating: 0, count: bb.count); for j in 1...bb.count { row[j] = min(prev[j] + 1, row[j-1] + 1, prev[j-1] + (aa[i-1] == bb[j-1] ? 0 : 1)) }; prev = row }
        return prev[bb.count]
    }
}

struct GameEngine {
    static func reduce(_ state: inout GameState, _ action: GameAction) {
        switch action {
        case .addPlayer(let name): state.players.append(Player(name: name, team: state.players.filter{$0.team == .A}.count <= state.players.filter{$0.team == .B}.count ? .A : .B))
        case .upsertPlayer(var player):
            if let i = state.players.firstIndex(where: { $0.id == player.id }) { state.players[i].name = player.name }
            else { player.team = state.players.filter{$0.team == .A}.count <= state.players.filter{$0.team == .B}.count ? .A : .B; state.players.append(player) }
        case .renamePlayer(let id, let name): if let i = state.players.firstIndex(where: { $0.id == id }) { state.players[i].name = name }
        case .setPlayerTeam(let id, let team): if let i = state.players.firstIndex(where: { $0.id == id }) { state.players[i].team = team }
        case .removePlayer(let id): state.players.removeAll { $0.id == id }; state.themeVotes.removeValue(forKey: id)
        case .assignTeams: for i in state.players.indices { state.players[i].team = i % 2 == 0 ? .A : .B }
        case .setTeamName(let team, let name): state.config.teamNames[team] = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Team \(team.rawValue)" : name
        case .voteTheme(let playerId, let themeId):
            state.themeVotes[playerId] = themeId
            let counts = Dictionary(grouping: state.themeVotes.values, by: { $0 }).mapValues(\.count)
            if let winner = counts.max(by: { $0.value == $1.value ? $0.key > $1.key : $0.value < $1.value })?.key { state.config.themeId = winner }
        case .setTheme(let themeId): state.config.themeId = themeId
        case .setCategory(let category): state.config.category = category
        case .setRoundsToWin(let rounds): state.config.roundsToWin = min(max(rounds, 2), 4)
        case .setMaxStatics(let statics): state.config.maxStatics = min(max(statics, 2), 3)
        case .startRound(let word), .nextRound(let word): start(&state, word)
        case .allReady: state.round?.phase = .awaitingClue
        case .clueGiven(let clue):
            guard var round = state.round, round.phase == .awaitingClue else { return }
            let clueing = round.clueingTeam
            let transmitterId = state.teams[clueing]!.transmitterOrder[state.teams[clueing]!.rotationIndex]
            round.history.append(TurnRecord(clueingTeam: clueing, transmitterId: transmitterId, clueText: clue.trimmingCharacters(in: .whitespacesAndNewlines)))
            round.phase = .opposingDecision; round.announcement = nil; state.round = round
        case .receiverPass(let team): decide(&state, team: team, guess: nil)
        case .receiverGuess(let team, let guess): decide(&state, team: team, guess: guess)
        case .reset: state = GameState()
        }
    }
    private static func start(_ state: inout GameState, _ word: WordEntry) {
        let a = state.players.filter{$0.team == .A}, b = state.players.filter{$0.team == .B}; guard a.count >= 2 && b.count >= 2 else { return }
        state.roundNumber += 1; state.status = .inRound; state.usedSignals.insert(word.signal)
        let ar = a[(state.roundNumber - 1) % a.count].id, br = b[(state.roundNumber - 1) % b.count].id
        let oldAScore = state.teams[.A]?.score ?? 0, oldBScore = state.teams[.B]?.score ?? 0
        state.teams[.A] = TeamState(id: .A, receiverId: ar, transmitterOrder: a.filter{$0.id != ar}.map(\.id), score: oldAScore)
        state.teams[.B] = TeamState(id: .B, receiverId: br, transmitterOrder: b.filter{$0.id != br}.map(\.id), score: oldBScore)
        state.round = RoundState(signal: word.signal, acceptedAnswers: [word.signal] + word.accepted, clueingTeam: state.roundNumber % 2 == 1 ? .A : .B, phase: .roleReveal)
    }
    private static func decide(_ state: inout GameState, team: TeamId, guess: String?) {
        guard var round = state.round else { return }
        let clueing = round.clueingTeam, opposing = clueing == .A ? TeamId.B : .A
        guard (round.phase == .opposingDecision && team == opposing) || (round.phase == .owningDecision && team == clueing) else { return }
        let correct = guess.map { GuessMatcher.isCorrect($0, accepted: round.acceptedAnswers) } ?? false
        let action = GuessAction(guess: guess, correct: correct)
        if round.history.isEmpty || round.history.last?.owningAction != nil { round.history.append(TurnRecord(clueingTeam: clueing, transmitterId: state.teams[clueing]!.transmitterOrder[state.teams[clueing]!.rotationIndex], clueText: nil)) }
        if round.phase == .opposingDecision { round.history[round.history.count-1].opposingAction = action } else { round.history[round.history.count-1].owningAction = action }
        if correct { finish(&state, &round, winner: team, reason: .correctGuess); return }
        if let g = guess { state.teams[team]!.statics += 1; round.announcement = "Team \(team.rawValue) guessed \"\(g)\" — Static (\(state.teams[team]!.statics)/\(state.config.maxStatics))"; if state.teams[team]!.statics >= state.config.maxStatics { finish(&state, &round, winner: team == .A ? .B : .A, reason: .lockout); return } }
        if round.phase == .opposingDecision { round.phase = .owningDecision } else { advance(&state, &round) }
        state.round = round
    }
    private static func finish(_ state: inout GameState, _ round: inout RoundState, winner: TeamId, reason: WinReason) { round.winner = winner; round.winReason = reason; round.phase = .roundOver; state.teams[winner]!.score += 1; state.status = state.teams[winner]!.score >= state.config.roundsToWin ? .matchOver : .inRound; state.round = round }
    private static func advance(_ state: inout GameState, _ round: inout RoundState) { let old = round.clueingTeam; state.teams[old]!.rotationIndex = (state.teams[old]!.rotationIndex + 1) % state.teams[old]!.transmitterOrder.count; round.clueingTeam = old == .A ? .B : .A; round.phase = .awaitingClue }
}
