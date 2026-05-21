#!/usr/bin/env bash

set -eu

PACKAGE="@anthropic-ai/claude-code-linux-arm64"
META_URL="https://registry.npmjs.org/${PACKAGE}/latest"

INSTALL_DIR="${TERMUX__PREFIX:?TERMUX__PREFIX is not set}/share/claude-code-native"
PACKAGE_JSON="$INSTALL_DIR/package.json"
BINARY_PATH="$INSTALL_DIR/claude"

if command -v jq >/dev/null 2>&1; then
	JSON=jq
elif command -v jaq >/dev/null 2>&1; then
	JSON=jaq
else
	printf 'Neither jq nor jaq found on PATH.\n' >&2
	exit 1
fi

if [ ! -f "$BINARY_PATH" ]; then
	printf 'Claude binary not found at %s\nPlease reinstall.\n' "$BINARY_PATH" >&2
	exit 1
fi
[ -x "$BINARY_PATH" ] || chmod ug+x "$BINARY_PATH"

printf 'Checking for updates... '
META=$(curl -fsSL "$META_URL" 2>/dev/null || true)
LATEST_VERSION=$(printf '%s' "$META" | "$JSON" -r '.version' 2>/dev/null || true)
if [ -f "$PACKAGE_JSON" ]; then
	INSTALLED_VERSION=$(grep '"version":' "$PACKAGE_JSON" | cut -d'"' -f4)
else
	INSTALLED_VERSION=""
fi

if [ -n "$LATEST_VERSION" ] && [ "$LATEST_VERSION" != "null" ] && [ "$LATEST_VERSION" != "$INSTALLED_VERSION" ]; then
	printf '\nNew version (%s) found. Updating...\n' "$LATEST_VERSION"
	URL=$(printf '%s' "$META" | "$JSON" -r '.dist.tarball')
	[ -n "$URL" ] && [ "$URL" != "null" ] || { printf 'Could not resolve update URL.\n' >&2; exit 1; }
	TMP="$(mktemp -d)"
	trap 'rm -rf "$TMP"' EXIT
	curl -fSL --progress-bar "$URL" -o "$TMP/claude_update.tgz"
	tar -xzf "$TMP/claude_update.tgz" -C "$INSTALL_DIR" --strip-components=1
	chmod ug+x "$BINARY_PATH"
	printf 'Update complete.\n'
else
	printf 'Done (already up to date).\n'
fi

glibc-runner "$BINARY_PATH" "$@"
