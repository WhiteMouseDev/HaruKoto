from __future__ import annotations

from sqlalchemy import and_, cast, func, literal
from sqlalchemy.dialects.postgresql import JSONB, JSONPATH
from sqlalchemy.sql.elements import ColumnElement

from app.models import Conversation


def has_user_utterance() -> ColumnElement[bool]:
    """Exclude empty/assistant-only records, including malformed legacy JSON.

    Duration is not stored per conversation, so this is evidence of participation,
    not proof of meeting the separate 15-second XP eligibility condition.
    """
    messages = cast(Conversation.messages, JSONB)
    return and_(
        func.jsonb_typeof(messages) == "array",
        func.jsonb_path_exists(
            messages,
            cast(
                r'strict $[*] ? (@.type() == "object" && @.role.type() == "string" && @.role == "user"'
                r' && @.content.type() == "string" && @.content like_regex "\\S")',
                JSONPATH,
            ),
            cast(literal("{}"), JSONB),
            True,
        ),
    )
