import Foundation

enum TeamId: String, Codable, CaseIterable { case A, B }
enum Phase: String, Codable { case roleReveal, awaitingClue, opposingDecision, owningDecision, roundOver }
enum Status: String, Codable { case lobby, inRound, matchOver }
enum WinReason: String, Codable { case correctGuess, lockout }

struct Player: Identifiable, Codable, Equatable { var id = UUID().uuidString; var name: String; var team: TeamId }

enum NetworkMode: String, Codable { case offline, hosting, joining }
struct TeamState: Codable, Equatable { var id: TeamId; var receiverId: String; var transmitterOrder: [String]; var rotationIndex = 0; var statics = 0; var score = 0 }
struct TurnRecord: Codable, Equatable { var clueingTeam: TeamId; var transmitterId: String; var clueText: String?; var opposingAction: GuessAction?; var owningAction: GuessAction? }
struct GuessAction: Codable, Equatable { var guess: String?; var correct: Bool; var passed: Bool { guess == nil } }
struct RoundState: Codable, Equatable { var signal: String; var acceptedAnswers: [String]; var clueingTeam: TeamId; var phase: Phase; var history: [TurnRecord] = []; var winner: TeamId?; var winReason: WinReason?; var announcement: String? }
struct GameConfig: Codable, Equatable { var maxStatics = 2; var roundsToWin = 3; var wordPack = "party-core"; var teamNames: [TeamId: String] = [.A: "Team A", .B: "Team B"]; var themeId = "signal"; var category = "Everything" }
struct GameState: Codable, Equatable { var players: [Player] = []; var teams: [TeamId: TeamState] = [:]; var round: RoundState?; var roundNumber = 0; var config = GameConfig(); var status: Status = .lobby; var usedSignals: Set<String> = []; var revision = 0; var notice: String? }
struct WordEntry: Codable, Equatable { let signal: String; let accepted: [String]; let difficulty: Int; let category: String?; let theme: String? }
struct WordPack: Codable, Equatable { let id: String; let name: String; let words: [WordEntry] }

// Only the authoritative host keeps answer aliases and the complete used-word set.
extension GameState {
    func visible(to playerId: String) -> GameState {
        var copy = self
        copy.usedSignals = []
        copy.round?.acceptedAnswers = []
        if round?.phase != .roundOver {
            let player = players.first { $0.id == playerId }
            if player == nil || teams[player!.team]?.receiverId == playerId {
                copy.round?.signal = ""
            }
        }
        return copy
    }
}

enum InputRules {
    static let roomAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    static func validRoomCode(_ code: String) -> Bool {
        code.count == 4 && code.allSatisfy { roomAlphabet.contains($0) }
    }
    static func validName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 32 && !trimmed.contains(where: { $0.isNewline })
    }
    static func validGuess(_ guess: String) -> Bool {
        guess.count <= 80 && !GuessMatcher.normalize(guess).isEmpty
    }
    static func clueError(_ clue: String, answers: [String]) -> String? {
        let word = clue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty, word.count <= 40,
              word.allSatisfy({ $0.isLetter || $0 == "-" || $0 == "'" }),
              word.first?.isLetter == true, word.last?.isLetter == true else {
            return "Use one word of up to 40 letters. Hyphens and apostrophes are allowed."
        }
        if GuessMatcher.isCorrect(word, accepted: answers) {
            return "Your hint cannot be the answer or a close spelling of it."
        }
        return nil
    }
}

enum WordSelection {
    static func pool(in pack: WordPack, config: GameConfig) -> [WordEntry] {
        pack.words.filter {
            ($0.theme ?? "signal") == config.themeId &&
            (config.category == "Everything" || $0.category == config.category)
        }
    }
    static func available(in pack: WordPack, state: GameState) -> [WordEntry] {
        pool(in: pack, config: state.config).filter { !state.usedSignals.contains($0.signal) }
    }
}
