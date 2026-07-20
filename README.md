# Loopy

Loopy is a native iPhone habit tracker for building consistent daily routines. It translates the warm, card-based concept in [`design/loopy.ios.html`](design/loopy.ios.html) into a native SwiftUI application with standard iOS navigation and controls.

## Current features

- Native four-tab navigation for Today, Stats, History, and Profile
- Binary, countable, and timed habits
- Daily and selected-weekday recurrence
- Persistent timer sessions and dated check-ins
- Habit creation, editing, archiving, increments, and resets
- Current streak and perfect-day calculations
- 30-day and one-year Swift Charts views
- Monthly completion calendar with day details
- System, light, and dark appearance settings
- Local-first SwiftData persistence
- VoiceOver labels and Dynamic Type-compatible layouts

HealthKit, reminders, iCloud sync, widgets, and achievements are planned but are not part of the current build.

## Technology

- Swift 6
- SwiftUI
- SwiftData
- Swift Charts
- Swift Testing
- XcodeGen

## Requirements

- Xcode 26 or newer
- iOS 17 or newer
- XcodeGen (`brew install xcodegen`)

## Getting started

Generate the Xcode project from `project.yml`:

```sh
xcodegen generate
open Loopy.xcodeproj
```

Choose an iPhone simulator or a signing-enabled physical device and run the `Loopy` scheme.

`project.yml` is the source of truth for project configuration. Regenerate the project after adding source files, resources, targets, or build settings instead of editing `project.pbxproj` manually.

## Command-line build

The explicit Xcode path works even when `xcode-select` points to Command Line Tools:

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

Run the unit tests on an available simulator:

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project Loopy.xcodeproj \
  -scheme Loopy \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

The current suite covers recurrence selection, count-target completion, and perfect-day analytics.

## Project structure

```text
Loopy/
├── App/                 App entry point and native tab navigation
├── Core/                Theme tokens and reusable view styling
├── Data/                SwiftData models, recurrence, and analytics
├── Features/
│   ├── HabitEditor/     Create and edit form
│   ├── History/         Calendar and day details
│   ├── Profile/         Name, appearance, and summary
│   ├── Stats/           Completion metrics and charts
│   └── Today/           Daily dashboard, check-ins, and timer
└── Resources/           Asset catalog

LoopyTests/              Swift Testing unit tests
design/                  Original interactive HTML reference
project.yml              XcodeGen project definition
```

## Core behavior

Tracking type and recurrence are modeled independently, allowing any habit to run daily or only on selected weekdays. Progress is stored as dated check-ins so edits to today's state never erase history. Archived habits retain their historical contribution.

A streak counts consecutive perfect scheduled days. Days with no due habits are skipped, and an incomplete current day does not break the streak before the day ends.

## TODO

### Next

- [ ] Add habit reordering and an archived-habits manager
- [ ] Allow historical check-ins to be corrected from the day-detail screen
- [ ] Add reminder scheduling with local notifications
- [ ] Add onboarding and first-habit guidance
- [ ] Expand tests for streak boundaries, time-zone changes, timers, and SwiftData migrations

### Integrations

- [ ] Add HealthKit-backed habits, beginning with steps and active energy
- [ ] Add private iCloud synchronization with SwiftData and CloudKit
- [ ] Add Home Screen and Lock Screen widgets
- [ ] Add App Intents for Shortcuts and Siri check-ins

### Release readiness

- [ ] Add the final app icon and launch assets
- [ ] Complete accessibility and localization audits
- [ ] Add UI tests for the primary create, check-in, edit, and archive flows
- [ ] Add privacy policy and App Store privacy disclosures
- [ ] Prepare App Store screenshots and metadata

See [`AGENTS.md`](AGENTS.md) for repository-specific implementation conventions.
