"""Pure calendar/evaluation and no-network CLI regressions."""

import asyncio
import json
import os
import subprocess
import sys
import time
from datetime import UTC, datetime
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.services import review_partition_check as check
from scripts import check_review_event_partitions as cli

AS_OF = datetime(2026, 10, 21, tzinfo=UTC)
API_ROOT = Path(__file__).resolve().parents[1]
CLI_PATH = API_ROOT / "scripts/check_review_event_partitions.py"


def healthy_snapshot(end: datetime = datetime(2027, 2, 1, tzinfo=UTC)) -> check.CatalogSnapshot:
    index_definitions = ["primary index", *sorted(check.EXPECTED_INDEX_DEFINITIONS)]
    indexes = [
        {
            "oid": 100 + index,
            "valid": True,
            "ready": True,
            "primary": index == 0,
            "unique": index == 0,
            "definition": definition,
            "parents": [],
        }
        for index, definition in enumerate(index_definitions)
    ]
    relation = {
        "oid": 1,
        "schema_name": "public",
        "name": "review_events",
        "kind": "p",
        "owner": "postgres",
        "rls": True,
        "force_rls": False,
        "is_partition": False,
        "key": "RANGE (created_at)",
        "key_is_timestamptz": True,
        "bounds": None,
        "parents": [],
        "has_children": True,
        "indexes": indexes,
        "constraints": ["PRIMARY KEY (id, created_at)"],
        "client_access": False,
        "public_access": False,
        "policy_count": 0,
    }
    children = []
    start = check.HISTORY_START
    while start < end:
        finish = check.add_months(start, 1)
        child = dict(
            relation,
            oid=len(children) + 2,
            name=f"review_events_{start:%Y_%m}",
            kind="r",
            is_partition=True,
            key=None,
            key_is_timestamptz=False,
            bounds=f"FOR VALUES FROM ('{start:%Y-%m-%d} 00:00:00+00') TO ('{finish:%Y-%m-%d} 00:00:00+00')",
            parents=[1],
            has_children=False,
            indexes=[dict(index, oid=1000 + len(children) * 3 + offset, parents=[index["oid"]]) for offset, index in enumerate(indexes)],
        )
        children.append(child)
        start = finish
    return check.CatalogSnapshot.model_validate(
        {
            "read_only": True,
            "isolation": "repeatable read",
            "timezone": "UTC",
            "parent": relation,
            "children": children,
            "security": {
                "roles": ["anon", "authenticated", "authenticator"],
                "unsafe_client_roles": False,
                "guard_enabled": True,
                "guard_identity_valid": True,
                "placeholder_present": True,
                "placeholder_owned_by_postgres": True,
                "placeholder_object_count": 0,
                "placeholder_access": False,
                "global_override_valid": True,
                "database_override_valid": True,
            },
        }
    )


def test_healthy_result_explains_scope_and_fixed_continuous_coverage_start() -> None:
    result = check.evaluate_catalog(healthy_snapshot(), AS_OF)
    assert result.status is check.Status.OK and result.exit_code == 0
    assert result.required_end == result.continuous_coverage_end == datetime(2027, 2, 1, tzinfo=UTC)
    assert result.missing_months == ()
    assert result.to_dict()["dataApiPlatformSwitch"] == "not_verified"


@pytest.mark.parametrize(
    ("timestamp", "expected"),
    [
        ("2026-12-31T23:59:59Z", "2027-04-01T00:00:00+00:00"),
        ("2027-01-01T09:00:00+09:00", "2027-05-01T00:00:00+00:00"),
        ("2028-02-29T23:59:59Z", "2028-06-01T00:00:00+00:00"),
        ("2026-11-01T00:00:00+09:00", "2027-02-01T00:00:00+00:00"),
    ],
)
def test_utc_calendar_horizon_handles_exact_boundaries_year_rollover_and_leap_day(timestamp: str, expected: str) -> None:
    as_of = datetime.fromisoformat(timestamp)
    result = check.evaluate_catalog(healthy_snapshot(datetime(2028, 7, 1, tzinfo=UTC)), as_of)
    assert result.status is check.Status.OK
    assert result.required_end == datetime.fromisoformat(expected)
    assert result.utc_as_of.utcoffset().total_seconds() == 0


@pytest.mark.parametrize(
    ("timestamp", "severity", "code"),
    [
        ("2026-11-02T00:00:00Z", check.Severity.WARNING, "COVERAGE_END_WITHIN_60_DAYS"),
        ("2026-12-02T00:00:00Z", check.Severity.ERROR, "COVERAGE_END_WITHIN_30_DAYS"),
        ("2026-12-25T00:00:00Z", check.Severity.CRITICAL, "COVERAGE_END_WITHIN_7_DAYS"),
    ],
)
def test_remaining_sixty_thirty_seven_day_thresholds(timestamp: str, severity: check.Severity, code: str) -> None:
    result = check.evaluate_catalog(healthy_snapshot(datetime(2027, 1, 1, tzinfo=UTC)), datetime.fromisoformat(timestamp))
    assert result.severity is severity
    assert code in {finding.code for finding in result.findings}
    assert result.exit_code != 0


@pytest.mark.parametrize("field", ["read_only", "isolation", "timezone", "parent", "roles", "guard_enabled", "placeholder_present"])
def test_missing_required_metadata_is_unknown(field: str) -> None:
    data = healthy_snapshot().model_dump()
    if field in {"read_only", "isolation", "timezone", "parent"}:
        data[field] = {"read_only": False, "isolation": "read committed", "timezone": "Asia/Seoul", "parent": None}[field]
    else:
        data["security"][field] = {"roles": [], "guard_enabled": None, "placeholder_present": False}[field]
    result = check.evaluate_catalog(check.CatalogSnapshot.model_validate(data), AS_OF)
    assert result.status is check.Status.UNKNOWN and result.exit_code == 3


@pytest.mark.parametrize(
    "value",
    [
        "",
        "sqlite:///private/password-secret",
        "postgresql://name:secret@host/db\nDROP TABLE users",
        "postgresql://name:secret@host/db?options=unsafe",
        "not-a-url-password-secret",
    ],
)
@pytest.mark.asyncio
async def test_invalid_or_malicious_database_url_never_connects_or_leaks(value: str, monkeypatch: pytest.MonkeyPatch) -> None:
    collector = AsyncMock(side_effect=AssertionError("No network is authorized"))
    monkeypatch.setattr(check, "_collect_snapshot", collector)
    result = await check.inspect_review_partitions(value, as_of=AS_OF)
    assert result.status is check.Status.UNKNOWN and result.exit_code == 3
    collector.assert_not_called()
    output = json.dumps(result.to_dict())
    assert "secret" not in output
    if value:
        assert value not in output


@pytest.mark.parametrize("scheme", ["postgres", "postgresql", "postgresql+asyncpg"])
def test_existing_postgresql_urls_normalize_without_losing_credentials_or_ssl(scheme: str) -> None:
    result = check.normalize_database_url(f"{scheme}://observer:encoded%40password@localhost:5432/test?sslmode=require")
    assert result.startswith("postgresql+asyncpg://observer:encoded%40password@localhost:5432/test")
    assert result.endswith("ssl=require")


@pytest.mark.asyncio
async def test_naive_and_out_of_range_timestamps_never_connect(monkeypatch: pytest.MonkeyPatch) -> None:
    collector = AsyncMock()
    monkeypatch.setattr(check, "_collect_snapshot", collector)
    for value in [datetime(2026, 10, 21), datetime(2026, 1, 1, tzinfo=UTC), datetime(9999, 12, 1, tzinfo=UTC)]:
        result = await check.inspect_review_partitions("postgresql://observer@localhost/test", as_of=value)
        assert result.status is check.Status.UNKNOWN
    collector.assert_not_called()


@pytest.mark.asyncio
async def test_driver_errors_are_sanitized(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(check, "_collect_snapshot", AsyncMock(side_effect=RuntimeError("postgres://user:secret@private-host/db")))
    result = await check.inspect_review_partitions("postgresql://observer@localhost/test", as_of=AS_OF)
    assert result.status is check.Status.UNKNOWN and result.exit_code == 3
    assert "secret" not in json.dumps(result.to_dict()) and "private-host" not in json.dumps(result.to_dict())
    monkeypatch.setattr(check, "_collect_snapshot", AsyncMock(return_value={"incomplete": "private-secret"}))
    malformed = await check.inspect_review_partitions("postgresql://observer@localhost/test", as_of=AS_OF)
    assert malformed.status is check.Status.UNKNOWN and malformed.exit_code == 3
    assert "private-secret" not in json.dumps(malformed.to_dict())


@pytest.mark.asyncio
async def test_cleanup_deadline_terminates_owned_connection_without_waiting_for_cancellation(monkeypatch: pytest.MonkeyPatch) -> None:
    terminated = asyncio.Event()

    async def stalled_cleanup() -> None:
        try:
            await asyncio.sleep(60)
        except asyncio.CancelledError:
            await terminated.wait()  # Simulate a driver ignoring graceful cancellation.

    driver = SimpleNamespace(terminate=terminated.set)
    transaction = SimpleNamespace(rollback=stalled_cleanup)
    connection = SimpleNamespace(
        begin=AsyncMock(return_value=transaction),
        close=AsyncMock(),
        sync_connection=SimpleNamespace(connection=SimpleNamespace(driver_connection=driver)),
    )
    engine = SimpleNamespace(connect=AsyncMock(return_value=connection), dispose=stalled_cleanup)
    monkeypatch.setattr(check, "create_async_engine", lambda *args, **kwargs: engine)
    monkeypatch.setattr(check, "configure_read_only_transaction", AsyncMock())
    monkeypatch.setattr(check, "read_catalog_snapshot", AsyncMock(return_value=healthy_snapshot()))
    monkeypatch.setattr(check, "CLEANUP_TIMEOUT_SECONDS", 0.01)
    monkeypatch.setattr(check, "OVERALL_TIMEOUT_SECONDS", 0.1)
    started = time.monotonic()
    result = await check.inspect_review_partitions("postgresql://observer@localhost/test", as_of=AS_OF)
    assert time.monotonic() - started < 0.2
    assert terminated.is_set() and result.status is check.Status.UNKNOWN
    await asyncio.sleep(0)
    assert not [task for task in asyncio.all_tasks() if task is not asyncio.current_task() and not task.done()]


@pytest.mark.parametrize(
    ("arguments", "exit_code", "code"),
    [
        ([], 3, "DATABASE_URL_MISSING"),
        (["--as-of", "2026-10-21"], 3, "ARGUMENTS_INVALID"),
        (["--unknown-password-secret"], 3, "ARGUMENTS_INVALID"),
    ],
)
def test_cli_without_env_or_with_invalid_arguments_does_not_load_dotenv_or_connect(arguments, exit_code, code, tmp_path) -> None:
    (tmp_path / ".env").write_text("DATABASE_URL=postgresql://private:secret@must-not-connect.invalid/database\n")
    environment = dict(os.environ)
    environment.pop("DATABASE_URL", None)
    result = subprocess.run(
        [sys.executable, str(CLI_PATH), *arguments], cwd=tmp_path, env=environment, capture_output=True, text=True, timeout=5, check=False
    )
    assert result.returncode == exit_code
    payload = json.loads(result.stdout)
    assert payload["status"] == "UNKNOWN" and payload["findings"][0]["code"] == code
    assert "secret" not in result.stdout + result.stderr and "must-not-connect" not in result.stdout + result.stderr


def test_cli_help_does_not_connect_even_with_malicious_database_url(monkeypatch, capsys) -> None:
    monkeypatch.setenv("DATABASE_URL", "postgresql://private:secret@must-not-connect.invalid/database")
    collector = AsyncMock(side_effect=AssertionError("Network forbidden"))
    monkeypatch.setattr(cli, "inspect_review_partitions", collector)
    with pytest.raises(SystemExit) as exited:
        cli.main(["--help"])
    assert exited.value.code == 0
    collector.assert_not_called()
    assert "DATABASE_URL" in capsys.readouterr().out


def test_import_has_no_application_configuration_or_session_side_effects(tmp_path) -> None:
    environment = dict(os.environ)
    environment.pop("DATABASE_URL", None)
    environment["PYTHONPATH"] = str(API_ROOT)
    program = (
        "import sys; import app.services.review_partition_check; assert not {'app.config','app.db.session','app.main'} & set(sys.modules)"
    )
    result = subprocess.run(
        [sys.executable, "-c", program], cwd=tmp_path, env=environment, capture_output=True, text=True, timeout=5, check=False
    )
    assert result.returncode == 0


@pytest.mark.asyncio
async def test_work_timeout_terminates_cancellation_ignoring_read_and_leaves_no_pending_task(monkeypatch) -> None:
    terminated = asyncio.Event()

    async def stalled_read(*_args):
        try:
            await asyncio.sleep(60)
        except asyncio.CancelledError:
            await terminated.wait()
        return healthy_snapshot()

    driver = SimpleNamespace(terminate=terminated.set)
    transaction = SimpleNamespace(rollback=AsyncMock())
    connection = SimpleNamespace(
        begin=AsyncMock(return_value=transaction),
        close=AsyncMock(),
        sync_connection=SimpleNamespace(connection=SimpleNamespace(driver_connection=driver)),
    )
    engine = SimpleNamespace(connect=AsyncMock(return_value=connection), dispose=AsyncMock())
    monkeypatch.setattr(check, "create_async_engine", lambda *args, **kwargs: engine)
    monkeypatch.setattr(check, "configure_read_only_transaction", AsyncMock())
    monkeypatch.setattr(check, "read_catalog_snapshot", stalled_read)
    monkeypatch.setattr(check, "CLEANUP_TIMEOUT_SECONDS", 0.01)
    monkeypatch.setattr(check, "OVERALL_TIMEOUT_SECONDS", 0.04)
    result = await check.inspect_review_partitions("postgresql://observer@localhost/test", as_of=AS_OF)
    assert terminated.is_set() and result.status is check.Status.UNKNOWN
    await asyncio.sleep(0)
    assert not [task for task in asyncio.all_tasks() if task is not asyncio.current_task() and not task.done()]


def test_asyncio_run_exits_after_cleanup_timeout_instead_of_hanging_at_shutdown(tmp_path) -> None:
    environment = dict(os.environ, PYTHONPATH=str(API_ROOT))
    program = """
import asyncio,json
from types import SimpleNamespace
from unittest.mock import AsyncMock
from datetime import UTC,datetime
from app.services import review_partition_check as check
from tests.test_review_partition_check import healthy_snapshot
async def main():
    released=asyncio.Event()
    async def blocked():
        try: await asyncio.sleep(60)
        except asyncio.CancelledError: await released.wait()
    driver=SimpleNamespace(terminate=released.set)
    connection=SimpleNamespace(begin=AsyncMock(return_value=SimpleNamespace(rollback=blocked)),close=AsyncMock(),
        sync_connection=SimpleNamespace(connection=SimpleNamespace(driver_connection=driver)))
    check.create_async_engine=lambda *args,**kwargs: SimpleNamespace(connect=AsyncMock(return_value=connection),dispose=blocked)
    check.configure_read_only_transaction=AsyncMock()
    check.read_catalog_snapshot=AsyncMock(return_value=healthy_snapshot())
    check.CLEANUP_TIMEOUT_SECONDS=.01
    check.OVERALL_TIMEOUT_SECONDS=.1
    result=await check.inspect_review_partitions('postgresql://observer@localhost/test',as_of=datetime(2026,10,21,tzinfo=UTC))
    await asyncio.sleep(0)
    assert released.is_set()
    assert not [task for task in asyncio.all_tasks() if task is not asyncio.current_task() and not task.done()]
    print(json.dumps(result.to_dict()))
asyncio.run(main())
"""
    result = subprocess.run(
        [sys.executable, "-c", program], cwd=tmp_path, env=environment, capture_output=True, text=True, timeout=3, check=False
    )
    assert result.returncode == 0, result.stderr
    assert json.loads(result.stdout)["status"] == "UNKNOWN"
