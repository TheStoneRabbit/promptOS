"""
Provider registry and router for promptOS.

Priority order (unless overridden by config):
  1. claude        — if ANTHROPIC_API_KEY is set
  2. openai        — if OPENAI_API_KEY is set
  3. groq          — if GROQ_API_KEY is set (free tier at console.groq.com)
  4. ollama        — local LLM, works offline
  5. (none)        — bash passthrough

Override with: PROMPTOS_PROVIDER=ollama|claude|openai|groq
"""

import os
from .base import Provider, Message
from .ollama import OllamaProvider
from .claude import ClaudeProvider
from .openai import OpenAIProvider
from .groq import GroqProvider

_REGISTRY: dict[str, type[Provider]] = {
    "ollama": OllamaProvider,
    "claude": ClaudeProvider,
    "openai": OpenAIProvider,
    "groq": GroqProvider,
}

_MODEL_ENV = {
    "claude": "PROMPTOS_CLAUDE_MODEL",
    "openai": "PROMPTOS_OPENAI_MODEL",
    "groq": "PROMPTOS_GROQ_MODEL",
    "ollama": "PROMPTOS_OLLAMA_MODEL",
}

_MODEL_DEFAULT = {
    "claude": "claude-sonnet-4-6",
    "openai": "gpt-4.1",
    "groq": "llama-3.1-8b-instant",
    "ollama": "mistral:7b-instruct",
}


def _model_for(name: str) -> str:
    env_key = _MODEL_ENV[name]
    return os.environ.get(env_key, _MODEL_DEFAULT[name])


def _build_provider(name: str) -> Provider:
    if name == "claude":
        return ClaudeProvider(model=_model_for("claude"))
    if name == "openai":
        return OpenAIProvider(model=_model_for("openai"))
    if name == "groq":
        return GroqProvider(model=_model_for("groq"))
    if name == "ollama":
        return OllamaProvider(model=_model_for("ollama"))
    raise ValueError(f"Unknown provider '{name}'. Choose from: {list(_REGISTRY)}")


def all_providers() -> list[Provider]:
    """Return instantiated providers from config/env."""
    return [
        _build_provider("claude"),
        _build_provider("openai"),
        _build_provider("groq"),
        _build_provider("ollama"),
    ]


def get_provider(name: str | None = None) -> Provider | None:
    """
    Return the best available provider.
    If name is given, return that specific provider (or None if unavailable).
    """
    if name:
        if name not in _REGISTRY:
            raise ValueError(f"Unknown provider '{name}'. Choose from: {list(_REGISTRY)}")
        p = _build_provider(name)
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
