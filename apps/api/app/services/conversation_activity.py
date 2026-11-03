from __future__ import annotations

import json

from sqlalchemy import and_, cast, func, literal
from sqlalchemy.dialects.postgresql import JSONB, JSONPATH
from sqlalchemy.sql.elements import ColumnElement

from app.models import Conversation

# Match Python str.strip(), which completion/reward eligibility uses. PostgreSQL
# regex whitespace classes depend on LC_CTYPE (C excludes e.g. U+3000). Literal
# characters, rather than classes or ranges, keep this predicate locale-independent.
_PYTHON_WHITESPACE = (
    "\t\n\v\f\r\x1c\x1d\x1e\x1f \x85\xa0\u1680"
    "\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200a"
    "\u2028\u2029\u202f\u205f\u3000"
)
_NON_WHITESPACE_REGEX_JSON = json.dumps(f"[^{_PYTHON_WHITESPACE}]")


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
                'strict $[*] ? (@.type() == "object" && @.role.type() == "string" && @.role == "user"'
                f' && @.content.type() == "string" && @.content like_regex {_NON_WHITESPACE_REGEX_JSON})',
                JSONPATH,
            ),
            cast(literal("{}"), JSONB),
            True,
        ),
    )
