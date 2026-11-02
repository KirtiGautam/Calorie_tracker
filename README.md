# Gramwise

A calorie and macro tracker for iPhone and iPad. Search for a food, log how many grams you ate, and see how your day stacks up against your targets.

## Features

- **Food search** across [USDA FoodData Central](https://fdc.nal.usda.gov) (whole foods) and [Open Food Facts](https://world.openfoodfacts.org) (packaged products). Both sources are queried in parallel, and if one fails the other's results still show. More results load as you scroll, and Open Food Facts products can be filtered by country (defaulting to your region) and brand, while USDA whole foods always appear.
- **Log by weight.** Enter grams or tap a preset, and the nutrients are scaled for you.
- **Today at a glance.** Energy, protein, carbs and fat with progress bars against your targets, plus a micronutrient breakdown and a line of encouragement based on how your day is going.
- **Look back.** Swipe or tap the arrows to step through earlier days you logged food on.
- **Daily targets.** Enter them yourself, or have them suggested from your body profile, activity level and goal (cut, maintain or bulk) using the Mifflin-St Jeor equation.
- **Local first.** Your log is stored on device with SwiftData and works fully offline.
- **An account is optional.** Create one from the cloud on Today to back up your log and targets to the Gramwise backend (`backend/`) and get them back on a new device or after a reinstall. The cloud shows the state: a red outline when there's no account, a spinner while syncing, green when up to date, and orange with a badge when the last sync failed. Your body profile never leaves the device.

## Requirements

- Xcode 27.1 or later
- iOS / iPadOS 27.0 or later
- Swift 6 with strict concurrency

The app has no third-party dependencies.

## Getting started

1. Clone the repository and open `CalTracker.xcodeproj`.
2. Pick the **CalTracker** scheme and a simulator, then build and run.

### USDA API key (optional)

The app works out of the box with USDA's public `DEMO_KEY`, which is heavily rate limited. To use your own free key:

1. Sign up at <https://fdc.nal.usda.gov/api-key-signup>.
2. Copy `Config/Secrets.xcconfig.example` to `Config/Secrets.xcconfig`.
3. Set `USDA_API_KEY` in the new file.

`Config/Secrets.xcconfig` is gitignored. Never commit it.

Open Food Facts doesn't need a key.

### Backend (optional)

Accounts and sync talk to the FastAPI service in [`backend/`](backend/README.md). By default the app expects it on this Mac at `http://localhost:8000`, which the simulator can reach. Start it with `docker compose up --build` in `backend/`, which also applies the database migrations. To point the app at a deployed backend, set `GRAMWISE_API_BASE_URL` in `Config/Secrets.xcconfig`, writing `//` as `/$()/` because xcconfig treats `//` as a comment:

```
GRAMWISE_API_BASE_URL = https:/$()/api.example.com
```

Without a reachable backend the app works as before. The cloud just stays red, or turns orange if you were signed in.

## Running tests

Unit tests use Swift Testing and never touch the network:

```sh
xcodebuild test \
  -project CalTracker.xcodeproj \
  -scheme CalTracker \
  -destination 'platform=iOS Simulator,name=iPhone Duo' \
  -only-testing:CalTrackerTests \
  -collect-test-diagnostics never
```

UI tests live in `CalTrackerUITests` and drive the real app against the **live** food APIs, so they need a network connection and can be slow or flaky when an API is down. Run them with `-only-testing:CalTrackerUITests`.

Swap `iPhone Duo` for any simulator you have installed (`xcrun simctl list devices available`).

## Project structure

```
CalTracker/
  App/          App entry point, SwiftData container, dependency wiring
  Domain/       Plain value types and logic: nutrients, targets, totals, goals
  Data/         USDA and Open Food Facts clients, combined search, persistence, targets storage,
                the Gramwise backend client, account session, food lookup and sync engine
  Features/     SwiftUI screens and their view models, one folder per feature
    Today/        Root screen with totals and the day's log
    FoodSearch/   Search across both sources
    LogFood/      Choose an amount and log it
    Targets/      Edit targets or calculate them from a body profile
    Account/      Create an account, sign in, and manage sync
    Shared/       Views used by several features
  Resources/    Asset catalog, Info.plist, string catalog
CalTrackerTests/    Unit tests, mirroring the app's folders, plus fixtures and test doubles
CalTrackerUITests/  End-to-end UI flows
Config/             Build settings and the optional secrets file
backend/            FastAPI + Supabase Postgres service for accounts and sync
```

## Contributing with AI agents

See [AGENTS.md](AGENTS.md) for build commands, conventions and gotchas aimed at coding agents. [SKILL.md](SKILL.md) holds the detailed Swift and SwiftUI guidelines the code follows.
