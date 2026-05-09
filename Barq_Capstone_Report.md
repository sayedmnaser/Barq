# Barq — Tow Service Platform for Bahrain

---

## Abstract

Barq is a mobile platform that connects drivers of disabled vehicles in the Kingdom of Bahrain with nearby tow truck operators in real time. The system replaces phone-based dispatch with a two-sided application: customers submit a tow request with pickup and destination on a Bahrain-restricted map, and the closest available driver is auto-assigned and tracked live. The backend runs on a self-hosted PocketBase deployment, while routing and geocoding are served by a hybrid stack that combines OpenStreetMap tiles with Google Directions and Geocoding APIs. AI services (Gemini 2.5 Flash) moderate driver applications, customer reports, and cancellation reasons, and a self-improving support chat collects user feedback to refine future replies. The deliverable is a Flutter application supporting Android and iOS in English and Arabic, with a foreground location service to keep driver tracking continuous when the app is backgrounded.

## Acknowledgments

I would like to thank my supervisor for guidance throughout the project, the Computer Science faculty at the university for shaping my engineering perspective, and the early users who tested two-account driver flows on real Bahrain roads. I am also grateful to my family for their support during long iteration cycles.

## List of Tables

- Table 3.1 Risk register
- Table 3.2 Activity plan and Gantt summary
- Table 4.1 Functional and non-functional requirements
- Table 4.2 Personas
- Table 5.1 Database collections (PocketBase)
- Table 6.1 Test cases — unit, integration, usability
- Table 7.1 Objectives versus delivered features

## List of Figures

- Figure 3.1 Process model
- Figure 4.1 Use case diagram
- Figure 4.2 Sequence diagram — accept and complete a job
- Figure 5.1 System architecture
- Figure 5.2 ERD of PocketBase collections
- Figure 5.3 UI design — customer dashboard
- Figure 5.4 UI design — driver panel
- Figure 5.5 Activity diagram — pricing and night surcharge
- Figure 5.6 Class diagram (selected services)

---

## Chapter 1 — Introduction

### 1.1 Problem Statement
Roadside breakdowns in Bahrain are still resolved through informal channels: drivers phone individual tow operators, negotiate prices verbally, and have no visibility into where the truck is or when it will arrive. This produces unpredictable wait times, opaque pricing, and limited accountability when drivers behave unsafely. There is no national equivalent of a ride-hailing experience for tow services that satisfies the local constraints — Arabic and English bilingual users, Bahrain-only coverage, predictable fixed pricing, and offline-tolerant fleet operation.

### 1.2 Project Objectives
1. Provide a customer mobile interface to request a tow with pickup and destination selected from a Bahrain-restricted map.
2. Provide a driver mobile interface that lists pending requests, supports accept and decline, in-trip status updates, and live location sharing even when the app is backgrounded.
3. Implement transparent fixed-tier pricing with an automatic night surcharge.
4. Provide live tracking comparable in feel to a ride-hailing app: driver-to-pickup polyline, traffic-aware ETA, animated marker, and follow-camera.
5. Add safety controls: rating after a completed job, "Report bad driver" with AI moderation, and an AI-reviewed driver-cancellation flow.
6. Support both English and Arabic with right-to-left layout.
7. Build offline-tolerant infrastructure so transient outages of routing or geocoding services do not break the app.

### 1.3 Relevance and Significance
The project addresses a real local gap, reuses existing open-source infrastructure (PocketBase, OpenStreetMap, Flutter) to keep operating cost low, and demonstrates practical AI integration: Gemini-based moderation of user-generated content, application reviews, and a self-improving chat using a user-fed thumbs-up/down loop. The hybrid mapping stack — OSM tiles plus Google routing — illustrates a cost-engineering trade-off relevant to any small-fleet operator in the region.

### 1.4 Report Outline
Chapter 2 surveys related ride-hailing and dispatch literature. Chapter 3 covers the process model, risks, and schedule. Chapter 4 presents requirements and personas. Chapter 5 describes the architecture, database, UI, and class design. Chapter 6 documents implementation and testing. Chapter 7 concludes with a summary of objectives delivered, lessons learned, and limitations. Chapter 8 outlines future work.

---

## Chapter 2 — Literature Review

The dominant academic and industrial work on real-time mobile dispatch comes from ride-hailing research (Uber, Bolt, Careem). The recurring sub-problems are: (a) **driver-customer matching** — typically nearest-distance with availability and rating tie-breakers; (b) **live tracking** — periodic location pushes (5–20 seconds) blended with client-side interpolation to give a Google-Maps-quality feel without overloading the network; (c) **ETA estimation** — increasingly traffic-aware via Google Directions or Mapbox Directions Traffic; and (d) **safety and trust** — post-trip ratings, driver vetting, and content moderation.

For tow-specific systems, the literature is thinner. Existing Gulf services (e.g. roadside-assistance products bundled with insurance) act largely as call centres with mobile front-ends. They lack live driver tracking and transparent pricing. Open-source counterparts (OsmAnd, GraphHopper) provide the components but no end-to-end product.

The Barq architecture borrows three well-known patterns:

1. **Stream-and-interpolate tracking.** A small, periodic stream of location fixes from the driver's device is animated client-side using a tween between the previous and current position. The result is visually equivalent to a high-frequency stream while keeping network traffic low.
2. **Geofence-gated state transitions.** Common in delivery apps: the driver may transition to "in transit" only when within a small radius of the pickup, and to "delivered" only when within a small radius of the destination. This eliminates a class of fraud where a driver marks the trip complete remotely.
3. **LLM-assisted moderation.** Recent practitioner work uses LLMs to triage low-stakes content (driver complaints, cancellation reasons, document verification) and route only ambiguous cases to human admins.

The self-improving support chat draws from retrieval-augmented generation: prior helpful Q&A pairs are injected as few-shot examples for future questions, providing a lightweight feedback loop without retraining a model.

---

## Chapter 3 — Project Management

### 3.1 Process Model
An **iterative-incremental** model was used. Each one-week sprint delivered a vertical slice (e.g. "driver accepts and completes a job", "customer rates the driver"). At the end of every sprint a release APK was generated and tested on two physical Android devices simulating customer and driver simultaneously. This approach was chosen over waterfall because the project surfaced unknowns (PocketBase rule subtleties, foreground location permissions on Android 14, Google Maps key restriction details) that benefit from empirical correction rather than upfront specification.

### 3.2 Risk Management
Table 3.1 lists the principal risks identified at project start, the mitigations applied, and the realised impact.

| Risk | Likelihood | Impact | Mitigation | Realised |
|---|---|---|---|---|
| OSRM and Nominatim downtime breaks routing or geocoding | Medium | High | Fallback chain: Google → OSRM → straight-line | Triggered twice during testing; fallback held |
| Driver phone backgrounded → no live tracking | High | High | Foreground service with persistent notification | Resolved via geolocator ForegroundNotificationConfig |
| API key leakage in APK | Medium | Medium | Key restricted by Android package + SHA-1 + API allow-list; budget alerts | Effective |
| User-generated abuse of the report system | Medium | Medium | Gemini moderation with confidence scoring, escalation route to admin | Effective; a small share routed to needs-review |
| Battery drain from continuous GPS | Medium | Medium | 5–20 s push interval, distance filter when far from target | Acceptable in field test |
| Customer or driver self-assignment | Low | High | Self-filter on nearby drivers, server-side guard on accept | Resolved |

### 3.3 Project Activities Plan
A 12-week plan was followed:

| Week | Activity |
|---|---|
| 1–2 | Requirement collection, persona work, PocketBase schema sketch |
| 3–4 | Customer side (request, dashboard, history), Bahrain map widget |
| 5–6 | Driver side (panel, pending list, profile, accept/start/complete) |
| 7 | Live tracking, foreground service, marker tweening |
| 8 | Pricing, ratings, support chat (initial) |
| 9 | AI moderation flows (driver applications, reports, cancellations) |
| 10 | Bilingual polish, geofence guards, hybrid Google routing integration |
| 11 | Usability testing with real users in Bahrain, regression fixes |
| 12 | Report writing and final APK build |

---

## Chapter 4 — Requirement Collection and Analysis

### 4.1 Requirement Elicitation
Requirements were gathered through three channels:

1. **Stakeholder interviews** with five drivers from existing Bahrain tow services and seven private customers who had used such services in the previous year.
2. **Competitor analysis** of Careem, Uber-style tow add-ons, and informal WhatsApp dispatch groups operating in Manama.
3. **Continuous in-sprint testing** with two physical phones — one acting as driver, one as customer — exercising the same flow drivers reported in interviews.

### 4.2 System Requirements

**Functional (FR):**
- FR1 — Customer authentication via email/password and OTP using phone number.
- FR2 — Customer can submit a tow request with pickup, destination, vehicle type, and notes.
- FR3 — System displays the closest three available drivers and auto-assigns the closest on confirmation.
- FR4 — Driver can register, upload license + national ID + vehicle photo, and be approved through AI review.
- FR5 — Driver can scan and store vehicle plate via on-device OCR with confirmation dialog.
- FR6 — Driver can accept, decline, start, complete, or request cancellation of a job.
- FR7 — Geofence: driver may start a trip only within 150 m of pickup, complete only within 150 m of destination.
- FR8 — Customer can track the driver live on a map and call the driver from the app.
- FR9 — Customer can rate (1–5 stars + comment) and report bad behaviour.
- FR10 — Driver-initiated cancellations are reviewed by an AI moderator before being applied.
- FR11 — Multilingual UI in Arabic and English with full RTL support.

**Non-functional (NFR):**
- NFR1 — Live driver position updates ≥ once per 20 seconds end-to-end.
- NFR2 — Application starts in ≤ 4 seconds on a mid-range Android device.
- NFR3 — Routing requests served within 1.5 seconds (Google Directions p95 in Bahrain).
- NFR4 — All map operations restricted to a Bahrain bounding box to avoid accidental cross-border quotes.
- NFR5 — All API keys removed from source control; only injected at build time via `--dart-define`.

### 4.3 Personas

**Sara, 28, marketing manager (customer).** Drives daily between Saar and Manama. Has experienced one breakdown previously and disliked phoning unknown numbers. Wants to know in advance how much the trip costs and to see the truck moving toward her.

**Khalid, 41, tow driver (driver).** Operates a flatbed truck independently. Currently relies on word of mouth. Wants a steady stream of jobs, a fast accept-flow, and the ability to politely refuse jobs that are too far without losing his rating.

**Admin, central operator.** Reviews driver applications, monitors flagged reports, and resolves disputed cancellations.

### 4.4 System Models

- **Use case diagram (Figure 4.1):** Customer (request tow, track service, rate, report). Driver (manage profile, accept job, start trip, complete trip, cancel). Admin (review applications, review reports, finalise cancellations).
- **Sequence diagram — accept and complete (Figure 4.2):** Customer → request created (status `pending`). Driver → list pending → accept (server validates not-self, sets `driver` relation, status `assigned`). Driver geofence at pickup → start trip (status `en_route`). Driver geofence at destination → complete (status `completed`). Customer → optional rate or report.

---

## Chapter 5 — System Design

### 5.1 Introduction
The system follows a thin-client / smart-server split: the Flutter mobile app contains UI logic, location and map composition, and AI service calls; PocketBase holds data, enforces access rules, and broadcasts realtime updates over WebSocket. A small set of stateless cloud APIs (Google Directions, Google Geocoding, OpenStreetMap tile servers, Google Gemini) are accessed directly by the client.

### 5.2 Software Architecture
The architecture is layered (Figure 5.1):

1. **Presentation layer (Flutter):** screens (`HomePage`, `RequestTowPage`, `TrackServicePage`, `DriverPage`, `SupportChatPage`, `ReportDriverPage`, `RateDriverSheet`, `BecomeDriverPage`) and reusable widgets (`BarqLiveMap`, `BahrainPlaceSearchSheet`).
2. **Service layer (Dart):** `PocketBaseService` (CRUD + realtime), `BahrainMapService` (routing + geocoding with Google → OSM fallback), `LocationService`, `DriverLocationService` (foreground service), `SupportAiService`, `ModerationAiService`, `AppPreferencesService`.
3. **Data layer:** PocketBase server with REST + WebSocket; SharedPreferences for client-side cache.
4. **External services:** Google Directions API, Google Geocoding API, OpenStreetMap tile CDN, Google Gemini, optionally Groq and OpenRouter as chat fallbacks.

### 5.3 Database Design
PocketBase collections (Table 5.1):

| Collection | Key fields |
|---|---|
| users | email, password, name, phoneNumber, Driver (bool), application_status, is_suspended |
| driver_profiles | user, driver_name, license_plate, driver_phone, driver_rating, driver_total_rides, driver_lat/lng, is_available, default_eta_minutes, default_distance_km |
| tow_requests | user, driver, pickup_location, destination, vehicle_type, status, pickup_lat/lng, destination_lat/lng, driver_lat/lng, distance_km, eta_minutes, base_fare, distance_fare, rated, pickup_photo, dropoff_photo, damage_photos, candidate_drivers, cancellation_reason, cancellation_verdict, cancellation_decision, cancellation_ai_confidence |
| ratings | user, driver, tow_request, stars (1–5), comment |
| driver_reports | reporter, driver (optional), tow_request, category, description, photos, ai_verdict, ai_action, ai_confidence, status |
| driver_applications | user, full_name, plate_number, license_front, license_back, national_id, car_photo, ai_verdict, ai_decision, ai_confidence, status |
| support_qa | user, question, answer, language, tags, helpful (-1/0/1) |

Access control is enforced server-side via PocketBase rules. A driver, identified by `Driver = true` on their user record, can read pending tow requests; a customer can read only their own. Drivers update only the location fields and status; rating creation requires the request status to be `completed`.

### 5.4 User Interface Design
The colour system uses a yellow/navy palette (`#F4C21E` / `#0B1220`) consistent with electrical/lightning branding. Both light and dark themes are supported via Material 3 theming. RTL is achieved through the standard `Directionality` widget driven by the user's selected language. Status pills use semantic colour: grey (pending), blue (assigned), amber (en_route), green (completed), red (cancelled), brown (cancel_pending). Map markers are pulsed for the driver, a green pin for pickup, and a red flag for destination (Figure 5.3).

### 5.5 System Flow Design
The pricing flow (Figure 5.5) is a flat-tier rule:

- ≤ 15 km → 10 BHD
- 16 – 20 km → 15 BHD
- > 20 km → 20 BHD
- Auto-detected night hours (22:00–05:59) → +5 BHD.

The accept-and-complete flow consists of:

1. Pending creation by customer.
2. Driver accepts under the rule "not self" and self-fills the `driver` relation.
3. Status `assigned` with the polyline rebuilt as driver→pickup.
4. Geofenced "start trip" flips to `en_route` and rebuilds the polyline as driver→destination.
5. Geofenced "complete" closes to `completed` and unlocks rating and report on the customer side.

### 5.6 Object-Oriented Design Approach
Domain objects (`TowRequest`, `User`, `PlaceResult`) are modelled as immutable Dart classes with `fromRecord` factories that decode PocketBase records, isolating the rest of the codebase from the wire format. Service classes are singletons with explicit `init()` lifecycle, simplifying testing and mocking. The `BarqLiveMap` widget owns its own `MapController` and animation controllers to localise tweening logic and avoid rebuild storms when the parent receives many small driver updates.

---

## Chapter 6 — System Implementation and Testing

### 6.2 System Implementation
The application is built with Flutter 3 and Dart 3, targeting Android API 24+ (Android 7.0) and iOS 13+. The release APK is 85 MB, which includes the embedded ML Kit text recognition model used for plate scanning. The PocketBase backend runs in Docker behind a reverse proxy at `https://api.barq-api.uk`.

Selected implementation highlights:

- **Live tracking pipeline.** On the driver device, `DriverLocationService` starts an Android foreground service with `enableWakeLock` and a persistent notification, ensuring the OS does not kill the process when the screen is off. Each fix is pushed twice — once to the driver's `driver_profiles` row (for the customer's request page if the driver has not yet been assigned) and once to every active `tow_requests` row whose `driver` relation matches. A "self-heal" path patches missing `driver` relations on existing rows by matching `driver_name`.
- **Smooth marker animation.** `BarqLiveMap` interpolates between consecutive driver positions with a 1.2-second `easeOutCubic` tween, runs a pulsing halo behind the driver marker, and animates the camera using a follow-driver mode that disengages when the user pans.
- **Hybrid routing.** `BahrainMapService.buildRoute` calls Google Directions first with `departure_time=now` for traffic-aware ETA, decodes the encoded polyline, and falls back to OSRM (and finally a great-circle estimate) when the call fails or the API key is absent. The customer Track Service rebuilds the polyline only when the driver moves ≥ 200 m or the leg changes (assigned ↔ en_route), avoiding excessive API spend.
- **AI moderation.** Driver applications (multi-image), driver reports (text + photos), and cancellation reasons are all reviewed by Gemini 2.5 Flash through `ModerationAiService`. Each call returns a strict JSON `{decision, confidence, reasoning}` parsed defensively with a fallback to `needs_review`.
- **Self-improving chat.** Helpful Q&A pairs from `support_qa` are retrieved at chat-time using a keyword OR-filter on `question` and `tags`, then injected as few-shot examples in the system prompt. Each new answer is persisted and exposed to a thumbs-up/down vote that writes back to the same record.
- **Security.** All API keys (Gemini, Google Maps, Groq, OpenRouter) are read via `String.fromEnvironment` and injected at build time via `--dart-define`, never committed to source. Google Maps keys are restricted by Android package name + SHA-1 fingerprint and limited to Directions API + Geocoding API.

### 6.3 System Testing
A combination of unit, integration, and manual tests was used (Table 6.1).

- **Unit tests** verified the pricing tier function across boundary distances (0, 15, 16, 20, 21 km), the Haversine helper against known Bahrain coordinates, and the support keyword extractor for both English and Arabic input.
- **Integration tests** exercised the PocketBase service against a sandbox instance: account creation, OTP authentication, tow_request creation with and without the driver relation, ratings, and reports.
- **Manual end-to-end tests** were run with two phones in different vehicles in Bahrain. The dataset covered the happy path (request → assign → start → complete → rate), the cancellation path (driver requests cancel → AI approves or rejects), the failure path (location permission denied, OSRM unavailable, Google Directions key invalid), and the self-prevention path (driver cannot accept own request, driver cannot order themselves as the closest driver).

### 6.4 Usability and User Experience Testing
Five participants — three customers and two drivers — performed predefined tasks while thinking aloud. Issues identified and resolved:

- Pending request card buttons wrapped vertically on mid-sized phones — resolved by removing the redundant Track button and giving Decline + Accept full half-width.
- "Distance fare (10.5 km) 14.239 BHD" was confusing under the new flat-tier pricing — resolved by relabelling the line as "Night surcharge" and only rendering it when the surcharge is applied.
- Customers expected to see the driver moving in real time with a Google-Maps-like feel — resolved with the smooth tween + follow camera + traffic-aware Directions. Reported satisfaction increased from "the dot jumps" to "feels alive".
- "Report bad driver" was hidden when the driver relation was missing on legacy requests — resolved by relaxing the gate and making the driver relation optional in the report API.

After fixes, all five participants completed every task without intervention.

---

## Chapter 7 — Conclusion

### 7.1 Summary of the Project
Barq delivers a working two-sided tow dispatch product for Bahrain. The platform covers customer onboarding, driver onboarding with AI-reviewed documents, live request matching with self-prevention guards, real-time location tracking through a foreground service, geofenced trip transitions, transparent flat-tier pricing with a night surcharge, and post-trip rating, reporting, and cancellation flows backed by AI moderation. The hybrid map stack — OpenStreetMap tiles paired with Google Directions and Geocoding — keeps recurring infrastructure cost low while providing traffic-aware ETAs and accurate Bahrain geocoding.

### 7.2 Objectives Versus Delivered Features
Table 7.1 maps each project objective to the corresponding delivered feature.

| Objective | Status | Evidence |
|---|---|---|
| Customer mobile interface to request a tow | Delivered | `RequestTowPage` with Bahrain place search and live nearest-driver pre-assignment |
| Driver mobile interface with accept/decline and live sharing | Delivered | `DriverPage` plus `DriverLocationService` foreground service |
| Transparent fixed-tier pricing with night surcharge | Delivered | `tierFareForDistance` in `RequestTowPage` and `GetEstimatePage` |
| Live tracking comparable to ride-hailing | Delivered | `BarqLiveMap` with tween, halo, follow camera; Google Directions polyline |
| Safety controls (rating, report, cancellation review) | Delivered | `RateDriverSheet`, `ReportDriverPage`, `applyDriverCancellationVerdict` |
| Bilingual (Arabic / English) RTL UI | Delivered | `Directionality` driven by `AppLanguage`, AppStrings table |
| Offline-tolerant infrastructure | Delivered | Routing fallback chain, optimistic UI, request retries |

### 7.3 Lessons Learned
- **PocketBase rules have to be imported, not just edited in the repo.** A repeating class of bugs came from differences between the schema in `pb_schema.json` and the schema actually live on the server. The fix that worked was to make schema imports a checklist item before each release build.
- **Substring-based field-error matching is dangerous.** A single line in `_hasRejectedOptionalField` that scanned error messages for substrings ("driver" matched inside "driver_rating") silently stripped a relation from updates, producing a class of bugs that took several iterations to isolate. Field-name matching should always be exact.
- **A foreground service is the only reliable way to keep tracking alive on Android.** Timer-based pushes from a backgrounded app are killed inconsistently across OEMs. The persistent notification is a small UX cost for a large reliability gain.
- **AI moderation is most useful at the edges, not the centre.** Gemini was effective at deciding "obvious accept" or "obvious reject" for driver applications and cancellation reasons. The interesting cases were always routed to a human admin via a `needs_review` decision.

### 7.4 Limitations
- Pricing is a flat tier, not zone-based; long high-speed corridors are slightly under-priced and short urban traffic-jam trips are slightly over-priced. A zone or time-multiplied model would be fairer.
- The initial driver pool is bootstrapped from `driver_profiles` rows; with very few drivers online, the "closest 3" view is sparse.
- The plate OCR uses ML Kit Latin recognition only. Bahrain plates also contain Arabic characters; switching to a Latin + Arabic recognizer or a custom-trained model would improve accuracy.
- iOS background tracking requires `UIBackgroundModes=location` in `Info.plist` and an "always" location permission prompt; the current build is Android-tested only.
- The support chat retrieval uses simple keyword filtering on PocketBase. Embedding-based retrieval would scale better as the Q&A corpus grows.

---

## Chapter 8 — Future Work

- **Mapbox or Google full migration** with vector tiles, traffic overlay, and turn-by-turn navigation in the driver app.
- **Embedding-based retrieval** for the support chat using Gemini embeddings and PocketBase as a vector store, replacing the keyword OR-filter.
- **Driver earnings dashboard** with weekly totals, payout requests, and tax-friendly export.
- **Live driver heatmap** for the admin role to spot supply gaps.
- **Push notifications** through Firebase Cloud Messaging for new pending requests on the driver side and status changes on the customer side.
- **Rating-weighted matching** that prefers drivers with higher ratings within the same distance band.
- **Multi-stop tows** for fleets and dealerships moving multiple vehicles in one shift.
- **iOS parity** including signed `Info.plist` background modes and fresh keystore + Apple Maps consideration.
- **Compliance hardening** — SOC2-style audit log of admin actions, driver document expiry tracking, GDPR-style data export and deletion endpoints.

---

## References

1. PocketBase Documentation. https://pocketbase.io/docs.
2. Flutter Documentation. https://docs.flutter.dev.
3. Google Maps Platform — Directions API. https://developers.google.com/maps/documentation/directions.
4. Google Maps Platform — Geocoding API. https://developers.google.com/maps/documentation/geocoding.
5. OpenStreetMap and OSRM. https://www.openstreetmap.org, https://project-osrm.org.
6. Google Gemini API. https://ai.google.dev.
7. Geolocator package for Flutter. https://pub.dev/packages/geolocator.
8. flutter_map package. https://pub.dev/packages/flutter_map.

---

## Appendix A — Build and Deployment

The release APK is generated by the PowerShell script `barq/build_release.ps1`:

```
.\build_release.ps1 -GeminiApiKey "AIza..." -GoogleMapsKey "AIza..."
```

The script accepts API keys interactively or via parameters, passes them to `flutter build apk --release` as `--dart-define` values, and prints the resulting path under `barq/build/app/outputs/flutter-apk/app-release.apk`. The PocketBase server is deployed via Docker Compose under `barq/deployment/pocketbase/`.

## Appendix B — Repository Layout

```
barq/
  android/               Android Gradle config and manifest
  ios/                   iOS project files
  lib/
    main.dart            Application entry, theming, HomePage
    request_tow_page.dart
    track_service_page.dart
    driver_page.dart
    support_chat_page.dart
    rate_driver_sheet.dart
    report_driver_page.dart
    become_driver_page.dart
    sign_in_page.dart / sign_up_page.dart
    settings.dart        AppStrings, AppLanguage, theme tokens
    models/              TowRequest, UserProfile, PlaceResult
    services/            PocketBaseService, BahrainMapService,
                         LocationService, DriverLocationService,
                         SupportAiService, ModerationAiService,
                         AppPreferencesService, AppConfig
    widgets/             BarqLiveMap, BahrainPlaceSearchSheet
  deployment/pocketbase/ Docker compose and pb_schema.json
  build_release.ps1      Release build helper
```

## Appendix C — PocketBase Schema Excerpt

The full schema is checked into `barq/deployment/pocketbase/pb_schema.json` and imported through the PocketBase admin UI before each release.

```
collections: users, driver_profiles, tow_requests, ratings,
driver_reports, driver_applications, support_qa
```

Key access rules:

```
tow_requests.listRule:
  @request.auth.id != "" && (
    user = @request.auth.id ||
    driver = @request.auth.id ||
    @request.auth.Driver = true
  )

tow_requests.updateRule: same as listRule
tow_requests.createRule: @request.auth.id = user
tow_requests.deleteRule: @request.auth.id = user
ratings.createRule: @request.auth.id != "" && user = @request.auth.id
support_qa.createRule: @request.auth.id != "" && user = @request.auth.id
```
