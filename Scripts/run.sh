#!/bin/zsh
# Builds the Debug app and relaunches it.
set -euo pipefail
cd "${0:A:h}/.."
xcodegen generate --quiet
xcodebuild -project Opaline.xcodeproj -scheme Opaline -configuration Debug -derivedDataPath .build/xcode build 2>&1 \
  | grep -E '^/.*(error|warning):|BUILD (SUCCEEDED|FAILED)' | sort -u
snapshots="$HOME/Library/Application Support/Opaline/snapshots"
if [[ -d "$snapshots" ]] && [[ -n "$(find "$snapshots" -mindepth 1 -newermt '-2 minutes' -print -quit)" ]]; then
  echo "An apply or restore ran in the last 2 minutes; not killing the app." >&2
  exit 1
fi
pkill -x Opaline || true
sleep 1
open .build/xcode/Build/Products/Debug/Opaline.app
