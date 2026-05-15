# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Layout Gotcha

The Flutter project root is **`barq/`**, not the repository root. All `flutter` commands must run from `barq/`. `pubspec.yaml`, `lib/`, and `test/` live there. `README_FIX.md` documents past confusion from copying `pubspec.yaml` into `lib/` — don't.

## Common Commands

Run from `barq/`:

```bash
flutter pub get              # install deps
flutter analyze              # static analysis
flutter test                 # run all tests
flutter test test/foo_test.dart -n "name"  # single test by name
flutter run                  # debug run, default backend (https://api.barq-api.uk)
flutter run --dart-define=POCKETBASE_URL=http://<lan-ip>:8090  # local PB on Wi-Fi
.\build_release.ps1          # Android release helper (Windows)
```

Runtime config is read from `--dart-define` at compile time via `lib/services/app_config.dart`. Keys: `POCKETBASE_URL`, `GEOCODING_BASE_URL`, `ROUTING_BASE_URL`, `MAP_TILE_URL`, `MAP_USER_AGENT`, `GOOGLE_MAPS_KEY`, `OPENROUTER_API_KEY`, `GEMINI_API_KEY`, `GROQ_API_KEY`. Changing them requires a full rebuild — hot reload won't pick up new defines.

## Architecture

Two-sided Flutter app (customer + driver) backed by **PocketBase** for auth, persistence, and realtime. No separate API server — the Flutter clients talk to PocketBase collections directly and rely on collection rules to enforce authorization. AI features are optional and routed through provider keys (OpenRouter / Gemini / Groq).

### Trip Lifecycle State Machine

Single string `status` field on the `tow_requests` collection drives the entire flow. Both customer and driver UIs branch on these exact values:

- `pending` — customer created the request, no driver assigned yet
- `assigned` — driver accepted, heading to pickup
- `en_route` — driver tapped "Start at pickup", heading to destination
- `completed` — trip finished (auto-set when driver reaches destination)
- `cancelled`, `cancel_pending`, `expired` — terminal/intermediate states

The driver app **never writes `completed` manually** — `PocketBaseService.updateTowRequestAsDriver` throws if you try. Completion is auto-triggered by the location-push pipeline (see below).

### Location Pipeline (the spine)

`DriverLocationService` (singleton, `lib/services/driver_location_service.dart`) starts when the driver goes online and pushes GPS every 5 seconds via `pushDriverLocationToActiveRequests` in `pocketbase_service.dart`. That function does three things on every tick:

1. Writes `driver_lat`/`driver_lng` onto every `assigned`/`en_route` request belonging to the driver. This is what powers the customer's live map marker.
2. **Auto-completes** a trip when status is `en_route` AND driver is within `_autoCompleteRadiusMeters` (150 m) of destination AND has left the pickup area. The pickup-distance guard is intentional — without it, short trips where pickup is near destination skip the `en_route` state on the customer screen.
3. Self-heals the `driver` relation by user ID when only `driver_name` is set.

The customer's `TrackServicePage` reads these same fields via a PocketBase realtime subscription (`subscribeTowRequest`) plus a 15-second polling fallback.

### Driver Matching

Matching is collection-rule + filter based, not a server algorithm:

- When a customer requests with no preferred driver, the request stores `candidate_drivers` (a list of user IDs picked client-side based on proximity from `driver_profiles`).
- Driver app's `getPendingTowRequests` returns `status = "pending"` rows excluding the requester, then client-filters by `candidate_drivers` membership.
- `updateTowRequestAsDriver` enforces single-acceptance with a pre-flight `getOne` + race-condition checks before writing `status: 'assigned'`.

### Key Files

| File | Owns |
|---|---|
| `lib/services/pocketbase_service.dart` | All PocketBase calls, trip-state writes, auto-complete logic, realtime sub/unsub. Single big service — most cross-cutting changes land here. |
| `lib/services/driver_location_service.dart` | Foreground GPS stream + 5 s push cadence. Foreground notification on Android keeps it alive while screen is locked. |
| `lib/services/bahrain_map_service.dart` | Geocoding, reverse geocoding, route building, ETA — wraps Nominatim + OSRM (or Google if `GOOGLE_MAPS_KEY` set). |
| `lib/services/app_preferences_service.dart` | `SharedPreferences` wrapper for cached pickup place, language, theme, declined-request IDs. |
| `lib/models/tow_request_model.dart` | The `TowRequest` data class. `TowRequest.fromRecord` is the single deserialization point. |
| `lib/track_service_page.dart` | Customer's live tracking screen. Subscribes by request ID. Branches heavily on `_status`. |
| `lib/driver_page.dart` | Driver dashboard. Holds pending/active/history lists. `_startTrip` writes `en_route`, gated by `_ensureDriverNear` (150 m of pickup). |
| `lib/settings.dart` | Localized strings (English + Arabic). Every user-facing string must go through `AppStrings(language).text(key)`. |

### Bilingual / RTL

All UI is bilingual via `AppLanguage` (enum) threaded through widgets and `AppStrings` lookups. Never hardcode user-facing text. RTL must work — Arabic is heavily used.

### Backend Deployment

PocketBase template lives in `barq/deployment/pocketbase/` (Docker + Caddy, or systemd binary). Collections: `users`, `tow_requests`, `driver_profiles`, `ratings`, `driver_reports`, `driver_applications`, `support_qa`. Schema and hooks ship as `pb_schema.json` and `pb_hooks/`. Collection **rules** (not visible in code) enforce who can read/write — when a write succeeds in the SDK but the customer screen doesn't update, suspect rules before suspecting Dart.

## When Things Break

- "Customer's track screen stuck on old status" — check the realtime sub fired (`_realtimeReady`) and PocketBase read rules permit the customer to see `status` updates. 15 s polling will mask realtime failures.
- "Driver tapped Start Trip and nothing happened" — `_ensureDriverNear` returns false silently with a SnackBar if driver is > 150 m from pickup (or no GPS fix). Not a bug.
- "Status jumps from `assigned` straight to `completed`" — the auto-complete guard in `pushDriverLocationToActiveRequests` is the relevant code path. The pickup-distance guard exists for this reason; don't remove it.
- `--dart-define` change not taking effect — full rebuild required (kill and rerun `flutter run`).
