from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(slots=True)
class ConversationHistory:
    system_prompt: str
    history: list[dict[str, str]]


def message_list(raw_messages: Any) -> list[dict[str, Any]]:
    if not isinstance(raw_messages, list):
        return []
    return [message for message in raw_messages if isinstance(message, dict)]


def extract_conversation_history(messages: list[dict[str, Any]]) -> ConversationHistory:
    system_prompt = ""
    history: list[dict[str, str]] = []

    for message in messages:
        role = message.get("role")
        content = str(message.get("content", ""))
        if role == "system":
            system_prompt = content
        elif role in ("user", "assistant"):
            history.append({"role": role, "content": content})

    return ConversationHistory(system_prompt=system_prompt, history=history)


def conversation_messages(messages: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [message for message in messages if message.get("role") in ("user", "assistant")]


def append_chat_exchange(
    messages: list[dict[str, Any]],
    *,
    user_message: str,
    assistant_message: str,
) -> list[dict[str, Any]]:
    return messages + [
        {"role": "user", "content": user_message},
        {"role": "assistant", "content": assistant_message},
    ]


def count_conversation_messages(messages: list[dict[str, Any]]) -> int:
    return len(conversation_messages(messages))
