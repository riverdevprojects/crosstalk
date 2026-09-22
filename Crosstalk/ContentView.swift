import SwiftUI

// A theme chooses both the words and the illustrated world.
struct GameTheme: Identifiable, Equatable {
    let definition: ThemeDefinition
    var id: String { definition.id }
    var name: String { definition.name }
    var symbol: String { definition.symbol }
    var background: String { definition.background }
    var receiver: String { "Guesser" }
    var transmitter: String { "Hint giver" }
    var teamAIcon: String { "circle.fill" }
    var teamBIcon: String { "diamond.fill" }
    static let all = ThemeDefinition.all.map { GameTheme(definition: $0) }
}

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
    static let teamA: [Color] = [Color(red: 0.12, green: 0.35, blue: 0.70), Color(red: 0.04, green: 0.40, blue: 0.48)]
    static let teamB: [Color] = [Color(red: 0.70, green: 0.12, blue: 0.33), Color(red: 0.65, green: 0.25, blue: 0.06)]
    static func team(_ t: TeamId) -> [Color] { t == .A ? teamA : teamB }

    static func font(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        .custom("ArialRoundedMTBold", size: size, relativeTo: .body).weight(weight)
    }
}

// MARK: - Root

enum FlowScreen { case welcome, entry, hostSetup, joinCode }

struct ContentView: View {
    @EnvironmentObject var store: GameStore
    @State private var screen: FlowScreen = .welcome
    @State private var playerName = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingRules = false
    @State private var confirmingLeave = false
    @State private var confirmingReset = false
    @Environment(\.scenePhase) private var scenePhase
    var theme: GameTheme { GameTheme.all.first { $0.id == store.state.config.themeId } ?? GameTheme.all[0] }

    var body: some View {
        ZStack {
            PartyBackground(theme: theme)
            VStack(spacing: 8) {
                if store.state.status != .lobby {
                    HStack {
                        Button("Leave room") { confirmingLeave = true }
                        Spacer()
                        if store.isHost { Button("Return to lobby") { confirmingReset = true } }
                    }
                    .font(CT.font(16, .bold)).foregroundStyle(.white).padding(.horizontal, 20)
                }
                Button("How to play") { showingRules = true }
                    .font(CT.font(16, .bold)).foregroundStyle(.white).padding(.top, 8)
                if let notice = store.state.notice {
                    Text(notice).font(CT.font(15, .medium)).foregroundStyle(.white).padding(.horizontal)
                }
                if let message = store.syncMessage {
                    HStack {
                        Text(message).font(.callout)
                        Button("Sync game") { store.syncGame() }.font(.callout.bold()).frame(minHeight: 44)
                    }
                    .padding(12).foregroundStyle(CT.ink).background(CT.panel, in: RoundedRectangle(cornerRadius: 16)).padding(.horizontal)
                }
                if let error = store.network.connectionError {
                    ScrollView { VStack(spacing: 12) {
                        Text(error).font(CT.font(17, .bold))
                        if store.network.mode == .joining {
                            Button("Retry joining") { store.retryJoin() }.buttonStyle(PartyButton.primary)
                        }
                        Button("Leave room") { leave() }.buttonStyle(PartyButton.secondary)
                    }
                    .padding().background(CT.panel).foregroundStyle(CT.ink).cornerRadius(20).padding() }
                } else {
                    content
                }
            }
        }
        .transaction { if reduceMotion { $0.animation = nil; $0.disablesAnimations = true } }
        .tint(CT.magenta)
        .onChange(of: scenePhase) { phase in
            if phase == .active, store.activePlayerId != nil, store.network.connectionError == nil {
                store.syncGame()
            }
        }
        .confirmationDialog("Return everyone to the lobby?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Reset match", role: .destructive) { store.send(.reset) }
        } message: { Text("This clears the current scores and round for every player.") }
        .sheet(isPresented: $showingRules) { RulesView() }
        .confirmationDialog("Leave this room?", isPresented: $confirmingLeave, titleVisibility: .visible) {
            Button("Leave room", role: .destructive) { leave() }
        } message: {
            Text(store.isHost ? "Leaving disconnects everyone from this room." : "Leaving an active match returns everyone to the lobby.")
        }
        .alert("Crosstalk", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
    }

    @ViewBuilder var content: some View {
        switch store.state.status {
        case .inRound: PartyScroll { RoundView(theme: theme) }
        case .matchOver: PartyScroll { MatchOverView() }
        case .lobby: lobbyFlow
        }
    }

    @ViewBuilder var lobbyFlow: some View {
        switch screen {
        case .welcome:
            WelcomeView { withAnimation(.easeInOut) { screen = .entry } }
                .transition(.opacity)
        case .entry:
            EntryView(
                name: $playerName,
                onHost: { store.hostGame(name: playerName); withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { screen = .hostSetup } },
                onJoin: { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { screen = .joinCode } }
            )
            .transition(.move(edge: .trailing).combined(with: .opacity))
        case .hostSetup:
            PartyScroll { HostLobby(theme: theme, onLeave: leave) }
                .transition(.move(edge: .trailing).combined(with: .opacity))
        case .joinCode:
            if store.state.players.count > 1 && !store.network.connectedNames.isEmpty {
                PartyScroll { PlayerLobby(theme: theme, onLeave: leave) }
                    .transition(.opacity)
            } else {
                JoinCodeView(
                    name: $playerName,
                    onJoin: { code in store.joinGame(name: playerName, code: code) },
                    onBack: leave
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }

    func leave() {
        store.leaveRoom()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { screen = .entry }
    }
}

/// Standard scrollable party page.
struct PartyScroll<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) { content }
                .padding(.horizontal, 18)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Animated background

struct PartyBackground: View {
    let theme: GameTheme
    var body: some View {
        GeometryReader { geometry in
            Image(theme.background)
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .overlay(Color.black.opacity(0.48))
                .overlay(LinearGradient(colors: [.black.opacity(0.25), .clear, .black.opacity(0.35)], startPoint: .top, endPoint: .bottom))
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
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
                    .shadow(color: accent.opacity(0.35), radius: 0, x: 0, y: 8)
                    .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(accent.opacity(0.25), lineWidth: 2)
            )
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
            if let icon { Image(systemName: icon).foregroundStyle(color).accessibilityHidden(true) }
            Text(text.uppercased()).foregroundStyle(CT.ink)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                    .shadow(color: (fill.last ?? .black).opacity(0.45), radius: pressed ? 2 : 9, x: 0, y: pressed ? 1 : 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.35), lineWidth: 1.5)
            )
            .offset(y: pressed ? 3 : 0)
            .scaleEffect(pressed ? 0.97 : 1)
            .opacity(enabled ? 1 : 0.45)
            .grayscale(enabled ? 0 : 0.4)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.6), value: pressed)
    }
}

extension PartyButton {
    static var primary: PartyButton { PartyButton(fill: [Color(red: 0.65, green: 0.10, blue: 0.40), Color(red: 0.72, green: 0.18, blue: 0.40)]) }
    static var go: PartyButton { PartyButton(fill: [Color(red: 0.08, green: 0.43, blue: 0.24), Color(red: 0.05, green: 0.35, blue: 0.20)]) }
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
        TextField(placeholder, text: $text, prompt: Text(placeholder).foregroundColor(CT.inkSoft.opacity(0.7)))
            .accessibilityLabel(placeholder)
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
    @Environment(\.dynamicTypeSize) private var textSize
    let label: String
    let icon: String
    let display: String
    var accent: Color = CT.purple
    let canDown: Bool, canUp: Bool
    let onDown: () -> Void, onUp: () -> Void
    var body: some View {
        VStack(spacing: 10) {
            SectionLabel(text: label, icon: icon, color: accent)
            if textSize.isAccessibilitySize {
                Text(display).font(.title2.bold()).foregroundStyle(CT.ink)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 14) { decrease; increase }
            } else {
                HStack(spacing: 14) {
                    decrease
                    Text(display).font(CT.font(30, .black)).foregroundStyle(CT.ink)
                        .frame(maxWidth: .infinity).contentTransition(.numericText())
                    increase
                }
            }
        }
    }
    var decrease: some View {
        roundBtn("minus", enabled: canDown, action: onDown).accessibilityLabel("Decrease \(label)")
    }
    var increase: some View {
        roundBtn("plus", enabled: canUp, action: onUp).accessibilityLabel("Increase \(label)")
    }
    func roundBtn(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 24, weight: .black))
        }
        .buttonStyle(PartyButton(fill: enabled ? [CT.ink, CT.inkSoft] : [Color(white: 0.85)], fg: .white))
        .frame(minWidth: 64, minHeight: 44)
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
            .background(
                Capsule()
                    .fill(LinearGradient(colors: CT.team(team), startPoint: .top, endPoint: .bottom))
                    .shadow(color: CT.team(team).last!.opacity(0.45), radius: 6, y: 3)
            )
    }
}

// MARK: - Logo header

struct LogoHeader: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var subtitle: String = "THE ULTIMATE PARTY GAME"
    @State private var wiggle = false
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ZStack {
                    Circle().fill(LinearGradient(colors: [CT.gold, CT.orange], startPoint: .top, endPoint: .bottom))
                        .frame(width: 56, height: 56)
                        .shadow(color: CT.orange.opacity(0.35), radius: 6, y: 3)
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 26, weight: .black))
                        .foregroundStyle(.white)
                }
                .rotationEffect(.degrees(wiggle ? -6 : 6))
                Text("CROSSTALK")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .accessibilityLabel("Crosstalk")
                    .foregroundStyle(.white)
                    .kerning(0)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Text(subtitle)
                .font(CT.font(14, .bold))
                .foregroundStyle(.white.opacity(0.92))
                .kerning(1)
                .padding(.vertical, 4).padding(.horizontal, 12)
                .background(Capsule().fill(.white.opacity(0.12)))
        }
        .padding(.top, 8)
        .onChange(of: reduceMotion) { if $0 { wiggle = false } }
        .onAppear { if !reduceMotion { withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { wiggle = true } } }
    }
}

// MARK: - Flow: welcome / entry / join

/// Header used on the flow pages, with an optional back/leave chip.
struct FlowHeader: View {
    var subtitle: String = "THE ULTIMATE PARTY GAME"
    var backLabel: String = "BACK"
    var onBack: (() -> Void)? = nil
    var body: some View {
        VStack(spacing: 10) {
            if let onBack {
                HStack {
                    Button { onBack() } label: {
                        Label(backLabel, systemImage: "chevron.left")
                            .font(CT.font(13, .black)).foregroundStyle(.white)
                            .padding(.vertical, 8).padding(.horizontal, 14)
                            .background(Capsule().fill(.white.opacity(0.20)))
                            .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }
            LogoHeader(subtitle: subtitle)
        }
    }
}

/// Animated splash / loading screen shown on launch.
struct WelcomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onDone: () -> Void
    @State private var progress: CGFloat = 0
    @State private var bounce = false
    var body: some View {
        VStack(spacing: 34) {
            Spacer()
            LogoHeader(subtitle: "GUESS • COMPETE • WIN")
                .scaleEffect(bounce ? 1.03 : 0.97)
            // playful loading bar
            VStack(spacing: 14) {
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.22)).frame(height: 16)
                    GeometryReader { geo in
                        Capsule()
                            .fill(LinearGradient(colors: [CT.gold, CT.orange], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(16, geo.size.width * progress), height: 16)
                            .shadow(color: CT.orange.opacity(0.6), radius: 6)
                    }
                    .frame(height: 16)
                }
                .frame(height: 16)
                .frame(maxWidth: 240)
                Text("LOADING…")
                    .font(CT.font(15, .black)).foregroundStyle(.white.opacity(0.9)).kerning(3)
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            if reduceMotion { onDone(); return }
            withAnimation(.easeInOut(duration: 1.6)) { progress = 1 }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { bounce = true }
            do { try await Task.sleep(nanoseconds: 2_000_000_000) } catch { return }
            onDone()
        }
    }
}

/// Name + Host/Join chooser. Leads to a dedicated page for each mode.
struct EntryView: View {
    @Binding var name: String
    let onHost: () -> Void
    let onJoin: () -> Void
    @State private var mode = 0 // 0 = Host, 1 = Join
    var body: some View {
        PartyScroll {
            LogoHeader()
            GamePanel(accent: CT.magenta) {
                SectionLabel(text: "Your Name", icon: "person.fill", color: CT.magenta)
                GameField(placeholder: "Enter your name…", text: $name)
                Text("1–32 characters").font(CT.font(13, .medium)).foregroundStyle(CT.inkSoft)

                SectionLabel(text: "Choose Mode", icon: "gamecontroller.fill", color: CT.magenta)
                ModeSelector(mode: $mode)

                Text(mode == 0 ? "Create a room and get a code your friends type in." : "Type the host's room code to jump into their game.")
                    .font(CT.font(14, .medium)).foregroundStyle(CT.inkSoft).multilineTextAlignment(.center)

                Button {
                    guard InputRules.validName(name) else { return }
                    if mode == 0 { onHost() } else { onJoin() }
                } label: {
                    Label(mode == 0 ? "CREATE ROOM" : "ENTER A CODE", systemImage: "arrow.right")
                }
                .buttonStyle(mode == 0 ? PartyButton.primary : PartyButton(fill: [CT.purple, CT.magenta]))
                .disabled(!InputRules.validName(name))
            }
        }
    }
}

/// Room-code entry page for joiners; shows a searching state after submit.
struct JoinCodeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject var store: GameStore
    @Binding var name: String
    let onJoin: (String) -> Void
    let onBack: () -> Void
    @State private var code = ""
    @State private var submitted = false
    @State private var spin = false
    var body: some View {
        PartyScroll {
            FlowHeader(subtitle: "JOIN A ROOM", onBack: { submitted = false; onBack() })
            GamePanel(accent: CT.purple) {
                if submitted {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 52, weight: .black))
                        .foregroundStyle(LinearGradient(colors: [CT.purple, CT.magenta], startPoint: .top, endPoint: .bottom))
                        .rotationEffect(.degrees(spin ? 8 : -8))
                    Text("SEARCHING FOR \(code)").font(CT.font(22, .black)).foregroundStyle(CT.ink)
                    Text(store.network.statusText).font(CT.font(14, .medium)).foregroundStyle(CT.inkSoft).multilineTextAlignment(.center)
                    Text("Make sure the host is nearby and their screen shows this code.")
                        .font(CT.font(13, .medium)).foregroundStyle(CT.inkSoft.opacity(0.8)).multilineTextAlignment(.center)
                    Button("CANCEL") { submitted = false; onBack() }
                        .buttonStyle(PartyButton.secondary)
                } else {
                    SectionLabel(text: "Room Code", icon: "number", color: CT.purple)
                    GameField(placeholder: "ABCD", text: $code, big: true)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .onChange(of: code) { code = String($0.uppercased().filter { InputRules.roomAlphabet.contains($0) }.prefix(4)) }
                    Text("Ask the host for their 4-character room code.")
                        .font(CT.font(14, .medium)).foregroundStyle(CT.inkSoft).multilineTextAlignment(.center)
                    Button {
                        let c = code.trimmed.uppercased()
                        guard InputRules.validRoomCode(c) else { return }
                        submitted = true
                        onJoin(c)
                    } label: {
                        Label("JOIN GAME", systemImage: "arrow.right.circle.fill")
                    }
                    .buttonStyle(PartyButton.primary)
                    .disabled(!InputRules.validRoomCode(code.trimmed))
                }
            }
        }
        .onAppear { if !reduceMotion { withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { spin = true } } }
    }
}

// MARK: - Lobby pages

struct HostLobby: View {
    @EnvironmentObject var store: GameStore
    let theme: GameTheme
    var onLeave: () -> Void = {}
    var body: some View {
        VStack(spacing: 20) {
            FlowHeader(subtitle: "HOST CONTROL", backLabel: "LEAVE", onBack: onLeave)
            RoomCodeCard()
            GamePanel(accent: CT.gold) {
                SectionLabel(text: "Host Control Center", icon: "crown.fill", color: CT.orange)
                Text("Choose a world to explore. Its theme sets the words and the scenery for everyone. Sort the teams, then start.")
                    .font(CT.font(15, .medium)).foregroundStyle(CT.inkSoft).multilineTextAlignment(.center)
            }
            HostSettings(theme: theme)
            TeamsEditor()
            StartCard()
        }
    }
}

struct PlayerLobby: View {
    @EnvironmentObject var store: GameStore
    let theme: GameTheme
    var onLeave: () -> Void = {}
    var body: some View {
        VStack(spacing: 20) {
            FlowHeader(subtitle: "IN THE LOBBY", backLabel: "LEAVE", onBack: onLeave)
            GamePanel(accent: CT.purple) {
                Image(systemName: theme.symbol)
                    .font(.system(size: 46, weight: .black))
                    .foregroundStyle(LinearGradient(colors: [CT.purple, CT.magenta], startPoint: .top, endPoint: .bottom))
                Text(theme.name.uppercased()).font(CT.font(30, .black)).foregroundStyle(CT.ink)
                Text("Set your name and wait for the host to start. Each round, one random player per team has to guess.")
                    .font(CT.font(15, .medium)).foregroundStyle(CT.inkSoft).multilineTextAlignment(.center)
                StatusPill(connected: !store.network.connectedNames.isEmpty, text: store.network.connectedNames.isEmpty ? "Connecting…" : "Connected")
            }
            MyNameCard(theme: theme)
            TeamsList(theme: theme)
        }
    }
}

/// Big shareable room code for the host page.
struct RoomCodeCard: View {
    @EnvironmentObject var store: GameStore
    var count: Int { store.network.connectedNames.count }
    var body: some View {
        GamePanel(accent: CT.gold) {
            SectionLabel(text: "Room Code", icon: "number", color: CT.orange)
            Text(store.network.roomCode.isEmpty ? "----" : store.network.roomCode)
                .font(CT.font(56, .black))
                .kerning(6)
                .foregroundStyle(LinearGradient(colors: [CT.gold, CT.orange], startPoint: .top, endPoint: .bottom))
                .lineLimit(1).minimumScaleFactor(0.5)
                .shadow(color: CT.orange.opacity(0.18), radius: 3, y: 2)
            Text("Friends pick JOIN and type this code to enter your room.")
                .font(CT.font(13, .medium)).foregroundStyle(CT.inkSoft).multilineTextAlignment(.center)
            StatusPill(connected: count > 0, text: count == 0 ? "Waiting for players" : "\(count) connected")
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
                Text("Each round, one player per team is randomly picked to be the \(theme.receiver) and guess — it could be you.")
                    .font(CT.font(15, .medium)).foregroundStyle(CT.inkSoft).multilineTextAlignment(.center)
                GameField(placeholder: "Change your name", text: $draft)
                    .onAppear { draft = p.name }
                Button("SAVE NAME") { store.send(.renamePlayer(p.id, draft)) }
                    .buttonStyle(PartyButton.primary)
                    .disabled(!InputRules.validName(draft))
            }
        }
    }
}

struct HostSettings: View {
    @EnvironmentObject var store: GameStore
    let theme: GameTheme
    var body: some View {
        GamePanel(accent: CT.purple) {
            SectionLabel(text: "Choose your world", icon: "paintpalette.fill", color: CT.magenta)
            Text("Your theme sets the words and scenery.").font(.subheadline).foregroundStyle(CT.inkSoft)
            ThemePicker()

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

struct ThemePicker: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dynamicTypeSize) private var textSize
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: textSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
            ForEach(GameTheme.all) { theme in
                let selected = store.state.config.themeId == theme.id
                Button { store.send(.setTheme(theme.id)) } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        GeometryReader { geometry in
                            Image(theme.background).resizable().scaledToFill()
                                .frame(width: geometry.size.width, height: 125, alignment: .top).clipped()
                        }.frame(height: 125).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top) {
                                Text(theme.name).font(.headline)
                                Spacer(minLength: 0)
                                if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(CT.purple) }
                            }
                            Text(theme.definition.description).font(.caption).foregroundStyle(CT.inkSoft)
                            Text("\(store.wordCount(for: theme.id)) words").font(.caption.bold())
                        }.padding(.horizontal, 10).padding(.bottom, 12)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .foregroundStyle(CT.ink)
                    .background(Color(white: 0.97))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? CT.purple : Color.gray.opacity(0.25), lineWidth: selected ? 3 : 1))
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(theme.name). \(theme.definition.description). \(store.wordCount(for: theme.id)) words")
                .accessibilityAddTraits(selected ? [.isSelected] : [])
                .accessibilityHint("Sets the words and background for everyone")
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
            SectionLabel(text: "Teams", icon: "person.3.fill", color: CT.magenta)
            GameField(placeholder: "Team A name", text: $a).onAppear { a = store.teamName(.A) }
            GameField(placeholder: "Team B name", text: $b).onAppear { b = store.teamName(.B) }
            Button("SAVE NAMES") { store.send(.setTeamName(.A, a)); store.send(.setTeamName(.B, b)) }
                .disabled(!InputRules.validName(a) || !InputRules.validName(b))
                .buttonStyle(PartyButton.secondary)
            Text("Tap A / B to move a player. Need at least 2 players on each team.")
                .font(CT.font(12, .medium)).foregroundStyle(CT.inkSoft).multilineTextAlignment(.center)
            TeamsList(theme: GameTheme.all.first { $0.id == store.state.config.themeId } ?? GameTheme.all[0], editable: true)
        }
    }
}

struct StartCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject var store: GameStore
    @State private var pulse = false
    var body: some View {
        let ready = store.state.players.filter { $0.team == .A }.count >= 2
            && store.state.players.filter { $0.team == .B }.count >= 2
        GamePanel(accent: CT.green) {
            HStack(spacing: 8) {
                Image(systemName: ThemeDefinition.find(store.state.config.themeId).symbol).foregroundStyle(CT.ink)
                Text("World: \(ThemeDefinition.find(store.state.config.themeId).name)").font(CT.font(16, .bold)).foregroundStyle(CT.ink)
            }
            Button { store.startOrNextRound() } label: {
                Label("START GAME", systemImage: "play.fill")
            }
            .buttonStyle(PartyButton(fill: [Color(red: 0.08, green: 0.43, blue: 0.24), Color(red: 0.05, green: 0.35, blue: 0.20)], big: true))
            .disabled(!ready || !store.canCompleteMatch)
            .scaleEffect(ready && pulse ? 1.03 : 1.0)
            .onAppear { if ready && !reduceMotion { withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true } } }
            .onChange(of: ready) { newValue in
                pulse = false
                if newValue && !reduceMotion { withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true } }
            }
            if !store.canCompleteMatch {
                Text("This theme needs at least \(store.state.config.roundsToWin * 2 - 1) unique words for this match. Choose another theme or fewer rounds.")
                    .font(CT.font(15, .medium)).foregroundStyle(CT.inkSoft)
            }
            if !ready {
                Text("Need at least 2 players on each team to start.")
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
        VStack(alignment: .leading, spacing: 12) {
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
                        .shadow(color: CT.team(team).last!.opacity(0.35), radius: 6, y: 4)
                )
            }
        }
    }
}

struct PlayerRow: View {
    @EnvironmentObject var store: GameStore
    let player: Player
    let editable: Bool
    @State private var draft = ""
    @State private var confirmingRemoval = false
    var body: some View {
        VStack(spacing: 8) {
            if editable {
                TextField("Name", text: $draft)
                    .font(CT.font(14, .bold)).foregroundColor(CT.ink).colorScheme(.light)
                    .padding(8).background(RoundedRectangle(cornerRadius: 10).fill(.white)).onAppear { draft = player.name }
                HStack(spacing: 6) {
                    Button("A") { store.send(.setPlayerTeam(player.id, .A)) }.buttonStyle(MiniButton(color: CT.teamA.first!)).accessibilityLabel("Move \(player.name) to \(store.teamName(.A))")
                    Button("B") { store.send(.setPlayerTeam(player.id, .B)) }.buttonStyle(MiniButton(color: CT.teamB.first!)).accessibilityLabel("Move \(player.name) to \(store.teamName(.B))")
                    Button("SAVE") { store.send(.renamePlayer(player.id, draft)) }.buttonStyle(MiniButton(color: .white, fg: CT.ink)).disabled(!InputRules.validName(draft)).accessibilityLabel("Save name for \(player.name)")
                }
                if store.activePlayerId != player.id {
                    Button("Remove player") { confirmingRemoval = true }
                        .font(CT.font(14, .bold)).foregroundStyle(.white).frame(minHeight: 44)
                        .accessibilityLabel("Remove \(player.name)")
                        .confirmationDialog("Remove \(player.name) from the room?", isPresented: $confirmingRemoval, titleVisibility: .visible) {
                            Button("Remove player", role: .destructive) { store.removePlayer(player.id) }
                        }
                }
            } else {
                Text(player.name + (store.activePlayerId == player.id ? " • YOU" : ""))
                    .font(CT.font(15, .black)).foregroundStyle(.white)
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
            .frame(minWidth: 44, minHeight: 44)
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
            LogoHeader(subtitle: "\(theme.name.uppercased()) • ROUND \(store.state.roundNumber)")
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
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(colors: [CT.gold, CT.orange], startPoint: .top, endPoint: .bottom))
                        .shadow(color: CT.orange.opacity(0.4), radius: 8, y: 4)
                )
            }
            switch store.state.round?.phase {
            case .roleReveal: RoleRevealView(theme: theme)
            case .awaitingClue: ClueView(theme: theme)
            case .opposingDecision, .owningDecision: DecisionView(theme: theme).id(store.state.round?.phase)
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
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(LinearGradient(colors: CT.team(t), startPoint: .top, endPoint: .bottom))
                            .shadow(color: CT.team(t).last!.opacity(0.35), radius: 6, y: 3)
                    )
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
            if store.isHost {
                Button("EVERYONE READY — START") { store.send(.allReady) }.buttonStyle(PartyButton.go)
                Text("Check that everyone has read their role before continuing.").font(CT.font(15, .medium))
            } else {
                Text("Tell the host when you are ready.").font(CT.font(17, .bold))
            }
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
                Text("SECRET WORD").font(CT.font(13, .black)).foregroundStyle(CT.magenta)
                Text(store.state.round?.signal.uppercased() ?? "")
                    .font(CT.font(36, .black)).foregroundStyle(CT.ink).minimumScaleFactor(0.6).multilineTextAlignment(.center)
            } else {
                Text("\(theme.receiver.uppercased()) WAITING").font(CT.font(26, .black)).foregroundStyle(CT.ink)
            }
            Text("Hint giver: \(store.playerName(active))").font(CT.font(17, .bold)).foregroundStyle(CT.inkSoft)
            if isActive {
                GameField(placeholder: "Type your one-word hint", text: $clue)
                Button("SUBMIT HINT") { store.send(.clueGiven(clue)) }
                    .buttonStyle(PartyButton.primary)
                    .disabled(InputRules.clueError(clue, answers: [store.state.round?.signal ?? ""]) != nil)
                Text("One word; no answer or close spelling. Hyphens and apostrophes are allowed.").font(CT.font(13, .medium))
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
    @Environment(\.dynamicTypeSize) private var textSize
    let theme: GameTheme
    @State private var guess = ""
    @State private var confirming = false
    var body: some View {
        let team = store.receiverTeamForDecision()
        let receiverId = team.flatMap { store.team($0)?.receiverId }
        let canAct = store.activePlayerId == receiverId
        GamePanel(accent: canAct ? CT.green : CT.purple) {
            if let hint = store.state.round?.history.last?.clueText {
                SectionLabel(text: "Current hint", icon: "text.bubble.fill")
                Text(hint).font(CT.font(30, .black)).accessibilityLabel("Current hint: \(hint)")
            }
            LastHintsView()
            if canAct {
                Text("YOUR TURN TO GUESS").font(CT.font(28, .black)).foregroundStyle(CT.ink).multilineTextAlignment(.center)
                Text("\(store.teamName(team ?? .A)) \(theme.receiver)".uppercased())
                    .font(CT.font(15, .black)).foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Capsule().fill(LinearGradient(colors: CT.team(team ?? .A), startPoint: .top, endPoint: .bottom)))
                GameField(placeholder: "Type your guess", text: $guess, big: true)
                let actionsLayout = textSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
                actionsLayout {
                    Button("PASS") { if let team, store.send(.receiverPass(team)) { guess = "" } }
                        .buttonStyle(PartyButton.secondary)
                    Button("LOCK GUESS") { confirming = true }
                        .buttonStyle(PartyButton.go)
                        .disabled(!InputRules.validGuess(guess))
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
            Button("Submit") { if let team, store.send(.receiverGuess(team, guess)) { guess = "" } }
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
            RoundRecapView()
            if store.isHost {
                Button("NEXT ROUND") { store.startOrNextRound() }.buttonStyle(PartyButton.go)
            } else {
                Text("Waiting for the host to start the next round.").font(CT.font(17, .bold))
            }
        }
    }
}

struct RoundRecapView: View {
    @EnvironmentObject var store: GameStore
    var body: some View {
        if let round = store.state.round, round.phase == .roundOver {
            Text("Answer: \(round.signal)").font(CT.font(24, .bold)).foregroundStyle(CT.ink)
                .multilineTextAlignment(.center).accessibilityIdentifier("round-answer")
            Text("\(store.teamName(round.winner ?? .A)) wins by \(round.winReason == .lockout ? "lockout" : "correct guess")!")
                .font(.headline).multilineTextAlignment(.center)
            if let turn = round.history.last, let guess = (turn.owningAction ?? turn.opposingAction)?.guess {
                Text("Final guess: “\(guess)”").font(.body).multilineTextAlignment(.center)
                    .accessibilityIdentifier("final-guess")
            }
            LastHintsView()
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
                Text("\(store.teamName(store.state.round?.winner ?? .A)) wins the match!")
                    .font(CT.font(30, .black)).foregroundStyle(CT.ink).multilineTextAlignment(.center)
                    .accessibilityIdentifier("match-winner")
                HStack(spacing: 12) {
                    scoreChip(.A)
                    scoreChip(.B)
                }
                RoundRecapView()
                if store.isHost {
                    Button("NEW MATCH") { store.send(.reset) }
                        .buttonStyle(PartyButton(fill: [Color(red: 0.08, green: 0.43, blue: 0.24), Color(red: 0.05, green: 0.35, blue: 0.20)], big: true))
                } else {
                    Text("Waiting for the host to start a new match…")
                        .font(CT.font(15, .medium)).foregroundStyle(CT.inkSoft).multilineTextAlignment(.center)
                }
            }
        }
    }
    func scoreChip(_ t: TeamId) -> some View {
        VStack(spacing: 4) {
            Text(store.teamName(t).uppercased()).font(CT.font(13, .black)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
            Text("\(store.team(t)?.score ?? 0)").font(CT.font(40, .black)).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity).padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: CT.team(t), startPoint: .top, endPoint: .bottom))
                .shadow(color: CT.team(t).last!.opacity(0.35), radius: 6, y: 3)
        )
    }
}

private extension String { var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) } }

struct RulesView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Play with 4–8 nearby phones, with at least two players on each team.")
                    Text("One player hosts. Everyone else enters the host's room code and allows Local Network access. All phones need the same app version.")
                    Text("The host chooses a theme. It sets both the secret words and the illustrated background for everyone—there is no separate category to choose.")
                    Text("Each round, one random player on each team guesses. Everyone else sees the same secret answer. Keep your phone hidden from the guessers.")
                    Text("The active hint giver submits one word. Hyphens and apostrophes are allowed; the answer and close spellings are not. The other team's guesser acts first, then the hint giver's guesser. Either can pass without penalty.")
                    Text("A correct guess wins the round. Each wrong guess adds one Static. Reaching the Static limit gives the round to the other team. Hints alternate between teams and rotate between hint givers.")
                    Text("The first team to the configured number of round wins takes the match. The host starts each round after everyone has had time to read.")
                    Text("If a player disconnects during a match, the match resets to the lobby. Rejoin, rebalance the teams, and start again. If the host leaves, everyone must join a new room.")
                }
                .font(.body).padding()
            }
            .navigationTitle("How to play")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
