#!/usr/bin/env bash

set -eu

YELLOW=$'\033[1;33m'
BLUE=$'\033[1;34m'
GREEN=$'\033[1;32m'
RED=$'\033[0;31m'
NC=$'\033[0m'

info()  { printf '%s\n' "${YELLOW}==>${NC} $*"; }
ok()    { printf '%s\n' "${GREEN}==>${NC} $*"; }
warn()  { printf '%s\n' "${RED}!!${NC} $*" >&2; }
die()   { warn "$*"; exit 1; }

if [ -r /dev/tty ]; then
	exec 3</dev/tty
else
	die "No TTY available for prompts. Re-run by saving the script and executing it directly, e.g.:
	curl -fsSL <url>/uninstall.sh -o \"\$PREFIX/tmp/uninstall.sh\" && bash \"\$PREFIX/tmp/uninstall.sh\""
fi

confirm() {
	# confirm "Prompt text" [default-y|default-n]
	local prompt="$1" default="${2:-default-n}" reply
	local hint="[y/N]"
	[ "$default" = "default-y" ] && hint="[Y/n]"
	printf '%s %s ' "${YELLOW}?${NC} $prompt" "$hint" >/dev/tty
	IFS= read -r reply <&3 || reply=""
	if [ -z "$reply" ]; then
		[ "$default" = "default-y" ]
		return $?
	fi
	case "$reply" in
		y|Y|yes|YES) return 0 ;;
		*) return 1 ;;
	esac
}

# --- Sanity ---
[ -n "${TERMUX__PREFIX:-}" ] || die "TERMUX__PREFIX is not set. Run inside Termux."
[ -d "$TERMUX__PREFIX/bin" ] || die "Invalid TERMUX__PREFIX: $TERMUX__PREFIX"

WRAPPER="$TERMUX__PREFIX/bin/claude"
PACKAGE="@anthropic-ai/claude-code-linux-arm64"
INSTALL_DIR="$TERMUX__PREFIX/share/claude-code-native"

# --- Step 1: remove wrapper ---
if [ -f "$WRAPPER" ] || [ -L "$WRAPPER" ]; then
	if grep -q "$PACKAGE" "$WRAPPER" 2>/dev/null; then
		info "Removing wrapper: ${BLUE}${WRAPPER}${NC}"
		rm -f "$WRAPPER"
		ok "Wrapper removed."
	else
		warn "Found ${WRAPPER} but it doesn't look like this project's wrapper; leaving it alone."
	fi
else
	info "No wrapper found at ${WRAPPER}."
fi

# --- Step 2: native binary directory ---
if [ -d "$INSTALL_DIR" ]; then
	if confirm "Remove native binary at ${BLUE}${INSTALL_DIR}${NC}?" default-y; then
		rm -rf "${INSTALL_DIR:?}"
		ok "Native binary removed."
	fi
else
	info "No native binary directory at ${INSTALL_DIR}."
fi

# --- Step 3: user config/data (XDG first, then legacy ~/.claude) ---
CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME:-}/.config}/claude"
if [ ! -d "$CONFIG_DIR" ]; then
	CONFIG_DIR="${HOME:-}/.claude"
fi
if [ -n "$CONFIG_DIR" ] && [ -d "$CONFIG_DIR" ]; then
	if confirm "Remove user config/data at ${BLUE}${CONFIG_DIR}${NC}? (contains sessions, settings, etc.)" default-n; then
		rm -rf "${CONFIG_DIR:?}"
		ok "Removed ${CONFIG_DIR}."
	else
		info "Keeping ${CONFIG_DIR}."
	fi
fi

# --- Step 4: optional Termux packages ---
printf '\n'
info "The following Termux packages were installed by this project but may be used elsewhere:"
printf '    %s\n' "glibc-repo  glibc-runner  jq"
info "Run ${BLUE}pkg uninstall${NC} on any you no longer need."

ok "${GREEN}Uninstall complete.${NC}"
