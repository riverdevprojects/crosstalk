# Release verification

## Automated

- `swift test`: pure rules, scoring, role/phase permissions, snapshots, input validation, and category selection.
- `./scripts/test-ios.sh`: the above plus GameStore message handling, peer-to-player identity binding, stale/unregistered action rejection, disconnect/reset/rejoin, and nested connection status publication.
- Builds use the iOS 16 deployment target. The runtime test device is whichever available iPhone simulator the script selects.

## Physical devices — required before release

These checks need real nearby phones and cannot be inferred from simulator unit tests:

- Four phones join, split 2/2, and finish a full match; repeat at eight phones.
- Both teams' receivers never see the secret before round end. Hints and history appear on both decision turns.
- Background/lock/force-close the active hint giver, receiver, and host in separate runs. Verify recovery screens, lobby reset, and rejoin without duplicate players.
- Leave from the lobby and during a match. Confirm roster removal and the reset explanation on remaining phones.
- Deny Local Network permission, use a wrong/short code, turn connectivity off, retry, and join with an older app version.
- Submit twice quickly; submit while another phone changes the game; ensure only one action/point is accepted.
- Host changes names, teams, theme and category; guests cannot change host controls or another player's name.
- Check all four themes, unavailable categories, and a completed best-of-seven match.

## Accessibility and layout

- Check a small iPhone (SE / iPhone 8 size) and a larger iPhone with default and largest accessibility text sizes. All pages scroll and form/buttons must remain reachable.
- With VoiceOver, check field names, increase/decrease controls, team movement controls, current hint, and score/Static readings. Decorative background shapes must not be announced.
- Enable Reduce Motion before launch and while running. Background and logo movement must stop, and the welcome animation must be skipped when enabled at launch.
- Review foreground/background contrast, keyboard coverage, long player/team names, and portrait layout.

## Distribution

The icon catalog includes iPhone and App Store artwork. Configure the signing team and verify a Release archive on your developer account before TestFlight. App Store metadata, screenshots, and device playtests are release work, not evidence supplied by an unsigned simulator build.
