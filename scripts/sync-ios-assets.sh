#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST_DIR="$ROOT_DIR/ios/TravelItinerary/WebApp"

mkdir -p "$DEST_DIR"
rm -rf "$DEST_DIR/css" "$DEST_DIR/js" "$DEST_DIR/data"
cp "$ROOT_DIR/index.html" "$DEST_DIR/index.html"
cp -R "$ROOT_DIR/css" "$ROOT_DIR/js" "$ROOT_DIR/data" "$DEST_DIR/"
find "$DEST_DIR" -name ".DS_Store" -delete

echo "Synced web assets to ios/TravelItinerary/WebApp"
