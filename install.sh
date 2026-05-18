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

# --- Step 1: required packages ---
info "Checking required Termux packages."
REQUIRED_PKGS="glibc-repo glibc-runner npm curl tar"
MISSING=""
for p in $REQUIRED_PKGS; do
	if ! dpkg -s "$p" >/dev/null 2>&1; then
		MISSING="$MISSING $p"
	fi
done

if [ -n "$MISSING" ]; then
	info "Installing missing packages:${BLUE}${MISSING}${NC}"
	pkg update -y
	# shellcheck disable=SC2086
	pkg install -y $MISSING
else
	ok "All required packages already installed."
fi

# --- Step 2: install @anthropic-ai/claude-code from npm ---
info "Installing ${BLUE}@anthropic-ai/claude-code${NC} via npm."
npm -g i @anthropic-ai/claude-code --force \
	|| die "Could not install claude-code from npm. Check your internet connection."

# --- Step 3: fetch native arm64 binary ---
info "Resolving native binary tarball URL."
URL=$(npm view @anthropic-ai/claude-code-linux-arm64 dist.tarball)
[ -n "$URL" ] || die "Could not resolve tarball URL. Check your internet connection."

NPM_ROOT="$(npm -g root)"
[ -n "$NPM_ROOT" ] && [ -d "$NPM_ROOT" ] || die "Invalid npm global root: '${NPM_ROOT}'."

INSTALL_DIR="$NPM_ROOT/@anthropic-ai/claude-code-linux-arm64"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

info "Downloading ${DIM}${URL}${NC}"
curl -fSL --progress-bar "$URL" -o "$TMPDIR/claude-native.tgz" \
	|| die "Could not download native binary. Check your internet connection."

info "Extracting to ${BLUE}${INSTALL_DIR}${NC}"
mkdir -p "$INSTALL_DIR"
tar -xzf "$TMPDIR/claude-native.tgz" -C "$INSTALL_DIR" --strip-components=1

# --- Step 4: write wrapper ---
WRAPPER="$TERMUX__PREFIX/bin/claude"
info "Writing wrapper script: ${BLUE}${WRAPPER}${NC}"
cat > "$WRAPPER" << 'EOF'
#!/usr/bin/env bash

set -eu

PACKAGE="@anthropic-ai/claude-code-linux-arm64"
NPM_ROOT="$(npm -g root)"
[ -n "$NPM_ROOT" ] && [ -d "$NPM_ROOT" ] || { printf 'Invalid npm global root.\n' >&2; exit 1; }

INSTALL_DIR="$NPM_ROOT/$PACKAGE"
PACKAGE_JSON="$INSTALL_DIR/package.json"
BINARY_PATH="$INSTALL_DIR/claude"

if [ ! -f "$BINARY_PATH" ]; then
	printf 'Claude binary not found at %s\nPlease reinstall.\n' "$BINARY_PATH" >&2
	exit 1
fi
[ -x "$BINARY_PATH" ] || chmod ug+x "$BINARY_PATH"

printf 'Checking for updates... '
LATEST_VERSION=$(npm view "$PACKAGE" version 2>/dev/null || true)
if [ -f "$PACKAGE_JSON" ]; then
	INSTALLED_VERSION=$(grep '"version":' "$PACKAGE_JSON" | cut -d'"' -f4)
else
	INSTALLED_VERSION=""
fi

if [ -n "$LATEST_VERSION" ] && [ "$LATEST_VERSION" != "$INSTALLED_VERSION" ]; then
	printf '\nNew version (%s) found. Updating...\n' "$LATEST_VERSION"
	URL=$(npm view "$PACKAGE" dist.tarball)
	[ -n "$URL" ] || { printf 'Could not resolve update URL.\n' >&2; exit 1; }
	TMP="$(mktemp -d)"
	trap 'rm -rf "$TMP"' EXIT
	curl -fSL --progress-bar "$URL" -o "$TMP/claude_update.tgz"
	tar -xzf "$TMP/claude_update.tgz" -C "$INSTALL_DIR" --strip-components=1
	chmod ug+x "$BINARY_PATH"
	printf 'Update complete.\n'
else
	printf 'Done (already up to date).\n'
fi

exec glibc-runner "$BINARY_PATH" "$@"
EOF
chmod +x "$WRAPPER"

ok "${GREEN}Installation complete.${NC}"
printf '%s\n' "Run ${BLUE}claude${NC} — it will check for updates and run natively."
