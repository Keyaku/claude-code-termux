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
NPM_PACKAGE="@anthropic-ai/claude-code"

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

# --- Step 2: native binary package ---
if command -v npm >/dev/null 2>&1; then
	NPM_ROOT="$(npm -g root 2>/dev/null || true)"
	if [ -n "$NPM_ROOT" ] && [ -d "$NPM_ROOT/$PACKAGE" ]; then
		if confirm "Remove native binary package at ${BLUE}${NPM_ROOT}/${PACKAGE}${NC}?" default-y; then
			rm -rf "${NPM_ROOT:?}/$PACKAGE"
			ok "Native binary package removed."
		fi
	fi

	# --- Step 3: claude-code npm package ---
	if npm -g ls --depth=0 "$NPM_PACKAGE" >/dev/null 2>&1; then
		if confirm "Uninstall ${BLUE}${NPM_PACKAGE}${NC} from global npm?" default-y; then
			npm -g uninstall "$NPM_PACKAGE" || warn "npm uninstall failed."
		fi
	else
		info "${NPM_PACKAGE} is not installed globally."
	fi
else
	warn "npm not found; skipping npm package cleanup."
fi

# --- Step 4: user config/data (XDG first, then legacy ~/.claude) ---
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

# --- Step 5: optional Termux packages ---
printf '\n'
info "The following Termux packages were installed by this project but may be used elsewhere:"
printf '    %s\n' "glibc-repo  glibc-runner"
info "Run ${BLUE}pkg uninstall glibc-runner glibc-repo${NC} manually if you no longer need them."

ok "${GREEN}Uninstall complete.${NC}"
