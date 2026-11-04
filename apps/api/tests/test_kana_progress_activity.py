from datetime import UTC, datetime
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock
from uuid import uuid4

import pytest

from app.models import StudyActivityReceipt
from app.schemas.kana import KanaProgressActivityRequest, KanaProgressActivityResponse
from app.services import kana_progress_activity as service
from app.services.lesson_study_activity import activity_fingerprint
from app.utils.date import study_date_kst

NOW = datetime(2026, 11, 4, 1, 2, 3, 456000, tzinfo=UTC)


def _request():
    return KanaProgressActivityRequest(activity_id=uuid4(), expected_user_id=uuid4(), kana_id=uuid4())


def _fingerprint(request):
    return activity_fingerprint({"version": 1, "sourceKind": service.SOURCE_KIND, **request.model_dump(mode="json", by_alias=True)})


def _receipt(request):
    response = KanaProgressActivityResponse(ok=True, activity_id=request.activity_id, processed_at=NOW)
    return StudyActivityReceipt(
        user_id=request.expected_user_id,
        activity_id=request.activity_id,
        source_kind=service.SOURCE_KIND,
        source_scope_id=request.kana_id,
        attempt_id=request.activity_id,
        source_item_key=str(request.kana_id),
        content_version=service._content_version(request),
        request_fingerprint=_fingerprint(request),
        fingerprint_version=1,
        response_schema_version=1,
        response_body=response.model_dump(mode="json", by_alias=True),
        processed_at=NOW,
        study_date=NOW.date(),
    )


def test_receipt_replay_keeps_original_response_and_utc_instant():
    request = _request()
    receipt = _receipt(request)
    result = service._read_receipt(receipt, request, _fingerprint(request))
    assert result.model_dump(mode="json", by_alias=True) == receipt.response_body
    assert result.ok is True and result.processed_at == NOW


@pytest.mark.parametrize("field,value", [("source_kind", "LESSON_ANSWER"), ("source_scope_id", uuid4())])
def test_receipt_identity_conflict_is_409(field, value):
    request = _request()
    receipt = _receipt(request)
    setattr(receipt, field, value)
    with pytest.raises(service.KanaProgressActivityError) as error:
        service._read_receipt(receipt, request, _fingerprint(request))
    assert error.value.status_code == 409


@pytest.mark.parametrize(
    "field,value",
    [
        ("request_fingerprint", "broken"),
        ("request_fingerprint", "0" * 64),
        ("fingerprint_version", 2),
        ("response_schema_version", 2),
        ("attempt_id", uuid4()),
        ("source_item_key", "other"),
        ("content_version", "0" * 64),
        ("response_body", {}),
        ("response_body", {"ok": False}),
        ("response_body", []),
        ("processed_at", NOW.replace(tzinfo=None)),
        ("study_date", datetime(2026, 11, 5).date()),
    ],
)
def test_corrupt_receipt_is_unconfirmed_not_a_new_write(field, value):
    request = _request()
    receipt = _receipt(request)
    setattr(receipt, field, value)
    with pytest.raises(service.KanaProgressActivityError) as error:
        service._read_receipt(receipt, request, _fingerprint(request))
    assert error.value.status_code == 503


async def test_expected_owner_is_checked_before_any_database_work():
    request = _request()
    db = AsyncMock()
    with pytest.raises(service.KanaProgressActivityError) as error:
        await service.record_kana_progress_activity(db, SimpleNamespace(id=uuid4()), request)
    assert error.value.status_code == 403
    assert not db.mock_calls


async def test_replay_uses_user_lock_before_receipt_and_never_loads_character(monkeypatch):
    request = _request()
    db = AsyncMock()
    db.get.return_value = _receipt(request)
    lock = AsyncMock()
    monkeypatch.setattr(service, "lock_study_user", lock)
    result = await service.record_kana_progress_activity(db, SimpleNamespace(id=request.expected_user_id), request)
    lock.assert_awaited_once()
    db.get.assert_awaited_once_with(StudyActivityReceipt, (request.expected_user_id, request.activity_id))
    db.commit.assert_not_awaited()
    assert result.processed_at == NOW


async def test_missing_character_rolls_back_without_progress_or_receipt(monkeypatch):
    request = _request()
    db = AsyncMock()
    db.get.return_value = None
    monkeypatch.setattr(service, "lock_study_user", AsyncMock())
    daily = AsyncMock()
    monkeypatch.setattr(service, "apply_daily_progress_increment", daily)
    with pytest.raises(service.KanaProgressActivityError) as error:
        await service.record_kana_progress_activity(db, SimpleNamespace(id=request.expected_user_id), request)
    assert error.value.status_code == 404
    daily.assert_not_awaited()
    db.add.assert_not_called()
    db.commit.assert_not_awaited()
    db.rollback.assert_awaited_once()


async def test_fresh_activity_reuses_legacy_effects_and_single_commit(monkeypatch):
    request = _request()
    db = AsyncMock()
    db.add = Mock()
    db.get.side_effect = [None, object()]
    monkeypatch.setattr(service, "lock_study_user", AsyncMock())
    daily = AsyncMock()
    monkeypatch.setattr(service, "apply_daily_progress_increment", daily)
    result = await service.record_kana_progress_activity(db, SimpleNamespace(id=request.expected_user_id), request)
    assert result.activity_id == request.activity_id
    daily.assert_awaited_once_with(db, user_id=request.expected_user_id, today=study_date_kst(result.processed_at), kana_learned=1)
    # Only existing card progress and its private receipt: no user reward mutation.
    receipt = db.add.call_args.args[0]
    assert receipt.source_kind == service.SOURCE_KIND and receipt.attempt_id == request.activity_id
    assert receipt.response_body == result.model_dump(mode="json", by_alias=True)
    db.commit.assert_awaited_once()


@pytest.mark.parametrize("status", [403, 404, 409, 503])
async def test_activity_route_preserves_service_status_and_korean_detail(client, monkeypatch, test_user_id, status):
    from app.routers import kana

    monkeypatch.setattr(
        kana, "record_kana_progress_activity", AsyncMock(side_effect=service.KanaProgressActivityError(status, "확인해주세요"))
    )
    response = await client.post(
        "/api/v1/kana/progress/activities",
        json={"activityId": str(uuid4()), "expectedUserId": str(test_user_id), "kanaId": str(uuid4())},
    )
    assert response.status_code == status
    assert response.json() == {
        "error": {
            "code": {403: "AUTH_FORBIDDEN", 404: "RESOURCE_NOT_FOUND"}.get(status, "SYSTEM_ERROR"),
            "message": "확인해주세요",
            "details": None,
        }
    }


async def test_activity_route_returns_exact_additive_camel_case_contract(client, monkeypatch, test_user_id):
    from app.routers import kana

    activity_id = uuid4()
    monkeypatch.setattr(
        kana,
        "record_kana_progress_activity",
        AsyncMock(return_value=KanaProgressActivityResponse(ok=True, activity_id=activity_id, processed_at=NOW)),
    )
    response = await client.post(
        "/api/v1/kana/progress/activities",
        json={"activityId": str(activity_id), "expectedUserId": str(test_user_id), "kanaId": str(uuid4())},
    )
    assert response.status_code == 200
    assert response.json() == {"ok": True, "activityId": str(activity_id), "processedAt": "2026-11-04T01:02:03.456000Z"}
