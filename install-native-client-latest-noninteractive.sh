#!/bin/sh
set -eu

REPO="andy-portmen/native-client"
API="https://api.github.com/repos/$REPO/releases/latest"

TMPDIR="$(mktemp -d 2>/dev/null || mktemp -d -t nativeclient)"
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

download() {
  url="$1"; out="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$out" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$out" "$url"
  else
    echo "Error: curl or wget required" >&2
    exit 2
  fi
}

RELEASE_JSON="$TMPDIR/release.json"
download "$API" "$RELEASE_JSON"

grep -oE '"browser_download_url":[[:space:]]*"[^"]+"' "$RELEASE_JSON" | sed -E 's/.*"([^"]+)".*/\1/' > "$TMPDIR/assets" || true
if [ ! -s "$TMPDIR/assets" ]; then
  echo "No assets found in latest release" >&2
  exit 3
fi

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m | tr '[:upper:]' '[:lower:]')"

pick_asset() {
  case "$OS" in
    darwin) grep -Ei 'darwin|mac|macos|osx' "$TMPDIR/assets" | grep -Ei '\.tar\.gz$|\.tgz$|\.zip$' || true ;;
    linux)  grep -Ei 'linux' "$TMPDIR/assets" | grep -Ei '\.tar\.gz$|\.tgz$|\.zip$' || true ;;
    *)      grep -Ei '\.tar\.gz$|\.tgz$|\.zip$' "$TMPDIR/assets" || true ;;
  esac
}

ASSET_URL="$(pick_asset | head -n1 || true)"
if [ -z "$ASSET_URL" ]; then
  ASSET_URL="$(grep -Ei '\.tar\.gz$|\.tgz$|\.zip$' "$TMPDIR/assets" | head -n1 || true)"
fi
if [ -z "$ASSET_URL" ]; then
  ASSET_URL="$(head -n1 "$TMPDIR/assets")"
fi

echo "Selected asset: $ASSET_URL"
ARCHIVE="$TMPDIR/$(basename "$ASSET_URL")"
echo "Downloading $ARCHIVE..."
download "$ASSET_URL" "$ARCHIVE"

echo "Extracting..."
case "$ARCHIVE" in
  *.zip)
    if command -v unzip >/dev/null 2>&1; then
      unzip -q "$ARCHIVE" -d "$TMPDIR"
    else
      echo "Error: unzip required to extract $ARCHIVE" >&2
      exit 4
    fi
    ;;
  *.tar.gz|*.tgz)
    tar -xzf "$ARCHIVE" -C "$TMPDIR"
    ;;
  *)
    if tar -tzf "$ARCHIVE" >/dev/null 2>&1; then
      tar -xzf "$ARCHIVE" -C "$TMPDIR"
    elif command -v unzip >/dev/null 2>&1; then
      unzip -q "$ARCHIVE" -d "$TMPDIR"
    else
      echo "Unknown archive format and extraction tools missing" >&2
      exit 5
    fi
    ;;
esac

INSTALLER="$(find "$TMPDIR" -maxdepth 6 -type f -name install.sh -print | head -n1 || true)"
if [ -z "$INSTALLER" ]; then
  echo "install.sh not found in archive" >&2
  exit 6
fi

echo "Found installer: $INSTALLER"
chmod +x "$INSTALLER"
cd "$(dirname "$INSTALLER")"

echo "Running installer (non-interactive)..."
sh ./install.sh
rc=$?
if [ $rc -ne 0 ]; then
  echo "Installer exited with code $rc" >&2
  exit $rc
fi

echo "Installer completed successfully."
