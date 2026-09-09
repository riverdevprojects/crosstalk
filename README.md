# Crosstalk

Native iPhone party word game based on `crosstalk-gdd.md`.

## Build

Open `Crosstalk.xcodeproj` in Xcode 16+, select an iPhone 8-or-newer simulator/device, and run.

- Deployment target: iOS 16.0 (iPhone 8 supported)
- Bundle id: `com.riverdevprojects.crosstalk`
- Native SwiftUI app, no web wrapper

## Included

- Pure Swift rule engine and deterministic guess matcher
- Nearby phone-to-phone multiplayer using MultipeerConnectivity (Bluetooth / peer-to-peer Wi‑Fi / local Wi‑Fi)
- Paged flow: welcome/loading, name + host/join, dedicated host and join pages
- Host/join by room code: the host gets a 4-character code others type in to join
- Keeps the phone awake while the app is open
- Theme-specific team backgrounds and role names
- Host chooses the theme and category (no captains, no voting)
- Host-only settings/team/player controls
- Each round randomly picks the guessing player (the one who doesn't know the word) on each team
- Custom team names and editable player names
- Written hint submission and hint history
- Typed guesses with confirmation
- Native lobby/player setup
- Team assignment, transmitter rotation, alternating openers
- Role reveal, clue, ordered receiver decision, round over, match over screens
- Static announcements and confirmation before spending a guess
- JSON word pack loaded at startup

This build is native and locally networked for in-person play. The host phone is authoritative and broadcasts state to joined phones.
