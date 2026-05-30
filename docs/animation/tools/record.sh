#!/usr/bin/env bash
# Regenerate ../videos/tunnela-tunnels.mp4 from the HTML animation.
# Re-run this any time you edit the animation and the video updates to match.
#
#   ./tools/record.sh                  # 1920x1080, 60fps, high quality (default)
#   FPS=30 SCALE=1 ./tools/record.sh   # 1280x720, 30fps
#   CRF=12 ./tools/record.sh           # even higher quality (lower CRF = better)
#   BITRATE=30M ./tools/record.sh      # force an explicit high bitrate
set -euo pipefail

cd "$(dirname "$0")/.."   # repo root

command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg not found — install with: brew install ffmpeg"; exit 1; }
command -v node   >/dev/null 2>&1 || { echo "node not found — install Node.js first"; exit 1; }

# install Playwright + chromium on first run
if [ ! -d node_modules/playwright ]; then
  echo "Installing Playwright (one-time)…"
  npm i -D playwright
  npx playwright install chromium
fi

node tools/record-video.mjs
