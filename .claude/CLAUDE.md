# claude-code-termux

Three shell scripts that install, run, and uninstall the native arm64 Claude Code binary on Termux. The binary is glibc-linked and is launched through `glibc-runner` because Termux uses bionic libc.

## Layout

- `install.sh` — bootstraps required Termux packages, fetches the latest native tarball from the npm registry, extracts it under `$TERMUX__PREFIX/share`, and drops the wrapper into `$TERMUX__PREFIX/bin/claude`.
- `claude.sh` — the wrapper. On every invocation it checks the npm registry for a newer version, updates in place if needed, then execs the binary via `glibc-runner`. Installed remotely from the `main` branch raw URL, so changes to it ship as soon as they're merged.
- `uninstall.sh` — removes the wrapper, then prompts before touching the native binary directory and user config. Prompts read from `/dev/tty` so it works when piped from `curl`.

## Conventions

- POSIX-ish bash with `set -eu`. No bashisms unless there's a reason; the scripts are expected to run under Termux's bash.
- Shared helpers (`info`/`ok`/`warn`/`die`, ANSI color vars) are duplicated across scripts intentionally — each script is fetched and run standalone via `curl | bash`, so there is no shared library to source.
- Package queries are abstracted over Termux's apt and pacman variants (see `pkg_installed` in `install.sh`). Preserve that when adding new package checks.
- JSON parsing picks `jq` or `jaq` at runtime; don't hardcode one.
- User-facing paths in log output are wrapped in the `$BLUE …$NC` color vars; keep that consistent.

## Things to be careful about

- The wrapper URL and npm package name are load-bearing constants. If you rename or move them, update all three scripts and the README install snippet.
- `uninstall.sh` checks the wrapper contains the npm package name before deleting it — that's the "is this ours?" guard. If you change the package name, this check must still match.
- Don't add a dependency that isn't in Termux's default repos without also updating the `REQUIRED_PKGS` list and the uninstall script's "packages we installed" note.
- The install and uninstall scripts are designed to be piped from `curl`; don't introduce interactive prompts in `install.sh`, and keep `uninstall.sh`'s `/dev/tty` handling intact.

## Testing

No automation. Before pushing changes:

- Run `shellcheck install.sh claude.sh uninstall.sh`.
- Manually exercise the affected script on-device. For `install.sh` / `uninstall.sh`, a fresh Termux session or a willingness to re-run the full cycle is the only way to be sure.

## Out of scope

- Supporting non-arm64 Termux or non-Termux Linux. The npm package name is arm64-specific and the scripts assert `TERMUX__PREFIX`.
- Bundling or replacing `glibc-runner`. See the README — alternatives exist (proot-distro, termux-glibc) but this project deliberately targets the minimal shim.
