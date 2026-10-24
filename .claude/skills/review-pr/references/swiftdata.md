# SwiftData review checklist

The project uses a versioned schema (`Data/Persistence/SchemaV1.swift`, `CalTrackerMigrationPlan.swift`) and the `FoodLogEntry` model. It doesn't use CloudKit. Review priorities, from most to least important: data loss, mass deletes, broken migrations, context isolation, and only then style.

## Schema changes (the most important check)

Any diff that changes a stored property of an `@Model` (adding, removing, renaming, changing its type or optionality, changing a relationship or `@Attribute` options) is a schema change:

- Once a version has shipped, editing `SchemaV1`'s models in place breaks existing stores. The change needs a new `VersionedSchema` (`SchemaV2`) with a new `versionIdentifier`, listed in `CalTrackerMigrationPlan.schemas`, plus a `MigrationStage` in `stages`. Use `.lightweight` for additive or optional changes, and `.custom` when data must be transformed.
- A missing stage is **High**. If it makes the container fail to open on existing installs, it's **Critical**, because `AppModelContainer` calls `fatalError` and the app crashes on launch.
- A renamed property needs `@Attribute(originalName:)`, or a custom stage. Without one, the old values are dropped.
- A new non-optional property needs a default value, or existing rows can't migrate.
- Make sure `AppModelContainer` and any type aliases point at the latest schema's models.
- Unit tests use in-memory containers, which skip the migration plan on purpose, so they **won't** catch a missing stage. Ask for a migration check or a manual upgrade test from the previous build. Flag that as not checked if it's missing.

## Models

- Don't name a property `description`. It's disallowed.
- Property observers (`didSet`) on `@Model` are silently ignored.
- `@Transient` needs a default and resets on every fetch. A computed property is usually better.
- Stored enums must be `Codable`. Enums with associated values are fine.
- Relationships:
  - Put `@Relationship` on **one side** only.
  - Give it an explicit `deleteRule:`. The default `.nullify` can orphan rows or crash with a non-optional inverse.
  - Give it an explicit `inverse:`.
- Use one `#Unique` per model, with multiple key paths in one macro. Uniqueness turns an insert into an upsert, so make sure that's intended.
- `#Index` speeds reads but slows writes. Food logging writes often and reads by day, so an index on the date property can be justified. An index on everything can't.
- `PersistentIdentifier` is temporary until the first save. Don't store or compare IDs before `save()`.

## Contexts, saving and deleting

- View models write through `FoodLogging` (`FoodLogStore`), never through `ModelContext` directly.
- Call `save()` explicitly after changes that matter. Autosave timing is unpredictable. There's no need to check `hasChanges` first.
- `save()` throws. The error must reach the user through `userMessage(for:)`, not be swallowed with `try?`.
- `ModelContext` and model instances never cross actors. For background work, use a `@ModelActor` or a dedicated context, and pass `PersistentIdentifier`s.
- A delete with a predicate (`delete(model:where:)`) needs a tight predicate. Check what happens with an empty or nil filter: could it delete every entry? An unbounded delete is Critical.
- Undo, edit and delete flows should work on the same context the UI reads from.

## Queries and predicates

Some predicates compile and then crash or fail at runtime:

- `$0.items.isEmpty == false` crashes. Use `!$0.items.isEmpty`.
- Computed properties, `@Transient` properties and fields inside `Codable` structs in a predicate compile, then crash.
- Regex in a predicate compiles, then fails.
- Not supported (won't compile): `hasPrefix` (use `starts(with:)`), `hasSuffix`, `lowercased()`, `map`, `reduce`, `count(where:)`, `first`, and custom operators.
- Text search uses `localizedStandardContains()`.
- Day boundaries: compute the start and end dates outside the predicate with the user's calendar and time zone, then compare stored dates in the predicate. Don't call `Calendar` inside it.

Other query rules:

- `@Query` works only inside SwiftUI views. In a view model or store, use `FetchDescriptor` with `modelContext.fetch`.
- Use explicit `sortBy` for deterministic ordering, and a `fetchLimit` for "recent" lists.
- Use `propertiesToFetch` and `relationshipKeyPathsForPrefetching` when a fetch is hot.
- `fetchCount()` doesn't update live. Make sure something else triggers a refresh.
- Filter in the predicate, not with in-memory `.filter` over a fetch of everything.

## Tests

- Use a fresh `AppModelContainer.make(inMemory: true)` per test. Never share one across tests.
- Tag tests `.persistence`.
- Cover insert, fetch for a day, update, delete, and the error path.
