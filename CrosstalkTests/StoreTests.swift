import XCTest
import MultipeerConnectivity
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
        let store = GameStore()
        var changes = 0
        let observer = store.objectWillChange.sink { changes += 1 }
        store.network.statusText = "Changed"
        XCTAssertGreaterThan(changes, 0)
        withExtendedLifetime(observer) {}
    }
    @MainActor func testNoMatchingWordsSurfacesErrorWithoutStarting() {
        let (store, _, _) = fixture()
        store.send(.addPlayer("Third")); store.send(.addPlayer("Fourth"))
        store.send(.setTheme("medieval")); store.send(.setCategory("Food"))
        store.startOrNextRound()
        XCTAssertEqual(store.state.status, .lobby)
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

}
