import XCTest
import SwiftUI
import MultipeerConnectivity
import Combine
import UIKit
@testable import Crosstalk

final class StoreTests: XCTestCase {
    @MainActor func fixture() -> (GameStore, MCPeerID, Player) {
        let store = GameStore()
        let host = Player(name: "Host", team: .A)
        store.activePlayerId = host.id
        store.state.players = [host]
        let peer = MCPeerID(displayName: "Guest phone")
        let guest = Player(name: "Guest", team: .B)
        store.receive(.hello(guest), from: peer)
        return (store, peer, guest)
    }
    @MainActor func testPeerBoundToOnePlayerCannotResetOrRenameHost() {
        let (store, peer, guest) = fixture()
        let before = store.state
        store.receive(.action(.renamePlayer(store.activePlayerId!, "Impersonator"), revision: store.state.revision), from: peer)
        store.receive(.action(.reset, revision: store.state.revision), from: peer)
        store.receive(.hello(Player(name: "Second identity", team: .A)), from: peer)
        XCTAssertEqual(store.state, before)
        store.receive(.action(.renamePlayer(guest.id, "Allowed"), revision: store.state.revision), from: peer)
        XCTAssertEqual(store.state.players.first { $0.id == guest.id }?.name, "Allowed")
    }
    @MainActor func testUnregisteredAndStaleActionsAreRejected() {
        let (store, peer, guest) = fixture()
        let revision = store.state.revision
        store.receive(.action(.renamePlayer(guest.id, "First"), revision: revision), from: peer)
        let before = store.state
        store.receive(.action(.renamePlayer(guest.id, "Stale"), revision: revision), from: peer)
        store.receive(.action(.renamePlayer(guest.id, "Unknown"), revision: store.state.revision), from: MCPeerID(displayName: "Unknown"))
        XCTAssertEqual(store.state, before)
    }
    @MainActor func testCannotRegisterWithSomeoneElsesID() {
        let (store, _, guest) = fixture()
        let before = store.state
        store.receive(.hello(guest), from: MCPeerID(displayName: "Impersonator"))
        XCTAssertEqual(store.state, before)
    }
    @MainActor func testDisconnectResetsActiveGameAndRemovesPlayerOnce() {
        let (store, peer, guest) = fixture()
        store.send(.addPlayer("Third")); store.send(.addPlayer("Fourth"))
        store.startOrNextRound()
        XCTAssertEqual(store.state.status, .inRound)
        store.receive(.leave, from: peer)
        XCTAssertEqual(store.state.status, .lobby)
        XCTAssertNil(store.state.round)
        XCTAssertFalse(store.state.players.contains { $0.id == guest.id })
        XCTAssertTrue(store.state.notice?.contains("match was reset") == true)
        let before = store.state
        store.receive(.leave, from: peer)
        XCTAssertEqual(store.state, before)
        store.receive(.hello(guest), from: peer)
        XCTAssertTrue(store.state.players.contains { $0.id == guest.id })
    }
    @MainActor func testMidRoundJoinCannotSeeOrChangeGame() {
        let (store, _, _) = fixture()
        store.send(.addPlayer("Third")); store.send(.addPlayer("Fourth"))
        store.startOrNextRound()
        let before = store.state
        store.receive(.hello(Player(name: "Late", team: .A)), from: MCPeerID(displayName: "Late phone"))
        XCTAssertEqual(store.state, before)
    }
    @MainActor func testNetworkChangesReachStoreObservers() {
        let network = FakeRoomNetwork()
        let store = GameStore(network: network)
        var changes = 0
        let observer = store.objectWillChange.sink { changes += 1 }
        network.statusText = "Changed"
        XCTAssertGreaterThan(changes, 0)
        withExtendedLifetime(observer) {}
    }
    @MainActor func testInsufficientWordsPreventsStartingWithoutResettingPlayers() {
        let pack = WordPack(id: "short", name: "Short", words: [WordEntry(signal: "dragon", accepted: [], difficulty: 1, theme: "medieval")])
        let store = GameStore(pack: pack)
        let host = Player(name: "Host", team: .A)
        store.activePlayerId = host.id
        store.state.players = [host]
        for name in ["Second", "Third", "Fourth"] { store.send(.addPlayer(name)) }
        store.startOrNextRound()
        XCTAssertEqual(store.state.status, .lobby)
        XCTAssertEqual(store.state.players.count, 4)
        XCTAssertNotNil(store.errorMessage)
    }
    @MainActor func testUntrustedSnapshotCannotReplaceHostState() {
        let (store, peer, _) = fixture()
        let before = store.state
        store.receive(.state(GameState()), from: peer)
        XCTAssertEqual(store.state, before)
    }
    @MainActor func testHostRemovalUnbindsGuestAndCannotRemoveHost() {
        let (store, peer, guest) = fixture()
        store.removePlayer(store.activePlayerId!)
        XCTAssertEqual(store.state.players.count, 2)
        store.removePlayer(guest.id)
        XCTAssertEqual(store.state.players.count, 1)
        let before = store.state
        store.receive(.action(.renamePlayer(guest.id, "Removed"), revision: store.state.revision), from: peer)
        XCTAssertEqual(store.state, before)
    }

    @MainActor func testEveryShippedThemeHasDistinctWordsAndBundledArtwork() {
        let pack = WordPackLoader.load()
        XCTAssertEqual(Set(pack.words.map(\.theme)), Set(ThemeDefinition.all.map(\.id)))
        for theme in ThemeDefinition.all {
            var config = GameConfig(); config.themeId = theme.id; config.roundsToWin = 4
            let words = WordSelection.pool(in: pack, config: config)
            XCTAssertGreaterThanOrEqual(words.count, 60, theme.id)
            XCTAssertEqual(Set(words.map { GuessMatcher.normalize($0.signal) }).count, words.count, theme.id)
            XCTAssertTrue(WordSelection.canCompleteMatch(in: pack, config: config), theme.id)
            XCTAssertNotNil(UIImage(named: theme.background), theme.background)
        }
    }

    @MainActor func testEveryThemeCanFinishASevenRoundMatchWithoutRepeats() {
        let pack = WordPackLoader.load()
        for theme in ThemeDefinition.all {
            var state = GameState()
            state.config.themeId = theme.id; state.config.roundsToWin = 4
            for name in ["Alex", "Blair", "Casey", "Drew"] { GameEngine.reduce(&state, .addPlayer(name)) }
            for index in 0..<7 {
                guard let word = WordSelection.available(in: pack, state: state).first else {
                    return XCTFail("Exhausted \(theme.id) in round \(index + 1)")
                }
                GameEngine.reduce(&state, index == 0 ? .startRound(word) : .nextRound(word))
                GameEngine.reduce(&state, .allReady)
                GameEngine.reduce(&state, .clueGiven("zzqhint"))
                let clueing = state.round!.clueingTeam
                GameEngine.reduce(&state, .receiverPass(clueing == .A ? .B : .A))
                GameEngine.reduce(&state, .receiverGuess(clueing, word.signal))
            }
            XCTAssertEqual(state.status, .matchOver, theme.id)
            XCTAssertEqual(state.usedSignals.count, 7, theme.id)
            XCTAssertEqual(state.teams[.A]?.score, 4, theme.id)
            XCTAssertEqual(state.teams[.B]?.score, 3, theme.id)
        }
    }

    @MainActor func networkFixture() -> (GameStore, FakeRoomNetwork, MCPeerID, Player) {
        let network = FakeRoomNetwork()
        network.mode = .hosting
        let peer = MCPeerID(displayName: "Guest")
        network.connectedPeers = [peer]
        let store = GameStore(network: network)
        let host = Player(name: "Host", team: .A)
        store.activePlayerId = host.id
        store.state.players = [host]
        let guest = Player(name: "Guest", team: .B)
        store.receive(.hello(guest), from: peer)
        return (store, network, peer, guest)
    }

    @MainActor func testFailedSnapshotRetriesLatestStateAndOnlyMatchingAcknowledgementClearsIt() {
        let (store, network, peer, guest) = networkFixture()
        store.receive(.acknowledge(revision: store.state.revision), from: peer)
        network.succeeds = false
        store.send(.renamePlayer(guest.id, "New name"))
        XCTAssertNotNil(store.syncMessage)
        XCTAssertNil(network.connectionError)
        let failedRevision = store.state.revision
        store.send(.setTheme("food"))
        network.succeeds = true
        network.sent = []
        store.retryPendingSnapshots()
        guard case .state(let snapshot) = network.sent.last?.0 else { return XCTFail("Expected snapshot retry") }
        XCTAssertEqual(snapshot.config.themeId, "food")
        XCTAssertEqual(snapshot.revision, store.state.revision)
        store.receive(.acknowledge(revision: failedRevision), from: peer)
        XCTAssertNotNil(store.syncMessage)
        store.receive(.acknowledge(revision: store.state.revision), from: peer)
        XCTAssertNil(store.syncMessage)
        network.sent = []
        store.retryPendingSnapshots()
        XCTAssertTrue(network.sent.isEmpty)
        store.leaveRoom()
    }

    @MainActor func testResyncIsRegisteredAndRedactsReceiverSecrets() {
        let (store, network, peer, guest) = networkFixture()
        store.send(.addPlayer("Third")); store.send(.addPlayer("Fourth"))
        store.startOrNextRound()
        store.state.teams[guest.team]?.receiverId = guest.id
        network.sent = []
        store.receive(.requestState, from: MCPeerID(displayName: "Unknown"))
        XCTAssertTrue(network.sent.isEmpty)
        store.receive(.requestState, from: peer)
        guard case .state(let snapshot) = network.sent.last?.0 else { return XCTFail("Expected snapshot") }
        XCTAssertEqual(snapshot.round?.signal, "")
        XCTAssertEqual(snapshot.round?.acceptedAnswers, [])
        XCTAssertTrue(snapshot.usedSignals.isEmpty)
        store.leaveRoom()
    }

    @MainActor func testGuestAcceptsHostSnapshotAndAcknowledgesWithoutRollingBack() {
        let network = FakeRoomNetwork(); network.mode = .joining
        let hostPeer = MCPeerID(displayName: "Host")
        network.hostPeer = hostPeer; network.connectedPeers = [hostPeer]
        let store = GameStore(network: network)
        let guest = Player(name: "Guest", team: .A)
        store.activePlayerId = guest.id
        var snapshot = GameState(players: [guest]); snapshot.revision = 5; snapshot.config.themeId = "city"
        store.receive(.state(snapshot), from: MCPeerID(displayName: "Stranger"))
        XCTAssertEqual(store.state.revision, 0)
        store.receive(.state(snapshot), from: hostPeer)
        XCTAssertEqual(store.state.config.themeId, "city")
        guard case .acknowledge(let revision) = network.sent.last?.0 else { return XCTFail("Expected acknowledgement") }
        XCTAssertEqual(revision, 5)
        snapshot.revision = 4; snapshot.config.themeId = "food"
        store.receive(.state(snapshot), from: hostPeer)
        XCTAssertEqual(store.state.config.themeId, "city")
        // Duplicate snapshots must still be acknowledged if an earlier receipt was lost.
        network.sent = []
        store.receive(.state(store.state), from: hostPeer)
        XCTAssertEqual(network.sent.count, 1)
    }

    @MainActor func testGuestSendFailurePreservesGameAndDoesNotReplayActionOnResync() {
        let network = FakeRoomNetwork(); network.mode = .joining; network.succeeds = false
        let store = GameStore(network: network)
        let guest = Player(name: "Guest", team: .A)
        store.activePlayerId = guest.id; store.state.players = [guest]
        let before = store.state
        XCTAssertFalse(store.send(.renamePlayer(guest.id, "Changed")))
        XCTAssertEqual(store.state, before)
        XCTAssertNotNil(store.syncMessage)
        XCTAssertNil(network.connectionError)
        network.succeeds = true; network.sent = []
        store.syncGame()
        XCTAssertEqual(network.sent.count, 1)
        guard case .requestState = network.sent[0].0 else { return XCTFail("Must not replay an action") }
    }

    @MainActor func testRetryBudgetStopsAndManualSyncRestartsDelivery() {
        let (store, network, peer, _) = networkFixture()
        for _ in 0..<8 { store.retryPendingSnapshots() }
        XCTAssertTrue(store.syncMessage?.contains("Sync game") == true)
        network.sent = []
        store.syncGame()
        XCTAssertFalse(network.sent.isEmpty)
        store.receive(.acknowledge(revision: store.state.revision), from: peer)
        XCTAssertNil(store.syncMessage)
        store.leaveRoom()
        network.sent = []
        store.retryPendingSnapshots()
        XCTAssertTrue(network.sent.isEmpty)
    }

}


@MainActor
final class FakeRoomNetwork: RoomNetwork {
    @Published var mode: NetworkMode = .offline
    @Published var connectedNames: [String] = []
    @Published var statusText = "Test network"
    @Published var roomCode = "ABCD"
    @Published var connectionError: String?
    var connectedPeers: [MCPeerID] = []
    var hostPeer: MCPeerID?
    var succeeds = true
    var sent: [(NetworkMessage, MCPeerID?)] = []
    func isHostPeer(_ peer: MCPeerID) -> Bool { peer == hostPeer }
    func configure(onMessage: @escaping (NetworkMessage, MCPeerID) -> Void, onDisconnect: @escaping (MCPeerID) -> Void) {}
    func host(code: String) { mode = .hosting; roomCode = code }
    func join(player: Player, code: String) { mode = .joining; roomCode = code }
    func joined() { connectionError = nil }
    func failJoin(_ message: String) { connectionError = message }
    func stop() { mode = .offline; connectedPeers = [] }
    @discardableResult func send(_ message: NetworkMessage, to peer: MCPeerID?) -> Bool {
        sent.append((message, peer))
        return succeeds
    }
}

// Visual review artifacts accompany the behavioral tests in the xcresult bundle.
// These use the real views and asset catalog, with a deterministic local game.
final class ScreenReviewTests: XCTestCase {
    @MainActor func capture<V: View>(_ view: V, name: String, width: CGFloat = 390, height: CGFloat = 844,
                                     textSize: DynamicTypeSize = .large, scrollToBottom: Bool = false) async throws {
        let controller = UIHostingController(rootView: view
            .environment(\.dynamicTypeSize, textSize)
            .transaction { $0.disablesAnimations = true })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: height))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        controller.view.frame = window.bounds
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 500_000_000)
        if scrollToBottom {
            func scrollView(in view: UIView) -> UIScrollView? {
                if let scroll = view as? UIScrollView { return scroll }
                return view.subviews.compactMap { scrollView(in: $0) }.first
            }
            let scroll = try XCTUnwrap(scrollView(in: controller.view))
            // Lazy grids settle their content height after newly visible rows are laid out.
            for _ in 0..<3 {
                let bottom = max(-scroll.adjustedContentInset.top, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
                scroll.setContentOffset(CGPoint(x: 0, y: bottom), animated: false)
                try await Task.sleep(nanoseconds: 100_000_000)
            }
        }
        let renderer = UIGraphicsImageRenderer(size: window.bounds.size)
        let image = renderer.image { _ in controller.view.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = XCTAttachment.Lifetime.keepAlways
        add(attachment)
        XCTAssertGreaterThan(image.size.width, 0)
    }

    @MainActor func testThemePickerAndAllWorldBackgrounds() async throws {
        let store = GameStore(network: FakeRoomNetwork())
        for theme in GameTheme.all {
            store.state.config.themeId = theme.id
            try await capture(ZStack {
                PartyBackground(theme: theme)
                PartyScroll {
                    LogoHeader(subtitle: theme.name.uppercased())
                    Spacer().frame(height: 130)
                    GamePanel {
                        Text(theme.name).font(.largeTitle.bold())
                        Text(theme.definition.description)
                        Text("70 words • Best of seven").font(.subheadline)
                    }
                }
            }.environmentObject(store), name: "world-\(theme.id)")
        }
        try await capture(ZStack {
            PartyBackground(theme: GameTheme.all[0])
            PartyScroll { HostSettings(theme: GameTheme.all[0]) }
        }.environmentObject(store), name: "theme-picker-small", width: 375, height: 667)
        try await capture(ZStack {
            PartyBackground(theme: GameTheme.all[0])
            PartyScroll { HostSettings(theme: GameTheme.all[0]) }
        }.environmentObject(store), name: "theme-picker-accessibility", width: 375, height: 667, textSize: .accessibility5, scrollToBottom: true)
    }

    @MainActor func testFinalMatchRecapAndDecisionAtLargeText() async throws {
        let store = GameStore(network: FakeRoomNetwork())
        let host = Player(name: "Alex", team: .A)
        store.activePlayerId = host.id
        store.state.players = [host, Player(name: "Blair", team: .B), Player(name: "Casey", team: .A), Player(name: "Drew", team: .B)]
        store.startOrNextRound()
        store.state.teams[.A]?.receiverId = host.id
        store.state.round?.phase = .owningDecision
        store.state.round?.clueingTeam = .A
        store.state.round?.history = [TurnRecord(clueingTeam: .A, transmitterId: store.state.players[2].id, clueText: "enchanted", opposingAction: GuessAction(guess: nil, correct: false))]
        try await capture(ZStack {
            PartyBackground(theme: GameTheme.all[0])
            PartyScroll { DecisionView(theme: GameTheme.all[0]) }
        }.environmentObject(store), name: "decision-accessibility", width: 375, height: 667, textSize: .accessibility5, scrollToBottom: true)
        store.state.teams[.A]?.score = 3
        store.state.round?.signal = "dragon"
        store.state.round?.phase = .roundOver
        store.state.round?.winner = .A
        store.state.round?.winReason = .correctGuess
        store.state.round?.history[0].owningAction = GuessAction(guess: "dragon", correct: true)
        store.state.status = .matchOver
        try await capture(ContentView().environmentObject(store), name: "match-recap-small", width: 375, height: 667)
        try await capture(ContentView().environmentObject(store), name: "match-recap-accessibility", width: 375, height: 667, textSize: .accessibility5, scrollToBottom: true)
    }
}
