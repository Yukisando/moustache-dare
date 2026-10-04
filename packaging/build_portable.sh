#!/usr/bin/env bash
# Builds a release and wraps it into a single double-clickable dist/MoustacheDare.exe.
set -euo pipefail
cd "$(dirname "$0")/.."
# Use a sibling Flutter checkout if there is one, otherwise whatever is on PATH.
if [ -d ../flutter/bin ]; then export PATH="$(cd ../flutter/bin && pwd):$PATH"; fi

flutter build windows --release

release=build/windows/x64/runner/Release
work=build/portable
rm -rf "$work" && mkdir -p "$work" dist
powershell -NoProfile -Command \
  "Compress-Archive -Path '$release\\*' -DestinationPath '$work\\app.zip' -Force"
date +%Y%m%d%H%M%S > "$work/build_id.txt"

MSYS_NO_PATHCONV=1 /c/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe -nologo -target:winexe -optimize \
  '-out:dist\MoustacheDare.exe' \
  '-win32icon:windows\runner\resources\app_icon.ico' \
  "-resource:$work/app.zip,app.zip" \
  "-resource:$work/build_id.txt,build_id.txt" \
  -r:System.IO.Compression.dll -r:System.IO.Compression.FileSystem.dll -r:System.Windows.Forms.dll \
  'packaging\Launcher.cs'

ls -la dist/MoustacheDare.exe
