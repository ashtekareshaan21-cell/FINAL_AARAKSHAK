#!/usr/bin/env bash
set -e

echo "=== Aarakshak Vercel Build Starting ==="

# 1. Install Flutter if not in PATH
if command -v flutter >/dev/null 2>&1; then
  echo "Flutter is already installed in system PATH."
elif [ -d "$PWD/_flutter/bin" ]; then
  echo "Using existing cached Flutter in $PWD/_flutter/bin"
  export PATH="$PATH:$PWD/_flutter/bin"
else
  echo "Downloading stable Flutter SDK..."
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$PWD/_flutter"
  export PATH="$PATH:$PWD/_flutter/bin"
fi

flutter --version

# 2. Configure Flutter
flutter config --no-analytics
flutter config --enable-web

# 3. Install project dependencies
echo "Fetching Flutter dependencies..."
flutter pub get

# 4. Determine build flags from environment variables
SERVER_URL="${AARAKSHAK_SERVER_URL:-https://aarakshak-onao.onrender.com}"
DART_DEFINES="--dart-define=AARAKSHAK_SERVER_URL=$SERVER_URL"

if [ -n "$AARAKSHAK_API_TOKEN" ]; then
  DART_DEFINES="$DART_DEFINES --dart-define=AARAKSHAK_API_TOKEN=$AARAKSHAK_API_TOKEN"
fi

echo "Building Flutter Web (release)..."
echo "Target backend server: $SERVER_URL"

# 5. Build Web bundle
flutter build web --release --no-wasm-dry-run $DART_DEFINES

echo "=== Build finished successfully. Artifacts ready in build/web/ ==="
