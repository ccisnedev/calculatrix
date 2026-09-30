#!/bin/bash
# build.sh: compile cx and package it into the release archive layout
# (Linux).
#
# Usage: ./scripts/build.sh
# Run from code/cli/. Used by .github/workflows/cli-release.yml and usable
# locally to reproduce a release build without pushing anything.
#
# Produces build/bin/cx and cx-linux-x64.tar.gz in the current directory,
# with cx directly under a top-level bin/ folder in the archive. That layout
# is required by modular_cli_sdk's LinuxPlatformOps: `expandArchive` extracts
# straight into the install directory, and `runPostInstall` /
# `scheduleDeletion` look for `<installDir>/bin/<binaryName>`.

set -euo pipefail

echo "Fetching dependencies..."
dart pub get

echo "Compiling cx..."
mkdir -p build/bin
dart compile exe bin/cx.dart -o build/bin/cx

ASSET="cx-linux-x64.tar.gz"
echo "Packaging $ASSET..."
rm -f "$ASSET"
tar czf "$ASSET" -C build bin

echo "Done: $ASSET"
