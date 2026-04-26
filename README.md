# promptOS

**AI-Native Linux** — a Linux distribution where AI has root access and is the primary interface to the system.

Type anything. The AI runs the system.

---

## What is this?

promptOS is an Arch Linux-based live OS where instead of a traditional shell, you talk to an AI that operates the computer on your behalf. The AI has full root access and can manage processes, install packages, configure networking, read and write files — anything you'd do in a terminal, but through natural language.

The traditional shell is still available as an escape hatch (`!cmd`), but it's not the primary interface.

---

## Features

- **Multi-provider AI**: auto-selects the best available — Claude, OpenAI, Groq, or Ollama (local/offline)
- **`qwen2.5:3b` baked in**: instruction-tuned model pre-installed, no internet or API key required
- **Root access**: AI runs as root with full system control
- **Auto-fallback**: if a provider fails, automatically switches to the next available one
- **Installer**: type `install promptOS` to install to disk from a USB drive
- **Auto-login**: boots directly to the AI shell, no password needed
- **SSH access**: connect via `ssh root@<ip>` for copy/paste from your host

---

## Requirements

**To build** (macOS):
```bash
brew install docker qemu
```

**To run** (target hardware):
- x86_64 machine, UEFI or BIOS
- 4GB RAM minimum (for `qwen2.5:3b`); 8GB+ recommended if you swap in larger models
- Any disk size for live use; 20GB+ recommended for install

---

## Build

```bash
./scripts/build.sh
```

Builds the ISO using Docker + archiso. The first build downloads `qwen2.5:3b` (~1.9GB) and caches it in a Docker volume (`promptos-ollama-cache`) — subsequent builds reuse the cache and are much faster.

Output: `dist/promptos-YYYY.MM.DD-x86_64.iso`

---

## Test in QEMU

```bash
./scripts/test.sh
```

Boots the latest ISO in QEMU with 4GB RAM and SSH forwarding on `localhost:2222`.

```bash
ssh root@localhost -p 2222
```

> Note: Ollama loads `qwen2.5:3b` into RAM in a few seconds on most hardware.

---

## Flash to USB

```bash
sudo dd if=dist/promptos-*.iso of=/dev/sdX bs=4m status=progress && sync
```

Replace `/dev/sdX` with your USB drive. On macOS use `/dev/diskN`. Or use [Balena Etcher](https://etcher.balena.io).

---

## Install to Disk

Boot from USB, then at the `promptOS>` prompt run any of:

```
install promptOS
/install
```

The installer will:
1. Offer to set up WiFi if you're offline (configs persist into the install)
2. Show available disks and let you pick one (with confirmation before erasing)
3. Partition automatically (512MiB EFI + rest as root)
4. Prompt for a root password and an admin user (wheel group, sudo)
5. Copy the live system to disk, install bootloader, set login shells
6. Reboot into the installed system

The Ollama model (`qwen2.5:3b`, ~1.9GB) is downloaded on first run, not baked
into the ISO. Make sure you're online (use `/wifi` if not) and run `/model pull`
or just send your first AI prompt to trigger the download.

---

## Push Updates to a Running Install

Once promptOS is installed somewhere on your network, you can iterate on
`promptsh` and the helper scripts without re-flashing the USB:

```bash
./scripts/push.sh 192.168.1.50              # connects as root@<ip>
./scripts/push.sh mason@192.168.1.50        # connects as user, uses sudo
./scripts/push.sh -n 192.168.1.50           # dry-run preview
```

What it syncs:
- `usr/local/bin/promptsh` and all `promptos-*` helper scripts
- `usr/local/lib/promptos/` (provider library + `AGENT.md`)
- `etc/profile.d/promptsh.sh`, `etc/bash.bashrc`
- `etc/ssh/sshd_config.d/promptos.conf`, `etc/vconsole.conf`

What it leaves alone (your per-machine state):
- `/etc/promptos/config` — your provider/model preferences
- `/etc/promptos/keys` — your API keys
- `/etc/shadow`, `/etc/passwd` — accounts and credentials

Promptsh changes apply on next login (`exit` and reconnect).
Console-font changes apply on next boot, or run `setfont $(awk -F= '/^FONT/{print $2}' /etc/vconsole.conf)`.

---

## AI Providers

Auto-selected at boot in priority order:

| Provider | Requires | Model |
|----------|----------|-------|
| `claude` | `ANTHROPIC_API_KEY` | `claude-sonnet-4-6` |
| `openai` | `OPENAI_API_KEY` | `gpt-4o` |
| `groq` | `GROQ_API_KEY` (free at console.groq.com) | `llama-3.1-8b-instant` |
| `ollama` | Nothing (baked in) | `qwen2.5:3b` (offline) |

**Set API keys:**
```
promptos-keys set claude sk-ant-...
promptos-keys set groq gsk_...
```

**Switch providers:**
```
/switch groq
/switch ollama
/switch          # cycle to next available
```

---

## Web Search & Fetch

The AI has a built-in web tool (no API key required, uses DuckDuckGo + w3m):

```bash
promptos-web search "kernel parameter for verbose boot"
promptos-web fetch  "https://wiki.archlinux.org/title/Mkinitcpio"
```

The AI can call these from `CMD:` blocks automatically when you ask about
current events, documentation, or anything outside its training cutoff.

---

## Shell Commands

| Command | Description |
|---------|-------------|
| `!cmd` | Run a bash command directly, bypassing AI |
| `!!prompt` | Send to AI and auto-execute any commands it returns |
| `/switch <name>` | Switch AI provider |
| `/providers` | List all providers and their status |
| `/autorun` | Toggle auto-execution of AI-suggested commands |
| `/clear` | Clear conversation history |
| `/keys` | Manage API keys |
| `install promptOS` | Launch the disk installer |
| `exit` | Exit promptsh |

---

## Project Structure

```
promptOS/
├── Dockerfile.build                   # archiso builder image (pinned to archive snapshot)
├── iso/
│   ├── profiledef.sh                  # archiso profile
│   ├── packages.x86_64                # live ISO package list
│   └── airootfs/                      # files overlaid onto the live system
│       ├── etc/promptos/config        # provider + model config
│       ├── etc/systemd/               # ollama, warmup, network services
│       ├── usr/local/bin/promptsh     # AI shell
│       ├── usr/local/bin/promptos-install  # disk installer
│       ├── usr/local/bin/promptos-warmup   # Ollama model pre-loader
│       └── usr/local/lib/promptos/    # provider library
│           ├── AGENT.md               # AI identity and ruleset (system prompt)
│           └── providers/             # claude, openai, groq, ollama
├── scripts/
│   ├── build.sh                       # build ISO via Docker
│   ├── docker-build.sh                # runs inside container
│   └── test.sh                        # boot ISO in QEMU
└── dist/                              # built ISOs (gitignored)
```

---

## Roadmap

- [x] Bootable Arch ISO with auto-login
- [x] AI shell (`promptsh`) with multi-provider support
- [x] `qwen2.5:3b` baked in (offline, instruction-tuned)
- [x] Groq provider (free cloud)
- [x] Auto-fallback between providers
- [x] Disk installer (`install promptOS`)
- [x] SSH access, network auto-configure on boot
- [ ] WiFi management via AI (`connect to <SSID>`)
- [ ] Persistent conversation memory across reboots (SQLite)
- [ ] Wayland + sway + Firefox for GUI apps
- [ ] GitHub Actions CI for automated ISO builds
- [ ] Signed ISO + packages
