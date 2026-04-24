import pytest

from app.seeds.lessons import _lesson_is_published


@pytest.mark.parametrize("status", ["PILOT", "PUBLISHED"])
def test_lesson_seed_publishes_reviewed_statuses(status: str) -> None:
    assert _lesson_is_published({"status": status}) is True


def test_lesson_seed_does_not_publish_draft_status() -> None:
    assert _lesson_is_published({"status": "DRAFT"}) is False


def test_lesson_seed_rejects_unknown_status() -> None:
    with pytest.raises(ValueError, match="Unsupported lesson meta.status: ARCHIVED"):
        _lesson_is_published({"status": "ARCHIVED"})
