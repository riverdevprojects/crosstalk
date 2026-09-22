# Crosstalk

A native SwiftUI iPhone party word game for 4–8 nearby players, using MultipeerConnectivity. Each player needs their own phone. No account or internet connection is required for play.

## Build and run

Open `Crosstalk.xcodeproj` in Xcode 16+, select the shared **Crosstalk** scheme, and run on an iPhone or simulator. The deployment target is iOS 16.0; iPhone 8 and newer are supported. For physical devices, select your development team under Signing & Capabilities. The bundle ID is `com.riverdevprojects.crosstalk`.

Allow Local Network access when prompted. Keep Wi‑Fi and Bluetooth enabled and the phones nearby. All players must run the same app version: the current multiplayer protocol is version 3 and rejects older clients.

## Play

1. Enter a name (1–32 characters). One player creates a room; everyone else enters its four-character code.
2. The host chooses a theme, match length, and Static limit. The theme sets both the word pool and illustrated background on every phone. Each team needs at least two players.
3. Each round randomly chooses a guesser on each team. The other players see the secret answer. Keep those screens private.
4. The host checks that everyone has read their role, then starts. The active hint giver submits one word. The opposing guesser acts first, followed by the hint giver's team. Passing costs nothing.
5. A correct guess wins the round. An incorrect guess adds a Static; reaching the limit awards the round to the other team. After both guessers act, hint giving switches teams and rotates between that team's hint givers.
6. The host starts the next round when everyone is ready. The first team to the selected number of round wins wins the match.

The **How to play** button is available throughout the app. See [game rules](docs/RULES.md) for clue and answer matching details.

## Connection and recovery behavior

- Joining times out after 20 seconds and offers retry. If discovery fails, check the room code and Local Network access under iOS Settings.
- Players can leave from the lobby or during play. If someone leaves/disconnects during a match, the host resets the match to the lobby and removes that player. Scores are reset deliberately so missing roles cannot strand a turn. Rejoin, rebalance teams, and start again.
- If the host leaves or the host connection is lost, guests see a recovery screen. There is no host migration or saved-match recovery.
- New players join only in the lobby. The maximum room size is eight phones including the host.
- The host validates sender identity, role, phase, and snapshot revision before applying guest actions. Receiver snapshots exclude the secret signal, answer aliases, and used-word list. The host remains trusted because it runs the authoritative engine locally.
- Each of the six themes has 70 words: Castle & Myth, Deep Space, Pirate Seas, Wild Kingdom, Food Market, and City Lights. There is no separate category. A match can start only if its theme has enough unique words for every possible round. Returning to the lobby resets the used-word list.
- Snapshots are acknowledged and retried every two seconds, up to eight retries. Transient delivery problems show a banner without hiding the game. Sync game requests/resends the latest personalized state and restarts retries. Foregrounding the app also requests a refresh. Guesses and passes are never automatically replayed.
- The match-ending screen shows the winning team, final answer, final guess, win reason, and scores. Returning to the lobby during play requires confirmation.

## Tests

Run the Foundation-only rule and permission tests on macOS:

```sh
swift test
```

Run the same tests plus iOS store/network-message integration tests on an available simulator:

```sh
./scripts/test-ios.sh
```

GitHub Actions runs both suites on pushes and pull requests. Tests cover phase transitions, scoring, lockouts, rotation, input limits, permissions, stale messages, disconnect/rejoin, snapshot privacy, theme capacity, failed snapshot delivery, acknowledgements, and resync privacy. A simulator does not replace a physical multi-phone playtest; see [release checks](docs/TESTING.md).

## Assets

The app icon uses the existing signal motif and party palette. Regenerate all required sizes on macOS with `swift scripts/generate-icon.swift`. Word content is in `Crosstalk/Resources/party-core.json`. Each word belongs to exactly one theme in `ThemeDefinition`; there is no category field. Each world has an original bundled portrait illustration. The built-in image generation prompts and asset paths are recorded in [theme-art.json](docs/theme-art.json).

The iOS suite also attaches small-screen and accessibility-size renderings to its `.xcresult` bundle for visual review. These do not replace interactive VoiceOver or keyboard testing. See [release preparation](docs/RELEASE.md) for unsigned archive verification, device acceptance tests, and store-copy drafts.
