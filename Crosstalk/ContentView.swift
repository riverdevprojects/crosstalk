import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: GameStore
    var body: some View {
        NavigationStack {
            ZStack { LinearGradient(colors: [.black, .indigo], startPoint: .top, endPoint: .bottom).ignoresSafeArea(); screen.padding() }
                .foregroundStyle(.white).navigationTitle("Crosstalk")
        }
    }
    @ViewBuilder var screen: some View {
        switch store.state.status {
        case .lobby: LobbyView()
        case .matchOver: MatchOverView()
        case .inRound: RoundView()
        }
    }
}

struct LobbyView: View {
    @EnvironmentObject var store: GameStore
    @State private var name = ""
    var body: some View { VStack(spacing: 18) {
        Text("Party word game. One phone hosts; everyone else joins nearby over Bluetooth/local Wi‑Fi.").font(.headline).multilineTextAlignment(.center)
        TextField("Your name", text: $name).textFieldStyle(.roundedBorder).foregroundColor(.black).tint(.indigo).colorScheme(.light).font(.title3)
        HStack {
            Button("Host") { guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }; store.hostGame(name: name) }.buttonStyle(.borderedProminent)
            Button("Join") { guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }; store.joinGame(name: name) }.buttonStyle(.bordered)
        }.font(.title2)
        Text(store.network.statusText).font(.caption)
        if !store.network.connectedNames.isEmpty { Text("Peers: \(store.network.connectedNames.joined(separator: ", "))").font(.caption2) }
        ScrollView { VStack(spacing: 12) { ForEach(TeamId.allCases, id: \.self) { team in VStack(alignment: .leading, spacing: 8) { Text("Team \(team.rawValue)").font(.headline); ForEach(store.state.players.filter{$0.team == team}) { p in HStack { Text(p.name).foregroundStyle(.white); Spacer(); if store.activePlayerId == p.id { Text("This phone").font(.caption).foregroundStyle(.mint) } }.padding().background(Color.white.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 12)) } } } } }
        if store.isHost {
            Stepper("Best of \(store.state.config.roundsToWin * 2 - 1)", value: $store.state.config.roundsToWin, in: 2...4)
            Stepper("Statics: \(store.state.config.maxStatics)", value: $store.state.config.maxStatics, in: 2...3)
            Button("Start Match") { store.startOrNextRound() }.buttonStyle(.borderedProminent).font(.title2).disabled(store.state.players.filter{$0.team == .A}.count < 2 || store.state.players.filter{$0.team == .B}.count < 2)
        } else { Text("Waiting for host to start…").opacity(0.8) }
        Text("Minimum 4 players. Keep Crosstalk open; the app prevents auto-lock while running.").font(.caption).opacity(0.75)
    } }
}

struct RoundView: View {
    @EnvironmentObject var store: GameStore
    var body: some View { VStack(spacing: 18) { HUDView(); if let a = store.state.round?.announcement { Text(a).padding().frame(maxWidth: .infinity).background(.orange).clipShape(RoundedRectangle(cornerRadius: 16)) }
        switch store.state.round?.phase { case .roleReveal: RoleRevealView(); case .awaitingClue: ClueView(); case .opposingDecision, .owningDecision: DecisionView(); case .roundOver: RoundOverView(); default: EmptyView() }
    } }
}

struct HUDView: View { @EnvironmentObject var store: GameStore; var body: some View { let r = store.state.round; VStack(spacing: 8) { Text("Round \(store.state.roundNumber) • Team \(r?.clueingTeam.rawValue ?? "—") clue").font(.headline); HStack { ForEach(TeamId.allCases, id: \.self) { t in Text("Team \(t.rawValue): \(store.team(t)?.score ?? 0) pts • Static \(store.team(t)?.statics ?? 0)/\(store.state.config.maxStatics)").font(.caption) } } } } }

struct RoleRevealView: View { @EnvironmentObject var store: GameStore; var body: some View { VStack(spacing: 22) { if let p = store.activePlayer { Text("Playing as \(p.name) • Team \(p.team.rawValue)").font(.headline); if store.isReceiver(p) { Text("You're the Receiver").font(.largeTitle.bold()); Text("Don't look at anyone's phone.") } else { Text(store.state.round?.signal.uppercased() ?? "").font(.system(size: 48, weight: .black)); Text("Your Receiver is \(store.playerName(store.team(p.team)?.receiverId)). Use shared history; the enemy hears every clue.") } } else { Text("Waiting for your player…") }; Button("Everyone is Ready") { store.send(.allReady) }.buttonStyle(.borderedProminent).font(.title2).disabled(!store.isHost) } } }

struct ClueView: View { @EnvironmentObject var store: GameStore; var body: some View { let active = store.activeTransmitterId(); VStack(spacing: 20) { if let p = store.activePlayer, !store.isReceiver(p) { Text("Signal: \(store.state.round?.signal.uppercased() ?? "")").font(.title.bold()) } else { Text("Receiver waiting").font(.title.bold()) }; Text("Active Transmitter: \(store.playerName(active))").font(.title2); Text("Say exactly one word out loud. No rhymes, spelling, gestures, proper-noun sentences, or part of the Signal.").multilineTextAlignment(.center); Button("I gave my clue") { store.send(.clueGiven) }.buttonStyle(.borderedProminent).font(.title2).disabled(store.activePlayerId != active) } } }

struct DecisionView: View { @EnvironmentObject var store: GameStore; @State private var guess = ""; @State private var confirming = false; var body: some View { let team = store.receiverTeamForDecision(); let receiverId = team.flatMap { store.team($0)?.receiverId }; let canAct = store.activePlayerId == receiverId; VStack(spacing: 18) { Text("Team \(team?.rawValue ?? "—") Receiver decides").font(.largeTitle.bold()).multilineTextAlignment(.center); Text(canAct ? "Guess or pass immediately." : "Waiting for \(store.playerName(receiverId))…").font(.caption); TextField("Type guess", text: $guess).textFieldStyle(.roundedBorder).foregroundColor(.black).tint(.indigo).colorScheme(.light).font(.title2).disabled(!canAct); HStack { Button("Pass") { if let team { store.send(.receiverPass(team)) }; guess = "" }.buttonStyle(.bordered).disabled(!canAct); Button("Guess") { confirming = true }.buttonStyle(.borderedProminent).disabled(!canAct || guess.trimmingCharacters(in: .whitespaces).isEmpty) } }.alert("Lock it in?", isPresented: $confirming) { Button("Cancel", role: .cancel) {}; Button("Submit") { if let team { store.send(.receiverGuess(team, guess)) }; guess = "" } } message: { Text(guess) } } }

struct RoundOverView: View { @EnvironmentObject var store: GameStore; var body: some View { VStack(spacing: 18) { Text("Round Over").font(.largeTitle.bold()); Text("Signal: \(store.state.round?.signal ?? "")").font(.title2); Text("Team \(store.state.round?.winner?.rawValue ?? "—") wins by \(store.state.round?.winReason == .lockout ? "lockout" : "correct guess")"); Button("Next Round") { store.startOrNextRound() }.buttonStyle(.borderedProminent).disabled(store.state.status == .matchOver || !store.isHost) } } }
struct MatchOverView: View { @EnvironmentObject var store: GameStore; var body: some View { VStack(spacing: 20) { Text("Match Over").font(.largeTitle.bold()); Text("Final — A \(store.team(.A)?.score ?? 0), B \(store.team(.B)?.score ?? 0)").font(.title); Button("New Match") { store.send(.reset) }.buttonStyle(.borderedProminent) } } }
