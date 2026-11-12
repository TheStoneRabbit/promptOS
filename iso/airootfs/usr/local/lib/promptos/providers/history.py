"""
History compaction for promptOS providers.

The APIs are stateless, so the full history is resent on every call. A sliding
window (bound_history) shifts the start of the prompt each call, which
invalidates the prompt cache. compact_history instead trims in one batch and
mutates the list in place, so the retained prefix stays byte-identical until
the next batch and caching keeps hitting. Old command-result messages are
shrunk in the same step, because changing them at any other time would also
invalidate the cache.
"""

from .base import Message

TRIGGER_MESSAGES = 40      # compact when non-system messages exceed this
KEEP_MESSAGES = 20         # ...down to roughly this many
FRESH_TAIL = 2             # newest messages are never shrunk
OLD_RESULT_HEAD = 300
OLD_RESULT_TAIL = 300
RESULT_PREFIX = "[command results]"


def _shrink(content: str) -> str:
    limit = OLD_RESULT_HEAD + OLD_RESULT_TAIL
    if len(content) <= limit + 80:
        return content
    omitted = len(content) - limit
    return (f"{content[:OLD_RESULT_HEAD]}\n"
            f"...[{omitted} chars of older command output trimmed]...\n"
            f"{content[-OLD_RESULT_TAIL:]}")


def compact_history(messages: list, trigger: int = TRIGGER_MESSAGES, keep: int = KEEP_MESSAGES) -> bool:
    """Trim `messages` in place. Returns True if a compaction happened."""
    system = [m for m in messages if m.role == "system"]
    rest = [m for m in messages if m.role != "system"]
    if len(rest) <= trigger:
        return False
    kept = rest[-keep:]
    # Conversations must open with a user turn.
    while kept and kept[0].role != "user":
        kept.pop(0)
    for i in range(max(0, len(kept) - FRESH_TAIL)):
        m = kept[i]
        if m.role == "user" and m.content.startswith(RESULT_PREFIX):
            shrunk = _shrink(m.content)
            if shrunk != m.content:
                kept[i] = Message(m.role, shrunk)
    messages[:] = system + kept
    return True
