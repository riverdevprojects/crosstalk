# Release preparation

## Verification status

This change has automated coverage for the rules, six theme pools and assets, guest authority, snapshot privacy, delivery failures, acknowledgements and resync. The iOS suite also produces visual review attachments. The implementation uses protocol version 3; all phones in a room must update together.

Device tests and distribution are **not complete** until results are recorded below. A passing simulator suite or unsigned archive does not establish real nearby networking or App Store readiness.

| Check | Evidence to record | Status |
| --- | --- | --- |
| Core and iOS suites | 22 core tests; 40 iOS tests (22 rules, 16 store/content, 2 render cases) | Passed locally, 2026-09-22 |
| Small screen and largest-text renderings | 375×667-point windows; default and accessibility5 text; picker, recap, and bottom controls | Rendered and visually reviewed locally, 2026-09-22 |
| Unsigned Release device archive | Xcode Release archive for generic iOS device | Passed locally, 2026-09-22 |
| Four-phone full match | Devices, OS versions, build, result | Needs physical devices |
| Eight-phone full match | Devices, OS versions, build, result | Needs physical devices |
| Lock/background/force-close/rejoin | Each active role and host; results | Needs physical devices |
| Network permission denial and retry | Fresh install, settings recovery, result | Needs physical devices |
| Interactive VoiceOver and keyboard | Small and large iPhone; reach every control | Needs interactive acceptance |
| Signed Release archive | Team, version/build, archive validation | Needs developer account |
| TestFlight smoke test | Installed build, devices, full match | Needs developer account and testers |

Local iOS tests ran on the iPhone 17 Pro / iOS 26.2 simulator. The 375×667 renderings are constrained test windows, not evidence of a run on an iPhone 8 or iOS 16 device. Artwork prompts and bundled paths are in [theme-art.json](theme-art.json).

Follow every scenario in [TESTING.md](TESTING.md). For each physical run, record build, phone models, OS versions, player count, theme, scenario, result, and any reproducible steps. Do not mark a row passed without running it.

## Archive

Compile an unsigned device archive locally:

```sh
xcodebuild -project Crosstalk.xcodeproj -scheme Crosstalk -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/Crosstalk.xcarchive \
  CODE_SIGNING_ALLOWED=NO archive
```

For distribution, open the project in Xcode, choose your development team, set the release version/build number, select a generic iOS device, and use Product → Archive. Validate the signed archive and upload from Organizer with the owner's account. The repository does not include signing credentials or a chosen development team.

## App Store copy draft

Name: **Crosstalk**

Subtitle: **One-word clues. Two rival teams.**

Promotional text: **Gather 4–8 friends, pick an illustrated world, and race to decode the secret word. Each player joins on their own iPhone.**

Description:

> Turn game night into a battle of one-word clues. In Crosstalk, two teams share a secret answer—but only the hint givers can see it. Give a clever hint, let the opposing guesser act first, and see which team cracks the word.
>
> Explore six illustrated worlds: Castle & Myth, Deep Space, Pirate Seas, Wild Kingdom, Food Market, and City Lights. Each world brings its own set of words and scenery, with 420 word entries across the game.
>
> Choose your match length and Static limit. Pass for free, risk a guess, or watch a wrong answer bring the other team closer to victory.
>
> Play with 4–8 nearby people, each with their own iPhone. One player hosts; everyone else enters the room code. No account or internet connection is needed for play. Keep Wi-Fi and Bluetooth enabled and allow Local Network access. All players need the same app version.

Keywords draft: **party,word,clues,teams,friends,guess,offline,local,multiplayer,game night**

Before submission the owner must provide the support URL, privacy-policy URL, copyright/contact details, age-rating answers, distribution territories, and pricing. Review the copy against the final shipping build.

## Privacy behavior for the owner to verify

The inspected build has no analytics, advertising SDK, account system, or remote backend. Player names and game state are exchanged with nearby peers using MultipeerConnectivity. The host processes guesses locally and sends role-specific state. Nothing in this implementation uploads match data to a developer-operated server. Data persists only in memory during the session. Use these implementation facts when completing the store privacy questions and your public privacy policy; verify them again if SDKs or services are added.

## Screenshot shot list

Capture the real release build at the device sizes required by the store:

1. Theme picker with the illustrated worlds.
2. Lobby with two balanced teams and a room code.
3. Hint giver screen against Castle & Myth scenery.
4. Guesser screen with current hint and hint history.
5. Match winner, final answer, and scores.

The generated scene art and unit-test renderings are review assets, not proof of a signed release or final store screenshots. Use only test player names and a disposable room for marketing captures.
