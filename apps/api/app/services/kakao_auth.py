from __future__ import annotations

import logging
from typing import Any, Protocol, cast

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

KAKAO_TOKEN_URL = "https://kauth.kakao.com/oauth/token"


class KakaoTokenExchangeError(Exception):
    """Raised when Kakao rejects the authorization code exchange."""


class KakaoIdTokenMissingError(Exception):
    """Raised when Kakao succeeds but omits the OIDC id_token."""


class KakaoTokenHttpClient(Protocol):
    async def post(self, url: str, *, data: dict[str, str]) -> httpx.Response: ...


async def exchange_kakao_authorization_code(
    *,
    code: str,
    redirect_uri: str,
) -> str:
    async with httpx.AsyncClient() as client:
        return await exchange_kakao_authorization_code_with_client(
            client,
            code=code,
            redirect_uri=redirect_uri,
        )


async def exchange_kakao_authorization_code_with_client(
    client: KakaoTokenHttpClient,
    *,
    code: str,
    redirect_uri: str,
    rest_api_key: str | None = None,
    client_secret: str | None = None,
) -> str:
    response = await client.post(
        KAKAO_TOKEN_URL,
        data={
            "grant_type": "authorization_code",
            "client_id": settings.KAKAO_REST_API_KEY if rest_api_key is None else rest_api_key,
            "client_secret": settings.KAKAO_CLIENT_SECRET if client_secret is None else client_secret,
            "code": code,
            "redirect_uri": redirect_uri,
        },
    )

    if response.status_code != 200:
        logger.warning("Kakao token exchange failed: %s", response.text)
        raise KakaoTokenExchangeError

    data = response.json()
    if not isinstance(data, dict):
        raise KakaoIdTokenMissingError

    id_token = cast(dict[str, Any], data).get("id_token")
    if not isinstance(id_token, str) or not id_token:
        raise KakaoIdTokenMissingError

    return id_token
