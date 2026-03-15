# PocketBase deployment template for Barq

This folder contains a production template so the Flutter app can talk to a public backend URL instead of a laptop on local Wi-Fi.

## Option A: direct binary on a VPS

1. Upload `pocketbase`, `pb_data`, `pb_hooks`, and `pb_migrations` to your Linux server.
2. Edit `pocketbase.service` and replace `api.barqapp.com` with your real domain.
3. Install the systemd service.
4. Point your DNS `A` record to the server IP.

## Option B: Docker + Caddy

1. Copy `.env.example` to `.env` and set `DOMAIN` and `EMAIL`.
2. Build and run:
   ```bash
   docker compose up -d --build
   ```
3. The Flutter app should use:
   ```text
   https://YOUR_DOMAIN
   ```

## Flutter production run

```bash
flutter run --dart-define=POCKETBASE_URL=https://api.barqapp.com
```

You can also override map services if you later move away from the public demo endpoints:

```bash
flutter run   --dart-define=POCKETBASE_URL=https://api.barqapp.com   --dart-define=GEOCODING_BASE_URL=https://your-geocoder.example.com   --dart-define=ROUTING_BASE_URL=https://your-router.example.com   --dart-define=MAP_TILE_URL=https://tiles.example.com/{z}/{x}/{y}.png   --dart-define=MAP_USER_AGENT=com.barq.app
```
