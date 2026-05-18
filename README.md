# claude-code-termux

Install [Claude Code](https://www.anthropic.com/claude-code) natively on Termux (arm64).

```bash
comand -v curl &>/dev/null || pkg install -y curl
curl -fsSL https://raw.githubusercontent.com/Keyaku/claude-code-termux/refs/heads/main/install.sh | bash
```

Then launch with `claude`. Each run checks npm for a newer native build and updates before exec'ing it through `glibc-runner`.
