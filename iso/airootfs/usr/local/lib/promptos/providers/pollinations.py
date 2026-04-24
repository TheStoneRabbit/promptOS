"""
Pollinations.ai provider — free, keyless cloud AI.
No API key required. Works out of the box.
https://pollinations.ai
"""

import json
import urllib.request
import urllib.error
from typing import Iterator

from .base import Provider, Message

POLLINATIONS_API_URL = "https://text.pollinations.ai/openai"
DEFAULT_MODEL = "openai"  # routes to GPT-4o-mini equivalent


class PollinationsProvider(Provider):
    name = "pollinations"

    def __init__(self, model: str = DEFAULT_MODEL):
        self.model = model

    def available(self) -> bool:
        # No API key required — always considered available.
        # Chat will fail gracefully if there's no internet.
        return True

    def chat(self, messages: list[Message], stream: bool = True) -> Iterator[str]:
        payload = json.dumps({
            "model": self.model,
            "messages": [{"role": m.role, "content": m.content} for m in messages],
            "stream": stream,
            "private": True,
        }).encode()

        req = urllib.request.Request(
            POLLINATIONS_API_URL,
            data=payload,
            headers={
                "Content-Type": "application/json",
                "User-Agent": "promptOS/1.0",
                "Referer": "https://promptos.dev",
            },
            method="POST",
        )

        with urllib.request.urlopen(req, timeout=60) as resp:
            if stream:
                for line in resp:
                    line = line.decode().strip()
                    if line.startswith("data:"):
                        data_str = line[5:].strip()
                        if data_str == "[DONE]":
                            break
                        try:
                            data = json.loads(data_str)
                            chunk = data["choices"][0].get("delta", {}).get("content", "")
                            if chunk:
                                yield chunk
                        except (json.JSONDecodeError, KeyError):
                            pass
            else:
                data = json.loads(resp.read())
                yield data["choices"][0]["message"]["content"]
