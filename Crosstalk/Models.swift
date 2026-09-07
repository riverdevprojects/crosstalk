import Foundation

enum TeamId: String, Codable, CaseIterable { case A, B }
enum Phase: String, Codable { case roleReveal, awaitingClue, opposingDecision, owningDecision, roundOver }
enum Status: String, Codable { case lobby, inRound, matchOver }
enum WinReason: String, Codable { case correctGuess, lockout }

struct Player: Identifiable, Codable, Equatable { var id = UUID().uuidString; var name: String; var team: TeamId }
struct TeamState: Codable, Equatable { var id: TeamId; var receiverId: String; var transmitterOrder: [String]; var rotationIndex = 0; var statics = 0; var score = 0 }
struct TurnRecord: Codable, Equatable { var clueingTeam: TeamId; var transmitterId: String; var opposingAction: GuessAction?; var owningAction: GuessAction? }
struct GuessAction: Codable, Equatable { var guess: String?; var correct: Bool; var passed: Bool { guess == nil } }
struct RoundState: Codable, Equatable { var signal: String; var acceptedAnswers: [String]; var clueingTeam: TeamId; var phase: Phase; var history: [TurnRecord] = []; var winner: TeamId?; var winReason: WinReason?; var announcement: String? }
struct GameConfig: Codable, Equatable { var maxStatics = 2; var roundsToWin = 3; var wordPack = "party-core" }
struct GameState: Codable, Equatable { var players: [Player] = []; var teams: [TeamId: TeamState] = [:]; var round: RoundState?; var roundNumber = 0; var config = GameConfig(); var status: Status = .lobby; var usedSignals: Set<String> = [] }
struct WordEntry: Codable, Equatable { let signal: String; let accepted: [String]; let difficulty: Int }
struct WordPack: Codable, Equatable { let id: String; let name: String; let words: [WordEntry] }
