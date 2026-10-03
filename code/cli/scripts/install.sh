#!/bin/bash
# install.sh: downloads and installs the latest Calculatrix CLI release on
# Linux.
#
# Usage:
#   curl -fsSL https://calculatrix.ccisne.dev/install.sh | bash
#
# This file is served from the site's web build (see
# .github/workflows/pages-release.yml, which copies it there) and also lives
# here as its source of truth.
#
# Modeled on ccisnedev/inquiry's code/site/install.sh, adapted for
# calculatrix (runbook docs/runbook-cli-stage-0.md, "Publishing (dogfood)"):
#   - this repository also publishes app releases tagged vX.Y.Z, so this
#     script lists releases and picks the newest cli-v* one instead of
#     calling GET /releases/latest, which would resolve to whichever kind of
#     release happens to be newest (constraint 3 in the runbook, D31);
#   - no `iq`-style alias is created: unlike inquiry, which symlinks a
#     second, shorter name alongside its own, the only symlink this script
#     creates keeps the same name, `cx`, and exists only to put the real
#     binary on the XDG-standard ~/.local/bin (issue #22, D40: no alias of
#     any kind);
#   - there is no host/skill deployment step: calculatrix has none;
#   - the collision check below is calculatrix-specific: inquiry's script
#     has none.
#
# What it does:
#   1. Detects Linux x64
#   2. Warns if `cx` already resolves to something this installer did not
#      put there
#   3. Lists releases and picks the newest cli-v* tag
#   4. Downloads the matching cx-linux-x64.tar.gz from GitHub Releases
#   5. Extracts to ~/.calculatrix/ (bin/cx)
#   6. Symlinks ~/.local/bin/cx (XDG standard, in default PATH) to it
#   7. Verifies with `cx version`

set -euo pipefail

REPO="ccisnedev/calculatrix"
INSTALL_DIR="$HOME/.calculatrix"
BIN_DIR="$INSTALL_DIR/bin"
ASSET_NAME="cx-linux-x64.tar.gz"
LINK_DIR="$HOME/.local/bin"
LINK_PATH="$LINK_DIR/cx"

# --- Platform check ----------------------------------------------------------

ARCH=$(uname -m)
OS=$(uname -s)

if [ "$OS" != "Linux" ]; then
  echo "Error: the Calculatrix CLI install.sh is for Linux only. Got: $OS" >&2
  exit 1
fi

if [ "$ARCH" != "x86_64" ]; then
  echo "Error: the Calculatrix CLI requires x86_64. Got: $ARCH" >&2
  exit 1
fi

# --- Collision check -----------------------------------------------------------

if command -v cx >/dev/null 2>&1; then
  EXISTING="$(command -v cx)"
  if [ "$EXISTING" != "$LINK_PATH" ]; then
    echo "Warning: 'cx' already resolves to $EXISTING, which is not $LINK_PATH." >&2
    echo "Warning: installing anyway; check your PATH order if the wrong one runs afterward." >&2
  fi
fi

# --- Fetch releases and pick the newest cli-v* one ----------------------------

# Two calls, not one: GET /releases returns every release in this repository
# (app releases tagged vX.Y.Z included), so this script never calls
# /releases/latest (constraint 3 in the runbook, D31). The first call only
# needs the tag names, so it is picked with sort -V rather than trusting the
# list's order. The second call, GET /releases/tags/<tag>, returns exactly
# one release object, which can be grepped the same simple way inquiry's
# script greps its own single /releases/latest response, with no risk of an
# asset name from a different release matching first.

echo ">>> Fetching releases..."
RELEASES_URL="https://api.github.com/repos/$REPO/releases"
RELEASES_JSON=$(curl -fsSL -H "Accept: application/vnd.github+json" "$RELEASES_URL")

CLI_VERSIONS=$(echo "$RELEASES_JSON" | grep -o '"tag_name":\s*"cli-v[^"]*"' | sed 's/.*"cli-v\([^"]*\)".*/\1/')

if [ -z "$CLI_VERSIONS" ]; then
  echo "Error: no cli-v* release found in $REPO." >&2
  exit 1
fi

TAG="cli-v$(echo "$CLI_VERSIONS" | sort -V | tail -1)"

echo ">>> Fetching release $TAG..."
RELEASE_URL="https://api.github.com/repos/$REPO/releases/tags/$TAG"
RELEASE_JSON=$(curl -fsSL -H "Accept: application/vnd.github+json" "$RELEASE_URL")
DOWNLOAD_URL=$(echo "$RELEASE_JSON" | grep -o '"browser_download_url":\s*"[^"]*'"$ASSET_NAME"'"' | head -1 | sed 's/.*"browser_download_url":\s*"\([^"]*\)".*/\1/')

if [ -z "$DOWNLOAD_URL" ]; then
  echo "Error: no $ASSET_NAME asset found in release $TAG." >&2
  exit 1
fi

echo "    Release: $TAG"
echo "    Asset:   $ASSET_NAME"

# --- Download and extract -----------------------------------------------------

TEMP_FILE=$(mktemp /tmp/cx-XXXXXX.tar.gz)

echo ">>> Downloading..."
curl -fsSL -o "$TEMP_FILE" "$DOWNLOAD_URL"

# Clean previous installation
if [ -d "$INSTALL_DIR" ]; then
  echo ">>> Removing previous installation..."
  rm -rf "$INSTALL_DIR"
fi

echo ">>> Extracting..."
mkdir -p "$INSTALL_DIR"
tar xzf "$TEMP_FILE" -C "$INSTALL_DIR"
rm -f "$TEMP_FILE"

chmod +x "$BIN_DIR/cx"

# --- PATH integration ----------------------------------------------------------

mkdir -p "$LINK_DIR"

if [ -L "$LINK_PATH" ] && [ "$(readlink "$LINK_PATH")" = "$BIN_DIR/cx" ]; then
  echo ">>> Symlink already configured: $LINK_PATH -> $BIN_DIR/cx"
else
  ln -sf "$BIN_DIR/cx" "$LINK_PATH"
  echo ">>> Symlink configured: $LINK_PATH -> $BIN_DIR/cx"
fi

if [[ ":$PATH:" != *":$LINK_DIR:"* ]]; then
  export PATH="$LINK_DIR:$PATH"
  echo ">>> Added $LINK_DIR to PATH for this session"
else
  echo ">>> PATH already includes $LINK_DIR"
fi

# Persist PATH in shell profiles (.bashrc / .zshrc) for future sessions
# (.profile is only sourced by login shells; interactive shells need rc files)
for RC_FILE in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [ -f "$RC_FILE" ] || continue
  if ! grep -q '\.local/bin' "$RC_FILE"; then
    printf '\n# Added by the Calculatrix CLI installer\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$RC_FILE"
    echo ">>> Added ~/.local/bin to PATH in $(basename "$RC_FILE")"
  fi
done

# --- Verify ----------------------------------------------------------------------

echo ">>> Verifying installation..."
VERSION_OUTPUT=$("$BIN_DIR/cx" version)
echo "    $VERSION_OUTPUT"

echo ""
echo ">>> Calculatrix CLI installed successfully!"
echo "    Location: $INSTALL_DIR"
echo "    Restart your terminal to use 'cx' from any directory."
echo ""
echo "    RPN:      cx '2 3 +'   (one quoted program; it can leave several results: cx '2 sqrt 1 3 /')"
echo "    Infix:    cx eval infix '2+3'"
echo "    Values:   every value is a matrix, exact (1/3, 0.1) or approximate, marked ~ (~1.41421356237)"
echo "    Discover: cx commands search <term>, cx commands show <word>; add --json for JSON output"
echo "    More: cx --help"
