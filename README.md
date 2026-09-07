# Crosstalk

Native iPhone party word game based on `crosstalk-gdd.md`.

## Build

Open `Crosstalk.xcodeproj` in Xcode 16+, select an iPhone 8-or-newer simulator/device, and run.

- Deployment target: iOS 16.0 (iPhone 8 supported)
- Bundle id: `com.riverdevprojects.crosstalk`
- Native SwiftUI app, no web wrapper

## Included

- Pure Swift rule engine and deterministic guess matcher
- Native lobby/player setup
- Team assignment, receiver/transmitter rotation, alternating openers
- Role reveal, clue, ordered receiver decision, round over, match over screens
- Static announcements and confirmation before spending a guess
- JSON word pack loaded at startup

This first commit is a local/native playable build. The engine is isolated so local networking or remote mode can be added without rewriting the rules.
