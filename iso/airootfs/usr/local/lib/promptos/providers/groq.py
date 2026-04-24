"""
Groq provider — free, fast cloud inference via Groq LPU chips.
API is OpenAI-compatible. Get a free key at https://console.groq.com
Requires GROQ_API_KEY in environment or promptOS config.
"""

import json
import os
import urllib.request
import urllib.error
from typing import Iterator

from .base import Provider, Message

GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions"
DEFAULT_MODEL = "llama-3.1-8b-instant"


class GroqProvider(Provider):
    name = "groq"

    def __init__(self, api_key: str | None = None, model: str | None = None):
        self.api_key = api_key or os.environ.get("GROQ_API_KEY", "")
        self.model = model or os.environ.get("PROMPTOS_GROQ_MODEL", DEFAULT_MODEL)

    def available(self) -> bool:
        return bool(self.api_key)

    def chat(self, messages: list[Message], stream: bool = True) -> Iterator[str]:
        if not self.api_key:
            raise RuntimeError("GROQ_API_KEY not set")

        payload = json.dumps({
            "model": self.model,
            "messages": [{"role": m.role, "content": m.content} for m in messages],
            "stream": stream,
        }).encode()

        req = urllib.request.Request(
            GROQ_API_URL,
            data=payload,
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {self.api_key}",
            },
            method="POST",
        )

        with urllib.request.urlopen(req, timeout=120) as resp:
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
