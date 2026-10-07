#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# BusBuddy Chrome Launcher
# Starts the Flutter web server and automatically opens Google Chrome
# with Web Audio autoplay enabled.
# ------------------------------------------------------------------------------
set -e

PORT=8080
API_KEY="${1:-$GEMINI_API_KEY}"

echo "=================================================="
echo " Starting BusBuddy for Google Chrome"
echo "=================================================="

# Terminate any stale background processes holding the port
pkill -9 -f "dart.*frontend_server" 2>/dev/null || true
pkill -9 -f "flutter_tools" 2>/dev/null || true

FLAGS=(
  "-d" "web-server"
  "--web-port" "$PORT"
  "--web-hostname" "127.0.0.1"
)

if [ -n "$API_KEY" ]; then
  echo "✓ Gemini API Key attached for live voice assistant."
  FLAGS+=("--dart-define=GEMINI_API_KEY=$API_KEY")
else
  echo "! No GEMINI_API_KEY provided."
  echo "  (You can pass it as: ./run_chrome.sh AIzaSy... or enter it inside the app)"
fi

# Background watcher: as soon as Flutter web-server is listening, open in Chrome
(
  URL="http://localhost:$PORT"
  CHROME_FLAGS="--autoplay-policy=no-user-gesture-required"

  # Wait for port to open (up to 45 seconds)
  for _ in {1..45}; do
    if (echo > /dev/tcp/127.0.0.1/$PORT) 2>/dev/null; then
      sleep 1
      echo ""
      echo "=================================================="
      echo "✓ BusBuddy Web Server is active at $URL"
      echo " Launching in Google Chrome..."
      echo "=================================================="
      
      if command -v google-chrome &>/dev/null; then
        google-chrome $CHROME_FLAGS "$URL" >/dev/null 2>&1 &
      elif command -v google-chrome-stable &>/dev/null; then
        google-chrome-stable $CHROME_FLAGS "$URL" >/dev/null 2>&1 &
      elif command -v chromium-browser &>/dev/null; then
        chromium-browser $CHROME_FLAGS "$URL" >/dev/null 2>&1 &
      elif command -v chromium &>/dev/null; then
        chromium $CHROME_FLAGS "$URL" >/dev/null 2>&1 &
      elif command -v xdg-open &>/dev/null; then
        xdg-open "$URL" >/dev/null 2>&1 &
      else
        echo "Please open your browser to: $URL"
      fi
      exit 0
    fi
    sleep 1
  done
) &

echo "Running: flutter ${FLAGS[*]}"
exec flutter run "${FLAGS[@]}"
