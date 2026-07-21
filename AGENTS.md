# Loopy contributor guide

## Project overview

Loopy is a native iPhone habit tracker built with SwiftUI, SwiftData, and Swift Charts. It targets iOS 17 and uses Swift 6 language mode.

The visual reference is `design/loopy.ios.html`, but the app must use native iOS navigation and presentation behavior. Preserve the reference's warm palette, rounded cards, and coral accent without recreating its simulated phone chrome or custom web navigation.

## Source of truth

- `project.yml` is the source of truth for Xcode project configuration.
- Generate `Loopy.xcodeproj` with `xcodegen generate` after changing targets, settings, resources, or source layout.
- Do not hand-edit `project.pbxproj` when the same change can be expressed in `project.yml`.
- Do not commit Xcode user state or `xcuserdata`.

## Code organization

- `Loopy/App`: application entry point and root tab/navigation structure.
- `Loopy/Core`: design tokens and reusable UI helpers.
- `Loopy/Data`: SwiftData models, scheduling rules, and analytics.
- `Loopy/Features`: feature-oriented SwiftUI screens.
- `LoopyTests`: unit tests using Swift Testing.
- `design`: original interactive design reference.

Keep new work feature-oriented. Put reusable business logic in `Data` or a dedicated service rather than embedding it in views.

## Product and UI conventions

- Use native `TabView`, `NavigationStack`, navigation titles, toolbar items, sheets, forms, and system back behavior.
- Use SF Symbols for tab, toolbar, and action icons.
- Use `LoopyTheme.coral` as the primary tint and semantic dynamic colors from `LoopyTheme` for branded surfaces.
- Support Dynamic Type, VoiceOver, dark mode, safe areas, and a minimum 44-point interactive target.
- Do not use color as the only completion indicator.
- Prefer system typography unless a separately licensed brand font is intentionally added.

## Data rules

- A habit's tracking kind and recurrence are independent concepts.
- Persist progress as dated `HabitCheckIn` records; never store only a mutable current completion state on `Habit`.
- Archive habits instead of deleting them so historical statistics remain valid.
- A perfect day means every habit due that day reached its target.
- Days with no scheduled habits do not extend or break a streak.
- An incomplete current day does not break the preceding streak until the day has ended.
- Preserve local calendar-day and time-zone information for check-ins.

When changing models, consider SwiftData migration and future CloudKit compatibility before altering required fields or identity behavior.

### Migration posture

Prefer **additive, optional-friendly** SwiftData changes so existing local stores open without a custom migration stage:

- Add new stored properties with default values in `init` (for example `reminderEnabled`, `reminderHour`, `reminderMinute`).
- Extend enums via new raw-value cases; never reuse or rename existing raw values.
- Keep `Habit.id` and `HabitCheckIn` day identity (`habitID` + `dayKey`) stable — CloudKit and widgets depend on them.
- Do not make previously optional fields required, remove columns, or change property types in place.
- When a breaking schema change is unavoidable, introduce an explicit `VersionedSchema` / `SchemaMigrationPlan` and cover it with tests before enabling CloudKit.
- New integrations (reminders, HealthKit kinds, sync flags) must remain offline-safe: progress still lands in dated `HabitCheckIn` rows.

## Build and test

Generate the project:

```sh
xcodegen generate
```

Build without signing:

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project Loopy.xcodeproj \
  -scheme Loopy \
  -sdk iphonesimulator \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Run tests on an installed simulator, replacing the device name when necessary:

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project Loopy.xcodeproj \
  -scheme Loopy \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

Add or update tests for recurrence, streaks, date boundaries, target calculations, and persistence behavior whenever those areas change. Before handing off a change, regenerate the project and run the most relevant build and tests.

## Current scope

The app includes binary, count, duration, and HealthKit-backed habits (steps / active energy), recurrence, timer sessions, statistics, calendar history with day edits, habit reordering and archive restore, local reminders, achievements, appearance settings, onboarding, App Intents, Home/Lock Screen widgets, private CloudKit sync when available, and local SwiftData persistence (shared via App Group with widgets).

Do not claim a capability in UI copy unless its permissions, privacy strings, and device verification for that capability are in place for the build you are shipping.

