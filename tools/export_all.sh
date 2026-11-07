#!/bin/sh
# Export the Windows, macOS, and Linux packages and make the zip files.
# CI runs this script for each pull request. Thus an export error shows
# before the merge, not in the release after the merge.
set -eu
rm -rf build GunFare-windows.zip GunFare-linux.zip GunFare-macos.zip
mkdir -p build/windows build/linux build/macos
godot --headless --path . --export-release "Windows" build/windows/GunFare.exe
godot --headless --path . --export-release "Linux" build/linux/GunFare.x86_64
godot --headless --path . --export-release "macOS" build/macos/GunFare.app
test -f build/windows/GunFare.exe
test -f build/linux/GunFare.x86_64
test -d build/macos/GunFare.app
(cd build/windows && zip -q -r ../../GunFare-windows.zip .)
(cd build/linux && zip -q -r ../../GunFare-linux.zip .)
(cd build/macos && zip -q -r -y ../../GunFare-macos.zip GunFare.app)
unzip -l GunFare-windows.zip | grep -q ' GunFare.exe$'
unzip -l GunFare-linux.zip | grep -q ' GunFare.x86_64$'
unzip -l GunFare-macos.zip | grep -q ' GunFare.app/Contents/MacOS/'
for f in GunFare-windows.zip GunFare-linux.zip GunFare-macos.zip; do
    size=$(wc -c < "$f")
    if [ "$size" -lt 1000000 ]; then
        echo "$f is too small ($size bytes)."
        exit 1
    fi
    echo "$f: $size bytes"
done
