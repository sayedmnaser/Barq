# Barq source bundle

This package is a cleaned-up Flutter source bundle for Barq with:

- PocketBase through a central service in `lib/services/pocketbase_service.dart`
- Bahrain map search and routing through `lib/services/bahrain_map_service.dart`
- live map widgets in estimate, request, and tracking screens
- a deployment template under `deployment/pocketbase/` so your phone app can work from any Wi-Fi once you host PocketBase on a public domain

## Open this as your project root

The important files are already in the correct places:

```text
barq/
  pubspec.yaml
  analysis_options.yaml
  assets/images/white_mod.png
  lib/
  test/
  deployment/pocketbase/
```

## App configuration

For production on a real phone, point the app to a public HTTPS backend:

```bash
flutter run --dart-define=POCKETBASE_URL=https://api.barqapp.com
```

For local testing on a real phone on the same Wi-Fi:

```bash
flutter run --dart-define=POCKETBASE_URL=http://YOUR_PC_IP:8090
```

## PocketBase collections expected

### `users`
Auth collection used for sign in and sign up.

### `tow_requests`
Required fields already used by the app:

- `user`
- `pickup_location`
- `destination`
- `vehicle_type`
- `details`
- `service_timing`
- `status`

Optional fields the app can read when available:

- `pickup_lat`
- `pickup_lng`
- `destination_lat`
- `destination_lng`
- `driver_lat`
- `driver_lng`
- `distance_km`
- `eta_minutes`
- `base_fare`
- `distance_fare`
- `driver_name`
- `driver_rating`
- `driver_total_rides`
- `license_plate`

## Notes

- The app source is ready to download and replace your project files.
- A public server/domain is still required if you want the app to work from any Wi-Fi in Bahrain.
- The deployment templates are in `deployment/pocketbase/`.
