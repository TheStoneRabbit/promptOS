"""
Provider registry and router for promptOS.

Priority order (unless overridden by config):
  1. claude   — if ANTHROPIC_API_KEY is set
  2. openai   — if OPENAI_API_KEY is set
  3. ollama   — if ollama is running locally
  4. (none)   — bash passthrough

Override with: PROMPTOS_PROVIDER=ollama|claude|openai
"""

import os
from .base import Provider, Message
from .ollama import OllamaProvider
from .claude import ClaudeProvider
from .openai import OpenAIProvider

_REGISTRY: dict[str, type[Provider]] = {
    "ollama": OllamaProvider,
    "claude": ClaudeProvider,
    "openai": OpenAIProvider,
}


def all_providers() -> list[Provider]:
    """Return instantiated providers from config/env."""
    return [
        ClaudeProvider(),
        OpenAIProvider(),
        OllamaProvider(model=os.environ.get("PROMPTOS_OLLAMA_MODEL", "llama3.2:1b")),
    ]


def get_provider(name: str | None = None) -> Provider | None:
    """
    Return the best available provider.
    If name is given, return that specific provider (or None if unavailable).
    """
    if name:
        cls = _REGISTRY.get(name)
        if not cls:
            raise ValueError(f"Unknown provider '{name}'. Choose from: {list(_REGISTRY)}")
        if name == "ollama":
            p = OllamaProvider(model=os.environ.get("PROMPTOS_OLLAMA_MODEL", "llama3.2:1b"))
        else:
            p = cls()
        return p if p.available() else None

    # Auto-select by priority
    for p in all_providers():
        if p.available():
            return p
    return None


def list_providers() -> list[dict]:
    """Return status of all providers (for /providers command)."""
    results = []
    for p in all_providers():
        results.append({
            "name": p.name,
            "available": p.available(),
        })
    return results


__all__ = ["Provider", "Message", "get_provider", "list_providers", "all_providers"]
