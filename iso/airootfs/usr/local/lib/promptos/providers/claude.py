"""
Anthropic Claude provider.
Requires ANTHROPIC_API_KEY in environment or promptOS config.

Token economy: the whole conversation is resent on every request, so this
provider marks the system prompt and the latest message as prompt-cache
breakpoints. Anything that is byte-identical to the previous request is then
billed at the cache-read rate (a small fraction of normal input). Callers keep
the system prompt stable within a session and put volatile context (time, cwd)
in the newest user message, never in the system prompt, or the cache misses.
"""

import json
import os
import urllib.request
import urllib.error
from typing import Iterator

from .base import Provider, Message

ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages"
ANTHROPIC_VERSION = "2023-06-01"
DEFAULT_MODEL = "claude-sonnet-5-5"
MAX_TOKENS = 16000
EFFORT = "medium"
CACHE_CONTROL = {"type": "ephemeral"}


class ClaudeProvider(Provider):
    name = "claude"

    def __init__(self, api_key: str | None = None, model: str = DEFAULT_MODEL):
        self.api_key = api_key or os.environ.get("ANTHROPIC_API_KEY", "")
        self.model = model
        # Usage of the most recent request: input_tokens, output_tokens,
        # cache_read_input_tokens, cache_creation_input_tokens. Shown by /verify-model.
        self.last_usage: dict = {}
        self.last_blocks: list = []

    def available(self) -> bool:
        return bool(self.api_key)

    @staticmethod
    def _build_body(messages: list[Message], model: str, stream: bool) -> dict:
        # Anthropic API separates system prompt from the messages array. Each
        # system Message becomes one text block; the last one carries a cache
        # breakpoint so the entire system prefix is cached.
        system_blocks = []
        api_messages = []
        for m in messages:
            if m.role == "system":
                system_blocks.append({"type": "text", "text": m.content})
            else:
                api_messages.append({"role": m.role, "content": m.content})
        if system_blocks:
            system_blocks[-1]["cache_control"] = CACHE_CONTROL
        # Second breakpoint on the newest message: on the next turn the API
        # finds this prefix cached and only the new turn is billed in full.
        if api_messages:
            last = api_messages[-1]
            last["content"] = [{"type": "text", "text": last["content"], "cache_control": CACHE_CONTROL}]

        body: dict = {
            "model": model,
            "max_tokens": MAX_TOKENS,
            "messages": api_messages,
            "stream": stream,
            "output_config": {"effort": EFFORT},
        }
        if system_blocks:
            body["system"] = system_blocks
        return body

    def _record_usage(self, usage: dict | None):
        if not usage:
            return
        for k in ("input_tokens", "output_tokens", "cache_read_input_tokens", "cache_creation_input_tokens"):
            if usage.get(k) is not None:
                self.last_usage[k] = usage[k]

    def chat(self, messages: list[Message], stream: bool = True) -> Iterator[str]:
        if not self.api_key:
            raise RuntimeError("ANTHROPIC_API_KEY not set")

        self.last_usage = {}
        self.last_stop_reason = ""
        self.last_blocks = []
        payload = json.dumps(self._build_body(messages, self.model, stream)).encode()
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
                saw_stop = False
                for line in resp:
                    line = line.decode().strip()
                    if line.startswith("data:"):
                        data_str = line[5:].strip()
                        if data_str == "[DONE]":
                            break
                        try:
                            data = json.loads(data_str)
                        except json.JSONDecodeError:
                            continue
                        etype = data.get("type")
                        if etype in ("content_block_start", "content_block_delta"):
                            _blk = data.get("content_block") or data.get("delta") or {}
                            _bt = _blk.get("type", "?")
                            if _bt not in self.last_blocks:
                                self.last_blocks.append(_bt)
                        if etype == "content_block_delta":
                            chunk = data.get("delta", {}).get("text", "")
                            if chunk:
                                yield chunk
                        elif etype == "message_start":
                            self._record_usage(data.get("message", {}).get("usage"))
                        elif etype == "message_delta":
                            self._record_usage(data.get("usage"))
                            # Claude 5-family safety classifiers can end a turn with
                            # stop_reason "refusal" and empty content — say so instead
                            # of showing a blank reply.
                            self.last_stop_reason = data.get("delta", {}).get("stop_reason") or self.last_stop_reason
                            if data.get("delta", {}).get("stop_reason") == "refusal":
                                yield "[Claude declined this request.]"
                        elif etype == "message_stop":
                            saw_stop = True
                        elif etype == "error":
                            err = data.get("error", {})
                            raise RuntimeError(f"Anthropic stream error: {err.get('type', 'error')}: {err.get('message', '')}")
                if not saw_stop:
                    raise RuntimeError("Anthropic stream ended without message_stop (connection dropped or truncated)")
            else:
                data = json.loads(resp.read())
                self._record_usage(data.get("usage"))
                if data.get("stop_reason") == "refusal":
                    yield "[Claude declined this request.]"
                    return
                yield "".join(b.get("text", "") for b in data.get("content", []) if b.get("type") == "text")

    def usage_summary(self) -> str:
        """One-line summary of the last request's token usage, or '' if unknown."""
        u = self.last_usage
        if not u:
            return ""
        fresh = u.get("input_tokens", 0)
        cached = u.get("cache_read_input_tokens", 0)
        written = u.get("cache_creation_input_tokens", 0)
        out = u.get("output_tokens", 0)
        total_in = fresh + cached + written
        pct = (100 * cached // total_in) if total_in else 0
        return f"last request: {total_in} in ({cached} cached, {pct}%), {out} out"
