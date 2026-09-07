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
        Text("Party word game. Split into two teams; one Receiver per team avoids the Signal.").font(.headline).multilineTextAlignment(.center)
        HStack { TextField("Player name", text: $name).textFieldStyle(.roundedBorder).foregroundStyle(.black); Button("Add") { guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }; store.send(.addPlayer(name)); name = "" }.buttonStyle(.borderedProminent) }
        List { ForEach(TeamId.allCases, id: \.self) { team in Section("Team \(team.rawValue)") { ForEach(store.state.players.filter{$0.team == team}) { p in HStack { Text(p.name); Spacer(); if store.activePlayerId == p.id { Text("This phone") } } .listRowBackground(Color.white.opacity(0.12)) } } } }.scrollContentBackground(.hidden)
        HStack { Picker("This phone", selection: $store.activePlayerId) { ForEach(store.state.players) { Text($0.name).tag(Optional($0.id)) } }.pickerStyle(.menu); Spacer() }
        Stepper("Best of \(store.state.config.roundsToWin * 2 - 1)", value: $store.state.config.roundsToWin, in: 2...4)
        Stepper("Statics: \(store.state.config.maxStatics)", value: $store.state.config.maxStatics, in: 2...3)
        Button("Start Match") { store.startOrNextRound() }.buttonStyle(.borderedProminent).font(.title2).disabled(store.state.players.filter{$0.team == .A}.count < 2 || store.state.players.filter{$0.team == .B}.count < 2)
        Text("Minimum 4 players. Native iPhone 8+ build; pass this device or install on each phone as the project grows into networking.").font(.caption).opacity(0.75)
    } }
}

struct RoundView: View {
    @EnvironmentObject var store: GameStore
    var body: some View { VStack(spacing: 18) { HUDView(); if let a = store.state.round?.announcement { Text(a).padding().frame(maxWidth: .infinity).background(.orange).clipShape(RoundedRectangle(cornerRadius: 16)) }
        switch store.state.round?.phase { case .roleReveal: RoleRevealView(); case .awaitingClue: ClueView(); case .opposingDecision, .owningDecision: DecisionView(); case .roundOver: RoundOverView(); default: EmptyView() }
    } }
}

struct HUDView: View { @EnvironmentObject var store: GameStore; var body: some View { let r = store.state.round; VStack(spacing: 8) { Text("Round \(store.state.roundNumber) • Team \(r?.clueingTeam.rawValue ?? "—") clue").font(.headline); HStack { ForEach(TeamId.allCases, id: \.self) { t in Text("Team \(t.rawValue): \(store.team(t)?.score ?? 0) pts • Static \(store.team(t)?.statics ?? 0)/\(store.state.config.maxStatics)").font(.caption) } } } } }

struct RoleRevealView: View { @EnvironmentObject var store: GameStore; var body: some View { VStack(spacing: 22) { Picker("Viewing as", selection: $store.activePlayerId) { ForEach(store.state.players) { Text($0.name).tag(Optional($0.id)) } }.pickerStyle(.menu); if let p = store.activePlayer { if store.isReceiver(p) { Text("You're the Receiver").font(.largeTitle.bold()); Text("Don't look at anyone's phone.") } else { Text(store.state.round?.signal.uppercased() ?? "").font(.system(size: 48, weight: .black)); Text("Your Receiver is \(store.playerName(store.team(p.team)?.receiverId)). Use shared history; the enemy hears every clue.") } }; Button("Everyone is Ready") { store.send(.allReady) }.buttonStyle(.borderedProminent).font(.title2) } } }

struct ClueView: View { @EnvironmentObject var store: GameStore; var body: some View { VStack(spacing: 20) { Text("Signal: \(store.state.round?.signal.uppercased() ?? "")").font(.title.bold()); Text("Active Transmitter: \(store.playerName(store.activeTransmitterId()))").font(.title2); Text("Say exactly one word out loud. No rhymes, spelling, gestures, proper-noun sentences, or part of the Signal.").multilineTextAlignment(.center); Button("I gave my clue") { store.send(.clueGiven) }.buttonStyle(.borderedProminent).font(.title2) } } }

struct DecisionView: View { @EnvironmentObject var store: GameStore; @State private var guess = ""; @State private var confirming = false; var body: some View { let team = store.receiverTeamForDecision(); VStack(spacing: 18) { Text("Team \(team?.rawValue ?? "—") Receiver decides").font(.largeTitle.bold()).multilineTextAlignment(.center); Text("Opposing Receiver always decides first. Guess or pass immediately.").font(.caption); TextField("Type guess", text: $guess).textFieldStyle(.roundedBorder).foregroundStyle(.black).font(.title2); HStack { Button("Pass") { if let team { store.send(.receiverPass(team)) }; guess = "" }.buttonStyle(.bordered); Button("Guess") { confirming = true }.buttonStyle(.borderedProminent).disabled(guess.trimmingCharacters(in: .whitespaces).isEmpty) } }.alert("Lock it in?", isPresented: $confirming) { Button("Cancel", role: .cancel) {}; Button("Submit") { if let team { store.send(.receiverGuess(team, guess)) }; guess = "" } } message: { Text(guess) } } }

struct RoundOverView: View { @EnvironmentObject var store: GameStore; var body: some View { VStack(spacing: 18) { Text("Round Over").font(.largeTitle.bold()); Text("Signal: \(store.state.round?.signal ?? "")").font(.title2); Text("Team \(store.state.round?.winner?.rawValue ?? "—") wins by \(store.state.round?.winReason == .lockout ? "lockout" : "correct guess")"); Button("Next Round") { store.startOrNextRound() }.buttonStyle(.borderedProminent).disabled(store.state.status == .matchOver) } } }
struct MatchOverView: View { @EnvironmentObject var store: GameStore; var body: some View { VStack(spacing: 20) { Text("Match Over").font(.largeTitle.bold()); Text("Final — A \(store.team(.A)?.score ?? 0), B \(store.team(.B)?.score ?? 0)").font(.title); Button("New Match") { store.send(.reset) }.buttonStyle(.borderedProminent) } } }
