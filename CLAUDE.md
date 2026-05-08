# LockedIn Project Guide

LockedIn is a productivity and discipline app focused on two core mechanics:

1. **Time Utilization Tracker.** Every focused hour is split into four 15 minute blocks. Each block carries a colour coded "utilization" record on a red to amber to green ramp. Non focus blocks are blue. Inside an active focus session the Android app surfaces a soft alarm so the user logs the just completed quarter on time.
2. **Habit Tracker.** One row per habit, one cell per day. Each cell carries a colour coded utilization for that day. The dashboard surfaces streaks and weekly or monthly stats. Reminders fire for predefined focus sessions and habits.

The product is a single Flutter app (Android primary; Linux desktop and Web are fall back targets used during development for fast iteration). The first milestone is a fully mocked UI: every screen exists, every interaction is wired, but data comes from seeded fixtures (`lib/data/mock.dart`). Logic, persistence and auth come later.

## Writing rules

* **Never use em dashes (`—`), en dashes (`–`), or double hyphen ASCII (`--`) as prose punctuation.** This applies to all docs, code comments, commit messages, and chat output. ASCII `--` inside a CLI flag (e.g. `flutter create --platforms android`) is allowed; the rule is about prose, not command syntax. If a dash slips in by accident, rewrite the sentence.
* Replace dashes with a period, comma, colon, parentheses, or by restructuring.
* No emoji as structural icons. Vector icons only (see "Iconography" below).

## Repo layout

```
LockedIn/
├── apps/
│   └── ironwill/                 the Flutter app (always run from here)
├── Docs/                      original spec PDFs (do not edit)
├── screenshots/               70+ Dribbble references for the design reviewer
│                              agent (gitignored; populated by the playwright
│                              crawl)
├── .claude/
│   ├── agents/design-reviewer.md
│   └── skills/                design, design-system, ui-styling, ui-ux-pro-max,
│                              brand
├── .mcp.json                  Playwright MCP, used for design crawls
└── CLAUDE.md                  this file
```

## Toolchain (already on disk; do not re-download)

| Tool | Path | Notes |
|---|---|---|
| Flutter SDK | `/media/abrar/AbrarSSD/Flutter/flutter` | Channel `stable` 3.41.9, Dart 3.11.5 |
| Android Studio | `/media/abrar/AbrarSSD/Flutter/android_studio/android-studio` | Bundled JBR at `…/jbr` |
| JDK | `${ANDROID_STUDIO}/jbr` | Already wired via `flutter config jdk-dir` |
| Android SDK | not installed yet | Defer until we need to run on a real device or emulator. UI mocks run on Linux desktop or Chrome. |

Always export PATH before running flutter commands in a fresh shell:

```bash
export PATH="/media/abrar/AbrarSSD/Flutter/flutter/bin:$PATH"
export ANDROID_STUDIO=/media/abrar/AbrarSSD/Flutter/android_studio/android-studio
export JAVA_HOME=$ANDROID_STUDIO/jbr
```

## How to run

From the repo root:

```bash
cd apps/ironwill
flutter pub get
flutter run -d linux         # fastest dev loop, no Android SDK needed
flutter run -d chrome        # for sharing screenshots, web preview
flutter run -d <android-id>  # once the Android SDK is set up
flutter analyze              # before every commit
flutter test                 # widget tests
```

When something refuses to build, the very first thing to try is `flutter clean && flutter pub get`. Cache divergence is the most common cause.

## Design language (non negotiable)

These rules are derived from a 70 shot research crawl on Dribbble (saved in `screenshots/`). Any deviation must be justified by the design reviewer agent and recorded under "Accepted deviations" at the bottom of this file.

### Personality

The brand is masculine, disciplined, focused, hard working. Reference vibes: David Goggins, Whoop, Strava on a serious day, the editorial side of Apple's Health app. Not Headspace, not Habitica, not anything cartoon.

* **Severe restraint, no gamified cute.** No mascots, no stickers, no emoji as icons, no cartoon illustrations. The interface earns trust by getting out of the way.
* **Editorial typography.** Inter Tight for display, condensed feeling weights, hierarchical sizes. Big numbers carry the screen.
* **Graphite plus ember.** Charcoal and steel surfaces with a single fierce ember orange accent for action. The utilization ramp is the only place multi hue colour appears, and only to convey data; never decoration.
* **Dark mode is the hero.** Build dark first; light mode follows. The product is most often used at the start or end of a focused day; deep ink mirrors that mood.

### Tokens

Colour, spacing, radii and type are defined once in `lib/theme/tokens.dart` and consumed via `Theme.of(context).extension<AppTokens>()`. Never hardcode hex values, font names, or pixel paddings inside feature code.

#### Surfaces

| Token | Light | Dark | Use |
|---|---|---|---|
| `bg` | `#F2EFE9` (paper) | `#07070A` (deep ink) | App background |
| `surface` | `#FFFFFF` | `#111114` | Cards |
| `surfaceAlt` | `#EAE6DF` | `#18181C` | Inputs, chips, secondary surfaces |
| `divider` | `#D8D3CA` | `#25252B` | Hairlines |
| `ink` | `#0A0A0B` | `#ECE9E2` | Primary text |
| `inkMuted` | `#4F4D4A` | `#8B887F` | Secondary text |
| `steel` | `#475569` (slate-600) | `#94A3B8` (slate-400) | Secondary chrome: icons, dividers, muted strokes |
| `accent` | `#EA580C` (ember-600) | `#F97316` (ember-500) | Primary CTA, streak emphasis, focus active state |
| `accentInk` | `#FFFFFF` | `#07070A` | Text on accent |

#### Utilization ramp (data colour, identical in both themes)

| Level | Hex | Meaning |
|---|---|---|
| `none` | transparent | block not yet logged |
| `notFocus` | `#2563EB` (blue-600) | scheduled non focus (sleep, family, planned downtime) |
| `wasted` (0%) | `#DC2626` (red-600) | full wastage |
| `low` (25%) | `#F97316` (orange-500) | mostly distracted |
| `mid` (50%) | `#EAB308` (yellow-500) | half utilized |
| `good` (75%) | `#84CC16` (lime-500) | mostly focused |
| `full` (100%) | `#16A34A` (green-600) | fully focused |

Rules:

* Never convey utilization by colour alone. Always pair with a glyph or a percentage label (WCAG `color-not-only`).
* Provide a legend on every screen that uses the ramp.

#### Spacing scale (4dp grid)

`xs 4`, `s 8`, `m 12`, `md 16`, `lg 20`, `xl 24`, `xxl 32`, `x3l 40`, `x4l 48`, `x5l 64`.

#### Radii

`xs 4`, `s 8`, `m 12`, `md 16`, `lg 20`, `xl 24`, `pill 999`.

#### Type (Inter and Inter Tight via `google_fonts`)

| Role | Family | Size | Weight | Use |
|---|---|---|---|---|
| `display` | Inter Tight | 40 | 700 | Hero numbers (streak count, today's focus minutes) |
| `headline` | Inter Tight | 24 | 600 | Screen title |
| `title` | Inter | 18 | 600 | Card title |
| `body` | Inter | 15 | 400 | Body text, descriptions |
| `label` | Inter | 13 | 500 | Chips, captions, axis labels |
| `mono` | Inter (tabular figures) | 14 | 500 | Numbers in lists, time stamps |

Tabular figures must be enabled (`featureSet: tnum`) wherever numbers stack. That includes calendar dates, streak counts, and time labels.

### Layout and navigation

* Bottom nav with 4 destinations, labelled. Max 5 (per `bottom-nav-limit`): **Today**, **Time**, **Habits**, **Stats**. Settings is reachable from the avatar in the top app bar.
* One primary CTA per screen (`primary-action`). FAB used only on Habits (add habit) and Time Tracker (log block).
* Safe areas respected. No fixed UI under notch or gesture bar.
* Touch targets at least 48dp (Material) and at least 8dp gap between targets. Quarter cells in the time grid expand their hit area beyond visual bounds.
* Mobile first, but every screen is responsive: on tablet and desktop we widen the inner column to `max-width: 480` and centre.

### Motion

* 200ms standard duration, 250ms for sheet and modal motion.
* Spring physics on press feedback (subtle 0.97 scale).
* Always honour `prefers-reduced-motion` (via `MediaQuery.disableAnimations`).
* Exit animations 60 to 70 percent of enter duration.

### Iconography

* No emoji as structural icons. Use `lucide_icons` (or another consistent vector set) at 1.5px stroke. The streak fire and "you're on a roll" affordances are SVG or text glyphs, not the fire emoji.
* One icon family across the entire app.
* Icon size tokens: `iconS 16`, `iconM 20`, `iconL 24`, `iconXL 32`.

## Persistence and offline behaviour

The app is fully offline. No network. Choices that drove the architecture:

* **SQLite via `sqflite` (Android) and `sqflite_common_ffi` (Linux desktop)** for typed, queryable persistence. Schema lives in [lib/data/local_db.dart](apps/ironwill/lib/data/local_db.dart). Current schema version is `5`. Bump when columns or tables change and add an `ALTER` block to `_onUpgrade`. See "Schema history" at the bottom for what each version added.
* **Repositories** in [lib/data/repositories.dart](apps/ironwill/lib/data/repositories.dart) are interface-driven. Mock impls live in [mock_repositories.dart](apps/ironwill/lib/data/mock_repositories.dart) and SQLite impls in [sqlite_repositories.dart](apps/ironwill/lib/data/sqlite_repositories.dart). The UI imports the abstract interfaces only.
* **Reads through `ValueListenable` streams.** Every list-shaped repository exposes a `ValueNotifier` that the UI binds to via `ValueListenableBuilder`. Writes update the notifier so listeners rebuild without manual `setState` plumbing.
* **JSON export and import** in [lib/data/backup.dart](apps/ironwill/lib/data/backup.dart). One file, all tables, format string `"lockedin-backup"` plus an integer version. The reader still accepts the legacy `manup-backup` and `ironwill-backup` strings so older exports import cleanly. Import wipes and replaces; we may add a merge-mode later. The export is shared via the system share sheet (`share_plus`); import picks via `file_picker`.

## Notifications and reminders

This is the gnarly part on Android because of Doze and OEM modifications.

* **Habit reminders and 15-minute session ticks** are scheduled with `flutter_local_notifications` via `AlarmManager`. We use `AndroidScheduleMode.exactAllowWhileIdle` so Doze cannot defer them. The manifest declares `USE_EXACT_ALARM` and `SCHEDULE_EXACT_ALARM`.
* **The persistent "session active" notification is a real foreground service**, not an `ongoing: true` regular notification. Regular ongoing notifications get reaped when Android kills the process and respawn each time the app re-evaluates, which produces a flickery, sometimes-audible respawn cycle. The flashlight notification, the music player notification, and similar system-tray-grade widgets are all backed by foreground services, and that is what we use.
  * Plugin: `flutter_foreground_task`.
  * Controller: [lib/services/focus_session_service.dart](apps/ironwill/lib/services/focus_session_service.dart).
  * Manifest: a `<service>` declaration for `com.pravera.flutter_foreground_task.service.ForegroundService` plus `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_DATA_SYNC` permissions.
  * Lifecycle: `FocusSessionForegroundController.reconcile(sessions)` is called on every app start, on every app resume, and after any habit/session/setting write. It starts the service if a session is currently inside its scheduled window and stops it when no session is live. Idempotent on each call.
* **Channel ids vary by chosen sound** (`lockedin_session_<sound>`, `lockedin_habit_<sound>`). Android freezes a channel's sound at first post; varying the id lets the user switch sounds without having to clear notification settings. Channels are pre-created at `init()` time so `show()` and `zonedSchedule()` always have a place to land.
* **Time conversions**: do NOT use `tz.local` for wall clock arithmetic. The `timezone` package's local zone defaults to UTC unless explicitly initialised, and `DateTime.now().timeZoneName` returns abbreviations like "BDT" that the IANA database does not know. Always build wall-clock times as system-local `DateTime`s and convert at the boundary via `tz.TZDateTime.from(dt, tz.local)`. The absolute moment is preserved regardless of what `tz.local` happens to be.

## Coding conventions

* Lints: `flutter_lints` is enforced. Run `flutter analyze` clean before reporting work as done.
* State: keep it dumb during the mock phase. `StatefulWidget` is fine. We will introduce Riverpod once persistence lands.
* Routing: `go_router` with a single `ShellRoute` for the bottom nav scaffold.
* No hardcoded colours, sizes, or strings inside widgets. Pull from `AppTokens`, `AppText`, and `Strings`.
* No `print` statements committed (use `debugPrint` if anything).
* Screens own seeded data via `lib/data/mock_db.dart` during the mock phase. Models (`Habit`, `Subject`, `SubjectBlock`, `DayBlocks`, `HabitField`) live in `lib/models/models.dart`.
* Default day pickers select **all 7 days**. The user deselects what they don't want; we don't ship "Weekdays" / "Every day" shortcut buttons because users couldn't tell they were tappable.
* Comments: skip "what" comments; only document non obvious "why". Public APIs without a clear name get a short doc comment.

## Working with the design reviewer agent

The agent at `.claude/agents/design-reviewer.md` is our source of truth for visual review. Before merging any UI change, run it on the new screens with the relevant Dribbble references from `screenshots/`. The agent must reference the design skills in `.claude/skills/` (notably `ui-ux-pro-max` and `design-system`).

Iterate until the agent's verdict is "ship ready", or the user explicitly accepts a deviation. Record any accepted deviation in this file under "Accepted deviations".

## Accepted deviations

(empty: no deviations approved yet)

## Schema history

Each version's `_onUpgrade` step is in [lib/data/local_db.dart](apps/ironwill/lib/data/local_db.dart). The fresh-install `_onCreate` reflects the latest version directly.

* **v1**: original. `habits`, `habit_logs`, `time_blocks`, `focus_sessions`, `profile`, `settings`.
* **v2**: `habits.description`, `habit_logs.note`, `settings.theme_mode`, `settings.onboarded`.
* **v3**: `focus_sessions` replaced by `subjects` + `subject_blocks`. A subject is the umbrella term ("Math", "Workout") and owns N scheduled blocks across weekdays. `subjects.expires_at` carries a TTL so a schedule decays after `LocalDb.defaultExpiryDays` (7) unless the user presses "Repeat next week". `habits.metadata` (TEXT JSON) is added; structured fields like `{"PU":"intList"}` go here. `settings.block_size_minutes` (default 30, allowed 15/30/60), `settings.pomodoro_enabled` (default 0), `settings.pomodoro_percent` (default 15) added.
* **v4**: `profile.weekly_focus_minutes_csv` (Mon..Sun, 7 ints comma-separated, default `240` × 7) supersedes the single `daily_focus_minutes_target`. Per-weekday focus targets, capped 0..1440 min so a SAT/GRE-prep user can set 12-hour days. The legacy `daily_focus_minutes_target` column stays as a max-summary for older readers.
* **v5**: `habit_logs.metadata` (TEXT JSON, default `{}`) holds per-day values for the structured fields the user defined on the parent habit. Values can be string, int, bool, list of int, list of bool.

The backup importer in [lib/data/backup.dart](apps/ironwill/lib/data/backup.dart) is forward-compatible with the legacy `manup-backup` and `ironwill-backup` format strings AND the legacy `focus_sessions` field (it migrates each focus_session into a subject + N blocks at import time). Single-value `daily_focus_minutes_target` is expanded to 7 weekdays. Habit rows without `metadata` get `{}`. So the user's old export imports cleanly into the new schema.

## App branding

LockedIn (formerly ManUp / IronWill). The user-visible label, applicationId, DB filename, notification channel ids, and backup format string are all `lockedin`-prefixed. The folder is still `apps/ironwill/` for build-path stability — that's a paper cut, not a correctness issue. The legacy strings are accepted on import only, never written.

## Phase progress (LockedIn pivot, started 2026-05-08)

| Phase | Status | What it shipped |
|---|---|---|
| 1 | done | Rename to LockedIn (label, applicationId, DB, channels, backup format). Logo: borderless fist v3, padded so the adaptive icon mask doesn't crop. APK output renamed to `LockedIn-debug.apk` / `LockedIn-release.apk` via Gradle `outputFileName`. |
| 2 | done | Schema v3. `Subject` + `SubjectBlock` models replace `FocusSession`. Multi-block-per-day allowed. Schedule TTL with "+1 week" / "Repeat next week" buttons. Notifications + foreground service consume `subjects`. `currentlyActiveBlock` helper replaces `currentlyActiveSession`. |
| 2.5 | done | Schema v4. `weeklyFocusMinutes` per-weekday target editor under Settings → Focus targets. 0..1440 min cap. Focus streak respects per-day target (0-min day is a free pass, doesn't break the streak). |
| 3 | done | Block-size selector (15/30/60) inline on the Time tab and in Settings. Storage stays at 15-min sub-blocks; render aggregates by averaging utilisation percentages and rounding to the nearest tier. Smart picker snaps to the chosen block size. FAB label adapts ("Log this hour" / "Log this 30 min" / "Log this quarter"). |
| 4 | done | Pomodoro: per-block toggle in the floating timer dialog AND on the subject editor. Settings → Pomodoro for the global default (toggle + 5..50% slider). Notifications: when pomodoro is on, the accountability tick fires once at rest start instead of every quarter. In-app timer pill switches from ember to steel during rest with a coffee glyph; the floating dialog flips its emphasized block to ember and shows "REST PERIOD". |
| 5 | done | Schema v5. Habit `metadata.fields` defines tracking schema (e.g. `PU: intList`). The habit log sheet shows a typed editor per field (text / number / yes-no / list of numbers / list of yes-no). Habit detail screen has a "Tracking fields" card showing the last 14 logged days plus a per-field summary line ("total 37 reps" / "avg 25" / "5/7 yes"). |
| 6 | pending | Design review pass against `screenshots/` references. |
| 7 | pending | E2E smoke test on web + device, ship release APK. |

## Open knowns / not-yet-fixed

* The web-server flutter device requires the Dart Debug Chrome extension to bootstrap; we use `flutter build web` + a static HTTP server when smoke-testing in Playwright instead.
* The persistent foreground notification updates at 1 Hz to render the dual timer live. That's noticeable battery on long sessions; we may bump to 2 s if users complain.
* The Radio widget pair in `_FieldEditorDialog` uses the pre-3.32 API (`groupValue`, `onChanged`); migrate to `RadioGroup` when we move to a newer Flutter SDK.
