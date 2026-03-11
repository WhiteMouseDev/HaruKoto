from datetime import date, datetime, timedelta, timezone

KST = timezone(timedelta(hours=9))


def get_today_kst() -> date:
    return datetime.now(KST).date()


def get_now_kst() -> datetime:
    return datetime.now(KST)
