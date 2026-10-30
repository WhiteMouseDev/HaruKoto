from datetime import UTC, date, datetime, timedelta, timezone

KST = timezone(timedelta(hours=9))


def get_today_kst() -> date:
    return datetime.now(KST).date()


def get_now_kst() -> datetime:
    return datetime.now(KST)


def study_date_kst(value: date | datetime) -> date:
    """Return the KST learning day; legacy naive timestamps are stored in UTC."""
    if isinstance(value, datetime):
        aware = value if value.tzinfo is not None else value.replace(tzinfo=UTC)
        return aware.astimezone(KST).date()
    return value
