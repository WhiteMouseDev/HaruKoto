from __future__ import annotations

import asyncio
import json
import os
import signal
import subprocess
import sys
import time
from dataclasses import replace
from pathlib import Path
from unittest.mock import AsyncMock

import httpx
import pytest
import sentry_sdk

from app.services import review_partition_check as check
from app.services import review_partition_monitor as monitor
from scripts import monitor_review_event_partitions as cli
from tests.test_review_partition_check import AS_OF, healthy_snapshot

API_ROOT = Path(__file__).resolve().parents[1]
DSN = "https://" + "a" * 32 + "@o123.ingest.us.sentry.io/123"
SLUG = "harukoto-review-partitions"


@pytest.fixture
def sentry_transport(monkeypatch):
    requests = []
    payloads = []
    responses = []
    client_options = []
    real_client = httpx.Client

    def receive(request):
        requests.append(request)
        lines = request.content.splitlines()
        assert json.loads(lines[1])["type"] == "check_in"
        payloads.append(json.loads(lines[2]))
        response = responses.pop(0) if responses else 200
        if isinstance(response, Exception):
            raise response
        return httpx.Response(response)

    def create_client(**options):
        client_options.append(options)
        return real_client(transport=httpx.MockTransport(receive), **options)

    monkeypatch.setattr(monitor.httpx, "Client", create_client)
    return requests, payloads, responses, client_options


def test_real_sdk_sends_paired_accepted_checkins_before_and_after_catalog_only_inspection(monkeypatch, sentry_transport):
    requests, payloads, _, options = sentry_transport
    original_client = sentry_sdk.get_global_scope().client

    async def inspect(database_url, *, as_of):
        assert len(requests) == 1 and payloads[0]["status"] == "in_progress"
        assert database_url == "postgresql://private:secret@database.invalid/app"
        assert as_of == AS_OF
        return check.evaluate_catalog(healthy_snapshot(), as_of)

    monkeypatch.setattr(monitor, "inspect_review_partitions", inspect)
    result = monitor.run_partition_monitor("postgresql://private:secret@database.invalid/app", DSN, SLUG, as_of=AS_OF)
    assert result.exit_code == 0 and result.delivery_accepted
    assert result.partition_check.status == check.Status.OK
    assert [event["status"] for event in payloads] == ["in_progress", "ok"]
    assert {event["check_in_id"] for event in payloads} == {result.check_in_id}
    assert all(set(event) <= monitor.CHECKIN_FIELDS and "monitor_config" not in event for event in payloads)
    assert all(request.url == "https://o123.ingest.us.sentry.io/api/123/envelope/" for request in requests)
    assert all("X-Sentry-Auth" in request.headers and "Cookie" not in request.headers for request in requests)
    assert options == [{"timeout": 3.0, "follow_redirects": False, "trust_env": False}]
    assert sentry_sdk.get_global_scope().client is original_client
    serialized = json.dumps(result.to_dict()) + "".join(request.content.decode() for request in requests)
    assert "private" not in serialized and "secret" not in serialized and "database.invalid" not in serialized


@pytest.mark.parametrize("status", list(check.Status))
def test_every_non_ok_result_reports_monitor_error_and_preserves_inspector_exit(monkeypatch, sentry_transport, status):
    result = replace(check.evaluate_catalog(healthy_snapshot(), AS_OF), status=status)
    inspect = AsyncMock(return_value=result)
    monkeypatch.setattr(monitor, "inspect_review_partitions", inspect)
    report = monitor.run_partition_monitor("postgresql://observer@database/app", DSN, SLUG, as_of=AS_OF)
    assert report.exit_code == result.exit_code and report.monitor_error is None
    assert report.completion_status == ("ok" if status == check.Status.OK else "error")
    assert sentry_transport[1][-1]["status"] == report.completion_status
    assert report.to_dict()["partitionCheck"] == result.to_dict()
    inspect.assert_awaited_once()


@pytest.mark.parametrize("failure", [500, 429, 302, httpx.ConnectError("private password secret"), httpx.ReadTimeout("private secret")])
@pytest.mark.parametrize("position", [0, 1])
def test_delivery_rejection_timeout_or_redirect_fails_closed_without_exposing_details(monkeypatch, sentry_transport, failure, position):
    responses = sentry_transport[2]
    responses.extend([200, failure] if position else [failure, 200])
    monkeypatch.setattr(monitor, "inspect_review_partitions", AsyncMock(return_value=check.evaluate_catalog(healthy_snapshot(), AS_OF)))
    report = monitor.run_partition_monitor("postgresql://private:secret@database/app", DSN, SLUG, as_of=AS_OF)
    assert report.exit_code == 3 and report.to_dict()["status"] == "UNKNOWN"
    assert report.monitor_error == "MONITOR_DELIVERY_FAILED" and not report.delivery_accepted
    assert report.partition_check.status == check.Status.OK
    if position == 0:
        assert sentry_transport[1][-1]["status"] == "error"
    assert "secret" not in json.dumps(report.to_dict())


@pytest.mark.parametrize("failure", [RuntimeError("private password secret"), asyncio.CancelledError(), KeyboardInterrupt()])
def test_inspection_exception_or_cancel_produces_acknowledged_error_not_success(monkeypatch, sentry_transport, failure):
    monkeypatch.setattr(monitor, "inspect_review_partitions", AsyncMock(side_effect=failure))
    report = monitor.run_partition_monitor("postgresql://observer@database/app", DSN, SLUG, as_of=AS_OF)
    assert report.exit_code == 3 and report.partition_check.status == check.Status.UNKNOWN
    assert report.delivery_accepted and report.completion_status == "error"
    assert [event["status"] for event in sentry_transport[1]] == ["in_progress", "error"]
    assert "secret" not in json.dumps(report.to_dict())


@pytest.mark.parametrize("failure", [RuntimeError("private secret"), asyncio.CancelledError(), KeyboardInterrupt()])
def test_http_cleanup_warning_after_both_acknowledgments_does_not_invent_an_unalerted_job_failure(monkeypatch, sentry_transport, failure):
    monkeypatch.setattr(monitor, "inspect_review_partitions", AsyncMock(return_value=check.evaluate_catalog(healthy_snapshot(), AS_OF)))
    monkeypatch.setattr(monitor.AcknowledgedTransport, "kill", lambda self: (_ for _ in ()).throw(failure))
    report = monitor.run_partition_monitor("postgresql://observer@database/app", DSN, SLUG, as_of=AS_OF)
    assert report.exit_code == 0 and report.monitor_error is None
    assert report.delivery_accepted and report.to_dict()["monitor"]["cleanupWarning"] == "HTTP_CLEANUP_FAILED"
    assert [event["status"] for event in sentry_transport[1]] == ["in_progress", "ok"]
    assert "secret" not in json.dumps(report.to_dict())


@pytest.mark.parametrize(
    "dsn",
    [
        "",
        "https://private:secret@sentry.io/123",
        "http://" + "a" * 32 + "@o123.ingest.sentry.io/123",
        "https://" + "a" * 32 + "@o123.ingest.sentry.io.evil.invalid/123",
        "https://" + "a" * 32 + "@127.0.0.1/123",
        DSN + "?secret=value",
        DSN + "#private",
        DSN.replace("/123", "/path/123"),
        DSN.replace(".io/", ".io:444/"),
    ],
)
def test_invalid_or_non_sentry_dsn_never_connects_or_inspects(monkeypatch, dsn):
    collector = AsyncMock(side_effect=AssertionError("Network forbidden"))
    monkeypatch.setattr(monitor, "inspect_review_partitions", collector)
    monkeypatch.setattr(monitor, "AcknowledgedTransport", lambda *_: pytest.fail("Transport must not initialize"))
    report = monitor.run_partition_monitor("postgresql://observer@database/app", dsn, SLUG, as_of=AS_OF)
    assert report.exit_code == 3 and report.monitor_error == "MONITOR_CONFIGURATION_INVALID"
    collector.assert_not_called()
    assert "secret" not in json.dumps(report.to_dict())


@pytest.mark.parametrize(("slug", "environment"), [("PRIVATE secret", "production"), (SLUG, "private secret")])
def test_invalid_labels_fail_before_network(monkeypatch, slug, environment):
    monkeypatch.setattr(monitor, "AcknowledgedTransport", lambda *_: pytest.fail("Transport must not initialize"))
    report = monitor.run_partition_monitor("unused", DSN, slug, environment=environment, as_of=AS_OF)
    assert report.exit_code == 3 and "secret" not in json.dumps(report.to_dict())


def test_future_rehearsal_uses_real_inspection_result_and_reports_advisory_not_fake_failure(monkeypatch, sentry_transport):
    future = AS_OF.replace(month=11, day=1)
    result = check.evaluate_catalog(healthy_snapshot(), future)
    assert result.status == check.Status.ADVISORY and result.missing_months == ("2027-02",)
    inspect = AsyncMock(return_value=result)
    monkeypatch.setattr(monitor, "inspect_review_partitions", inspect)
    report = monitor.run_partition_monitor("unused", DSN, SLUG + "-test", as_of=future)
    assert report.exit_code == 1 and report.completion_status == "error"
    assert report.to_dict()["partitionCheck"]["utcAsOf"] == "2026-11-01T00:00:00Z"
    inspect.assert_awaited_once_with("unused", as_of=future)


@pytest.mark.parametrize("arguments", [[], ["--unknown-private-secret"], ["--monitor-slug", SLUG, "--as-of", "not-a-date"]])
def test_cli_invalid_arguments_do_not_load_dotenv_or_connect(arguments, tmp_path):
    (tmp_path / ".env").write_text("DATABASE_URL=postgresql://private:secret@database.invalid/app\nSENTRY_DSN=" + DSN)
    environment = dict(os.environ)
    environment.pop("DATABASE_URL", None)
    environment.pop("SENTRY_DSN", None)
    result = subprocess.run(
        [sys.executable, str(API_ROOT / "scripts/monitor_review_event_partitions.py"), *arguments],
        cwd=tmp_path,
        env=environment,
        capture_output=True,
        text=True,
        timeout=5,
        check=False,
    )
    assert result.returncode == 3 and json.loads(result.stdout)["status"] == "UNKNOWN"
    assert "secret" not in result.stdout + result.stderr and not result.stderr


def test_cli_help_is_side_effect_free(monkeypatch, capsys):
    monkeypatch.setattr(cli, "run_partition_monitor", lambda *_args, **_kwargs: pytest.fail("No execution"))
    with pytest.raises(SystemExit) as exited:
        cli.main(["--help"])
    assert exited.value.code == 0 and "SENTRY_DSN" in capsys.readouterr().out


def test_import_does_not_initialize_application_or_global_sentry_client(tmp_path):
    environment = dict(os.environ, PYTHONPATH=str(API_ROOT), SENTRY_DSN=DSN)
    program = (
        "import sys,sentry_sdk; initial=sentry_sdk.get_global_scope().client; import app.services.review_partition_monitor; "
        "assert sentry_sdk.get_global_scope().client is initial; assert not {'app.config','app.db.session','app.main'} & set(sys.modules)"
    )
    result = subprocess.run([sys.executable, "-c", program], cwd=tmp_path, env=environment, capture_output=True, text=True, timeout=5)
    assert result.returncode == 0 and not result.stdout + result.stderr


@pytest.mark.skipif(not hasattr(signal, "SIGTERM"), reason="POSIX process signal required")
def test_cli_sigterm_acknowledges_error_and_exits_without_leaking_credentials(tmp_path):
    ready = tmp_path / "started"
    events = tmp_path / "events"
    program = f"""
import asyncio,json
from pathlib import Path
from sentry_sdk.transport import Transport
from app.services import review_partition_monitor as monitor
from scripts.monitor_review_event_partitions import main
class FakeTransport(Transport):
    accepted=0
    failed=False
    def __init__(self,dsn): super().__init__()
    def capture_envelope(self,envelope):
        self.accepted+=1
        with Path({str(events)!r}).open('a') as out: out.write(json.loads(envelope.items[0].get_bytes())['status']+'\\n')
async def inspect(*args,**kwargs):
    Path({str(ready)!r}).write_text('ready')
    await asyncio.sleep(100)
monitor.AcknowledgedTransport=FakeTransport
monitor.inspect_review_partitions=inspect
raise SystemExit(main(['--monitor-slug',{SLUG!r}]))
"""
    environment = dict(
        os.environ, PYTHONPATH=str(API_ROOT), DATABASE_URL="postgresql://private:secret@database.invalid/app", SENTRY_DSN=DSN
    )
    process = subprocess.Popen(
        [sys.executable, "-c", program], cwd=tmp_path, env=environment, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
    )
    try:
        deadline = time.monotonic() + 5
        while not ready.exists() and process.poll() is None and time.monotonic() < deadline:
            time.sleep(0.02)
        assert ready.exists()
        process.terminate()
        stdout, stderr = process.communicate(timeout=5)
        assert process.returncode == 3 and not stderr
        assert json.loads(stdout)["partitionCheck"]["status"] == "UNKNOWN"
        assert events.read_text().splitlines() == ["in_progress", "error"]
        assert "secret" not in stdout + stderr
    finally:
        if process.poll() is None:
            process.kill()
            process.wait(timeout=5)


def test_cli_enforces_60_second_outer_deadline_and_restores_signal_state(monkeypatch, capsys):
    timers = []
    handlers = []
    sentinel = object()
    monkeypatch.setattr(cli.signal, "signal", lambda signum, handler: handlers.append((signum, handler)) or sentinel)
    monkeypatch.setattr(cli.signal, "setitimer", lambda *args: timers.append(args) or (0.0, 0.0))
    monkeypatch.setattr(cli, "run_partition_monitor", lambda *_args, **_kwargs: monitor.monitor_configuration_error())
    assert cli.main(["--monitor-slug", SLUG]) == 3
    assert timers == [(signal.ITIMER_REAL, 60), (signal.ITIMER_REAL, 0), (signal.ITIMER_REAL, 0.0, 0.0)]
    assert handlers == [
        (signal.SIGALRM, cli._interrupt),
        (signal.SIGTERM, cli._interrupt),
        (signal.SIGALRM, sentinel),
        (signal.SIGTERM, sentinel),
    ]
    assert json.loads(capsys.readouterr().out)["status"] == "UNKNOWN"


def test_sdk_drop_is_not_mistaken_for_acknowledged_delivery(monkeypatch, sentry_transport):
    monkeypatch.setattr(monitor, "inspect_review_partitions", AsyncMock(return_value=check.evaluate_catalog(healthy_snapshot(), AS_OF)))
    monkeypatch.setattr(monitor.Client, "capture_event", lambda *_args, **_kwargs: None)
    report = monitor.run_partition_monitor("unused", DSN, SLUG, as_of=AS_OF)
    assert report.exit_code == 3 and report.monitor_error == "MONITOR_DELIVERY_FAILED"
    assert not sentry_transport[0] and not report.delivery_accepted
