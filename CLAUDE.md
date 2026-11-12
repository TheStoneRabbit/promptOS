# promptOS — CLAUDE.md

## Project Vision

**promptOS** is a Linux distribution where AI is the primary interface and operator of the system.
The AI agent has root access and acts as an intelligent shell, system manager, and first-class OS citizen.
Think less "AI assistant bolted onto Linux" and more "Linux built around AI as the kernel of human intent."

---

## Architecture Philosophy

- The AI layer sits between the user and the OS, translating natural language into system actions
- AI has real root access — it can manage processes, install packages, configure networking, modify files
- The traditional shell (bash/zsh) is still available as an escape hatch (`!cmd`), but not the primary interface
- System should be minimal — every layer that doesn't serve the AI-first UX is dead weight
- Security model: AI is trusted, but actions are logged and reversible where possible

---

## Base Distro Decision

**Base: Arch Linux**

Rationale:
- Minimal by default — no bloat to strip out
- Rolling release — always current packages
- pacman + AUR give access to almost any software
- Clean init system (systemd) easy to customize
- Strong community, excellent wiki
- ISO build tooling: `archiso` is mature and well-documented

---

## Build & Test Strategy (macOS Host)

### ISO Build Environment

Since we're on macOS, we cannot run `archiso` natively.

1. **Docker + archiso** — primary build method
   - `FROM --platform=linux/amd64 archlinux:latest` required on Apple Silicon
   - `--disable-sandbox` required for pacman inside Docker
   - `docker run --privileged` required for archiso/loopback devices
   - Ollama model cached in Docker volume `promptos-ollama-cache` to avoid re-downloading

2. **QEMU** — testing
   - `-m 4096` required (Ollama needs headroom)
   - `-netdev user,hostfwd=tcp::2222-:22` for SSH clipboard forwarding
   - `-display cocoa,show-cursor=on` on macOS

### Build Commands

```bash
./scripts/build.sh          # build ISO (Docker)
./scripts/test.sh           # boot ISO in QEMU with 4GB RAM
ssh root@localhost -p 2222  # clipboard/copy-paste via SSH
```

### Toolchain Summary

| Task | Tool |
|------|------|
| Build ISO | Docker + archiso (local) or GitHub Actions (CI) |
| Boot/test ISO | QEMU on macOS (4GB RAM minimum) |
| Package management | pacman |
| AI runtime | Ollama (baked in) + Claude/OpenAI API (optional) |
| Init/service mgmt | systemd |
| Display (planned) | Wayland + sway |

---

## Current Implementation Status

### Phase 1 — Bootable Skeleton ✅
- Docker-based archiso build environment working
- Bootable Arch ISO (TTY only, auto-login as root)
- Validated boot in QEMU
- `profiledef.sh`, `packages.x86_64`, EFI/syslinux boot configs

### Phase 2 — AI Layer Integration ✅ (mostly)
- **`promptsh`** — custom AI shell, auto-launched as root login shell
  - Multi-provider: Ollama, Claude API, OpenAI API
  - Provider auto-detected at startup; shown in banner as `[ollama]` / `[claude]` etc.
  - `!cmd` runs bash directly without AI
  - `/switch` to change provider at runtime
  - `/providers` to list available providers
  - Figlet banner renders `promptOS` correctly at boot
  - readline-safe ANSI prompt (`\001`/`\002` wrappers) — no width miscalculation
  - Compact command output (default): live one-line status while running; long output
    collapsed to head/tail with hidden-line count. `/out [n|all]` shows full output,
    `/verbose` toggles live streaming (persisted in `~/.promptsh/state.json`).
    The AI gets a head+tail excerpt (`_ai_excerpt`, 1500 chars) of every command's output.
  - Message queue + type-ahead: `TypeAhead` puts the tty in no-echo/non-canonical mode only
    while a reply streams, reads keystrokes on a thread, and renders the input line inside the
    Rich `Live` region (`_compose_live`). Enter queues; `/queue` cmds work mid-stream. Unsent
    text is prefilled into the next prompt (`get_input(default=...)`). Not active on bare TTY.
  - Testable off-device: load `promptsh` with `importlib` SourceFileLoader in a venv with
    `rich` + `prompt_toolkit`, set `TERM=linux` to exercise the bare-TTY code path.
- **`AGENT.md`** — AI identity/ruleset loaded as system prompt
  - Located at `/usr/local/lib/promptos/AGENT.md`
  - Defines AI as promptOS system agent with full root access
- **Ollama installed (offline fallback)**
  - Installed via pacman (`ollama` package); service enabled in `customize_airootfs.sh`
  - No model is baked into the ISO — `qwen3:8b` is pulled on demand with `promptos-model pull` / `/model pull`
  - Starts automatically via `ollama.service` (systemd, multi-user.target)
  - Default provider in config: `PROMPTOS_PROVIDER=claude` (Ollama + `qwen3:8b` is the offline fallback, downloaded on demand via `promptos-model pull`)

### Phase 3–5 — Planned
See roadmap below.

---

## Key Files & Directories (actual structure)

```
promptOS/
├── CLAUDE.md
├── Dockerfile.build                          # FROM --platform=linux/amd64 archlinux
├── iso/
│   ├── profiledef.sh                         # archiso profile (bios.syslinux + uefi.systemd-boot)
│   ├── packages.x86_64                       # package list (includes figlet, python, networkmanager)
│   ├── airootfs/
│   │   ├── etc/
│   │   │   ├── mkinitcpio.conf               # CRITICAL: no autodetect hook (breaks on Docker overlay)
│   │   │   │                                 # HOOKS=(base udev memdisk archiso block)
│   │   │   │                                 # MODULES=(squashfs iso9660 loop overlay)
│   │   │   ├── promptos/config               # default provider, model, API keys (blank)
│   │   │   ├── shadow                        # empty root password
│   │   │   ├── ssh/sshd_config.d/promptos.conf  # PermitRootLogin + PermitEmptyPasswords
│   │   │   └── systemd/system/
│   │   │       ├── ollama.service            # starts Ollama on boot
│   │   │       └── getty@tty1.service.d/autologin.conf  # auto-login as root
│   │   ├── usr/local/
│   │   │   ├── bin/promptsh                  # AI shell (Python, readline, multi-provider)
│   │   │   └── lib/promptos/
│   │   │       ├── AGENT.md                  # AI identity + ruleset (system prompt)
│   │   │       └── providers/
│   │   │           ├── __init__.py           # provider router (ollama > claude > openai)
│   │   │           ├── base.py               # Provider ABC + Message dataclass
│   │   │           ├── ollama.py             # Ollama HTTP client (/api/chat)
│   │   │           ├── claude.py             # Anthropic API client
│   │   │           └── openai.py             # OpenAI API client
│   │   └── root/
│   │       └── customize_airootfs.sh         # post-pacstrap: installs Ollama + pulls llama3.2:1b
│   ├── syslinux/                             # BIOS boot (syslinux.cfg)
│   └── efiboot/loader/                       # UEFI boot (loader.conf + entries/)
├── scripts/
│   ├── build.sh                              # Docker build + mounts ollama-cache volume
│   ├── docker-build.sh                       # runs inside container: mkarchiso + cache mgmt
│   └── test.sh                               # QEMU boot with 4GB RAM + SSH forwarding
└── dist/                                     # ISO output (gitignored)
```

---

## Critical Implementation Notes

### mkinitcpio.conf (DO NOT CHANGE without understanding this)
The file at `iso/airootfs/etc/mkinitcpio.conf` must NOT include the `autodetect` hook.
archiso 88+ copies pacstrap's built initramfs directly into the ISO — it does not rebuild it.
The `autodetect` hook fails inside Docker because it detects the overlay root filesystem,
not the actual hardware modules needed for live ISO boot.

Required config:
```
MODULES=(squashfs iso9660 loop overlay)
HOOKS=(base udev memdisk archiso block)
```

### Ollama model name must be exact
Model is `llama3.2:1b` (with the `:1b` tag). Using `llama3.2` alone returns HTTP 404.
Ensure `PROMPTOS_OLLAMA_MODEL=llama3.2:1b` in `/etc/promptos/config` and that all
provider instantiation code passes this value (not a bare `llama3.2` default).

### Provider instantiation
When `get_provider("ollama")` is called by name, it must still pass the model from env:
```python
OllamaProvider(model=os.environ.get("PROMPTOS_OLLAMA_MODEL", "llama3.2:1b"))
```

### Prompt caching / token economy
The Claude provider marks the system prompt and the newest message as prompt-cache
breakpoints, so the unchanged prefix of each request is billed at the cache-read rate.
This only works if the system prompt is byte-identical from turn to turn:
- Never put a clock, cwd, or other per-turn data in a `system` Message. Put it in the
  newest user message instead (see `_live_context()` / `_request_messages()` in `promptos-gui`).
- `providers.base.bound_history()` caps history at 60 non-system messages and trims the
  oldest half in one go (not one per turn) so the cached prefix stays stable between trims.
- `/verify` in promptsh and the GUI prints the last request's cached-token share.

### Docker platform
Always build with `FROM --platform=linux/amd64` — `archlinux:latest` has no ARM64 image.
All `pacman` calls inside Docker need `--disable-sandbox` (seccomp restriction).

---

## AI Model Strategy

- **Claude-first**: default provider is Claude API (`claude-opus-5-5`). Decided 2026-11-11: no small local model is reliable enough for multi-step root shell work, so Claude is the base model.
- **Offline fallback**: Ollama + `qwen3:8b` (best small tool-use model as of late 2026; not baked into the ISO, pulled on demand with `promptos-model pull`)
- **Provider priority (auto mode)**: claude → openai → groq → ollama
- **Override**: set `PROMPTOS_PROVIDER=ollama|openai|groq|auto` in `/etc/promptos/config` or env; API keys via `promptos-keys set claude <key>`
- System context (hostname, uptime, disk, running services) injected into AI system prompt at session start

---

## Phased Roadmap

### Phase 1 — Bootable Skeleton ✅
- [x] Docker-based archiso build environment
- [x] Minimal bootable Arch ISO (TTY, auto-login)
- [x] Validated boot in QEMU
- [x] `profiledef.sh` and package list
- [ ] GitHub Actions CI for ISO builds

### Phase 2 — AI Layer Integration ✅
- [x] Ollama installed + `llama3.2:1b` baked into ISO
- [x] `promptsh` — AI shell with multi-provider support
- [x] AI runs as root, has full system access
- [x] `AGENT.md` identity/ruleset loaded as system prompt
- [x] `!cmd` bash passthrough
- [ ] `promptd` daemon (persistent AI session across terminal sessions)
- [ ] Action logging to `/var/log/promptos/actions.log`

### Phase 3 — Root Access & Safety Model
- [ ] Define "safe" vs "destructive" action categories
- [ ] Confirmation prompts for destructive actions (configurable)
- [ ] Audit log with rollback metadata (file backups before overwrite)

### Phase 4 — UX & Interface
- [ ] Wayland + sway + Firefox for GUI/browser support
- [ ] AI launches GUI apps on demand ("open a browser")
- [ ] "Ambient" mode: AI monitors system health and proactively reports/acts
- [ ] Persistence: SQLite conversation store across reboots

### Phase 5 — Hardening & Distribution
- [ ] AI-narrated installer (`promptos-install` wrapping `archinstall`)
- [ ] USB bootable (ISO is already hybrid — just `dd` to flash)
- [ ] Custom branding (bootloader, login screen, motd)
- [ ] Signed packages and ISO
- [ ] Public release + documentation site

---

## Planned Features (next phases)

### WiFi
- `networkmanager` + `iw` + `wireless-regdb` in package list
- AI interface: "connect me to <SSID>" → `nmcli device wifi connect ...`
- `nmtui` available as text UI fallback

### Installer (`promptos-install`)
- AI-narrated conversational install experience
- Built on top of `archinstall` for partitioning/fstab/bootloader
- Launched from live environment: user types "install promptOS"

### Display & Browser
- Wayland + sway (minimal compositor)
- Firefox for browser
- AI launches GUI apps on demand

### Package Management
- `pacman` in place, AI has root so no sudo friction
- AUR support via `yay` or `paru` (Phase 3+)

---

## Open Questions / Decisions Pending

- [ ] `promptd` daemon vs. current stateless `promptsh` approach
- [ ] Persistence model: SQLite conversation store across reboots
- [ ] Multi-user: one AI session per user, or one system-level agent?
- [ ] When to add Wayland/sway/Firefox (Phase 4)

---

## Dev Environment Requirements (macOS)

```bash
brew install docker qemu
# Docker Desktop or OrbStack also works
```

---

## Notes & Conventions

- All build scripts should be idempotent
- ISO artifacts go in `dist/` (gitignored)
- Keep the package list minimal — justify every addition
- Prefer Rust or Go for system-level tooling; Python acceptable for AI glue code
- Document every non-obvious architectural decision inline or in this file
- `promptOS` — capital OS, always. Never "promptos", "PromptOS", or "promes"
