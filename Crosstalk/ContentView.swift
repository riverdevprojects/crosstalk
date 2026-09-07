import SwiftUI

struct GameTheme: Identifiable, Equatable {
    let id: String, name: String, symbol: String, receiver: String, transmitter: String, teamAIcon: String, teamBIcon: String
    let aColors: [Color], bColors: [Color]
    static let all = [
        GameTheme(id: "signal", name: "Signal Ops", symbol: "antenna.radiowaves.left.and.right", receiver: "Receiver", transmitter: "Transmitter", teamAIcon: "wave.3.right.circle.fill", teamBIcon: "bolt.circle.fill", aColors: [.blue, .cyan, .black], bColors: [.red, .orange, .black]),
        GameTheme(id: "medieval", name: "Medieval", symbol: "building.columns.fill", receiver: "Hero", transmitter: "Squire", teamAIcon: "flag.fill", teamBIcon: "flag.2.crossed.fill", aColors: [.blue, .purple, .black], bColors: [.red, .brown, .black]),
        GameTheme(id: "space", name: "Space", symbol: "sparkles", receiver: "Captain", transmitter: "Navigator", teamAIcon: "moon.stars.fill", teamBIcon: "sun.max.fill", aColors: [.indigo, .blue, .black], bColors: [.pink, .orange, .black]),
        GameTheme(id: "pirates", name: "Pirates", symbol: "sailboat.fill", receiver: "Captain", transmitter: "Crewmate", teamAIcon: "drop.fill", teamBIcon: "flame.fill", aColors: [.teal, .blue, .black], bColors: [.red, .yellow, .black])
    ]
}

let categories = ["Everything", "Animals", "Food", "Places", "Objects"]

struct ContentView: View {
    @EnvironmentObject var store: GameStore
    var theme: GameTheme { GameTheme.all.first { $0.id == store.state.config.themeId } ?? GameTheme.all[0] }
    var body: some View {
        NavigationStack {
            ZStack { TeamBackdrop(team: store.activePlayer?.team, theme: theme); ScrollView { screen.padding(20) } }
                .foregroundStyle(.white).navigationTitle("Crosstalk")
        }
    }
    @ViewBuilder var screen: some View { switch store.state.status { case .lobby: LobbyView(theme: theme); case .matchOver: MatchOverView(); case .inRound: RoundView(theme: theme) } }
}

struct TeamBackdrop: View {
    let team: TeamId?; let theme: GameTheme
    var body: some View { let colors = team == .A ? theme.aColors : team == .B ? theme.bColors : [.black, .indigo]; ZStack { LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea(); Image(systemName: team == .A ? theme.teamAIcon : team == .B ? theme.teamBIcon : theme.symbol).font(.system(size: 220)).opacity(0.12).offset(x: 70, y: -150) } }
}

struct Card<Content: View>: View { @ViewBuilder var content: Content; var body: some View { VStack(spacing: 16) { content }.padding(18).frame(maxWidth: .infinity).background(.ultraThinMaterial.opacity(0.9)).clipShape(RoundedRectangle(cornerRadius: 26)).shadow(color: .black.opacity(0.25), radius: 12) } }
struct BigButton: ButtonStyle { func makeBody(configuration: Configuration) -> some View { configuration.label.font(.title3.bold()).padding().frame(maxWidth: .infinity).background(configuration.isPressed ? .white.opacity(0.18) : .white.opacity(0.26)).clipShape(RoundedRectangle(cornerRadius: 18)) } }
struct TeamBadge: View { @EnvironmentObject var store: GameStore; let team: TeamId; var body: some View { Text(store.teamName(team).uppercased()).font(.title.bold()).padding(.horizontal, 18).padding(.vertical, 10).background(team == .A ? .blue : .red).clipShape(Capsule()) } }

struct LobbyView: View {
    @EnvironmentObject var store: GameStore
    let theme: GameTheme
    @State private var name = ""
    var body: some View { VStack(spacing: 18) {
        if store.isHost { HostLobby(theme: theme, name: $name) } else { PlayerLobby(theme: theme, name: $name) }
    } }
}

struct HostLobby: View {
    @EnvironmentObject var store: GameStore
    let theme: GameTheme
    @Binding var name: String
    var body: some View { VStack(spacing: 18) {
        Card { Label("HOST CONTROL CENTER", systemImage: "crown.fill").font(.title.bold()); Text("You choose category, team names, settings, and start the match.").multilineTextAlignment(.center) }
        ConnectionCard(name: $name)
        HostSettings(theme: theme)
        TeamsEditor()
        StartCard()
    } }
}

struct PlayerLobby: View {
    @EnvironmentObject var store: GameStore
    let theme: GameTheme
    @Binding var name: String
    var body: some View { VStack(spacing: 18) {
        Card { Image(systemName: theme.symbol).font(.system(size: 54)); Text(theme.name).font(.largeTitle.bold()); Text("Vote for a theme, edit your name, then wait for the host.").multilineTextAlignment(.center) }
        ConnectionCard(name: $name)
        MyNameCard()
        ThemeVoteCard(selected: theme)
        TeamsList(theme: theme)
    } }
}

struct ConnectionCard: View { @EnvironmentObject var store: GameStore; @Binding var name: String; var body: some View { Card { TextField("Your name", text: $name).textFieldStyle(.roundedBorder).foregroundColor(.black).tint(.indigo).colorScheme(.light).font(.title3); HStack { Button("Host") { guard !name.trimmed.isEmpty else { return }; store.hostGame(name: name) }.buttonStyle(.borderedProminent); Button("Join") { guard !name.trimmed.isEmpty else { return }; store.joinGame(name: name) }.buttonStyle(.bordered) }.font(.title2); Text(store.network.statusText).font(.caption) } } }

struct MyNameCard: View { @EnvironmentObject var store: GameStore; @State private var draft = ""; var body: some View { if let p = store.activePlayer { Card { TeamBadge(team: p.team); Text("You are on \(store.teamName(p.team))").font(.headline); TextField("Change your name", text: $draft).textFieldStyle(.roundedBorder).foregroundColor(.black).colorScheme(.light).onAppear { draft = p.name }; Button("Save Name") { store.send(.renamePlayer(p.id, draft)) }.buttonStyle(.borderedProminent).disabled(draft.trimmed.isEmpty) } } } }

struct HostSettings: View { @EnvironmentObject var store: GameStore; let theme: GameTheme; var body: some View { Card { Text("Game Setup").font(.title2.bold()); Picker("Category", selection: Binding(get: { store.state.config.category }, set: { store.send(.setCategory($0)) })) { ForEach(categories, id: \.self) { Text($0).tag($0) } }.pickerStyle(.segmented); Picker("Theme", selection: Binding(get: { store.state.config.themeId }, set: { store.send(.setTheme($0)) })) { ForEach(GameTheme.all) { Text($0.name).tag($0.id) } }.pickerStyle(.menu); ThemeVoteSummary(); Stepper("Best of \(store.state.config.roundsToWin * 2 - 1)", value: Binding(get: { store.state.config.roundsToWin }, set: { store.send(.setRoundsToWin($0)) }), in: 2...4); Stepper("Statics: \(store.state.config.maxStatics)", value: Binding(get: { store.state.config.maxStatics }, set: { store.send(.setMaxStatics($0)) }), in: 2...3) } } }
struct ThemeVoteSummary: View { @EnvironmentObject var store: GameStore; var body: some View { VStack(alignment: .leading) { Text("Theme votes").font(.headline); ForEach(GameTheme.all) { t in Text("\(t.name): \(store.state.themeVotes.values.filter { $0 == t.id }.count)").font(.caption) } }.frame(maxWidth: .infinity, alignment: .leading) } }
struct ThemeVoteCard: View { @EnvironmentObject var store: GameStore; let selected: GameTheme; var body: some View { Card { Text("Vote Theme").font(.title2.bold()); ForEach(GameTheme.all) { t in Button { if let id = store.activePlayerId { store.send(.voteTheme(id, t.id)) } } label: { Label(t.name + (selected.id == t.id ? "  ✓" : ""), systemImage: t.symbol) }.buttonStyle(BigButton()) } } } }

struct TeamsEditor: View { @EnvironmentObject var store: GameStore; @State private var a = ""; @State private var b = ""; var body: some View { Card { Text("Teams").font(.title2.bold()); TextField("Team A name", text: $a).textFieldStyle(.roundedBorder).foregroundColor(.black).colorScheme(.light).onAppear { a = store.teamName(.A) }; TextField("Team B name", text: $b).textFieldStyle(.roundedBorder).foregroundColor(.black).colorScheme(.light).onAppear { b = store.teamName(.B) }; HStack { Button("Save Team Names") { store.send(.setTeamName(.A, a)); store.send(.setTeamName(.B, b)) }.buttonStyle(.borderedProminent); Button("Auto Split") { store.send(.assignTeams) }.buttonStyle(.bordered) }; TeamsList(theme: GameTheme.all.first { $0.id == store.state.config.themeId } ?? GameTheme.all[0], editable: true) } } }
struct StartCard: View { @EnvironmentObject var store: GameStore; var body: some View { Card { Button("START MATCH") { store.startOrNextRound() }.buttonStyle(.borderedProminent).font(.title.bold()).disabled(store.state.players.filter{$0.team == .A}.count < 2 || store.state.players.filter{$0.team == .B}.count < 2); Text("Need at least 2 players per team.").font(.caption).opacity(0.8) } } }

struct TeamsList: View { @EnvironmentObject var store: GameStore; let theme: GameTheme; var editable = false; var body: some View { HStack(alignment: .top, spacing: 12) { ForEach(TeamId.allCases, id: \.self) { team in VStack(spacing: 10) { Label(store.teamName(team), systemImage: team == .A ? theme.teamAIcon : theme.teamBIcon).font(.headline); ForEach(store.state.players.filter{$0.team == team}) { p in PlayerRow(player: p, editable: editable) } }.frame(maxWidth: .infinity).padding(10).background(team == .A ? Color.blue.opacity(0.20) : Color.red.opacity(0.20)).clipShape(RoundedRectangle(cornerRadius: 20)) } } } }
struct PlayerRow: View { @EnvironmentObject var store: GameStore; let player: Player; let editable: Bool; @State private var draft = ""; var body: some View { VStack(spacing: 8) { if editable { TextField("Name", text: $draft).textFieldStyle(.roundedBorder).foregroundColor(.black).colorScheme(.light).onAppear { draft = player.name }; HStack { Button("A") { store.send(.setPlayerTeam(player.id, .A)) }; Button("B") { store.send(.setPlayerTeam(player.id, .B)) }; Button("Save") { store.send(.renamePlayer(player.id, draft)) } }.font(.caption) } else { Text(player.name + (store.activePlayerId == player.id ? " • YOU" : "")).font(.subheadline.bold()) } }.padding(10).frame(maxWidth: .infinity).background(player.team == .A ? Color.blue.opacity(0.45) : Color.red.opacity(0.45)).clipShape(RoundedRectangle(cornerRadius: 14)) } }

struct RoundView: View { @EnvironmentObject var store: GameStore; let theme: GameTheme; var body: some View { VStack(spacing: 18) { HUDView(theme: theme); if let p = store.activePlayer { TeamBadge(team: p.team); Text("You are \(p.name)").font(.headline) }; if let a = store.state.round?.announcement { Text(a).padding().frame(maxWidth: .infinity).background(.orange).clipShape(RoundedRectangle(cornerRadius: 16)) }; switch store.state.round?.phase { case .roleReveal: RoleRevealView(theme: theme); case .awaitingClue: ClueView(theme: theme); case .opposingDecision, .owningDecision: DecisionView(theme: theme); case .roundOver: RoundOverView(); default: EmptyView() } } } }
struct HUDView: View { @EnvironmentObject var store: GameStore; let theme: GameTheme; var body: some View { let r = store.state.round; Card { Text("Round \(store.state.roundNumber) • \(store.teamName(r?.clueingTeam ?? .A)) hint").font(.headline); HStack { ForEach(TeamId.allCases, id: \.self) { t in Text("\(store.teamName(t)): \(store.team(t)?.score ?? 0) • Static \(store.team(t)?.statics ?? 0)/\(store.state.config.maxStatics)").font(.caption.bold()).frame(maxWidth: .infinity).padding(8).background(t == .A ? Color.blue.opacity(0.35) : Color.red.opacity(0.35)).clipShape(RoundedRectangle(cornerRadius: 10)) } } } } }
struct RoleRevealView: View { @EnvironmentObject var store: GameStore; let theme: GameTheme; var body: some View { Card { if let p = store.activePlayer { if store.isReceiver(p) { Text("YOU ARE THE \(theme.receiver.uppercased())").font(.largeTitle.bold()).multilineTextAlignment(.center); Text("Do not look at anyone else's phone.") } else { Text("YOU ARE A \(theme.transmitter.uppercased())").font(.caption.bold()).opacity(0.8); Text(store.state.round?.signal.uppercased() ?? "").font(.system(size: 46, weight: .black)).minimumScaleFactor(0.5); Text("Your \(theme.receiver) is \(store.playerName(store.team(p.team)?.receiverId)).") } } else { Text("Waiting for your player…") }; Button("Everyone is Ready") { store.send(.allReady) }.buttonStyle(.borderedProminent).font(.title2).disabled(!store.isHost) } } }
struct ClueView: View { @EnvironmentObject var store: GameStore; let theme: GameTheme; @State private var clue = ""; var body: some View { let active = store.activeTransmitterId(); let isActive = store.activePlayerId == active; Card { if let p = store.activePlayer, !store.isReceiver(p) { Text("Signal: \(store.state.round?.signal.uppercased() ?? "")").font(.title.bold()).minimumScaleFactor(0.6) } else { Text("\(theme.receiver) Waiting").font(.title.bold()) }; Text("Hint giver: \(store.playerName(active))").font(.title3.bold()); if isActive { TextField("Type your one-word hint", text: $clue).textFieldStyle(.roundedBorder).foregroundColor(.black).tint(.indigo).colorScheme(.light).font(.title2); Button("Submit Hint") { store.send(.clueGiven(clue)); clue = "" }.buttonStyle(.borderedProminent).font(.title2).disabled(clue.trimmed.isEmpty) } else { Text("Only \(store.playerName(active)) can submit the hint.").font(.headline).multilineTextAlignment(.center) }; LastHintsView() } } }
struct LastHintsView: View { @EnvironmentObject var store: GameStore; var body: some View { if !(store.state.round?.history.isEmpty ?? true) { VStack(alignment: .leading, spacing: 6) { Text("Hint history").font(.headline); ForEach(Array((store.state.round?.history ?? []).enumerated()), id: \.offset) { _, rec in if let clue = rec.clueText { Text("\(store.teamName(rec.clueingTeam)): \(clue)").font(.caption).frame(maxWidth: .infinity, alignment: .leading) } } } } } }

struct DecisionView: View { @EnvironmentObject var store: GameStore; let theme: GameTheme; @State private var guess = ""; @State private var confirming = false; var body: some View { let team = store.receiverTeamForDecision(); let receiverId = team.flatMap { store.team($0)?.receiverId }; let canAct = store.activePlayerId == receiverId; Card { if canAct { Text("YOUR TURN TO GUESS").font(.largeTitle.bold()).multilineTextAlignment(.center); Text("\(store.teamName(team ?? .A)) \(theme.receiver)").font(.title3.bold()).padding(.horizontal, 16).padding(.vertical, 8).background(team == .A ? Color.blue.opacity(0.65) : Color.red.opacity(0.65)).clipShape(Capsule()); TextField("Type your guess", text: $guess).textFieldStyle(.roundedBorder).foregroundColor(.black).tint(.indigo).colorScheme(.light).font(.largeTitle); HStack(spacing: 14) { Button("Pass") { if let team { store.send(.receiverPass(team)) }; guess = "" }.buttonStyle(.bordered); Button("Lock Guess") { confirming = true }.buttonStyle(.borderedProminent).disabled(guess.trimmed.isEmpty) }.font(.title2) } else { Image(systemName: "hourglass").font(.system(size: 72)).opacity(0.9); Text("Waiting for the \(theme.receiver)").font(.largeTitle.bold()).multilineTextAlignment(.center); Text("\(store.playerName(receiverId)) is deciding now.").font(.title3.bold()); Text("Guess controls only appear on that player's phone.").font(.subheadline).opacity(0.8) } }.alert("Lock it in?", isPresented: $confirming) { Button("Cancel", role: .cancel) {}; Button("Submit") { if let team { store.send(.receiverGuess(team, guess)) }; guess = "" } } message: { Text(guess) } } }

struct RoundOverView: View { @EnvironmentObject var store: GameStore; var body: some View { Card { Text("Round Over").font(.largeTitle.bold()); Text("Signal: \(store.state.round?.signal ?? "")").font(.title2); Text("\(store.teamName(store.state.round?.winner ?? .A)) wins by \(store.state.round?.winReason == .lockout ? "lockout" : "correct guess")"); LastHintsView(); Button("Next Round") { store.startOrNextRound() }.buttonStyle(.borderedProminent).disabled(store.state.status == .matchOver || !store.isHost) } } }
struct MatchOverView: View { @EnvironmentObject var store: GameStore; var body: some View { Card { Text("Match Over").font(.largeTitle.bold()); Text("Final — \(store.teamName(.A)) \(store.team(.A)?.score ?? 0), \(store.teamName(.B)) \(store.team(.B)?.score ?? 0)").font(.title); Button("New Match") { store.send(.reset) }.buttonStyle(.borderedProminent) } } }
private extension String { var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) } }
