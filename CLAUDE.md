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
│   └── lockedin/                 the Flutter app (always run from here)
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
cd apps/lockedin
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

* **SQLite via `sqflite` (Android) and `sqflite_common_ffi` (Linux desktop)** for typed, queryable persistence. Schema lives in [lib/data/local_db.dart](apps/lockedin/lib/data/local_db.dart). Current schema version is `6`. Bump when columns or tables change and add an `ALTER` block to `_onUpgrade`. See "Schema history" at the bottom for what each version added.
* **Repositories** in [lib/data/repositories.dart](apps/lockedin/lib/data/repositories.dart) are interface-driven. Mock impls live in [mock_repositories.dart](apps/lockedin/lib/data/mock_repositories.dart) and SQLite impls in [sqlite_repositories.dart](apps/lockedin/lib/data/sqlite_repositories.dart). The UI imports the abstract interfaces only.
* **Reads through `ValueListenable` streams.** Every list-shaped repository exposes a `ValueNotifier` that the UI binds to via `ValueListenableBuilder`. Writes update the notifier so listeners rebuild without manual `setState` plumbing.
* **JSON export and import** in [lib/data/backup.dart](apps/lockedin/lib/data/backup.dart). One file, all tables, format string `"lockedin-backup"` plus an integer version. The reader still accepts the legacy `manup-backup` and `ironwill-backup` strings so older exports import cleanly. Import wipes and replaces; we may add a merge-mode later. The export is shared via the system share sheet (`share_plus`); import picks via `file_picker`.

## Notifications and reminders

This is the gnarly part on Android because of Doze and OEM modifications.

* **Habit reminders and 15-minute session ticks** are scheduled with `flutter_local_notifications` via `AlarmManager`. We use `AndroidScheduleMode.exactAllowWhileIdle` so Doze cannot defer them. The manifest declares `USE_EXACT_ALARM` and `SCHEDULE_EXACT_ALARM`.
* **The persistent "session active" notification is a real foreground service**, not an `ongoing: true` regular notification. Regular ongoing notifications get reaped when Android kills the process and respawn each time the app re-evaluates, which produces a flickery, sometimes-audible respawn cycle. The flashlight notification, the music player notification, and similar system-tray-grade widgets are all backed by foreground services, and that is what we use.
  * Plugin: `flutter_foreground_task`.
  * Controller: [lib/services/focus_session_service.dart](apps/lockedin/lib/services/focus_session_service.dart).
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
* Screens own seeded data via `lib/data/mock_db.dart` during the mock phase. Models (`Habit`, `Subject`, `FocusSession`, `DayBlocks`, `HabitField`) live in `lib/models/models.dart`.
* Default day pickers select **all 7 days**. The user deselects what they don't want; we don't ship "Weekdays" / "Every day" shortcut buttons because users couldn't tell they were tappable.
* Comments: skip "what" comments; only document non obvious "why". Public APIs without a clear name get a short doc comment.

## Working with the design reviewer agent

The agent at `.claude/agents/design-reviewer.md` is our source of truth for visual review. Before merging any UI change, run it on the new screens with the relevant Dribbble references from `screenshots/`. The agent must reference the design skills in `.claude/skills/` (notably `ui-ux-pro-max` and `design-system`).

Iterate until the agent's verdict is "ship ready", or the user explicitly accepts a deviation. Record any accepted deviation in this file under "Accepted deviations".

## Accepted deviations

(empty: no deviations approved yet)

## Schema history

Each version's `_onUpgrade` step is in [lib/data/local_db.dart](apps/lockedin/lib/data/local_db.dart). The fresh-install `_onCreate` reflects the latest version directly.

* **v1**: original. `habits`, `habit_logs`, `time_blocks`, `focus_sessions`, `profile`, `settings`.
* **v2**: `habits.description`, `habit_logs.note`, `settings.theme_mode`, `settings.onboarded`.
* **v3**: `focus_sessions` replaced by `subjects` + `subject_blocks`. A subject is the umbrella term ("Math", "Workout") and owns N scheduled blocks across weekdays. `subjects.expires_at` carries a TTL so a schedule decays after `LocalDb.defaultExpiryDays` (7) unless the user presses "Repeat next week". `habits.metadata` (TEXT JSON) is added; structured fields like `{"PU":"intList"}` go here. `settings.block_size_minutes` (default 30, allowed 15/30/60), `settings.pomodoro_enabled` (default 0), `settings.pomodoro_percent` (default 15) added.
* **v4**: `profile.weekly_focus_minutes_csv` (Mon..Sun, 7 ints comma-separated, default `240` × 7) supersedes the single `daily_focus_minutes_target`. Per-weekday focus targets, capped 0..1440 min so a SAT/GRE-prep user can set 12-hour days. The legacy `daily_focus_minutes_target` column stays as a max-summary for older readers.
* **v5**: `habit_logs.metadata` (TEXT JSON, default `{}`) holds per-day values for the structured fields the user defined on the parent habit. Values can be string, int, bool, list of int, list of bool.
* **v6**: BREAKING. Recurring weekly `subject_blocks` replaced by one-shot `focus_sessions(id, subject_id NULL, start_at ms, end_at ms, created_at ms)`. The frontend fans out "every Mon/Wed 9-10" into N rows. The repo enforces non-overlap on create / update so collisions never reach disk. `time_blocks.subject_id` (nullable, FK ON DELETE SET NULL) tags each logged quarter with the subject it belonged to so stats attribute directly off the column instead of intersecting with the (gone) recurring schedule. Migration fans every `subject_blocks` row out into focus_sessions covering today through the owning subject's `expires_at`, then drops `subject_blocks`.

The backup importer in [lib/data/backup.dart](apps/lockedin/lib/data/backup.dart) is forward-compatible with all four legacy shapes: `manup-backup`/`ironwill-backup` format strings, v1 `focus_sessions` (one row per subject with `days_csv` + start/end hour/minute), v2 `subjects` + `subject_blocks` (recurring weekly), and v3+ modern `focus_sessions` (one-shot windows with `start_at`/`end_at` ms). The first three are fanned out into modern focus_sessions at import time, covering today through each subject's expiry. Single-value `daily_focus_minutes_target` is expanded to 7 weekdays; habit rows without `metadata` get `{}`; time_block rows without `subject_id` get null. So every old export imports cleanly into the new schema.

## App branding

LockedIn (formerly ManUp / IronWill). The user-visible label, applicationId, DB filename, notification channel ids, backup format string, AND the Flutter project folder are all `lockedin`-prefixed. The legacy `manup-backup` and `ironwill-backup` strings are accepted on import only, never written. The GitHub repo is still `IronWill` for URL stability; rename it via `gh repo rename` if and when SEO matters.

## Phase progress (LockedIn pivot, started 2026-05-08)

| Phase | Status | What it shipped |
|---|---|---|
| 1 | done | Rename to LockedIn (label, applicationId, DB, channels, backup format). Logo: borderless fist v3, padded so the adaptive icon mask doesn't crop. APK output renamed to `LockedIn-debug.apk` / `LockedIn-release.apk` via Gradle `outputFileName`. |
| 2 | done | Schema v3. `Subject` + `SubjectBlock` models replace `FocusSession`. Multi-block-per-day allowed. Schedule TTL with "+1 week" / "Repeat next week" buttons. Notifications + foreground service consume `subjects`. `currentlyActiveBlock` helper replaces `currentlyActiveSession`. |
| 2.5 | done | Schema v4. `weeklyFocusMinutes` per-weekday target editor under Settings → Focus targets. 0..1440 min cap. Focus streak respects per-day target (0-min day is a free pass, doesn't break the streak). |
| 3 | done | Block-size selector + Schema v5 + habit metadata KV editor. |
| 4 | done | Pomodoro universalised (Settings only, no per-block override). Block-size universalised (Settings only, removed from Time tab). `computeBlockTiming` now takes `blockSizeMinutes / pomodoroEnabled / pomodoroPercent` and renders 2 cards (off) or 3 cards (on: total / next log / next rest) in the floating dialog. Foreground service tray uses the same math via the task isolate — sends settings via `sendDataToTask`. Pre-start branch in `_renderBody` reads "Starts in MM:SS" instead of misleading "Log in" before block start. Self-stop after `endAt + 5 min` so the tray can't tick forever on stale data after process death. |
| 4.5 | done | Pomodoro model: rest per logging cycle. Each `blockSize` cycle has focus phase + rest slice = `(cycleSize × pomodoroPercent / 100)`. Repeats until session end. Notifications split mandatory log tick (every cycleEnd) from optional rest tick (every restStart, only when pomodoro on). Different notification ids per cycle for log and rest. |
| 5 | done | Notification scheduling overhaul. Was: pre-schedule 7 days of session ticks. Bugs hit: (1) `qIndex` reset to 0 per block caused same-day cross-block id collisions because `sessionTickId` keyed on `subject.id`; (2) the `& 0x1FFF` mask was only 8192 buckets and nearly-identical block ids collided modulo 8192 anyway. Fixed: key on `block.id`, widen the hash bucket to ~1B via `'$blockId:$day:$qIndex'.hashCode.abs() % (1 << 30) + 100000`. Then replaced the 7-day pre-schedule with a 2 h horizon refreshed every 30 s by the existing reconcile ticker, so mid-session settings changes propagate cleanly without a giant cancel-and-reschedule pass. `cancelAll()` proved unreliable across `install -r`; switched to enumerating `pendingNotificationRequests()` and cancelling each by id. |
| 6 | done | UX polish batch: dark-mode focus picker fix, preset chips on focus target, default reminder 18:00, default field type "number", cadence 2x2 grid, tracking-fields collapsed "advanced" toggle, glyph picker modal with categorised library, block editor mode chips (Weekdays default), expiry calendar with block-count badges, today log button restructure, habit field cascade (delete strips historical metadata), settings entry rename, onboarding "screen goes dark" bug fixed (was `Expanded(ListView)` inside `IntrinsicHeight` — Android Skia paints black, web's CanvasKit fudges it). `FocusScope.unfocus()` on every onboarding page transition and modal dismiss so soft keyboard drops with the route change. |
| 7 | done | Stats enrichment: highlights card (best day / worst day / peak hour-of-day / unlogged blocks), 24-bar hour-of-day strip, per-habit completion list, per-subject focus breakdown card. Subject attribution is schedule-based today (intersect time_blocks with subject_blocks on weekday + window). `WeeklyStats` carries `bestDayIndex / worstDayIndex / goalHitDays / evaluatedTargetDays / avgUtilizationPct / hourlyMinutes / unloggedFocusQuarters / habitRows / subjectRows`. |
| 8 | done | Schema v6. Recurring `subject_blocks` replaced by one-shot `focus_sessions` (start_at / end_at / nullable subject_id). `time_blocks.subject_id` added (FK ON DELETE SET NULL). `FocusSessionsRepository` enforces non-overlap on create + update. Subjects are now just labels (name + soft expiry). New "Start a focus session" sheet (home, onboarding, sessions list) with subject picker + quick duration chips. New Sessions screen at `/settings/sessions` lists everything grouped by day. Logging UX rewritten: bottom sheet asks "How focused were you the past X minutes?", auto-picks subject when a session overlaps the block, asks the user "which session" when 2+ overlap, writes `time_blocks.subject_id` so stats attribution is now tag-based. `Stats` range picker (Week/Month/Year) functional — uses new `StatsRange` enum routed through `getRange()`. Settings reachable from every tab AppBar. Notifications + foreground service walk `focus_sessions` instead of subject_blocks; the 2 h horizon + 30 s reconcile ticker is unchanged. Backup imports legacy v1 focus_sessions, v2 subject_blocks, AND v3 focus_sessions cleanly — all three fan out into modern one-shots at import time. |
| 9 | pending | Design review pass against `screenshots/` references. |
| 10 | pending | E2E smoke test on web + device, ship release APK. |

## Open knowns / not-yet-fixed

* The web-server flutter device requires the Dart Debug Chrome extension to bootstrap; we use `flutter build web` + a static HTTP server when smoke-testing in Playwright instead.
* The persistent foreground notification updates at 1 Hz to render the dual timer live. That's noticeable battery on long sessions; we may bump to 2 s if users complain.
* The Radio widget pair in `_FieldEditorDialog` uses the pre-3.32 API (`groupValue`, `onChanged`); migrate to `RadioGroup` when we move to a newer Flutter SDK.
* Mock backend now defaults `AppSettings.onboarded = true` so web previews skip the onboarding flow. Live (sqlite) backend is unaffected — that path reads `onboarded` from the DB.
* Subjects screen still uses the old "expiry" framing. v6 made expiry a soft hint (it no longer gates sessions), so the wording could be slimmed further. Not urgent.

## ERD documentation

`docs/lockedin-erd-v5.drawio` — current schema (v5) ER diagram. Open in https://app.diagrams.net. 7 tables, 2 enforced FKs (with ON DELETE CASCADE), 4 app-enforced logical relationships shown as dashed edges. Composite PKs marked `PK1` / `PK2` (`habit_logs` PK = `(habit_id, date_iso)`, `time_blocks` PK = `(date_iso, quarter)`). Python validator in commit `a466b5f` confirms 0 table-table overlaps and 0 edge-table intersections. Update this file when the schema changes.

## v6 planning (Subject/SubjectBlock → Subject/FocusSession + tagged TimeBlocks)

User feedback: planning a week (or even one day) of focus sessions ahead is too high-friction. People want "start now, do it, forget it." Also want to backfill past performance and tag the time they actually focused on a subject.

Direction (breaking change, user accepts users will dump dbs):

* **Subjects** stay as-is. Just the umbrella name + expiry.
* **SubjectBlock** is removed. Replaced by **FocusSession**: a one-shot schedule with `start_at` + `end_at` + nullable `subject_id` + status. No weekday recurrence at the model level — recurring is sugar on top (user creates many sessions at once via the Settings "plan mode" for advanced users).
* **time_blocks** gains a nullable `subject_id` foreign key. This is the new attribution path: a 15-minute quarter knows which subject (if any) it belongs to, computed at log time rather than post-hoc by intersecting with schedules.

Use cases the new model unlocks:

1. On-demand focus session from home: a floating dialog with start/end/date + subject selector (last-selected pre-picked, "new subject" inline). Onboarding uses the same dialog.
2. Logging a quarter during an active focus session: time_block's subject_id auto-populates from the active focus_session's subject_id hint.
3. Logging a quarter outside any active session: user picks subject (or skips) alongside utilisation. Same path supports backfilling old days.
4. Stats: per-subject day-by-day detail using the tagged time_blocks. No more schedule-based attribution.

UI surface:

* Home: primary CTA = "Start a focus session" (opens the floating dialog).
* Settings → "Subjects and focus sessions" → the advanced "plan mode" (bulk session creation / recurring templates).
* Settings reachable from all four bottom-nav tabs, not just home.
* Stats `_RangePicker` (Week / Month / Year) actually swaps the data range.

Out-of-scope but on the radar: optional backend sync via websocket for cross-device + "see other people's stats" social pressure, IP-geolocation lookup (no GPS) for region-grouped leaderboards.
