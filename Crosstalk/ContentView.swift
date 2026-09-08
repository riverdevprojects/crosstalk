import SwiftUI

// MARK: - Themes (unchanged data, refreshed party palette)

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
let categoryIcons: [String: String] = ["Everything": "square.grid.2x2.fill", "Animals": "pawprint.fill", "Food": "fork.knife", "Places": "map.fill", "Objects": "cube.fill"]

// MARK: - Party design system

enum CT {
    // Background
    static let bgTop = Color(red: 0.42, green: 0.16, blue: 0.86)     // deep purple
    static let bgMid = Color(red: 0.78, green: 0.17, blue: 0.74)     // magenta
    static let bgBot = Color(red: 1.00, green: 0.38, blue: 0.66)     // pink

    // Panel + ink
    static let panel = Color.white
    static let ink = Color(red: 0.20, green: 0.12, blue: 0.34)       // dark purple ink
    static let inkSoft = Color(red: 0.42, green: 0.36, blue: 0.55)

    // Accents
    static let purple = Color(red: 0.55, green: 0.24, blue: 0.95)
    static let magenta = Color(red: 0.90, green: 0.20, blue: 0.66)
    static let pink = Color(red: 1.00, green: 0.40, blue: 0.66)
    static let gold = Color(red: 1.00, green: 0.78, blue: 0.20)
    static let orange = Color(red: 1.00, green: 0.52, blue: 0.20)
    static let green = Color(red: 0.28, green: 0.82, blue: 0.45)
    static let cyan = Color(red: 0.25, green: 0.78, blue: 0.95)

    // Team identity
    static let teamA: [Color] = [Color(red: 0.24, green: 0.62, blue: 1.0), Color(red: 0.18, green: 0.82, blue: 0.92)]
    static let teamB: [Color] = [Color(red: 1.0, green: 0.36, blue: 0.62), Color(red: 1.0, green: 0.52, blue: 0.24)]
    static func team(_ t: TeamId) -> [Color] { t == .A ? teamA : teamB }

    static func font(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font { .system(size: size, weight: weight, design: .rounded) }
}

// MARK: - Root

struct ContentView: View {
    @EnvironmentObject var store: GameStore
    var theme: GameTheme { GameTheme.all.first { $0.id == store.state.config.themeId } ?? GameTheme.all[0] }
    var body: some View {
        ZStack {
            PartyBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    screen.padding(.horizontal, 18).padding(.bottom, 32)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .tint(CT.magenta)
    }
    @ViewBuilder var screen: some View {
        switch store.state.status {
        case .lobby: LobbyView(theme: theme)
        case .matchOver: MatchOverView()
        case .inRound: RoundView(theme: theme)
        }
    }
}

// MARK: - Animated background

struct PartyBackground: View {
    @State private var float = false
    var body: some View {
        ZStack {
            LinearGradient(colors: [CT.bgTop, CT.bgMid, CT.bgBot], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            // soft glow blobs
            Circle().fill(Color.white.opacity(0.16)).frame(width: 320).blur(radius: 30)
                .offset(x: -130, y: float ? -320 : -290)
            Circle().fill(CT.gold.opacity(0.22)).frame(width: 240).blur(radius: 26)
                .offset(x: 150, y: float ? 300 : 340)
            Circle().fill(CT.cyan.opacity(0.18)).frame(width: 200).blur(radius: 24)
                .offset(x: 140, y: float ? -180 : -150)
            // decorative party shapes
            decor("music.note", size: 40, x: -140, y: -120, rot: -18, opacity: 0.18)
            decor("star.fill", size: 30, x: 150, y: -60, rot: 12, opacity: 0.22)
            decor("sparkles", size: 46, x: -120, y: 260, rot: 0, opacity: 0.20)
            decor("music.note", size: 28, x: 130, y: 150, rot: 20, opacity: 0.16)
            decor("circle.fill", size: 16, x: -60, y: -300, rot: 0, opacity: 0.22)
            decor("star.fill", size: 18, x: -160, y: 60, rot: -10, opacity: 0.18)
        }
        .onAppear { withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) { float = true } }
    }
    func decor(_ symbol: String, size: CGFloat, x: CGFloat, y: CGFloat, rot: Double, opacity: Double) -> some View {
        Image(systemName: symbol)
            .font(.system(size: size, weight: .black))
            .foregroundStyle(.white.opacity(opacity))
            .rotationEffect(.degrees(rot))
            .offset(x: x, y: float ? y - 14 : y + 14)
    }
}

// MARK: - Building blocks

/// Opaque white game panel with a colored offset shadow and gentle entrance.
struct GamePanel<Content: View>: View {
    var accent: Color = CT.purple
    @ViewBuilder var content: Content
    @State private var appeared = false
    var body: some View {
        VStack(spacing: 16) { content }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(CT.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(accent.opacity(0.25), lineWidth: 2)
            )
            .shadow(color: accent.opacity(0.45), radius: 0, x: 0, y: 8)
            .shadow(color: Color.black.opacity(0.20), radius: 16, x: 0, y: 10)
            .foregroundStyle(CT.ink)
            .scaleEffect(appeared ? 1 : 0.94)
            .opacity(appeared ? 1 : 0)
            .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appeared = true } }
    }
}

/// Uppercase section header used inside panels.
struct SectionLabel: View {
    let text: String
    var icon: String? = nil
    var color: Color = CT.magenta
    var body: some View {
        HStack(spacing: 8) {
            if let icon { Image(systemName: icon) }
            Text(text.uppercased())
        }
        .font(CT.font(15, .black))
        .foregroundStyle(color)
        .kerning(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Chunky game button with depth + press animation.
struct PartyButton: ButtonStyle {
    var fill: [Color]
    var fg: Color = .white
    var big: Bool = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(CT.font(big ? 24 : 18, .heavy))
            .foregroundColor(fg)
            .kerning(0.5)
            .padding(.vertical, big ? 20 : 15)
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: fill, startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.35), lineWidth: 1.5)
            )
            .shadow(color: (fill.last ?? .black).opacity(0.55), radius: pressed ? 2 : 9, x: 0, y: pressed ? 1 : 6)
            .offset(y: pressed ? 3 : 0)
            .scaleEffect(pressed ? 0.97 : 1)
            .opacity(enabled ? 1 : 0.45)
            .grayscale(enabled ? 0 : 0.4)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: pressed)
    }
}

extension PartyButton {
    static var primary: PartyButton { PartyButton(fill: [CT.magenta, CT.pink]) }
    static var go: PartyButton { PartyButton(fill: [CT.green, Color(red: 0.16, green: 0.68, blue: 0.42)]) }
    static var gold: PartyButton { PartyButton(fill: [CT.gold, CT.orange], fg: CT.ink) }
    static var secondary: PartyButton { PartyButton(fill: [Color(white: 0.97), Color(white: 0.90)], fg: CT.ink) }
    static func team(_ t: TeamId) -> PartyButton { PartyButton(fill: CT.team(t)) }
}

/// Big rounded input field.
struct GameField: View {
    let placeholder: String
    @Binding var text: String
    var big: Bool = false
    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundColor(CT.inkSoft.opacity(0.7)))
            .font(CT.font(big ? 30 : 20, .bold))
            .foregroundColor(CT.ink)
            .tint(CT.magenta)
            .colorScheme(.light)
            .multilineTextAlignment(.leading)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(white: 0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(CT.purple.opacity(0.25), lineWidth: 2)
            )
    }
}

/// Connection status indicator.
struct StatusPill: View {
    let connected: Bool
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(connected ? CT.green : Color(red: 0.85, green: 0.30, blue: 0.42))
                .frame(width: 12, height: 12)
                .shadow(color: (connected ? CT.green : .red).opacity(0.7), radius: 4)
            Text(text.uppercased())
                .font(CT.font(13, .bold))
                .foregroundStyle(CT.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 8).padding(.horizontal, 14)
        .background(Capsule().fill(connected ? CT.green.opacity(0.14) : Color(red: 0.98, green: 0.90, blue: 0.92)))
        .overlay(Capsule().stroke((connected ? CT.green : Color(red: 0.85, green: 0.30, blue: 0.42)).opacity(0.4), lineWidth: 1.5))
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: connected)
    }
}

/// Tactile [-] N [+] control.
struct GameStepper: View {
    let label: String
    let icon: String
    let display: String
    var accent: Color = CT.purple
    let canDown: Bool, canUp: Bool
    let onDown: () -> Void, onUp: () -> Void
    var body: some View {
        VStack(spacing: 10) {
            SectionLabel(text: label, icon: icon, color: accent)
            HStack(spacing: 14) {
                roundBtn("minus", enabled: canDown, action: onDown)
                Text(display)
                    .font(CT.font(30, .black))
                    .foregroundStyle(CT.ink)
                    .frame(maxWidth: .infinity)
                    .contentTransition(.numericText())
                roundBtn("plus", enabled: canUp, action: onUp)
            }
        }
    }
    func roundBtn(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { action() }
        } label: {
            Image(systemName: symbol).font(CT.font(20, .black))
        }
        .buttonStyle(PartyButton(fill: enabled ? [accent, accent.opacity(0.8)] : [Color(white: 0.85)], fg: .white))
        .frame(width: 56)
        .disabled(!enabled)
    }
}

/// Team badge pill.
struct TeamBadge: View {
    @EnvironmentObject var store: GameStore
    let team: TeamId
    var body: some View {
        Text(store.teamName(team).uppercased())
            .font(CT.font(22, .black))
            .foregroundStyle(.white)
            .padding(.horizontal, 20).padding(.vertical, 10)
            .background(Capsule().fill(LinearGradient(colors: CT.team(team), startPoint: .top, endPoint: .bottom)))
            .shadow(color: CT.team(team).last!.opacity(0.5), radius: 6, y: 3)
    }
}

// MARK: - Logo header

struct LogoHeader: View {
    var subtitle: String = "THE ULTIMATE PARTY GAME"
    @State private var wiggle = false
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(LinearGradient(colors: [CT.gold, CT.orange], startPoint: .top, endPoint: .bottom))
                        .frame(width: 56, height: 56)
                        .shadow(color: CT.orange.opacity(0.6), radius: 8, y: 4)
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 26, weight: .black))
                        .foregroundStyle(.white)
                }
                .rotationEffect(.degrees(wiggle ? -6 : 6))
                Text("CROSSTALK")
                    .font(CT.font(40, .black))
                    .foregroundStyle(.white)
                    .kerning(1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .shadow(color: CT.bgTop.opacity(0.6), radius: 0, x: 0, y: 3)
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
            }
            Text(subtitle)
                .font(CT.font(14, .bold))
                .foregroundStyle(.white.opacity(0.92))
                .kerning(2)
                .padding(.vertical, 5).padding(.horizontal, 14)
                .background(Capsule().fill(.white.opacity(0.18)))
        }
        .padding(.top, 8)
        .onAppear { withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { wiggle = true } }
    }
}

// MARK: - Lobby

struct LobbyView: View {
    @EnvironmentObject var store: GameStore
    let theme: GameTheme
    @State private var name = ""
    var body: some View {
        VStack(spacing: 20) {
            LogoHeader()
            if store.isHost { HostLobby(theme: theme, name: $name) } else { PlayerLobby(theme: theme, name: $name) }
        }
    }
}

struct HostLobby: View {
    @EnvironmentObject var store: GameStore
    let theme: GameTheme
    @Binding var name: String
    var body: some View {
        VStack(spacing: 20) {
            GamePanel(accent: CT.gold) {
                SectionLabel(text: "Host Control Center", icon: "crown.fill", color: CT.orange)
                Text("You connect the room, randomize captains & teams, and start. Captains choose the category.")
                    .font(CT.font(15, .medium)).foregroundStyle(CT.inkSoft).multilineTextAlignment(.center)
            }
            ConnectionCard(name: $name)
            HostSettings(theme: theme)
            CaptainCategoryCard(theme: theme)
            TeamsEditor()
            StartCard()
        }
    }
}

struct PlayerLobby: View {
    @EnvironmentObject var store: GameStore
    let theme: GameTheme
    @Binding var name: String
    var body: some View {
        VStack(spacing: 20) {
            GamePanel(accent: CT.purple) {
                Image(systemName: theme.symbol)
                    .font(.system(size: 46, weight: .black))
                    .foregroundStyle(LinearGradient(colors: [CT.purple, CT.magenta], startPoint: .top, endPoint: .bottom))
                Text(theme.name.uppercased()).font(CT.font(30, .black)).foregroundStyle(CT.ink)
                Text("Vote for a theme, set your name, then wait for the host.")
                    .font(CT.font(15, .medium)).foregroundStyle(CT.inkSoft).multilineTextAlignment(.center)
            }
            ConnectionCard(name: $name)
            MyNameCard(theme: theme)
            CaptainCategoryCard(theme: theme)
            ThemeVoteCard(selected: theme)
            TeamsList(theme: theme)
        }
    }
}

struct ConnectionCard: View {
    @EnvironmentObject var store: GameStore
    @Binding var name: String
    @State private var mode: Int = 0 // 0 = Host, 1 = Join
    var connected: Bool { !store.network.connectedNames.isEmpty }
    var body: some View {
        GamePanel(accent: CT.magenta) {
            SectionLabel(text: "Your Name", icon: "person.fill", color: CT.magenta)
            GameField(placeholder: "Enter your name…", text: $name)

            SectionLabel(text: "Mode", icon: "gamecontroller.fill", color: CT.magenta)
            ModeSelector(mode: $mode)

            Button {
                guard !name.trimmed.isEmpty else { return }
                if mode == 0 { store.hostGame(name: name) } else { store.joinGame(name: name) }
            } label: {
                Label(mode == 0 ? "START HOSTING" : "FIND A GAME", systemImage: mode == 0 ? "wifi.router.fill" : "magnifyingglass")
            }
            .buttonStyle(mode == 0 ? PartyButton.primary : PartyButton(fill: [CT.purple, CT.magenta]))
            .disabled(name.trimmed.isEmpty)

            StatusPill(connected: connected, text: store.network.statusText)
        }
    }
}

struct ModeSelector: View {
    @Binding var mode: Int
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width / 2
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(white: 0.93))
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(LinearGradient(colors: mode == 0 ? [CT.magenta, CT.pink] : [CT.purple, CT.magenta], startPoint: .top, endPoint: .bottom))
                    .padding(4)
                    .frame(width: w)
                    .offset(x: mode == 0 ? 0 : w)
                    .shadow(color: CT.magenta.opacity(0.5), radius: 6, y: 3)
                HStack(spacing: 0) {
                    segment("HOST", "crown.fill", index: 0)
                    segment("JOIN", "arrow.right.circle.fill", index: 1)
                }
            }
        }
        .frame(height: 56)
    }
    func segment(_ title: String, _ icon: String, index: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { mode = index }
        } label: {
            Label(title, systemImage: icon)
                .font(CT.font(17, .black))
                .foregroundStyle(mode == index ? .white : CT.inkSoft)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
    }
}

struct MyNameCard: View {
    @EnvironmentObject var store: GameStore
    let theme: GameTheme
    @State private var draft = ""
    var body: some View {
        if let p = store.activePlayer {
            GamePanel(accent: CT.team(p.team).first!) {
                TeamBadge(team: p.team)
                Text(store.isCaptain(p) ? "You are the \(theme.receiver) • Team Captain" : "You are a \(theme.transmitter)")
                    .font(CT.font(17, .bold)).foregroundStyle(CT.ink).multilineTextAlignment(.center)
                GameField(placeholder: "Change your name", text: $draft)
                    .onAppear { draft = p.name }
                Button("SAVE NAME") { store.send(.renamePlayer(p.id, draft)) }
                    .buttonStyle(PartyButton.primary)
                    .disabled(draft.trimmed.isEmpty)
            }
        }
    }
}

struct HostSettings: View {
    @EnvironmentObject var store: GameStore
    let theme: GameTheme
    var body: some View {
        GamePanel(accent: CT.purple) {
            SectionLabel(text: "Host Setup", icon: "slider.horizontal.3", color: CT.purple)

            SectionLabel(text: "Theme", icon: "paintpalette.fill", color: CT.magenta)
            VStack(spacing: 10) {
                ForEach(GameTheme.all) { t in
                    let selected = store.state.config.themeId == t.id
                    Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { store.send(.setTheme(t.id)) } } label: {
                        HStack {
                            Image(systemName: t.symbol)
                            Text(t.name.uppercased())
                            Spacer()
                            if selected { Image(systemName: "checkmark.circle.fill") }
                        }
                    }
                    .buttonStyle(selected ? PartyButton(fill: [CT.purple, CT.magenta]) : PartyButton.secondary)
                }
            }

            ThemeVoteSummary()

            GameStepper(label: "Rounds", icon: "flag.checkered", display: "Best of \(store.state.config.roundsToWin * 2 - 1)", accent: CT.magenta,
                        canDown: store.state.config.roundsToWin > 2, canUp: store.state.config.roundsToWin < 4,
                        onDown: { store.send(.setRoundsToWin(store.state.config.roundsToWin - 1)) },
                        onUp: { store.send(.setRoundsToWin(store.state.config.roundsToWin + 1)) })
            GameStepper(label: "Statics", icon: "bolt.slash.fill", display: "\(store.state.config.maxStatics)", accent: CT.orange,
                        canDown: store.state.config.maxStatics > 2, canUp: store.state.config.maxStatics < 3,
                        onDown: { store.send(.setMaxStatics(store.state.config.maxStatics - 1)) },
                        onUp: { store.send(.setMaxStatics(store.state.config.maxStatics + 1)) })
        }
    }
}

struct ThemeVoteSummary: View {
    @EnvironmentObject var store: GameStore
    var body: some View {
        VStack(spacing: 8) {
            SectionLabel(text: "Theme Votes", icon: "hand.thumbsup.fill", color: CT.purple)
            ForEach(GameTheme.all) { t in
                let count = store.state.themeVotes.values.filter { $0 == t.id }.count
                HStack {
                    Image(systemName: t.symbol).foregroundStyle(CT.magenta).frame(width: 24)
                    Text(t.name).font(CT.font(15, .bold)).foregroundStyle(CT.ink)
                    Spacer()
                    Text("\(count)")
                        .font(CT.font(15, .black)).foregroundStyle(.white)
                        .frame(minWidth: 30).padding(.vertical, 4).padding(.horizontal, 8)
                        .background(Capsule().fill(count > 0 ? CT.magenta : Color(white: 0.75)))
                        .contentTransition(.numericText())
                }
            }
        }
    }
}

struct CaptainCategoryCard: View {
    @EnvironmentObject var store: GameStore
    let theme: GameTheme
    var body: some View {
        let captainTeam = store.captainTeam(for: store.activePlayerId)
        GamePanel(accent: CT.cyan) {
            SectionLabel(text: "Captain Category Vote", icon: "checklist", color: CT.cyan)
            if let captainTeam {
                Text("You are the \(theme.receiver) for \(store.teamName(captainTeam)). Pick your team's category.")
                    .font(CT.font(14, .medium)).foregroundStyle(CT.inkSoft).multilineTextAlignment(.center)
                let selected = store.state.teamCategoryVotes[captainTeam] ?? "Everything"
                VStack(spacing: 10) {
                    ForEach(categories, id: \.self) { cat in
                        let on = selected == cat
                        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { store.send(.setTeamCategoryVote(captainTeam, cat)) } } label: {
                            HStack {
                                Image(systemName: categoryIcons[cat] ?? "circle.fill")
                                Text(cat.uppercased())
                                Spacer()
                                if on { Image(systemName: "checkmark.circle.fill") }
                            }
                        }
                        .buttonStyle(on ? PartyButton(fill: [CT.cyan, Color(red: 0.16, green: 0.6, blue: 0.85)]) : PartyButton.secondary)
                    }
                }
            } else {
                Text("Only the two \(theme.receiver)s / team captains choose categories.")
                    .font(CT.font(14, .medium)).foregroundStyle(CT.inkSoft).multilineTextAlignment(.center)
            }
            HStack {
                categoryChip(.A)
                Spacer()
                categoryChip(.B)
            }
            Text("If captains pick different categories, the app randomly chooses one 50/50 at match start.")
                .font(CT.font(12, .medium)).foregroundStyle(CT.inkSoft.opacity(0.8)).multilineTextAlignment(.center)
        }
    }
    func categoryChip(_ t: TeamId) -> some View {
        VStack(spacing: 4) {
            Text(store.teamName(t).uppercased()).font(CT.font(11, .black)).foregroundStyle(CT.team(t).first!)
            Text(store.state.teamCategoryVotes[t] ?? "—").font(CT.font(14, .bold)).foregroundStyle(CT.ink)
        }
    }
}

struct ThemeVoteCard: View {
    @EnvironmentObject var store: GameStore
    let selected: GameTheme
    var body: some View {
        let myVote = store.activePlayerId.flatMap { store.state.themeVotes[$0] } ?? store.state.config.themeId
        GamePanel(accent: CT.gold) {
            SectionLabel(text: "Vote Theme", icon: "star.fill", color: CT.orange)
            Text("Your vote changes the room theme immediately.")
                .font(CT.font(13, .medium)).foregroundStyle(CT.inkSoft)
            VStack(spacing: 10) {
                ForEach(GameTheme.all) { t in
                    let on = myVote == t.id
                    Button {
                        if let id = store.activePlayerId { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { store.send(.voteTheme(id, t.id)) } }
                    } label: {
                        HStack {
                            Image(systemName: t.symbol)
                            Text(t.name.uppercased())
                            Spacer()
                            if on { Image(systemName: "checkmark.circle.fill") }
                        }
                    }
                    .buttonStyle(on ? PartyButton.gold : PartyButton.secondary)
                }
            }
        }
    }
}

struct TeamsEditor: View {
    @EnvironmentObject var store: GameStore
    @State private var a = ""
    @State private var b = ""
    var body: some View {
        GamePanel(accent: CT.teamA.first!) {
            SectionLabel(text: "Teams + Captains", icon: "person.3.fill", color: CT.magenta)
            GameField(placeholder: "Team A name", text: $a).onAppear { a = store.teamName(.A) }
            GameField(placeholder: "Team B name", text: $b).onAppear { b = store.teamName(.B) }
            HStack(spacing: 12) {
                Button("SAVE NAMES") { store.send(.setTeamName(.A, a)); store.send(.setTeamName(.B, b)) }
                    .buttonStyle(PartyButton.secondary)
                Button { store.randomizeCaptainsAndTeams() } label: { Label("RANDOMIZE", systemImage: "shuffle") }
                    .buttonStyle(PartyButton.primary)
            }
            TeamsList(theme: GameTheme.all.first { $0.id == store.state.config.themeId } ?? GameTheme.all[0], editable: true)
        }
    }
}

struct StartCard: View {
    @EnvironmentObject var store: GameStore
    @State private var pulse = false
    var body: some View {
        let ready = store.state.players.filter { $0.team == .A }.count >= 2
            && store.state.players.filter { $0.team == .B }.count >= 2
            && store.state.captainIds[.A] != nil && store.state.captainIds[.B] != nil
        GamePanel(accent: CT.green) {
            HStack(spacing: 8) {
                Image(systemName: categoryIcons[store.state.config.category] ?? "square.grid.2x2.fill").foregroundStyle(CT.green)
                Text("Final category: \(store.state.config.category)").font(CT.font(16, .bold)).foregroundStyle(CT.ink)
            }
            Button { store.startOrNextRound() } label: {
                Label("START GAME", systemImage: "play.fill")
            }
            .buttonStyle(PartyButton(fill: [CT.green, Color(red: 0.16, green: 0.68, blue: 0.42)], big: true))
            .disabled(!ready)
            .scaleEffect(ready && pulse ? 1.03 : 1.0)
            .onAppear { if ready { withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true } } }
            .onChange(of: ready) { newValue in
                pulse = false
                if newValue { withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true } }
            }
            if !ready {
                Text("Randomize captains first. Need 2 players per team.")
                    .font(CT.font(12, .medium)).foregroundStyle(CT.inkSoft).multilineTextAlignment(.center)
            }
        }
    }
}

struct TeamsList: View {
    @EnvironmentObject var store: GameStore
    let theme: GameTheme
    var editable = false
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(TeamId.allCases, id: \.self) { team in
                VStack(spacing: 10) {
                    Label(store.teamName(team).uppercased(), systemImage: team == .A ? theme.teamAIcon : theme.teamBIcon)
                        .font(CT.font(15, .black)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                    ForEach(store.state.players.filter { $0.team == team }) { p in
                        PlayerRow(player: p, editable: editable)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(LinearGradient(colors: CT.team(team).map { $0.opacity(0.9) }, startPoint: .top, endPoint: .bottom))
                )
                .shadow(color: CT.team(team).last!.opacity(0.4), radius: 6, y: 4)
            }
        }
    }
}

struct PlayerRow: View {
    @EnvironmentObject var store: GameStore
    let player: Player
    let editable: Bool
    @State private var draft = ""
    var body: some View {
        VStack(spacing: 8) {
            let captain = store.isCaptain(player)
            if editable {
                HStack {
                    if captain { Image(systemName: "crown.fill").foregroundStyle(CT.gold) }
                    TextField("Name", text: $draft)
                        .font(CT.font(14, .bold)).foregroundColor(CT.ink).colorScheme(.light)
                        .padding(8).background(RoundedRectangle(cornerRadius: 10).fill(.white)).onAppear { draft = player.name }
                }
                HStack(spacing: 6) {
                    Button("A") { store.send(.setPlayerTeam(player.id, .A)) }.buttonStyle(MiniButton(color: CT.teamA.first!))
                    Button("B") { store.send(.setPlayerTeam(player.id, .B)) }.buttonStyle(MiniButton(color: CT.teamB.first!))
                    Button("SAVE") { store.send(.renamePlayer(player.id, draft)) }.buttonStyle(MiniButton(color: .white, fg: CT.ink))
                }
            } else {
                HStack {
                    if captain { Image(systemName: "crown.fill").foregroundStyle(CT.gold) }
                    Text(player.name + (store.activePlayerId == player.id ? " • YOU" : ""))
                        .font(CT.font(15, .black)).foregroundStyle(.white)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.22)))
    }
}

struct MiniButton: ButtonStyle {
    var color: Color
    var fg: Color = .white
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CT.font(12, .black)).foregroundColor(fg)
            .padding(.vertical, 6).padding(.horizontal, 10)
            .background(Capsule().fill(color))
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Round

struct RoundView: View {
    @EnvironmentObject var store: GameStore
    let theme: GameTheme
    var body: some View {
        VStack(spacing: 20) {
            LogoHeader(subtitle: "ROUND \(store.state.roundNumber)")
            HUDView(theme: theme)
            if let p = store.activePlayer {
                VStack(spacing: 8) {
                    TeamBadge(team: p.team)
                    Text("You are \(p.name)").font(CT.font(16, .bold)).foregroundStyle(.white)
                }
            }
            if let a = store.state.round?.announcement {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                    Text(a).font(CT.font(15, .bold))
                }
                .foregroundStyle(CT.ink)
                .padding().frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(LinearGradient(colors: [CT.gold, CT.orange], startPoint: .top, endPoint: .bottom)))
                .shadow(color: CT.orange.opacity(0.5), radius: 8, y: 4)
            }
            switch store.state.round?.phase {
            case .roleReveal: RoleRevealView(theme: theme)
            case .awaitingClue: ClueView(theme: theme)
            case .opposingDecision, .owningDecision: DecisionView(theme: theme)
            case .roundOver: RoundOverView()
            default: EmptyView()
            }
        }
    }
}

struct HUDView: View {
    @EnvironmentObject var store: GameStore
    let theme: GameTheme
    var body: some View {
        let r = store.state.round
        GamePanel(accent: CT.magenta) {
            HStack(spacing: 8) {
                Image(systemName: "megaphone.fill").foregroundStyle(CT.magenta)
                Text("\(store.teamName(r?.clueingTeam ?? .A)) HINT").font(CT.font(15, .black)).foregroundStyle(CT.ink)
            }
            HStack(spacing: 12) {
                ForEach(TeamId.allCases, id: \.self) { t in
                    VStack(spacing: 4) {
                        Text(store.teamName(t).uppercased()).font(CT.font(12, .black)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                        Text("\(store.team(t)?.score ?? 0)").font(CT.font(34, .black)).foregroundStyle(.white)
                        Text("Static \(store.team(t)?.statics ?? 0)/\(store.state.config.maxStatics)")
                            .font(CT.font(11, .bold)).foregroundStyle(.white.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity).padding(12)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(LinearGradient(colors: CT.team(t), startPoint: .top, endPoint: .bottom)))
                    .shadow(color: CT.team(t).last!.opacity(0.45), radius: 6, y: 3)
                }
            }
        }
    }
}

struct RoleRevealView: View {
    @EnvironmentObject var store: GameStore
    let theme: GameTheme
    var body: some View {
        GamePanel(accent: CT.purple) {
            if let p = store.activePlayer {
                if store.isReceiver(p) {
                    Text("YOU ARE THE\n\(theme.receiver.uppercased())")
                        .font(CT.font(30, .black)).foregroundStyle(CT.ink).multilineTextAlignment(.center)
                    Text("Do not look at anyone else's phone.")
                        .font(CT.font(15, .medium)).foregroundStyle(CT.inkSoft)
                } else {
                    Text("YOU ARE A \(theme.transmitter.uppercased())")
                        .font(CT.font(14, .black)).foregroundStyle(CT.inkSoft)
                    Text(store.state.round?.signal.uppercased() ?? "")
                        .font(CT.font(44, .black)).foregroundStyle(LinearGradient(colors: [CT.purple, CT.magenta], startPoint: .top, endPoint: .bottom))
                        .minimumScaleFactor(0.5).multilineTextAlignment(.center)
                    Text("Your \(theme.receiver) is \(store.playerName(store.team(p.team)?.receiverId)).")
                        .font(CT.font(15, .bold)).foregroundStyle(CT.ink)
                }
            } else {
                Text("Waiting for your player…").font(CT.font(17, .bold)).foregroundStyle(CT.inkSoft)
            }
            Button("EVERYONE IS READY") { store.send(.allReady) }
                .buttonStyle(PartyButton.primary)
                .disabled(!store.isHost)
        }
    }
}

struct ClueView: View {
    @EnvironmentObject var store: GameStore
    let theme: GameTheme
    @State private var clue = ""
    var body: some View {
        let active = store.activeTransmitterId()
        let isActive = store.activePlayerId == active
        GamePanel(accent: CT.magenta) {
            if let p = store.activePlayer, !store.isReceiver(p) {
                Text("SIGNAL").font(CT.font(13, .black)).foregroundStyle(CT.magenta)
                Text(store.state.round?.signal.uppercased() ?? "")
                    .font(CT.font(36, .black)).foregroundStyle(CT.ink).minimumScaleFactor(0.6).multilineTextAlignment(.center)
            } else {
                Text("\(theme.receiver.uppercased()) WAITING").font(CT.font(26, .black)).foregroundStyle(CT.ink)
            }
            Text("Hint giver: \(store.playerName(active))").font(CT.font(17, .bold)).foregroundStyle(CT.inkSoft)
            if isActive {
                GameField(placeholder: "Type your one-word hint", text: $clue)
                Button("SUBMIT HINT") { store.send(.clueGiven(clue)); clue = "" }
                    .buttonStyle(PartyButton.primary)
                    .disabled(clue.trimmed.isEmpty)
            } else {
                Text("Only \(store.playerName(active)) can submit the hint.")
                    .font(CT.font(15, .bold)).foregroundStyle(CT.inkSoft).multilineTextAlignment(.center)
            }
            LastHintsView()
        }
    }
}

struct LastHintsView: View {
    @EnvironmentObject var store: GameStore
    var body: some View {
        if !(store.state.round?.history.isEmpty ?? true) {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "Hint History", icon: "text.bubble.fill", color: CT.purple)
                ForEach(Array((store.state.round?.history ?? []).enumerated()), id: \.offset) { _, rec in
                    if let clue = rec.clueText {
                        HStack {
                            Circle().fill(CT.team(rec.clueingTeam).first!).frame(width: 8, height: 8)
                            Text("\(store.teamName(rec.clueingTeam)): \(clue)")
                                .font(CT.font(13, .semibold)).foregroundStyle(CT.ink)
                            Spacer()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct DecisionView: View {
    @EnvironmentObject var store: GameStore
    let theme: GameTheme
    @State private var guess = ""
    @State private var confirming = false
    var body: some View {
        let team = store.receiverTeamForDecision()
        let receiverId = team.flatMap { store.team($0)?.receiverId }
        let canAct = store.activePlayerId == receiverId
        GamePanel(accent: canAct ? CT.green : CT.purple) {
            if canAct {
                Text("YOUR TURN TO GUESS").font(CT.font(28, .black)).foregroundStyle(CT.ink).multilineTextAlignment(.center)
                Text("\(store.teamName(team ?? .A)) \(theme.receiver)".uppercased())
                    .font(CT.font(15, .black)).foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Capsule().fill(LinearGradient(colors: CT.team(team ?? .A), startPoint: .top, endPoint: .bottom)))
                GameField(placeholder: "Type your guess", text: $guess, big: true)
                HStack(spacing: 12) {
                    Button("PASS") { if let team { store.send(.receiverPass(team)) }; guess = "" }
                        .buttonStyle(PartyButton.secondary)
                    Button("LOCK GUESS") { confirming = true }
                        .buttonStyle(PartyButton.go)
                        .disabled(guess.trimmed.isEmpty)
                }
            } else {
                Image(systemName: "hourglass")
                    .font(.system(size: 64, weight: .black))
                    .foregroundStyle(LinearGradient(colors: [CT.purple, CT.magenta], startPoint: .top, endPoint: .bottom))
                Text("Waiting for the \(theme.receiver)").font(CT.font(26, .black)).foregroundStyle(CT.ink).multilineTextAlignment(.center)
                Text("\(store.playerName(receiverId)) is deciding now.").font(CT.font(16, .bold)).foregroundStyle(CT.inkSoft)
                Text("Guess controls only appear on that player's phone.")
                    .font(CT.font(13, .medium)).foregroundStyle(CT.inkSoft.opacity(0.8)).multilineTextAlignment(.center)
            }
        }
        .alert("Lock it in?", isPresented: $confirming) {
            Button("Cancel", role: .cancel) {}
            Button("Submit") { if let team { store.send(.receiverGuess(team, guess)) }; guess = "" }
        } message: { Text(guess) }
    }
}

struct RoundOverView: View {
    @EnvironmentObject var store: GameStore
    var body: some View {
        GamePanel(accent: CT.gold) {
            Image(systemName: "party.popper.fill")
                .font(.system(size: 40, weight: .black))
                .foregroundStyle(LinearGradient(colors: [CT.gold, CT.orange], startPoint: .top, endPoint: .bottom))
            Text("ROUND OVER").font(CT.font(30, .black)).foregroundStyle(CT.ink)
            Text("Signal: \(store.state.round?.signal ?? "")").font(CT.font(18, .bold)).foregroundStyle(CT.inkSoft)
            Text("\(store.teamName(store.state.round?.winner ?? .A)) wins by \(store.state.round?.winReason == .lockout ? "lockout" : "correct guess")!")
                .font(CT.font(17, .black)).foregroundStyle(CT.ink).multilineTextAlignment(.center)
            LastHintsView()
            Button("NEXT ROUND") { store.startOrNextRound() }
                .buttonStyle(PartyButton.primary)
                .disabled(store.state.status == .matchOver || !store.isHost)
        }
    }
}

struct MatchOverView: View {
    @EnvironmentObject var store: GameStore
    var body: some View {
        VStack(spacing: 20) {
            LogoHeader(subtitle: "MATCH OVER")
            GamePanel(accent: CT.gold) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 56, weight: .black))
                    .foregroundStyle(LinearGradient(colors: [CT.gold, CT.orange], startPoint: .top, endPoint: .bottom))
                    .shadow(color: CT.orange.opacity(0.5), radius: 8, y: 4)
                Text("MATCH OVER").font(CT.font(34, .black)).foregroundStyle(CT.ink)
                HStack(spacing: 12) {
                    scoreChip(.A)
                    scoreChip(.B)
                }
                Button("NEW MATCH") { store.send(.reset) }
                    .buttonStyle(PartyButton(fill: [CT.green, Color(red: 0.16, green: 0.68, blue: 0.42)], big: true))
            }
        }
    }
    func scoreChip(_ t: TeamId) -> some View {
        VStack(spacing: 4) {
            Text(store.teamName(t).uppercased()).font(CT.font(13, .black)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
            Text("\(store.team(t)?.score ?? 0)").font(CT.font(40, .black)).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity).padding(14)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(LinearGradient(colors: CT.team(t), startPoint: .top, endPoint: .bottom)))
        .shadow(color: CT.team(t).last!.opacity(0.45), radius: 6, y: 3)
    }
}

private extension String { var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) } }
