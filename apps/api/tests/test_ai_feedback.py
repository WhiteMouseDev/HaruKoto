from __future__ import annotations

import asyncio
import json
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import httpx
import pytest
from google import genai
from google.genai import errors, types
from pydantic import ValidationError

from app.schemas.ai_feedback import LiveFeedbackOutput, TextFeedbackOutput
from app.services.ai_conversation import generate_feedback_summary, generate_live_feedback
from app.services.ai_json import parse_feedback_response
from app.services.live_feedback_evidence import ground_live_feedback


@pytest.fixture
def feedback_output():
    return {
        "overallScore": 80,
        "fluency": 70.5,
        "accuracy": 85,
        "vocabularyDiversity": 70,
        "naturalness": 85,
        "strengths": ["예약 이름을 전달했어요"],
        "improvements": ["정중한 표현을 연습해 보세요"],
        "recommendedExpressions": [{"ja": "予約しました", "ko": "예약했어요"}],
        "corrections": [{"original": "予約した", "corrected": "予約しました", "explanation": "정중한 표현이에요"}],
        "translatedTranscript": [{"role": "user", "ja": "予約した", "ko": "예약했어"}],
    }


def test_feedback_preserves_existing_numeric_types_and_transcript(feedback_output):
    result = parse_feedback_response(f"```json\n{json.dumps(feedback_output)}\n```", LiveFeedbackOutput)
    assert result == feedback_output
    assert type(result["overallScore"]) is int
    assert type(result["fluency"]) is float


@pytest.mark.parametrize("invalid", ["provider error", "{}", "[]", '{"messageJa":"こんにちは"}', "null"])
def test_feedback_rejects_non_evaluations_instead_of_returning_zero_scores(invalid):
    with pytest.raises(ValidationError):
        parse_feedback_response(invalid, LiveFeedbackOutput)


@pytest.mark.parametrize("score", [-1, 101, True, "80", None, float("nan"), float("inf")])
def test_feedback_rejects_invalid_scores(feedback_output, score):
    feedback_output["overallScore"] = score
    with pytest.raises(ValidationError):
        parse_feedback_response(json.dumps(feedback_output), LiveFeedbackOutput)


def test_feedback_rejects_missing_required_feedback_fields(feedback_output):
    del feedback_output["fluency"]
    with pytest.raises(ValidationError):
        parse_feedback_response(json.dumps(feedback_output), LiveFeedbackOutput)


@pytest.mark.asyncio
async def test_live_feedback_retries_malformed_output_with_level_and_scenario_context(feedback_output):
    client = MagicMock()
    client.aio.models.generate_content = AsyncMock(
        side_effect=[SimpleNamespace(text="not an evaluation"), SimpleNamespace(text=json.dumps(feedback_output))]
    )
    with (
        patch("app.services.ai_conversation.ensure_google_client", return_value=client),
        patch("app.services.ai_conversation.asyncio.sleep", new_callable=AsyncMock),
    ):
        result = await generate_live_feedback(
            [{"role": "user", "text": "予約した"}], scenario_info="ホテルで予約を確認する", jlpt_level="N2"
        )

    assert result == feedback_output
    assert client.aio.models.generate_content.await_count == 2
    request = client.aio.models.generate_content.await_args.kwargs
    assert "ホテルで予約を確認する" in request["contents"]
    assert "N2" in request["contents"]
    assert request["config"].response_mime_type == "application/json"
    assert request["config"].response_schema is None
    assert request["config"].response_json_schema == LiveFeedbackOutput.model_json_schema()
    assert request["config"].thinking_config.thinking_budget == 0
    assert request["config"].http_options.retry_options.attempts == 1


@pytest.mark.asyncio
async def test_live_feedback_failure_exhausts_retries_without_success_fallback():
    client = MagicMock()
    client.aio.models.generate_content = AsyncMock(return_value=SimpleNamespace(text="{}"))
    with (
        patch("app.services.ai_conversation.ensure_google_client", return_value=client),
        patch("app.services.ai_conversation.asyncio.sleep", new_callable=AsyncMock),
        pytest.raises(ValidationError),
    ):
        await generate_live_feedback([{"role": "user", "text": "こんにちは"}])
    assert client.aio.models.generate_content.await_count == 3


@pytest.mark.asyncio
async def test_live_feedback_allows_no_correction_for_natural_polite_speech(feedback_output):
    utterance = "予約したキムです。チェックインをお願いします。"
    feedback_output["corrections"] = []
    feedback_output["improvements"] = []
    feedback_output["translatedTranscript"][0]["ja"] = utterance
    client = MagicMock()
    client.aio.models.generate_content = AsyncMock(return_value=SimpleNamespace(text=json.dumps(feedback_output)))
    with patch("app.services.ai_conversation.ensure_google_client", return_value=client):
        result = await generate_live_feedback([{"role": "user", "text": utterance}], jlpt_level="N5")

    assert result["corrections"] == []
    assert result["improvements"] == []
    instruction = client.aio.models.generate_content.await_args.kwargs["config"].system_instruction
    # This checks prompt delivery and optional feedback, not model quality.
    assert "敬語不足や誤りとして指摘しない" in instruction
    assert "連体修飾の普通形" in instruction
    assert "선택 연습" in instruction
    assert "韓国語の言い換えを、日本語の訂正例として使わない" in instruction


@pytest.mark.asyncio
async def test_text_feedback_rejects_provider_chat_fallback():
    client = MagicMock()
    client.aio.models.generate_content = AsyncMock(return_value=SimpleNamespace(text="評価できません"))
    with (
        patch("app.services.ai_conversation.ensure_google_client", return_value=client),
        pytest.raises(ValidationError),
    ):
        await generate_feedback_summary([{"role": "user", "content": "こんにちは"}])
    config = client.aio.models.generate_content.await_args.kwargs["config"]
    assert config.response_schema is None
    assert config.response_json_schema == TextFeedbackOutput.model_json_schema()
    assert config.thinking_config is None
    assert config.http_options.retry_options.attempts == 1


@pytest.mark.asyncio
@pytest.mark.parametrize("status_code", [400, 401, 403, 404, 422])
async def test_live_feedback_does_not_retry_permanent_provider_errors(status_code, caplog):
    error = errors.ClientError(status_code, {"error": {"message": "private provider request content"}})
    client = MagicMock()
    client.aio.models.generate_content = AsyncMock(side_effect=error)
    with (
        patch("app.services.ai_conversation.ensure_google_client", return_value=client),
        patch("app.services.ai_conversation.asyncio.sleep", new_callable=AsyncMock) as sleep,
        pytest.raises(errors.ClientError) as raised,
    ):
        await generate_live_feedback([{"role": "user", "text": "こんにちは"}])

    assert raised.value is error
    assert client.aio.models.generate_content.await_count == 1
    sleep.assert_not_awaited()
    assert f"status_code={status_code}" in caplog.text
    assert "private provider request content" not in caplog.text


@pytest.mark.asyncio
@pytest.mark.parametrize("status_code", [408, 429, 500, 503])
async def test_live_feedback_retries_transient_provider_errors(status_code, feedback_output):
    error_type = errors.ClientError if status_code < 500 else errors.ServerError
    client = MagicMock()
    client.aio.models.generate_content = AsyncMock(
        side_effect=[
            error_type(status_code, {"error": {"message": "temporary failure"}}),
            SimpleNamespace(text=json.dumps(feedback_output)),
        ]
    )
    with (
        patch("app.services.ai_conversation.ensure_google_client", return_value=client),
        patch("app.services.ai_conversation.asyncio.sleep", new_callable=AsyncMock) as sleep,
    ):
        result = await generate_live_feedback([{"role": "user", "text": "予約した"}])

    assert result == feedback_output
    assert client.aio.models.generate_content.await_count == 2
    sleep.assert_awaited_once_with(1)


@pytest.mark.asyncio
@pytest.mark.parametrize("live", [True, False])
async def test_feedback_sdk_sends_json_schema_instead_of_legacy_schema(live, feedback_output):
    expected = feedback_output.copy()
    if not live:
        expected.pop("corrections")
        expected.pop("translatedTranscript")
        expected["recommendedExpressions"] = ["予約しました"]
    schema = LiveFeedbackOutput if live else TextFeedbackOutput
    requests = []

    async def respond(request):
        body = json.loads(request.content)
        requests.append(body)
        assert "responseSchema" not in body["generationConfig"]
        assert body["generationConfig"]["responseJsonSchema"] == schema.model_json_schema()
        if live:
            assert types.ThinkingConfig.model_validate(body["generationConfig"]["thinkingConfig"]).thinking_budget == 0
        else:
            assert "thinkingConfig" not in body["generationConfig"]
        return httpx.Response(200, json={"candidates": [{"content": {"role": "model", "parts": [{"text": json.dumps(expected)}]}}]})

    async with httpx.AsyncClient(transport=httpx.MockTransport(respond)) as http:
        client = genai.Client(api_key="offline-test-placeholder", http_options=types.HttpOptions(httpx_async_client=http))
        try:
            with patch("app.services.ai_conversation.ensure_google_client", return_value=client):
                result = (
                    await generate_live_feedback([{"role": "user", "text": "予約した"}])
                    if live
                    else await generate_feedback_summary([{"role": "user", "content": "予約した"}])
                )
        finally:
            await client.aio.aclose()
            client.close()
    assert result == expected
    assert len(requests) == 1


@pytest.mark.asyncio
async def test_live_feedback_sdk_does_not_multiply_service_retries():
    requests = []

    async def unavailable(request):
        requests.append(request)
        return httpx.Response(503, json={"error": {"code": 503, "status": "UNAVAILABLE", "message": "temporary failure"}})

    async with httpx.AsyncClient(transport=httpx.MockTransport(unavailable)) as http:
        client = genai.Client(api_key="offline-test-placeholder", http_options=types.HttpOptions(httpx_async_client=http))
        try:
            with (
                patch("app.services.ai_conversation.ensure_google_client", return_value=client),
                patch("app.services.ai_conversation.asyncio.sleep", new_callable=AsyncMock),
                pytest.raises(errors.ServerError),
            ):
                await generate_live_feedback([{"role": "user", "text": "こんにちは"}])
        finally:
            await client.aio.aclose()
            client.close()
    assert len(requests) == 3


@pytest.mark.parametrize(
    "user_text,quote", [("こんにちは", "予約した"), ("저는 예약했어요", "予約した"), ("저는 예약했어요", "저는 예약했어요")]
)
def test_corrections_cannot_cite_invented_assistant_or_korean_reconstructed_speech(feedback_output, user_text, quote):
    feedback_output["corrections"][0]["original"] = quote
    transcript = [{"role": "assistant", "text": "予約した"}, {"role": "user", "text": user_text}]
    result = ground_live_feedback(feedback_output, transcript)
    assert result["corrections"] == []
    assert result["translatedTranscript"] == [
        {"role": "assistant", "ja": "予約した", "ko": ""},
        {"role": "user", "ja": user_text, "ko": ""},
    ]


def test_valid_user_quote_allows_whitespace_differences_without_rewriting_original(feedback_output):
    result = ground_live_feedback(feedback_output, [{"role": "user", "text": "予約 した"}])
    assert result["corrections"][0]["original"] == "予約した"
    assert result["translatedTranscript"] == [{"role": "user", "ja": "予約 した", "ko": "예약했어"}]


@pytest.mark.asyncio
async def test_live_feedback_has_a_total_timeout(monkeypatch):
    async def never_finishes(**kwargs):
        await asyncio.Event().wait()

    client = MagicMock()
    client.aio.models.generate_content = AsyncMock(side_effect=never_finishes)
    monkeypatch.setattr("app.services.ai_conversation.LIVE_FEEDBACK_TIMEOUT_SECONDS", 0.01)
    with patch("app.services.ai_conversation.ensure_google_client", return_value=client), pytest.raises(TimeoutError):
        await generate_live_feedback([{"role": "user", "text": "こんにちは"}])
