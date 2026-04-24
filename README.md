# promptOS

**AI-Native Linux** — a Linux distribution where AI has root access and is the primary interface to the system.

Type anything. The AI runs the system.

---

## What is this?

promptOS is an Arch Linux-based live OS where instead of a traditional shell, you talk to an AI that operates the computer on your behalf. The AI has full root access and can manage processes, install packages, configure networking, read and write files — anything you'd do in a terminal, but through natural language.

The traditional shell is still available as an escape hatch (`!cmd`), but it's not the primary interface.

---

## Features

- **Multi-provider AI**: auto-selects the best available — Claude, OpenAI, Groq, Pollinations (keyless), or Ollama (local/offline)
- **`dolphin3:8b` baked in**: uncensored 8B model pre-installed, no internet or API key required
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
- 8GB RAM minimum (for `dolphin3:8b`)
- Any disk size for live use; 20GB+ recommended for install

---

## Build

```bash
./scripts/build.sh
```

Builds the ISO using Docker + archiso. The first build downloads `dolphin3:8b` (~5GB) and caches it in a Docker volume (`promptos-ollama-cache`) — subsequent builds reuse the cache and are much faster.

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

> Note: Ollama takes ~3 minutes to load `dolphin3:8b` into RAM on first boot in QEMU. On real hardware with NVMe it's much faster.

---

## Flash to USB

```bash
sudo dd if=dist/promptos-*.iso of=/dev/sdX bs=4m status=progress && sync
```

Replace `/dev/sdX` with your USB drive. On macOS use `/dev/diskN`. Or use [Balena Etcher](https://etcher.balena.io).

---

## Install to Disk

Boot from USB, then at the `promptOS>` prompt:

```
install promptOS
```

The installer will:
1. Show available disks and let you pick one
2. Confirm before erasing anything
3. Partition automatically (512MiB EFI + rest as root)
4. Install the base system and copy all promptOS files
5. Copy the Ollama model — no re-download needed
6. Set `promptsh` as the login shell and boot into it

---

## AI Providers

Auto-selected at boot in priority order:

| Provider | Requires | Model |
|----------|----------|-------|
| `claude` | `ANTHROPIC_API_KEY` | `claude-sonnet-4-6` |
| `openai` | `OPENAI_API_KEY` | `gpt-4o` |
| `groq` | `GROQ_API_KEY` (free at console.groq.com) | `llama-3.1-8b-instant` |
| `pollinations` | Nothing | keyless cloud AI |
| `ollama` | Nothing (baked in) | `dolphin3:8b` (offline) |

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
│           └── providers/             # claude, openai, groq, pollinations, ollama
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
- [x] `dolphin3:8b` baked in (offline, uncensored)
- [x] Groq + Pollinations providers (free/keyless cloud)
- [x] Auto-fallback between providers
- [x] Disk installer (`install promptOS`)
- [x] SSH access, network auto-configure on boot
- [ ] WiFi management via AI (`connect to <SSID>`)
- [ ] Persistent conversation memory across reboots (SQLite)
- [ ] Wayland + sway + Firefox for GUI apps
- [ ] GitHub Actions CI for automated ISO builds
- [ ] Signed ISO + packages
