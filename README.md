# claude-code-termux

Install [Claude Code](https://www.anthropic.com/claude-code) natively on Termux.

**arm64 only.** The npm package this pulls (`@anthropic-ai/claude-code-linux-arm64`) and the `glibc-runner` shim it relies on are both arm64-specific. The install and wrapper scripts will refuse to run on anything else.

```bash
command -v curl &>/dev/null || pkg install -y curl
curl -fsSL https://raw.githubusercontent.com/Keyaku/claude-code-termux/refs/heads/main/install.sh | bash
```

Then launch with `claude`. Each run checks the npm registry for a newer native build and updates before exec'ing it through `glibc-runner`.

## Uninstall

```bash
command -v curl &>/dev/null || pkg install -y curl
curl -fsSL https://raw.githubusercontent.com/Keyaku/claude-code-termux/refs/heads/main/uninstall.sh -o "$PREFIX/tmp/uninstall.sh" && bash "$PREFIX/tmp/uninstall.sh" && rm "$PREFIX/tmp/uninstall.sh"
```

Removes the wrapper and prompts before touching the native binary or user config.
