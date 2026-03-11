from datetime import UTC, datetime

from dateutil.relativedelta import relativedelta

from app.services.subscription import get_subscription_period_end


def test_monthly_period_end():
    """Monthly plan adds exactly 1 month."""
    base = datetime(2025, 1, 15, 12, 0, 0, tzinfo=UTC)
    result = get_subscription_period_end("monthly", from_date=base)
    expected = base + relativedelta(months=1)
    assert result == expected
    assert result.year == 2025
    assert result.month == 2
    assert result.day == 15


def test_yearly_period_end():
    """Yearly plan adds exactly 1 year."""
    base = datetime(2025, 3, 1, 0, 0, 0, tzinfo=UTC)
    result = get_subscription_period_end("yearly", from_date=base)
    expected = base + relativedelta(years=1)
    assert result == expected
    assert result.year == 2026
    assert result.month == 3
    assert result.day == 1


def test_monthly_end_of_month():
    """Monthly plan handles end-of-month correctly (Jan 31 -> Feb 28)."""
    base = datetime(2025, 1, 31, 12, 0, 0, tzinfo=UTC)
    result = get_subscription_period_end("monthly", from_date=base)
    assert result.month == 2
    assert result.day == 28


def test_yearly_leap_year():
    """Yearly plan from Feb 29 in a leap year goes to Feb 28 next year."""
    base = datetime(2024, 2, 29, 12, 0, 0, tzinfo=UTC)
    result = get_subscription_period_end("yearly", from_date=base)
    assert result.year == 2025
    assert result.month == 2
    assert result.day == 28


def test_default_from_date():
    """When from_date is None, uses current time (result is ~1 month from now)."""
    before = datetime.now(tz=UTC)
    result = get_subscription_period_end("monthly")
    after = datetime.now(tz=UTC)

    expected_min = before + relativedelta(months=1)
    expected_max = after + relativedelta(months=1)
    assert expected_min <= result <= expected_max
