#!/usr/bin/env bash

set -eu

YELLOW=$'\033[1;33m'
BLUE=$'\033[1;34m'
GREEN=$'\033[1;32m'
RED=$'\033[0;31m'
DIM=$'\033[2m'
NC=$'\033[0m'

info()  { printf '%s\n' "${YELLOW}==>${NC} $*"; }
ok()    { printf '%s\n' "${GREEN}==>${NC} $*"; }
warn()  { printf '%s\n' "${RED}!!${NC} $*" >&2; }
die()   { warn "$*"; exit 1; }

# --- Sanity: Termux environment ---
[ -n "${TERMUX__PREFIX:-}" ] || die "TERMUX__PREFIX is not set. This script must run inside Termux."
[ -d "$TERMUX__PREFIX/bin" ] || die "TERMUX__PREFIX ($TERMUX__PREFIX) does not look like a valid Termux prefix."
command -v pkg >/dev/null 2>&1 || die "pkg not found. This script requires Termux."

# The npm package and glibc-runner shim are arm64-only; bail early on anything else.
ARCH="$(uname -m)"
case "$ARCH" in
	aarch64|arm64) ;;
	*) die "Unsupported architecture: $ARCH. This project only supports arm64 Termux." ;;
esac

# Abstract package query across Termux's apt and pacman variants.
# `pkg install` works in both; only the "is it installed?" check differs.
if command -v dpkg >/dev/null 2>&1; then
	pkg_installed() { dpkg -s "$1" >/dev/null 2>&1; }
elif command -v pacman >/dev/null 2>&1; then
	pkg_installed() { pacman -Qi "$1" >/dev/null 2>&1; }
else
	die "Neither dpkg nor pacman found; cannot query package state."
fi

PACKAGE="@anthropic-ai/claude-code-linux-arm64"
META_URL="https://registry.npmjs.org/${PACKAGE}/latest"
INSTALL_DIR="$TERMUX__PREFIX/share/claude-code-native"
WRAPPER_URL="https://raw.githubusercontent.com/Keyaku/claude-code-termux/refs/heads/main/claude.sh"

# --- Step 1: required packages ---
info "Checking required Termux packages."
REQUIRED_PKGS="glibc-repo glibc-runner curl tar"
# Only ensure jq is present if neither jq nor jaq is already installed.
if ! command -v jq >/dev/null 2>&1 && ! command -v jaq >/dev/null 2>&1; then
	REQUIRED_PKGS="$REQUIRED_PKGS jq"
fi

MISISNG_REPO=0
MISSING=""
for p in $REQUIRED_PKGS; do
	if ! pkg_installed "$p"; then
		[ "$p" = "glibc-repo" ] && MISSING_REPO=1 || MISSING="$MISSING $p"
	fi
done

if [ -n "$MISSING" ]; then
	info "Installing missing packages:${BLUE}${MISSING}${NC}"
	pkg update -y
	if [ $MISSING_REPO -eq 1 ]; then
		pkg install -y glibc-repo
		pkg update
	fi
	# shellcheck disable=SC2086
	pkg install -y $MISSING
else
	ok "All required packages already installed."
fi

# Pick JSON parser at runtime (no shims).
if command -v jq >/dev/null 2>&1; then
	JSON=jq
elif command -v jaq >/dev/null 2>&1; then
	JSON=jaq
else
	die "Neither jq nor jaq found after package install."
fi

# --- Step 2: fetch native arm64 binary ---
info "Querying npm registry for latest ${BLUE}${PACKAGE}${NC}."
META=$(curl -fsSL "$META_URL") || die "Could not reach npm registry. Check your internet connection."
URL=$(printf '%s' "$META" | "$JSON" -r '.dist.tarball')
[ -n "$URL" ] && [ "$URL" != "null" ] || die "Could not resolve tarball URL from registry response."

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

info "Downloading ${DIM}${URL}${NC}"
curl -fSL --progress-bar "$URL" -o "$TMPDIR/claude-native.tgz" \
	|| die "Could not download native binary. Check your internet connection."

info "Extracting to ${BLUE}${INSTALL_DIR}${NC}"
mkdir -p "$INSTALL_DIR"
tar -xzf "$TMPDIR/claude-native.tgz" -C "$INSTALL_DIR" --strip-components=1

# --- Step 3: fetch wrapper ---
WRAPPER="$TERMUX__PREFIX/bin/claude"
info "Downloading wrapper script to ${BLUE}${WRAPPER}${NC}"
curl -fsSL "$WRAPPER_URL" -o "$WRAPPER" \
	|| die "Could not download wrapper from $WRAPPER_URL."
chmod +x "$WRAPPER"

ok "${GREEN}Installation complete.${NC}"
printf '%s\n' "Run ${BLUE}claude${NC} — it will check for updates and run natively."
