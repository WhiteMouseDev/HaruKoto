"""Source-controlled admission pause for the study writer cutover.

OFF by default; activation requires a separately approved artifact/deployment.
There is no request/env override, and already-running handlers are not stopped.
"""

from __future__ import annotations

import posixpath
import re
from urllib.parse import unquote

from starlette.responses import JSONResponse
from starlette.types import ASGIApp, Receive, Scope, Send

STUDY_WRITES_PAUSED = False
STOP_MESSAGE = "학습 저장을 잠시 점검하고 있어요. 잠시 후 같은 기록으로 다시 시도해주세요."
STOP_HEADERS = {"Retry-After": "60", "Cache-Control": "private, no-store"}

# The two GETs are writers: mission auto-rewards and old-session expiration.
BLOCKED_ROUTES: frozenset[tuple[str, str]] = frozenset(
    {
        ("POST", "/api/v1/quiz/start"),
        ("POST", "/api/v1/quiz/smart-start"),
        ("POST", "/api/v1/quiz/wrong-answer-review/start"),
        ("POST", "/api/v1/quiz/resume"),
        ("POST", "/api/v1/quiz/answer"),
        ("POST", "/api/v1/quiz/complete"),
        ("GET", "/api/v1/quiz/incomplete"),
        ("GET", "/api/v1/missions/today"),
        ("POST", "/api/v1/missions/claim"),
        ("POST", "/api/v1/kana/progress"),
        ("POST", "/api/v1/kana/progress/activities"),
        ("POST", "/api/v1/kana/quiz/start"),
        ("POST", "/api/v1/kana/quiz/answer"),
        ("POST", "/api/v1/kana/quiz/complete"),
        ("POST", "/api/v1/kana/stage-complete"),
        ("POST", "/api/v1/lessons/{lesson_id}/start"),
        ("POST", "/api/v1/lessons/{lesson_id}/submit"),
        ("POST", "/api/v1/lessons/{lesson_id}/submissions"),
        # The registered p6 activity writer is paused before its user mutex.
        ("POST", "/api/v1/lessons/{lesson_id}/study-activities"),
        ("POST", "/api/v1/chat/start"),
        ("POST", "/api/v1/chat/message"),
        ("POST", "/api/v1/chat/end"),
        ("POST", "/api/v1/chat/live-token"),
        ("POST", "/api/v1/chat/live-session"),
        ("POST", "/api/v1/chat/live-feedback"),
        ("DELETE", "/api/v1/chat/{conversation_id}"),
        ("PATCH", "/api/v1/study/daily-goal"),
        ("PATCH", "/api/v1/study/category-goal"),
        ("PATCH", "/api/v1/user/profile"),
        ("POST", "/api/v1/user/avatar"),
        ("PATCH", "/api/v1/user/avatar"),
        ("PATCH", "/api/v1/user/account"),
        ("DELETE", "/api/v1/user/account"),
    }
)


def _canonical_path(path: str) -> str:
    # ASGI has decoded once. Additional decoding conservatively pauses ambiguous
    # encodings too; the OFF/passthrough request itself is never rewritten.
    for _ in range(4):
        decoded = unquote(path)
        if decoded == path:
            break
        path = decoded
    return posixpath.normpath("/" + path.lstrip("/")).rstrip("/") or "/"


def _template_pattern(template: str) -> re.Pattern[str]:
    parts = _canonical_path(template).split("/")
    return re.compile("/".join("[^/]+" if part.startswith("{") and part.endswith("}") else re.escape(part) for part in parts))


_BLOCKED_PATTERNS = tuple((method, _template_pattern(template)) for method, template in sorted(BLOCKED_ROUTES))


def is_study_write_route(method: str, path: str) -> bool:
    method = "GET" if method.upper() == "HEAD" else method.upper()
    canonical = _canonical_path(path)
    return any(method == blocked_method and pattern.fullmatch(canonical) for blocked_method, pattern in _BLOCKED_PATTERNS)


class StudyWriteStopMiddleware:
    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] == "http" and STUDY_WRITES_PAUSED:
            path = scope.get("path", "")
            root_path = scope.get("root_path", "").rstrip("/")
            if root_path and path.startswith(root_path + "/"):
                path = path[len(root_path) :]
            if is_study_write_route(scope.get("method", "GET"), path):
                response = JSONResponse({"detail": STOP_MESSAGE}, status_code=503, headers=STOP_HEADERS)
                await response(scope, receive, send)
                return
        await self.app(scope, receive, send)
