// Phase 1 — app configuration for the live server.
//
// The server URL and API token are supplied at build time with
// --dart-define, so no URL, token or secret is ever committed to the repo:
//   flutter run --dart-define=AARAKSHAK_SERVER_URL=https://your-server.example.com \
//               --dart-define=AARAKSHAK_API_TOKEN=your-token
//
// If AARAKSHAK_SERVER_URL is not set, serverBaseUrl is empty and the app
// must NOT fall back to localhost. On a phone, 127.0.0.1 is the phone
// itself, not the server — the old default. An empty URL means "no server
// configured": InternetTransport fails honestly instead of pretending.
class AppConfig {
  static const String serverBaseUrl = String.fromEnvironment(
    'AARAKSHAK_SERVER_URL',
    defaultValue: '',
  );

  static const String apiToken = String.fromEnvironment(
    'AARAKSHAK_API_TOKEN',
    defaultValue: '',
  );

  static bool get isServerConfigured =>
      serverBaseUrl.isNotEmpty &&
      (serverBaseUrl.startsWith('https://') ||
          serverBaseUrl.startsWith('http://'));

  // Overpass and the public disaster feeds need no key.
  static const String overpassUrl = 'https://overpass-api.de/api/interpreter';
  static const String usgsFeedUrl =
      'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/2.5_day.geojson';
  static const String gdacsFeedUrl =
      'https://www.gdacs.org/gdacsapi/api/events/geteventlist/SEARCH';
}
