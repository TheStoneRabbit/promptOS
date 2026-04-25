"""
Ollama provider — local LLM inference.
Requires `ollama serve` running on the system.
"""

import json
import os
import urllib.request
import urllib.error
from typing import Iterator

from .base import Provider, Message


class OllamaProvider(Provider):
    name = "ollama"

    def __init__(self, model: str = "dolphin3:8b", base_url: str | None = None):
        base_url = base_url or os.environ.get("PROMPTOS_OLLAMA_BASE_URL", "http://localhost:11434")
        self.model = model
        self.base_url = base_url

    def available(self) -> bool:
        try:
            urllib.request.urlopen(f"{self.base_url}/api/tags", timeout=2)
            return True
        except Exception:
            return False

    def chat(self, messages: list[Message], stream: bool = True) -> Iterator[str]:
        payload = json.dumps({
            "model": self.model,
            "messages": [{"role": m.role, "content": m.content} for m in messages],
            "stream": stream,
        }).encode()

        req = urllib.request.Request(
            f"{self.base_url}/api/chat",
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )

        with urllib.request.urlopen(req, timeout=600) as resp:
            if stream:
                for line in resp:
                    line = line.strip()
                    if line:
                        data = json.loads(line)
                        chunk = data.get("message", {}).get("content", "")
                        if chunk:
                            yield chunk
                        if data.get("done"):
                            break
            else:
                data = json.loads(resp.read())
                yield data["message"]["content"]
