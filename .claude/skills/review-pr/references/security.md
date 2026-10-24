# Security and privacy review checklist

Gramwise stores personal health data (food logs, body profile, goals) on device and calls two public APIs. It has no accounts or backend. Keep findings proportionate. There's no auth surface to review, but health data and the API key still matter.

## Secrets

- `Config/Secrets.xcconfig` must not be in the diff. A real USDA key must not appear in any tracked file: Swift, plist, xcconfig, fixtures, tests or docs. Either is **Critical**, and the key must be rotated, not just deleted, because git history keeps it.
- The key reaches code only through `Info.plist` (`USDAAPIKey`) from `USDA_API_KEY`. `DEMO_KEY` in `Base.xcconfig` is fine.
- The USDA key travels in the request URL (`api_key=`). Any new logging of request URLs, `URLRequest` descriptions or error messages that embed the URL leaks it. That's a finding.
- Test fixtures must not contain real keys copied from captured responses.

## Logging

- No `print` in app code. If diagnostics are needed, use `Logger` (OSLog) with a subsystem and category.
- Interpolated values that come from the user or contain health data (food names, quantities, weight, targets) need `privacy: .private`. A non-sensitive value can be `.public`, but nothing should default to public by accident.
- Don't log full response bodies.

## Data at rest

- Food logs live in SwiftData, and targets and profile in `UserDefaults` under `targets.*`. That's acceptable for non-secret preferences.
- Any credential or token (for example, if a PR adds a user-supplied API key field) must go in the **Keychain**, never `UserDefaults`, `@AppStorage`, a plist or a file. If a PR adds Keychain code, check the following:
  - an explicit `kSecAttrAccessible` value (for example `AfterFirstUnlockThisDeviceOnly`);
  - `errSecDuplicateItem` handled with an update;
  - `errSecItemNotFound` handled;
  - every `OSStatus` checked;
  - no `SecItem*` calls on the main actor.
- Exports and shares (CSV, share sheet) contain health data. Write them to a temporary directory, not a world-readable location, and make sure the user starts them.

## Untrusted remote data (USDA and Open Food Facts)

Open Food Facts data is user-contributed and often incomplete or wrong. Treat every field as untrusted:

- Decoding must tolerate missing, null, string-typed or extra fields without failing the whole response. One bad product shouldn't hide every result.
- Validate numbers before they reach totals:
  - Reject or clamp negative values, NaN, infinity and absurd magnitudes (for example a 100 g serving with 90,000 kcal).
  - Make sure division by a zero serving size can't happen.
  - Check that unit conversions (kJ to kcal, mg to g, per serving to per 100 g) are right.
- Check HTTP status before decoding. Non-2xx responses and rate limiting (USDA `DEMO_KEY` returns 429) map to a clear user message through `userMessage(for:)`.
- Strip or escape text from remote sources before using it in anything interpreted (URLs, predicates, attributed strings with links).

## Building requests

- All endpoints use `https`. A new `http://` URL, or an `NSAppTransportSecurity` exception in Info.plist, is High unless the PR justifies it.
- Build URLs with `URLComponents` and `setStrictlyEncodedQueryItems(_:)`, never by interpolating user input into a URL string. Barcodes are digits only, so validate them before use.
- Set reasonable timeouts. Don't retry in a tight loop, which against a rate-limited `DEMO_KEY` causes a retry storm.

## Platform and privacy manifest

- `CalTracker/Resources/PrivacyInfo.xcprivacy` declares no tracking, no collected data, and `UserDefaults` with reason `CA92.1`. If a PR adds another required-reason API (file timestamps, system boot time, disk space, active keyboards), a new reason for an existing one, tracking or analytics SDKs, or data that leaves the device beyond answering a search, the manifest must be updated in the same PR. A missing update is Medium.
- New entitlements or Info.plist usage descriptions (camera for barcode scanning, HealthKit) need a clear, localized purpose string. HealthKit also needs the entitlement and per-type authorization handling, including denial.
- `@AppStorage` must never hold anything sensitive.
