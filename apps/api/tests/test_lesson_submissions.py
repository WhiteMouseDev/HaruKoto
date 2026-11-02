"""Wire, owner assertion and immutable fingerprint regressions (no DB/network)."""

from copy import deepcopy
from datetime import UTC, datetime
from unittest.mock import AsyncMock, patch
from uuid import uuid1, uuid4

import pytest
from pydantic import ValidationError

from app.models.lesson import LessonSubmission
from app.schemas.lesson import LessonSubmissionRequest, LessonSubmissionResponse
from app.services.lesson_command import LessonServiceError
from app.services.lesson_submission import get_lesson_submission, submission_fingerprint, submit_lesson_once


def _request(user_id):
    return {
        "submissionId": str(uuid4()),
        "expectedUserId": str(user_id),
        "answers": [
            {"order": 1, "selectedAnswer": "a"},
            {"order": 2, "submittedOrder": ["日本", "へ", "行きます"]},
        ],
    }


def _response(submission_id):
    return LessonSubmissionResponse.model_validate(
        {
            "submissionId": str(submission_id),
            "processedAt": datetime.now(UTC).isoformat(),
            "result": {"scoreCorrect": 1, "scoreTotal": 2, "results": [], "status": "COMPLETED", "srsItemsRegistered": 2},
        }
    )


def test_fingerprint_defaults_are_canonical_but_answers_tokens_and_times_are_not_rewritten():
    user_id, lesson_id = uuid4(), uuid4()
    raw = _request(user_id)
    request = LessonSubmissionRequest.model_validate(raw)
    base = submission_fingerprint(lesson_id, request)
    explicit = deepcopy(raw)
    explicit["answers"][0].update(submittedOrder=None, responseMs=0)
    explicit["answers"][1].update(selectedAnswer=None, responseMs=0)
    assert submission_fingerprint(lesson_id, LessonSubmissionRequest.model_validate(explicit)) == base
    mutations = [
        {**raw, "answers": list(reversed(raw["answers"]))},
        {**raw, "answers": [{**raw["answers"][0], "responseMs": 1}, raw["answers"][1]]},
        {**raw, "answers": [raw["answers"][0], {**raw["answers"][1], "submittedOrder": ["へ", "日本", "行きます"]}]},
        {**raw, "expectedUserId": str(uuid4())},
    ]
    for mutation in mutations:
        assert submission_fingerprint(lesson_id, LessonSubmissionRequest.model_validate(mutation)) != base
    assert submission_fingerprint(uuid4(), request) != base


@pytest.mark.parametrize("mutation", ["uuid_version", "unknown", "answer_unknown", "bool_order", "string_ms"])
def test_new_request_is_strict_without_strengthening_legacy(mutation):
    raw = _request(uuid4())
    if mutation == "uuid_version":
        raw["submissionId"] = str(uuid1())
    elif mutation == "unknown":
        raw["retry"] = True
    elif mutation == "answer_unknown":
        raw["answers"][0]["isCorrect"] = True
    elif mutation == "bool_order":
        raw["answers"][0]["order"] = True
    else:
        raw["answers"][0]["responseMs"] = "100"
    with pytest.raises(ValidationError):
        LessonSubmissionRequest.model_validate(raw)


@pytest.mark.asyncio
async def test_owner_mismatch_precedes_all_db_reads_or_writes(mock_user):
    db = AsyncMock()
    request = LessonSubmissionRequest.model_validate(_request(uuid4()))
    with pytest.raises(LessonServiceError) as error:
        await submit_lesson_once(db, mock_user, lesson_id=uuid4(), request=request)
    assert error.value.status_code == 403
    with pytest.raises(LessonServiceError) as error:
        await get_lesson_submission(db, mock_user, lesson_id=uuid4(), submission_id=uuid4(), expected_user_id=request.expected_user_id)
    assert error.value.status_code == 403
    assert db.mock_calls == []


@pytest.mark.asyncio
@pytest.mark.parametrize("corruption", ["schema_version", "fingerprint_version", "body", "identity", "timestamp"])
async def test_corrupt_or_unknown_receipts_fail_closed(mock_user, corruption):
    lesson_id, submission_id = uuid4(), uuid4()
    response = _response(submission_id)
    receipt = LessonSubmission(
        user_id=mock_user.id,
        lesson_id=lesson_id,
        submission_id=submission_id,
        request_fingerprint="a" * 64,
        fingerprint_version=1,
        response_schema_version=1,
        response_body=response.model_dump(mode="json", by_alias=True),
        processed_at=response.processed_at,
    )
    if corruption == "schema_version":
        receipt.response_schema_version = 2
    elif corruption == "fingerprint_version":
        receipt.fingerprint_version = 2
    elif corruption == "body":
        receipt.response_body = {"result": {}}
    elif corruption == "identity":
        receipt.response_body["submissionId"] = str(uuid4())
    else:
        receipt.processed_at = datetime(2000, 1, 1, tzinfo=UTC)
    db = AsyncMock()
    db.get.return_value = receipt
    with pytest.raises(LessonServiceError) as error:
        await get_lesson_submission(db, mock_user, lesson_id=lesson_id, submission_id=submission_id, expected_user_id=mock_user.id)
    assert error.value.status_code == 503
    db.commit.assert_not_awaited()
    db.execute.assert_not_awaited()


@pytest.mark.asyncio
async def test_new_route_camel_envelope_and_query_alias_are_exact(client, mock_user):
    lesson_id = uuid4()
    request = _request(mock_user.id)
    expected = _response(request["submissionId"])
    with patch("app.routers.lesson_submissions.submit_lesson_once", new=AsyncMock(return_value=expected)) as submit:
        response = await client.post(f"/api/v1/lessons/{lesson_id}/submissions", json=request)
    assert response.status_code == 200
    assert response.headers["cache-control"] == "private, no-store"
    assert response.json() == expected.model_dump(mode="json", by_alias=True)
    assert submit.await_args.kwargs["request"].expected_user_id == mock_user.id
    with patch("app.routers.lesson_submissions.get_lesson_submission", new=AsyncMock(return_value=expected)) as get:
        response = await client.get(
            f"/api/v1/lessons/{lesson_id}/submissions/{expected.submission_id}", params={"expectedUserId": str(mock_user.id)}
        )
    assert response.status_code == 200
    assert response.headers["cache-control"] == "private, no-store"
    assert get.await_args.kwargs["expected_user_id"] == mock_user.id


@pytest.mark.asyncio
@pytest.mark.parametrize("status", [403, 404, 409, 503])
async def test_new_route_domain_errors_are_private_and_keep_standard_error_shape(client, mock_user, status):
    with patch(
        "app.routers.lesson_submissions.submit_lesson_once",
        new=AsyncMock(side_effect=LessonServiceError(status, "제출 결과를 확인해주세요")),
    ):
        response = await client.post(f"/api/v1/lessons/{uuid4()}/submissions", json=_request(mock_user.id))
    assert response.status_code == status
    assert response.headers["cache-control"] == "private, no-store"
    assert response.json()["error"]["message"] == "제출 결과를 확인해주세요"


@pytest.mark.asyncio
async def test_missing_get_assertion_and_invalid_post_are_no_store_422(client, mock_user):
    response = await client.get(f"/api/v1/lessons/{uuid4()}/submissions/{uuid4()}")
    assert response.status_code == 422
    assert response.headers["cache-control"] == "private, no-store"
    assert response.json()["error"]["message"] == "요청 검증에 실패했습니다"
    response = await client.post(f"/api/v1/lessons/{uuid4()}/submissions", json={"answers": []})
    assert response.status_code == 422
    assert response.headers["cache-control"] == "private, no-store"


@pytest.mark.asyncio
async def test_unexpected_lookup_failure_keeps_standard_error_and_no_store(client, mock_user):
    with patch("app.routers.lesson_submissions.get_lesson_submission", new=AsyncMock(side_effect=RuntimeError("synthetic read failure"))):
        response = await client.get(f"/api/v1/lessons/{uuid4()}/submissions/{uuid4()}", params={"expectedUserId": str(mock_user.id)})
    assert response.status_code == 500
    assert response.headers["cache-control"] == "private, no-store"
    assert response.json()["error"]["message"] == "서버 내부 오류가 발생했습니다"
