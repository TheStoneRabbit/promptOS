"""
Anthropic Claude provider.
Requires ANTHROPIC_API_KEY in environment or promptOS config.
"""

import json
import os
import urllib.request
import urllib.error
from typing import Iterator

from .base import Provider, Message

ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages"
ANTHROPIC_VERSION = "2023-06-01"
DEFAULT_MODEL = "claude-sonnet-4-6"
MAX_TOKENS = 8096


class ClaudeProvider(Provider):
    name = "claude"

    def __init__(self, api_key: str | None = None, model: str = DEFAULT_MODEL):
        self.api_key = api_key or os.environ.get("ANTHROPIC_API_KEY", "")
        self.model = model

    def available(self) -> bool:
        return bool(self.api_key)

    def chat(self, messages: list[Message], stream: bool = True) -> Iterator[str]:
        if not self.api_key:
            raise RuntimeError("ANTHROPIC_API_KEY not set")

        # Anthropic API separates system prompt from the messages array
        system_content = ""
        api_messages = []
        for m in messages:
            if m.role == "system":
                system_content = m.content
            else:
                api_messages.append({"role": m.role, "content": m.content})

        body: dict = {
            "model": self.model,
            "max_tokens": MAX_TOKENS,
            "messages": api_messages,
            "stream": stream,
        }
        if system_content:
            body["system"] = system_content

        payload = json.dumps(body).encode()
        req = urllib.request.Request(
            ANTHROPIC_API_URL,
            data=payload,
            headers={
                "Content-Type": "application/json",
                "x-api-key": self.api_key,
                "anthropic-version": ANTHROPIC_VERSION,
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
                            if data.get("type") == "content_block_delta":
                                chunk = data.get("delta", {}).get("text", "")
                                if chunk:
                                    yield chunk
                        except json.JSONDecodeError:
                            pass
            else:
                data = json.loads(resp.read())
                yield data["content"][0]["text"]
