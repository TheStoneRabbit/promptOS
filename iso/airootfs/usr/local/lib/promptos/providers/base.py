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
