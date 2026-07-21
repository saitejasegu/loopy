# Loopy

Loopy is a native iPhone habit tracker for building consistent daily routines. It translates the warm, card-based concept in [`design/loopy.ios.html`](design/loopy.ios.html) into a native SwiftUI application with standard iOS navigation and controls.

## Current features

- Native four-tab navigation for Today, Stats, History, and Profile
- Binary, countable, timed, and Apple Health habits (steps + active energy)
- Daily and selected-weekday recurrence
- Persistent timer sessions and dated check-ins
- Habit creation, editing, archiving/restore, reordering, increments, and resets
- Historical check-in edits from the day-detail screen
- Local reminders with notification permission handling
- Achievements derived from real streak / perfect-day progress
- Current streak and perfect-day calculations
- 30-day and one-year Swift Charts views
- Monthly completion calendar with day details
- First-launch onboarding
- System, light, and dark appearance settings
- App Intents / Shortcuts check-ins
- Home Screen and Lock Screen widgets (App Group shared store)
- Private iCloud / CloudKit sync when the account is available
- Local-first SwiftData persistence
- VoiceOver labels and Dynamic Type-compatible layouts

## Technology

- Swift 6
- SwiftUI
- SwiftData
- Swift Charts
- WidgetKit
- App Intents
- HealthKit
- UserNotifications
- Swift Testing + XCTest UI tests
- XcodeGen

## Requirements

- Xcode 26 or newer
- iOS 17 or newer
- XcodeGen (`brew install xcodegen`)
- Apple Developer capabilities for App Groups, HealthKit, and iCloud (CloudKit) when signing for device

## Getting started

Generate the Xcode project from `project.yml` (required after pulling — widget and UI test targets live here):

```sh
xcodegen generate
open Loopy.xcodeproj
```

Choose an iPhone simulator or a signing-enabled physical device and run the `Loopy` scheme.

`project.yml` is the source of truth for project configuration. Regenerate the project after adding source files, resources, targets, or build settings instead of editing `project.pbxproj` manually.

## Command-line build

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project Loopy.xcodeproj \
  -scheme Loopy \
  -sdk iphonesimulator \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Tests

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project Loopy.xcodeproj \
  -scheme Loopy \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

Unit tests cover recurrence, count/duration progress, perfect days, streak rules (including incomplete today and empty due days), archive windows, DayKey calendars, and achievements. UI tests cover launch and opening the new-habit sheet.

## Project structure

```text
Loopy/
├── App/                 App entry, tabs, model container
├── Core/                Theme tokens and reusable view styling
├── Data/                Models, analytics, check-in service, reminders, HealthKit, persistence
├── Features/
│   ├── Archive/         Archived habits manager
│   ├── HabitEditor/     Create and edit form
│   ├── History/         Calendar and editable day details
│   ├── Onboarding/      First-launch guidance
│   ├── Profile/         Name, achievements, appearance, sync
│   ├── Reminders/       Per-habit notification settings
│   ├── Stats/           Completion metrics and charts
│   └── Today/           Daily dashboard, check-ins, timer, reorder
├── Intents/             App Intents / Shortcuts
└── Resources/           Asset catalog + entitlements

LoopyWidget/             WidgetKit extension
LoopyTests/              Swift Testing unit tests
LoopyUITests/            XCTest UI tests
docs/                    Privacy, accessibility, App Store drafts
design/                  Original interactive HTML reference
project.yml              XcodeGen project definition
```

## Core behavior

Tracking type and recurrence are modeled independently, allowing any habit to run daily or only on selected weekdays. Progress is stored as dated check-ins so edits to today's state never erase history. Archived habits retain their historical contribution. Health-backed habits sync quantities into the same check-in store.

A streak counts consecutive perfect scheduled days. Days with no due habits are skipped, and an incomplete current day does not break the streak before the day ends.

## Docs

- [`docs/PRIVACY.md`](docs/PRIVACY.md) — privacy policy draft
- [`docs/ACCESSIBILITY.md`](docs/ACCESSIBILITY.md) — a11y checklist
- [`docs/APP_STORE.md`](docs/APP_STORE.md) — store listing draft

See [`AGENTS.md`](AGENTS.md) for repository-specific implementation conventions.
