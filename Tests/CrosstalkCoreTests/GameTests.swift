import XCTest
#if canImport(CrosstalkCore)
@testable import CrosstalkCore
#else
@testable import Crosstalk
#endif

final class GameTests: XCTestCase {
    let word = WordEntry(signal: "rocket", accepted: ["space rocket"], difficulty: 1, theme: "space")
    func lobby() -> GameState {
        var state = GameState(); state.config.themeId = "space"
        for name in ["Alex", "Blair", "Casey", "Drew", "Eli", "Fran"] { GameEngine.reduce(&state, .addPlayer(name)) }
        return state
    }
    func round() -> GameState {
        var state = lobby()
        GameEngine.reduce(&state, .startRound(word))
        return state
    }
    func decision() -> GameState {
        var state = round()
        GameEngine.reduce(&state, .allReady)
        GameEngine.reduce(&state, .clueGiven("orbit"))
        return state
    }
    func testRequiresTwoPlayersPerTeam() {
        var state = GameState(); state.config.themeId = "space"
        for name in ["Alex", "Blair", "Casey"] { GameEngine.reduce(&state, .addPlayer(name)) }
        GameEngine.reduce(&state, .startRound(word))
        XCTAssertEqual(state.status, .lobby)
        XCTAssertNil(state.round)
    }
    func testRolesPartitionEachTeam() {
        let state = round()
        for id in TeamId.allCases {
            let team = state.teams[id]!
            XCTAssertFalse(team.transmitterOrder.contains(team.receiverId))
            XCTAssertEqual(Set(team.transmitterOrder + [team.receiverId]), Set(state.players.filter { $0.team == id }.map(\.id)))
        }
    }
    func testCannotStartOverAnActiveRound() {
        var state = round(); let before = state
        GameEngine.reduce(&state, .startRound(WordEntry(signal: "moon", accepted: [], difficulty: 1, theme: "space")))
        GameEngine.reduce(&state, .nextRound(word))
        XCTAssertEqual(state, before)
    }
    func testCompletedRoundCannotBeReopenedOrScoredTwice() {
        var state = decision()
        GameEngine.reduce(&state, .receiverGuess(.B, "rocket"))
        let before = state
        GameEngine.reduce(&state, .allReady)
        GameEngine.reduce(&state, .clueGiven("orbit"))
        GameEngine.reduce(&state, .receiverGuess(.B, "rocket"))
        XCTAssertEqual(state, before)
        XCTAssertEqual(state.teams[.B]?.score, 1)
    }
    func testWrongTeamCannotDecide() {
        var state = decision(); let before = state
        GameEngine.reduce(&state, .receiverGuess(.A, "rocket"))
        GameEngine.reduce(&state, .receiverPass(.A))
        XCTAssertEqual(state, before)
    }
    func testPassingRotatesHintGiverAndAlternatesTeams() {
        var state = decision()
        GameEngine.reduce(&state, .receiverPass(.B))
        XCTAssertEqual(state.round?.phase, .owningDecision)
        GameEngine.reduce(&state, .receiverPass(.A))
        XCTAssertEqual(state.round?.phase, .awaitingClue)
        XCTAssertEqual(state.round?.clueingTeam, .B)
        XCTAssertEqual(state.teams[.A]?.rotationIndex, 1)
        XCTAssertEqual(state.teams[.A]?.statics, 0)
        XCTAssertEqual(state.teams[.B]?.statics, 0)
    }
    func testLockoutAwardsOtherTeam() {
        var state = decision()
        state.teams[.B]?.statics = state.config.maxStatics - 1
        GameEngine.reduce(&state, .receiverGuess(.B, "banana"))
        XCTAssertEqual(state.round?.winner, .A)
        XCTAssertEqual(state.round?.winReason, .lockout)
        XCTAssertEqual(state.teams[.A]?.score, 1)
    }
    func testMatchOverBlocksMoreRounds() {
        var state = decision()
        state.teams[.B]?.score = state.config.roundsToWin - 1
        GameEngine.reduce(&state, .receiverGuess(.B, "rocket"))
        XCTAssertEqual(state.status, .matchOver)
        let before = state
        GameEngine.reduce(&state, .nextRound(word))
        GameEngine.reduce(&state, .allReady)
        XCTAssertEqual(state, before)
    }
    func testNextRoundKeepsScoresAndAlternatesOpener() {
        var state = decision()
        GameEngine.reduce(&state, .receiverGuess(.B, "rocket"))
        GameEngine.reduce(&state, .nextRound(WordEntry(signal: "moon", accepted: [], difficulty: 1, theme: "space")))
        XCTAssertEqual(state.roundNumber, 2)
        XCTAssertEqual(state.round?.clueingTeam, .B)
        XCTAssertEqual(state.teams[.B]?.score, 1)
        XCTAssertEqual(state.round?.phase, .roleReveal)
    }
    func testRosterAndSettingsCannotChangeDuringRound() {
        var state = round(); let before = state
        GameEngine.reduce(&state, .removePlayer(state.players[0].id))
        GameEngine.reduce(&state, .setPlayerTeam(state.players[0].id, .B))
        GameEngine.reduce(&state, .setRoundsToWin(4))
        GameEngine.reduce(&state, .upsertPlayer(Player(name: "Late", team: .A)))
        XCTAssertEqual(state, before)
    }
    func testResetRetainsPlayersAndConfigurationButClearsMatch() {
        var state = decision(); state.revision = 42
        let players = state.players, config = state.config
        GameEngine.reduce(&state, .reset)
        XCTAssertEqual(state.status, .lobby)
        XCTAssertEqual(state.players, players)
        XCTAssertEqual(state.config, config)
        XCTAssertEqual(state.revision, 42)
        XCTAssertNil(state.round)
        XCTAssertTrue(state.teams.isEmpty)
        XCTAssertTrue(state.usedSignals.isEmpty)
    }
    func testInvalidCluesDoNotAdvanceTurn() {
        var state = round(); GameEngine.reduce(&state, .allReady)
        let before = state
        for clue in ["", "two words", "rocket", "rockets", "123", String(repeating: "x", count: 41)] {
            GameEngine.reduce(&state, .clueGiven(clue))
            XCTAssertEqual(state, before, clue)
        }
        GameEngine.reduce(&state, .clueGiven("  orbit  "))
        XCTAssertEqual(state.round?.history.last?.clueText, "orbit")
    }
    func testInvalidGuessesDoNotSpendStatic() {
        var state = decision(); let before = state
        for guess in ["", "!!!", String(repeating: "x", count: 81)] {
            GameEngine.reduce(&state, .receiverGuess(.B, guess))
            XCTAssertEqual(state, before)
        }
    }
    func testGuessNormalizationAndAliases() {
        XCTAssertTrue(GuessMatcher.isCorrect(" The Peanut-Butter ", accepted: ["peanut butter"]))
        XCTAssertTrue(GuessMatcher.isCorrect("berries", accepted: ["berry"]))
        XCTAssertTrue(GuessMatcher.isCorrect("space rocket", accepted: ["rocket", "space rocket"]))
        XCTAssertTrue(GuessMatcher.isCorrect("rocker", accepted: ["rocket"]))
        XCTAssertFalse(GuessMatcher.isCorrect("", accepted: ["rocket"]))
        XCTAssertFalse(GuessMatcher.isCorrect("cat", accepted: ["bat"]))
    }
    func testGuestCannotUseHostControlsOrRenameOtherPlayers() {
        let state = lobby(), id = lobby().players[0].id
        XCTAssertFalse(ActionAuthorization.allows(.reset, playerId: id, isHost: true, state: state))
        let own = state.players[0].id
        for action in [GameAction.reset, .allReady, .startRound(word), .setTheme("space"), .removePlayer(own), .upsertPlayer(state.players[0])] {
            XCTAssertFalse(ActionAuthorization.allows(action, playerId: own, isHost: false, state: state))
        }
        XCTAssertTrue(ActionAuthorization.allows(.renamePlayer(own, "New"), playerId: own, isHost: false, state: state))
        XCTAssertFalse(ActionAuthorization.allows(.renamePlayer(state.players[1].id, "New"), playerId: own, isHost: false, state: state))
    }
    func testOnlyActiveRolesMaySubmitEvenOnHost() {
        var state = round(); GameEngine.reduce(&state, .allReady)
        let team = state.teams[.A]!, transmitter = team.transmitterOrder[0]
        for player in state.players {
            XCTAssertEqual(ActionAuthorization.allows(.clueGiven("orbit"), playerId: player.id, isHost: true, state: state), player.id == transmitter)
        }
        GameEngine.reduce(&state, .clueGiven("orbit"))
        for player in state.players {
            XCTAssertEqual(ActionAuthorization.allows(.receiverGuess(.B, "rocket"), playerId: player.id, isHost: false, state: state), player.id == state.teams[.B]?.receiverId)
        }
    }
    func testReceiverSnapshotDoesNotLeakSecretThroughUsedWords() throws {
        let state = round()
        for id in TeamId.allCases {
            let snapshot = state.visible(to: state.teams[id]!.receiverId)
            XCTAssertEqual(snapshot.round?.signal, "")
            XCTAssertEqual(snapshot.round?.acceptedAnswers, [])
            XCTAssertTrue(snapshot.usedSignals.isEmpty)
            let payload = String(data: try JSONEncoder().encode(snapshot), encoding: .utf8)!
            XCTAssertFalse(payload.contains("rocket"))
        }
        XCTAssertEqual(state.round?.signal, "rocket")
    }
    func testTransmitterSnapshotAndRoundEndReveal() {
        var state = decision()
        let id = state.teams[.A]!.transmitterOrder[0]
        XCTAssertEqual(state.visible(to: id).round?.signal, "rocket")
        XCTAssertEqual(state.visible(to: id).round?.acceptedAnswers, [])
        XCTAssertEqual(state.visible(to: "unknown").round?.signal, "")
        GameEngine.reduce(&state, .receiverGuess(.B, "rocket"))
        XCTAssertEqual(state.visible(to: state.teams[.B]!.receiverId).round?.signal, "rocket")
    }
    func testThemeIsTheOnlyWordFilterAndNeverFallsBack() {
        let pack = WordPack(id: "test", name: "Test", words: [word])
        var state = lobby(); state.config.themeId = "food"
        XCTAssertTrue(WordSelection.available(in: pack, state: state).isEmpty)
        state.config.themeId = "space"
        XCTAssertEqual(WordSelection.available(in: pack, state: state), [word])
        state.usedSignals.insert(word.signal)
        XCTAssertTrue(WordSelection.available(in: pack, state: state).isEmpty)
    }
    func testShortOrDuplicatePoolsCannotPromiseACompleteMatch() {
        var config = GameConfig(); config.themeId = "space"; config.roundsToWin = 4
        let duplicates = WordPack(id: "test", name: "Test", words: Array(repeating: word, count: 7))
        XCTAssertFalse(WordSelection.canCompleteMatch(in: duplicates, config: config))
        let unique = (0..<7).map { WordEntry(signal: "word\($0)", accepted: [], difficulty: 1, theme: "space") }
        XCTAssertTrue(WordSelection.canCompleteMatch(in: WordPack(id: "test", name: "Test", words: unique), config: config))
    }
    func testCannotStartWithWordFromAnotherTheme() {
        var state = lobby(); state.config.themeId = "food"
        let before = state
        GameEngine.reduce(&state, .startRound(word))
        XCTAssertEqual(state, before)
    }
    func testThemeChangeAndInputsAreBounded() {
        var state = lobby()
        GameEngine.reduce(&state, .setTheme("food"))
        XCTAssertEqual(state.config.themeId, "food")
        GameEngine.reduce(&state, .setTheme("unknown"))
        XCTAssertEqual(state.config.themeId, "food")
        XCTAssertTrue(InputRules.validRoomCode("AB23"))
        for code in ["ABC", "ABCDE", "AB0O", "abcd", "１２３４"] { XCTAssertFalse(InputRules.validRoomCode(code)) }
        for name in [" ", String(repeating: "a", count: 33), "a\nb"] { XCTAssertFalse(InputRules.validName(name)) }
    }
}
