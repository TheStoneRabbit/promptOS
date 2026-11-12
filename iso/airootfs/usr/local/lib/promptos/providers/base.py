"""
Base provider interface for promptOS.
All AI providers implement this contract.
"""

from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Iterator


@dataclass
class Message:
    role: str   # "user" | "assistant" | "system"
    content: str


# Conversation history is resent in full on every request (the APIs are
# stateless), so a long session grows linearly in cost. Cap the number of
# non-system messages; when the cap is hit, drop the oldest half in one go
# rather than one-per-turn so the retained prefix stays byte-identical for
# many turns and prompt caching keeps hitting.
MAX_HISTORY_MESSAGES = 60


def bound_history(messages: list["Message"], max_messages: int = MAX_HISTORY_MESSAGES) -> list["Message"]:
    """Return a copy of `messages` trimmed to the system prompt + recent turns."""
    system = [m for m in messages if m.role == "system"]
    rest = [m for m in messages if m.role != "system"]
    if len(rest) <= max_messages:
        return list(messages)
    keep = rest[-(max_messages // 2):]
    # Conversations must open with a user turn; drop a dangling assistant lead-in.
    while keep and keep[0].role != "user":
        keep.pop(0)
    return system + keep


class Provider(ABC):
    """Abstract base class for all AI providers."""

    name: str = "unknown"

    @abstractmethod
    def available(self) -> bool:
        """Return True if this provider is reachable/configured."""
        ...

    @abstractmethod
    def chat(self, messages: list[Message], stream: bool = True) -> Iterator[str]:
        """
        Send messages and yield response chunks.
        If stream=False, yields a single chunk with the full response.
        """
        ...

    def complete(self, messages: list[Message]) -> str:
        """Convenience: return full response as a string."""
        return "".join(self.chat(messages, stream=False))
