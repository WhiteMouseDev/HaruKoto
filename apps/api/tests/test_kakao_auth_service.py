from __future__ import annotations

import httpx
import pytest

from app.services.kakao_auth import (
    KAKAO_TOKEN_URL,
    KakaoIdTokenMissingError,
    KakaoTokenExchangeError,
    exchange_kakao_authorization_code_with_client,
)


class StubKakaoClient:
    def __init__(self, response: httpx.Response) -> None:
        self.response = response
        self.calls: list[tuple[str, dict[str, str]]] = []

    async def post(self, url: str, *, data: dict[str, str]) -> httpx.Response:
        self.calls.append((url, data))
        return self.response


@pytest.mark.asyncio
async def test_exchange_kakao_authorization_code_posts_oauth_payload() -> None:
    client = StubKakaoClient(httpx.Response(200, json={"id_token": "id-token"}))

    id_token = await exchange_kakao_authorization_code_with_client(
        client,
        code="authorization-code",
        redirect_uri="harukoto://oauth/kakao",
        rest_api_key="rest-key",
        client_secret="client-secret",
    )

    assert id_token == "id-token"
    assert client.calls == [
        (
            KAKAO_TOKEN_URL,
            {
                "grant_type": "authorization_code",
                "client_id": "rest-key",
                "client_secret": "client-secret",
                "code": "authorization-code",
                "redirect_uri": "harukoto://oauth/kakao",
            },
        )
    ]


@pytest.mark.asyncio
async def test_exchange_kakao_authorization_code_raises_for_failed_exchange() -> None:
    client = StubKakaoClient(httpx.Response(401, text="invalid code"))

    with pytest.raises(KakaoTokenExchangeError):
        await exchange_kakao_authorization_code_with_client(
            client,
            code="bad-code",
            redirect_uri="harukoto://oauth/kakao",
        )


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "response",
    [
        httpx.Response(200, json={}),
        httpx.Response(200, json={"id_token": ""}),
        httpx.Response(200, json=[]),
    ],
)
async def test_exchange_kakao_authorization_code_raises_when_id_token_missing(response: httpx.Response) -> None:
    client = StubKakaoClient(response)

    with pytest.raises(KakaoIdTokenMissingError):
        await exchange_kakao_authorization_code_with_client(
            client,
            code="authorization-code",
            redirect_uri="harukoto://oauth/kakao",
        )
