"""Explicit, acknowledged Sentry check-ins around the bounded catalog inspector.

This module never loads application settings, reads .env, configures a monitor,
changes the database, or submits exception/trace payloads. Cloud Run supplies
its outer task deadline; each synchronous HTTPS operation also has a timeout.
"""

from __future__ import annotations

import asyncio
import re
import time
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import TYPE_CHECKING, Any, cast
from urllib.parse import urlsplit

import httpx
from sentry_sdk import Client
from sentry_sdk.envelope import Envelope
from sentry_sdk.transport import Transport
from sentry_sdk.utils import Dsn

from app.services.review_partition_check import PartitionCheckResult, Status, inspect_review_partitions, unknown_result, validate_as_of

if TYPE_CHECKING:
    from sentry_sdk._types import Event, Hint

HTTP_TIMEOUT_SECONDS = 3.0
SAFE_LABEL = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]{0,63}\Z")
SAFE_SLUG = re.compile(r"[a-z0-9][a-z0-9_-]{0,63}\Z")
SENTRY_INGEST_HOST = re.compile(r"(?:o[0-9]+\.)?ingest(?:\.[a-z]{2})?\.sentry\.io\Z")
CHECKIN_FIELDS = {"type", "event_id", "check_in_id", "monitor_slug", "status", "duration", "environment", "timestamp"}


def _valid_dsn(value: str) -> bool:
    try:
        parsed = urlsplit(value)
        return bool(
            parsed.scheme == "https"
            and parsed.hostname
            and (parsed.hostname == "sentry.io" or SENTRY_INGEST_HOST.fullmatch(parsed.hostname))
            and parsed.port in {None, 443}
            and parsed.password is None
            and re.fullmatch(r"[0-9a-f]{32}", parsed.username or "")
            and re.fullmatch(r"/[1-9][0-9]*", parsed.path)
            and not parsed.query
            and not parsed.fragment
        )
    except (ValueError, UnicodeError):
        return False


def _checkin_only(event: Event, hint: Hint) -> Event | None:
    if event.get("type") != "check_in":
        return None
    return cast("Event", {key: value for key, value in event.items() if key in CHECKIN_FIELDS})


class AcknowledgedTransport(Transport):
    """Use the SDK envelope format, but do not mistake queue drain for delivery."""

    def __init__(self, dsn: str) -> None:
        super().__init__()
        auth = Dsn(dsn).to_auth(client="harukoto-partition-monitor/1")
        self.endpoint = auth.get_api_url()
        self.headers = {"X-Sentry-Auth": auth.to_header(), "Content-Type": "application/x-sentry-envelope"}
        self.http = httpx.Client(timeout=HTTP_TIMEOUT_SECONDS, follow_redirects=False, trust_env=False)
        self.accepted = 0
        self.failed = False

    def capture_envelope(self, envelope: Envelope) -> None:
        try:
            if not envelope.items or any(item.type != "check_in" for item in envelope.items):
                self.failed = True
                return
            # Do not read or log the response body, which is not needed for acknowledgment.
            with self.http.stream("POST", self.endpoint, headers=self.headers, content=envelope.serialize()) as response:
                if 200 <= response.status_code < 300:
                    self.accepted += 1
                else:
                    self.failed = True
        except Exception:
            self.failed = True

    def kill(self) -> None:
        self.http.close()


@dataclass(frozen=True)
class MonitorRunResult:
    partition_check: PartitionCheckResult
    monitor_slug: str | None
    environment: str | None
    check_in_id: str | None
    completion_status: str | None
    delivery_accepted: bool
    monitor_error: str | None = None
    cleanup_warning: bool = False

    @property
    def exit_code(self) -> int:
        return 3 if self.monitor_error else self.partition_check.exit_code

    def to_dict(self) -> dict[str, Any]:
        return {
            "status": Status.UNKNOWN.value if self.monitor_error else self.partition_check.status.value,
            "exitCode": self.exit_code,
            "partitionCheck": self.partition_check.to_dict(),
            "monitor": {
                "slug": self.monitor_slug,
                "environment": self.environment,
                "checkInId": self.check_in_id,
                "completionStatus": self.completion_status,
                "delivery": "accepted" if self.delivery_accepted else "not_confirmed",
                "error": self.monitor_error,
                "cleanupWarning": "HTTP_CLEANUP_FAILED" if self.cleanup_warning else None,
            },
        }


def monitor_configuration_error(code: str = "MONITOR_CONFIGURATION_INVALID") -> MonitorRunResult:
    result = unknown_result(datetime.now(UTC), code, "Monitor configuration must be explicit and valid before execution.")
    return MonitorRunResult(result, None, None, None, None, False, code)


def run_partition_monitor(
    database_url: str,
    sentry_dsn: str,
    monitor_slug: str,
    *,
    environment: str = "production",
    as_of: datetime | None = None,
) -> MonitorRunResult:
    try:
        timestamp = validate_as_of(as_of or datetime.now(UTC))
    except (ValueError, TypeError, OverflowError):
        return monitor_configuration_error()
    if not _valid_dsn(sentry_dsn) or not SAFE_SLUG.fullmatch(monitor_slug) or not SAFE_LABEL.fullmatch(environment):
        return monitor_configuration_error()

    check_in_id = uuid.uuid4().hex
    started = time.monotonic()
    transport: AcknowledgedTransport | None = None
    client: Client | None = None
    delivery_accepted = False
    monitor_error = None
    cleanup_warning = False
    completion_status = "error"
    result = unknown_result(timestamp, "MONITOR_EXECUTION_FAILED", "The monitor could not complete its inspection.")
    try:
        transport = AcknowledgedTransport(sentry_dsn)
        client = Client(
            dsn=sentry_dsn,
            transport=transport,
            default_integrations=False,
            auto_enabling_integrations=False,
            auto_session_tracking=False,
            send_default_pii=False,
            send_client_reports=False,
            enable_backpressure_handling=False,
            enable_logs=False,
            traces_sample_rate=0.0,
            profiles_sample_rate=0.0,
            max_breadcrumbs=0,
            attach_stacktrace=False,
            include_local_variables=False,
            include_source_context=False,
            debug=False,
            spotlight=False,
            server_name="partition-monitor",
            release="",
            environment=environment,
            shutdown_timeout=0,
            before_send=_checkin_only,
        )
        start_event: Event = {
            "type": "check_in",
            "check_in_id": check_in_id,
            "monitor_slug": monitor_slug,
            "status": "in_progress",
            "environment": environment,
        }
        client.capture_event(start_event)
        start_accepted = transport.accepted == 1 and not transport.failed
        try:
            result = asyncio.run(inspect_review_partitions(database_url, as_of=timestamp))
        except (Exception, asyncio.CancelledError, KeyboardInterrupt):
            result = unknown_result(timestamp, "MONITOR_EXECUTION_FAILED", "The monitor could not complete its inspection.")
        completion_status = "ok" if result.status == Status.OK and start_accepted else "error"
        finish_event: Event = {
            "type": "check_in",
            "check_in_id": check_in_id,
            "monitor_slug": monitor_slug,
            "status": completion_status,
            "environment": environment,
            "duration": time.monotonic() - started,
        }
        client.capture_event(finish_event)
        delivery_accepted = transport.accepted == 2 and not transport.failed
        if not delivery_accepted:
            monitor_error = "MONITOR_DELIVERY_FAILED"
    except (Exception, asyncio.CancelledError, KeyboardInterrupt):
        monitor_error = "MONITOR_EXECUTION_FAILED"
    finally:
        try:
            if client is not None:
                # Delivery is synchronous: this only closes SDK resources, without a background queue.
                client.close(timeout=0)
            elif transport is not None:
                transport.kill()
        except (Exception, asyncio.CancelledError, KeyboardInterrupt):
            # Both acknowledgments already establish completion. A one-shot process
            # releases this HTTP resource on exit; do not turn an accepted OK into
            # an unalerted job failure. Inspector/DB cleanup failures remain UNKNOWN.
            cleanup_warning = True
            if not delivery_accepted:
                monitor_error = monitor_error or "MONITOR_CLEANUP_FAILED"
    return MonitorRunResult(
        result, monitor_slug, environment, check_in_id, completion_status, delivery_accepted, monitor_error, cleanup_warning
    )
