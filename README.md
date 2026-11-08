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

### Backend

USDA food search, accounts and sync talk to the FastAPI service in [`backend/`](backend/README.md). By default the app expects it on this Mac at `http://localhost:8000`, which the simulator can reach. Start it with `docker compose up --build` in `backend/`, which also applies the database migrations. To point the app at a deployed backend, copy `Config/Secrets.xcconfig.example` to `Config/Secrets.xcconfig` (gitignored, never commit it) and set `GRAMWISE_API_BASE_URL`, writing `//` as `/$()/` because xcconfig treats `//` as a comment:

```
GRAMWISE_API_BASE_URL = https:/$()/api.example.com
```

The backend holds the USDA API key, so the app doesn't have one. Set `USDA_API_KEY` in `backend/.env` ([get a free key](https://fdc.nal.usda.gov/api-key-signup)). Open Food Facts doesn't need a key, and the app calls it directly.

Without a reachable backend the app still works. Your log stays on the device and Open Food Facts search works, but USDA results show an inline error. The cloud stays red, or turns orange if you were signed in.

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

UI tests live in `CalTrackerUITests` and drive the real app against the **live** food APIs, so they need a network connection and can be slow or flaky when an API is down. USDA results come through the backend, so have it running too. Run them with `-scheme CalTrackerUITests` instead of `-only-testing:CalTrackerTests`.

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
backend/            FastAPI + Supabase Postgres service for accounts, sync and USDA food search
```

## Contributing with AI agents

See [AGENTS.md](AGENTS.md) for build commands, conventions and gotchas aimed at coding agents. [SKILL.md](SKILL.md) holds the detailed Swift and SwiftUI guidelines the code follows.
