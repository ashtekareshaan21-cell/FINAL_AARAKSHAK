# Aarakshak server — deploy (Phase 1)

The Flutter app talks to this FastAPI server only when a server URL is
configured at build time. There is no localhost fallback in the app.

## 1. Deploy the server

Any host that runs Python + uvicorn works (Render, Railway, Fly.io,
a VPS — pick one, the code does not depend on the host):

```bash
pip install -r requirements.txt
AARAKSHAK_API_TOKEN=<a long random token> \
AARAKSHAK_CORS_ORIGINS=https://your-dashboard.example.com \
uvicorn main:app --host 0.0.0.0 --port 8000
```

Required before production use:

- `AARAKSHAK_API_TOKEN` — must be set. Without it the server logs a
  warning and accepts unauthenticated packets (local dev only).
- HTTPS — the app accepts an `http://` URL only for local testing.
  A deployed server must be `https://`.

## 2. Point the app at it

```bash
flutter run \
  --dart-define=AARAKSHAK_SERVER_URL=https://your-server.example.com \
  --dart-define=AARAKSHAK_API_TOKEN=<same token as the server>
```

Without `AARAKSHAK_SERVER_URL`, `InternetTransport` reports
disconnected and packets stay QUEUED locally — it never claims a
delivery to a server that does not exist.

## 3. Free data feeds in this phase (no keys)

- NASA EONET — already live.
- GDACS global alerts — `live_disaster_service.dart`.
- USGS earthquakes (M2.5+, past day) — same file.
- OSM Overpass hospitals/shelters — `overpass_service.dart`.
  Overpass is a shared public service: call `refreshFromOverpass`
  on manual refresh only, not on every screen build.

## What Phase 1 does NOT do

- It does not wire `SyncService` to run at app start, and it does
  not add WebSocket ACKs — that is Phase 2.
- It does not promise IMD/NDMA data. No open IMD API was verified
  in the audit; EONET + GDACS + USGS + Open-Meteo are the live
  sources until an official feed is found.
