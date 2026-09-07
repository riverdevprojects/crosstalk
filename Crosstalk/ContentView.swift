import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: GameStore
    var activeTeam: TeamId? { store.activePlayer?.team }

    var body: some View {
        NavigationStack {
            ZStack {
                TeamBackdrop(team: activeTeam)
                ScrollView { screen.padding(20) }
            }
            .foregroundStyle(.white)
            .navigationTitle("Crosstalk")
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

struct TeamBackdrop: View {
    let team: TeamId?
    var body: some View {
        let colors: [Color] = team == .A ? [.blue, .cyan, .black] : team == .B ? [.red, .orange, .black] : [.black, .indigo]
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            Image(systemName: team == .A ? "wave.3.right.circle.fill" : team == .B ? "bolt.circle.fill" : "antenna.radiowaves.left.and.right")
                .font(.system(size: 210)).opacity(0.10).offset(x: 70, y: -140)
        }
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { VStack(spacing: 16) { content }.padding(18).frame(maxWidth: .infinity).background(.ultraThinMaterial.opacity(0.82)).clipShape(RoundedRectangle(cornerRadius: 24)).shadow(radius: 10) }
}

struct TeamBadge: View {
    let team: TeamId
    var body: some View { Text("TEAM \(team.rawValue)").font(.title.bold()).padding(.horizontal, 18).padding(.vertical, 10).background(team == .A ? .blue : .red).clipShape(Capsule()) }
}

struct LobbyView: View {
    @EnvironmentObject var store: GameStore
    @State private var name = ""
    var body: some View { VStack(spacing: 18) {
        Card { Text("Host on one phone. Everyone else joins nearby.").font(.title3.bold()).multilineTextAlignment(.center); Text("Team A is blue waves. Team B is red lightning.").font(.subheadline).opacity(0.9) }
        Card {
            TextField("Your name", text: $name).textFieldStyle(.roundedBorder).foregroundColor(.black).tint(.indigo).colorScheme(.light).font(.title3)
            HStack { Button("Host Game") { guard !name.trimmed.isEmpty else { return }; store.hostGame(name: name) }.buttonStyle(.borderedProminent); Button("Join Game") { guard !name.trimmed.isEmpty else { return }; store.joinGame(name: name) }.buttonStyle(.bordered) }.font(.title2)
            Text(store.network.statusText).font(.caption)
        }
        if let p = store.activePlayer { TeamBadge(team: p.team); Text("You are \(p.name)").font(.headline) }
        TeamsList()
        if store.isHost { Card { Stepper("Best of \(store.state.config.roundsToWin * 2 - 1)", value: $store.state.config.roundsToWin, in: 2...4); Stepper("Statics: \(store.state.config.maxStatics)", value: $store.state.config.maxStatics, in: 2...3); Button("Start Match") { store.startOrNextRound() }.buttonStyle(.borderedProminent).font(.title2).disabled(store.state.players.filter{$0.team == .A}.count < 2 || store.state.players.filter{$0.team == .B}.count < 2) } }
        else { Text("Waiting for host to start…").font(.headline) }
    } }
}

struct TeamsList: View { @EnvironmentObject var store: GameStore; var body: some View { HStack(alignment: .top, spacing: 12) { ForEach(TeamId.allCases, id: \.self) { team in VStack(spacing: 10) { Text("Team \(team.rawValue)").font(.headline); ForEach(store.state.players.filter{$0.team == team}) { p in Text(p.name + (store.activePlayerId == p.id ? "  • YOU" : "")).font(.subheadline.bold()).padding(10).frame(maxWidth: .infinity).background(team == .A ? Color.blue.opacity(0.45) : Color.red.opacity(0.45)).clipShape(RoundedRectangle(cornerRadius: 14)) } }.frame(maxWidth: .infinity) } } } }

struct RoundView: View { @EnvironmentObject var store: GameStore; var body: some View { VStack(spacing: 18) { HUDView(); if let p = store.activePlayer { TeamBadge(team: p.team); Text("You are \(p.name)").font(.headline) }; if let a = store.state.round?.announcement { Text(a).padding().frame(maxWidth: .infinity).background(.orange).clipShape(RoundedRectangle(cornerRadius: 16)) }; switch store.state.round?.phase { case .roleReveal: RoleRevealView(); case .awaitingClue: ClueView(); case .opposingDecision, .owningDecision: DecisionView(); case .roundOver: RoundOverView(); default: EmptyView() } } } }

struct HUDView: View { @EnvironmentObject var store: GameStore; var body: some View { let r = store.state.round; Card { Text("Round \(store.state.roundNumber) • Team \(r?.clueingTeam.rawValue ?? "—") clue").font(.headline); HStack { ForEach(TeamId.allCases, id: \.self) { t in Text("\(t.rawValue): \(store.team(t)?.score ?? 0) pts • Static \(store.team(t)?.statics ?? 0)/\(store.state.config.maxStatics)").font(.caption.bold()).frame(maxWidth: .infinity).padding(8).background(t == .A ? Color.blue.opacity(0.35) : Color.red.opacity(0.35)).clipShape(RoundedRectangle(cornerRadius: 10)) } } } } }

struct RoleRevealView: View { @EnvironmentObject var store: GameStore; var body: some View { Card { if let p = store.activePlayer { if store.isReceiver(p) { Text("YOU ARE THE RECEIVER").font(.largeTitle.bold()).multilineTextAlignment(.center); Text("Do not look at anyone else's phone.") } else { Text("SIGNAL").font(.caption.bold()).opacity(0.8); Text(store.state.round?.signal.uppercased() ?? "").font(.system(size: 46, weight: .black)).minimumScaleFactor(0.5); Text("Your Receiver is \(store.playerName(store.team(p.team)?.receiverId)).") } } else { Text("Waiting for your player…") }; Button("Everyone is Ready") { store.send(.allReady) }.buttonStyle(.borderedProminent).font(.title2).disabled(!store.isHost) } } }

struct ClueView: View {
    @EnvironmentObject var store: GameStore
    @State private var clue = ""
    var body: some View { let active = store.activeTransmitterId(); let isActive = store.activePlayerId == active; Card { if let p = store.activePlayer, !store.isReceiver(p) { Text("Signal: \(store.state.round?.signal.uppercased() ?? "")").font(.title.bold()).minimumScaleFactor(0.6) } else { Text("Receiver Waiting").font(.title.bold()) }; Text("Hint giver: \(store.playerName(active))").font(.title3.bold()); if isActive { TextField("Type your one-word hint", text: $clue).textFieldStyle(.roundedBorder).foregroundColor(.black).tint(.indigo).colorScheme(.light).font(.title2); Button("Submit Hint") { store.send(.clueGiven(clue)); clue = "" }.buttonStyle(.borderedProminent).font(.title2).disabled(clue.trimmed.isEmpty) } else { Text("Only \(store.playerName(active)) can submit the hint.").font(.headline).multilineTextAlignment(.center) }; LastHintsView() } }
}

struct LastHintsView: View { @EnvironmentObject var store: GameStore; var body: some View { if !(store.state.round?.history.isEmpty ?? true) { VStack(alignment: .leading, spacing: 6) { Text("Hint history").font(.headline); ForEach(Array((store.state.round?.history ?? []).enumerated()), id: \.offset) { _, rec in if let clue = rec.clueText { Text("Team \(rec.clueingTeam.rawValue): \(clue)").font(.caption).frame(maxWidth: .infinity, alignment: .leading) } } } } } }

struct DecisionView: View {
    @EnvironmentObject var store: GameStore
    @StateObject private var speech = SpeechRecognizer()
    @State private var guess = ""
    @State private var confirming = false
    var body: some View { let team = store.receiverTeamForDecision(); let receiverId = team.flatMap { store.team($0)?.receiverId }; let canAct = store.activePlayerId == receiverId; Card { Text("Team \(team?.rawValue ?? "—") Receiver").font(.largeTitle.bold()).multilineTextAlignment(.center); Text(canAct ? "Tap the big box and say your answer, or type it." : "Waiting for \(store.playerName(receiverId))…").font(.headline).multilineTextAlignment(.center); Button(action: { if canAct { speech.toggle() } }) { VStack { Image(systemName: speech.isRecording ? "mic.circle.fill" : "mic.circle").font(.system(size: 76)); Text(speech.isRecording ? "Listening… tap to stop" : "Tap to speak guess").font(.title3.bold()) } .padding().frame(maxWidth: .infinity).background(canAct ? Color.white.opacity(0.18) : Color.gray.opacity(0.18)).clipShape(RoundedRectangle(cornerRadius: 22)) }.disabled(!canAct); TextField("Type guess", text: $guess).textFieldStyle(.roundedBorder).foregroundColor(.black).tint(.indigo).colorScheme(.light).font(.title2).disabled(!canAct).onChange(of: speech.text) { guess = $0 }; if let e = speech.errorText { Text(e).font(.caption).foregroundStyle(.yellow) }; HStack { Button("Pass") { if let team { store.send(.receiverPass(team)) }; guess = "" }.buttonStyle(.bordered).disabled(!canAct); Button("Lock Guess") { confirming = true }.buttonStyle(.borderedProminent).disabled(!canAct || guess.trimmed.isEmpty) } }.alert("Lock it in?", isPresented: $confirming) { Button("Cancel", role: .cancel) {}; Button("Submit") { speech.stop(); if let team { store.send(.receiverGuess(team, guess)) }; guess = "" } } message: { Text(guess) } }
}

struct RoundOverView: View { @EnvironmentObject var store: GameStore; var body: some View { Card { Text("Round Over").font(.largeTitle.bold()); Text("Signal: \(store.state.round?.signal ?? "")").font(.title2); Text("Team \(store.state.round?.winner?.rawValue ?? "—") wins by \(store.state.round?.winReason == .lockout ? "lockout" : "correct guess")"); LastHintsView(); Button("Next Round") { store.startOrNextRound() }.buttonStyle(.borderedProminent).disabled(store.state.status == .matchOver || !store.isHost) } } }
struct MatchOverView: View { @EnvironmentObject var store: GameStore; var body: some View { Card { Text("Match Over").font(.largeTitle.bold()); Text("Final — A \(store.team(.A)?.score ?? 0), B \(store.team(.B)?.score ?? 0)").font(.title); Button("New Match") { store.send(.reset) }.buttonStyle(.borderedProminent) } } }

private extension String { var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) } }
