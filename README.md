# promptOS

**AI-Native Linux** — a Linux distribution where AI has root access and is the primary interface to the system.

Type anything. The AI runs the system.

---

## What is this?

promptOS is an Arch Linux-based live OS where instead of a traditional shell, you talk to an AI that operates the computer on your behalf. The AI has full root access and can manage processes, install packages, configure networking, read and write files — anything you'd do in a terminal, but through natural language.

The traditional shell is still available as an escape hatch (`!cmd`), but it's not the primary interface.

---

## Features

- **Multi-provider AI**: Ollama (local, offline), Claude API, OpenAI API — auto-detected at boot
- **Ollama baked in**: `llama3.2:1b` comes pre-installed, no internet required
- **Root access**: AI runs as root with full system control
- **SSH clipboard**: connect via SSH to copy/paste between host and VM
- **Auto-login**: boots directly to the AI shell, no password needed

---

## Requirements

- macOS with Docker and QEMU installed
- 8GB+ RAM recommended (4GB minimum for QEMU)

```bash
brew install docker qemu
```

---

## Build

```bash
./scripts/build.sh
```

Builds the ISO using Docker + archiso. The Ollama model is cached in a Docker volume (`promptos-ollama-cache`) so subsequent builds are fast.

Output: `dist/promptos-YYYY.MM.DD-x86_64.iso`

---

## Run

```bash
./scripts/test.sh
```

Boots the latest ISO in QEMU with 4GB RAM and SSH port forwarding on `localhost:2222`.

---

## Copy/Paste via SSH

Once booted, connect from your Mac:

```bash
ssh root@localhost -p 2222
```

No password required.

---

## AI Providers

| Provider | Requires | Notes |
|----------|----------|-------|
| `ollama` | Nothing (baked in) | Default. Runs `llama3.2:1b` locally |
| `claude` | `ANTHROPIC_API_KEY` | Uses `claude-sonnet-4-6` |
| `openai` | `OPENAI_API_KEY` | Uses `gpt-4o` |

Set API keys at runtime:
```
promptOS> !echo "ANTHROPIC_API_KEY=sk-..." >> /etc/promptos/keys
```

Switch providers:
```
promptOS> /switch
```

---

## Project Structure

```
promptOS/
├── iso/
│   ├── profiledef.sh              # archiso profile
│   ├── packages.x86_64            # package list
│   └── airootfs/                  # files overlaid onto the live system
│       ├── etc/promptos/config    # default provider + model config
│       └── usr/local/bin/promptsh # the AI shell
├── scripts/
│   ├── build.sh                   # build ISO via Docker
│   └── test.sh                    # boot ISO in QEMU
└── dist/                          # built ISOs (gitignored)
```

---

## Roadmap

- [x] Bootable Arch ISO
- [x] AI shell with multi-provider support
- [x] Ollama + llama3.2:1b baked in
- [ ] WiFi management via AI
- [ ] AI-narrated installer
- [ ] Wayland + sway + Firefox
- [ ] Persistent conversation memory (SQLite)
- [ ] USB bootable installer
