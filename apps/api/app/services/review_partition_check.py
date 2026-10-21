"""Bounded catalog-only inspection; no application settings, data or DDL imports.

Coverage starts at March 2026. The rolling horizon is a minimum: additional
valid monthly partitions are allowed. Platform Data API enablement cannot be
observed through PostgreSQL catalogs and is always reported as not verified.
"""

from __future__ import annotations

import asyncio
import math
import re
from collections.abc import Awaitable
from contextlib import suppress
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from enum import StrEnum
from typing import Any

from pydantic import BaseModel, ConfigDict
from sqlalchemy import text
from sqlalchemy.engine import make_url
from sqlalchemy.ext.asyncio import AsyncConnection, AsyncTransaction, create_async_engine
from sqlalchemy.pool import NullPool

CONNECT_TIMEOUT_SECONDS = 3
STATEMENT_TIMEOUT_MS = 5000
LOCK_TIMEOUT_MS = 1000
OVERALL_TIMEOUT_SECONDS = 12
MAX_MONTHS = 1200
HISTORY_START = datetime(2026, 3, 1, tzinfo=UTC)
REQUIRED_ROLES = {"anon", "authenticated", "authenticator"}
EXPECTED_INDEX_DEFINITIONS = {
    "CREATE INDEX idx_review_events_user ON ONLY public.review_events USING btree (user_id, created_at DESC)",
    "CREATE INDEX idx_review_events_user_day ON ONLY public.review_events USING btree (user_id, reviewed_on) WHERE (is_new_card = true)",
}


class Status(StrEnum):
    OK = "OK"
    ADVISORY = "ADVISORY"
    ERROR = "ERROR"
    UNKNOWN = "UNKNOWN"


class Severity(StrEnum):
    INFO = "INFO"
    WARNING = "WARNING"
    ERROR = "ERROR"
    CRITICAL = "CRITICAL"
    UNKNOWN = "UNKNOWN"


@dataclass(frozen=True)
class Finding:
    code: str
    severity: Severity
    message: str
    month: str | None = None


@dataclass(frozen=True)
class PartitionCheckResult:
    status: Status
    severity: Severity
    utc_as_of: datetime
    required_end: datetime | None
    continuous_coverage_end: datetime | None
    missing_months: tuple[str, ...]
    remaining_days: int | None
    findings: tuple[Finding, ...]

    @property
    def exit_code(self) -> int:
        return {Status.OK: 0, Status.ADVISORY: 1, Status.ERROR: 2, Status.UNKNOWN: 3}[self.status]

    def to_dict(self) -> dict[str, Any]:
        def stamp(value: datetime | None) -> str | None:
            return value.astimezone(UTC).isoformat().replace("+00:00", "Z") if value is not None else None

        return {
            "status": self.status.value,
            "severity": self.severity.value,
            "utcAsOf": stamp(self.utc_as_of),
            "requiredEnd": stamp(self.required_end),
            "continuousCoverageEnd": stamp(self.continuous_coverage_end),
            "missingMonths": list(self.missing_months),
            "remainingDays": self.remaining_days,
            "dataApiPlatformSwitch": "not_verified",
            "findings": [
                {"code": finding.code, "severity": finding.severity.value, "message": finding.message, "month": finding.month}
                for finding in self.findings
            ],
        }


class CatalogModel(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)


class CatalogIndex(CatalogModel):
    oid: int
    valid: bool
    ready: bool
    primary: bool
    unique: bool
    definition: str
    parents: list[int]


class CatalogRelation(CatalogModel):
    oid: int
    schema_name: str
    name: str
    kind: str
    owner: str
    rls: bool
    force_rls: bool
    is_partition: bool
    key: str | None
    key_is_timestamptz: bool
    bounds: str | None
    parents: list[int]
    has_children: bool
    indexes: list[CatalogIndex]
    constraints: list[str]
    client_access: bool
    public_access: bool
    policy_count: int


class CatalogSecurity(CatalogModel):
    roles: list[str]
    unsafe_client_roles: bool
    guard_enabled: bool | None
    guard_identity_valid: bool | None
    placeholder_present: bool
    placeholder_owned_by_postgres: bool
    placeholder_object_count: int
    placeholder_access: bool
    global_override_valid: bool
    database_override_valid: bool


class CatalogSnapshot(CatalogModel):
    read_only: bool
    isolation: str
    timezone: str
    parent: CatalogRelation | None
    children: list[CatalogRelation]
    security: CatalogSecurity


# Only pg_catalog relations are read. The name-pattern branch includes detached
# or wrong-schema names; the recursive branch includes renamed/subpartitioned
# attached objects. Never filter attached children to public before inspection.
CATALOG_SQL = """
WITH RECURSIVE target AS (
    SELECT c.oid FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relname='review_events'
), tree(oid,depth) AS (
    SELECT oid,0 FROM target
    UNION ALL
    SELECT i.inhrelid,t.depth+1 FROM tree t JOIN pg_catalog.pg_inherits i ON i.inhparent=t.oid WHERE t.depth<8
), candidates AS (
    SELECT c.* FROM pg_catalog.pg_class c
    WHERE c.oid IN (SELECT oid FROM tree) OR c.relname ~ '^review_events_[0-9]{4}_[0-9]{2}$'
    ORDER BY c.oid LIMIT 1201
), metadata AS (
    SELECT c.oid,jsonb_build_object(
      'oid',c.oid::bigint,'schema_name',n.nspname,'name',c.relname,'kind',c.relkind,'owner',pg_catalog.pg_get_userbyid(c.relowner),
      'rls',c.relrowsecurity,'force_rls',c.relforcerowsecurity,'is_partition',c.relispartition,
      'key',CASE WHEN c.relkind='p' THEN pg_catalog.pg_get_partkeydef(c.oid) ELSE NULL END,
      'key_is_timestamptz',EXISTS(
        SELECT 1 FROM pg_catalog.pg_partitioned_table p JOIN pg_catalog.pg_attribute a
          ON a.attrelid=p.partrelid AND p.partattrs::text=a.attnum::text
        WHERE p.partrelid=c.oid AND p.partstrat='r' AND p.partnatts=1 AND p.partexprs IS NULL
          AND a.attname='created_at' AND a.atttypid='timestamp with time zone'::regtype AND a.attnotnull AND NOT a.attisdropped
      ),
      'bounds',pg_catalog.pg_get_expr(c.relpartbound,c.oid),
      'parents',(SELECT COALESCE(jsonb_agg(i.inhparent::bigint ORDER BY i.inhparent),'[]'::jsonb)
                 FROM pg_catalog.pg_inherits i WHERE i.inhrelid=c.oid),
      'has_children',EXISTS(SELECT 1 FROM pg_catalog.pg_inherits i WHERE i.inhparent=c.oid),
      'indexes',(SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'oid',ix.indexrelid::bigint,'valid',ix.indisvalid,'ready',ix.indisready,'primary',ix.indisprimary,'unique',ix.indisunique,
        'definition',pg_catalog.pg_get_indexdef(ix.indexrelid),
        'parents',(SELECT COALESCE(jsonb_agg(ii.inhparent::bigint ORDER BY ii.inhparent),'[]'::jsonb)
                   FROM pg_catalog.pg_inherits ii WHERE ii.inhrelid=ix.indexrelid)
      ) ORDER BY ix.indexrelid),'[]'::jsonb) FROM pg_catalog.pg_index ix WHERE ix.indrelid=c.oid),
      'constraints',(SELECT COALESCE(jsonb_agg(pg_catalog.pg_get_constraintdef(k.oid) ORDER BY k.oid),'[]'::jsonb)
                     FROM pg_catalog.pg_constraint k WHERE k.conrelid=c.oid),
      'public_access',EXISTS(
        SELECT 1 FROM pg_catalog.aclexplode(COALESCE(c.relacl,pg_catalog.acldefault('r',c.relowner))) a WHERE a.grantee=0
      ) OR EXISTS(
        SELECT 1 FROM pg_catalog.pg_attribute at,LATERAL pg_catalog.aclexplode(at.attacl) a
        WHERE at.attrelid=c.oid AND at.attnum>0 AND NOT at.attisdropped AND a.grantee=0
      ),
      'client_access',CASE WHEN c.relkind IN ('r','p','v','m','f') THEN EXISTS(
        SELECT 1 FROM pg_catalog.pg_roles r WHERE r.rolname IN ('anon','authenticated') AND (
          pg_catalog.has_table_privilege(r.oid,c.oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') OR
          pg_catalog.has_any_column_privilege(r.oid,c.oid,'SELECT,INSERT,UPDATE,REFERENCES')
        )
      ) ELSE true END,
      'policy_count',(SELECT count(*) FROM pg_catalog.pg_policy p WHERE p.polrelid=c.oid)
    ) value FROM candidates c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
), placeholder AS (
    SELECT * FROM pg_catalog.pg_namespace WHERE nspname='pgrst_no_exposed_schemas'
), guard AS (
    SELECT e.*,p.proowner,p.prosecdef,p.proname,p.proconfig,n.nspname FROM pg_catalog.pg_event_trigger e
    JOIN pg_catalog.pg_proc p ON p.oid=e.evtfoid JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace
    WHERE e.evtname='zz_harukoto_secure_public_ddl'
)
SELECT jsonb_build_object(
  'read_only',pg_catalog.current_setting('transaction_read_only')='on',
  'isolation',pg_catalog.current_setting('transaction_isolation'),'timezone',pg_catalog.current_setting('TimeZone'),
  'parent',(SELECT value FROM metadata WHERE oid IN (SELECT oid FROM target)),
  'children',(SELECT COALESCE(jsonb_agg(value ORDER BY oid),'[]'::jsonb) FROM metadata WHERE oid NOT IN (SELECT oid FROM target)),
  'security',jsonb_build_object(
    'roles',(SELECT COALESCE(jsonb_agg(rolname ORDER BY rolname),'[]'::jsonb) FROM pg_catalog.pg_roles
             WHERE rolname IN ('anon','authenticated','authenticator')),
    'unsafe_client_roles',EXISTS(SELECT 1 FROM pg_catalog.pg_roles
         WHERE rolname IN ('anon','authenticated') AND (rolsuper OR rolbypassrls)),
    'guard_enabled',(SELECT evtenabled IN ('O','A') FROM guard),
    'guard_identity_valid',(SELECT nspname='public' AND proname='harukoto_secure_public_ddl'
         AND proowner='postgres'::regrole AND prosecdef AND evtevent='ddl_command_end'
         AND COALESCE(proconfig @> ARRAY['search_path=pg_catalog'],false)
         AND (evttags IS NULL OR evttags @> ARRAY['CREATE TABLE']) FROM guard),
    'placeholder_present',EXISTS(SELECT 1 FROM placeholder),
    'placeholder_owned_by_postgres',EXISTS(SELECT 1 FROM placeholder WHERE nspowner='postgres'::regrole),
    'placeholder_object_count',(SELECT count(*) FROM pg_catalog.pg_depend d
         WHERE d.refclassid='pg_catalog.pg_namespace'::regclass AND d.refobjid IN (SELECT oid FROM placeholder)),
    'placeholder_access',EXISTS(
      SELECT 1 FROM placeholder n,LATERAL pg_catalog.aclexplode(COALESCE(n.nspacl,pg_catalog.acldefault('n',n.nspowner))) a
      WHERE a.grantee=0
    ) OR EXISTS(
      SELECT 1 FROM placeholder n CROSS JOIN pg_catalog.pg_roles r
      WHERE r.rolname IN ('anon','authenticated','authenticator') AND pg_catalog.has_schema_privilege(r.oid,n.oid,'USAGE,CREATE')
    ),
    'global_override_valid',EXISTS(
      SELECT 1 FROM pg_catalog.pg_roles r,LATERAL unnest(r.rolconfig) setting
      WHERE r.rolname='authenticator' AND setting='pgrst.db_schemas=pgrst_no_exposed_schemas'
    ),
    'database_override_valid',NOT EXISTS(
      SELECT 1 FROM pg_catalog.pg_db_role_setting d JOIN pg_catalog.pg_roles r ON r.oid=d.setrole,
      LATERAL unnest(d.setconfig) setting
      WHERE r.rolname='authenticator' AND d.setdatabase=(SELECT oid FROM pg_catalog.pg_database
            WHERE datname=pg_catalog.current_database())
        AND setting LIKE 'pgrst.db_schemas=%' AND setting<>'pgrst.db_schemas=pgrst_no_exposed_schemas'
    )
  )
)
"""


def month_start(value: datetime) -> datetime:
    if value.tzinfo is None or value.utcoffset() is None:
        raise ValueError("An aware timestamp is required")
    value = value.astimezone(UTC)
    return datetime(value.year, value.month, 1, tzinfo=UTC)


def add_months(value: datetime, months: int) -> datetime:
    number = value.year * 12 + value.month - 1 + months
    year, month = divmod(number, 12)
    return datetime(year, month + 1, 1, tzinfo=UTC)


def validate_as_of(value: datetime) -> datetime:
    start = month_start(value)
    offset = (start.year - HISTORY_START.year) * 12 + start.month - HISTORY_START.month
    if not 0 <= offset <= MAX_MONTHS - 4:
        raise ValueError("Timestamp outside bounded inspection range")
    return value.astimezone(UTC)


def unknown_result(as_of: datetime, code: str, message: str) -> PartitionCheckResult:
    return PartitionCheckResult(
        Status.UNKNOWN, Severity.UNKNOWN, as_of.astimezone(UTC), None, None, (), None, (Finding(code, Severity.UNKNOWN, message),)
    )


def evaluate_catalog(snapshot: CatalogSnapshot, as_of: datetime) -> PartitionCheckResult:
    as_of = validate_as_of(as_of)
    required_end = add_months(month_start(as_of), 4)
    if not snapshot.read_only or snapshot.isolation != "repeatable read" or snapshot.timezone != "UTC":
        return unknown_result(as_of, "TRANSACTION_UNVERIFIED", "Read-only, repeatable-read UTC inspection could not be verified.")
    if len(snapshot.children) >= MAX_MONTHS:
        return unknown_result(as_of, "CATALOG_LIMIT", "Catalog inventory exceeds the bounded inspection limit.")
    if not REQUIRED_ROLES.issubset(snapshot.security.roles):
        return unknown_result(as_of, "SECURITY_METADATA_MISSING", "Required client-role security metadata is missing.")
    if snapshot.parent is None:
        return unknown_result(as_of, "PARENT_MISSING", "The expected qualified review-event parent is missing.")
    if snapshot.security.guard_enabled is None or snapshot.security.guard_identity_valid is None:
        return unknown_result(as_of, "GUARD_MISSING", "The required DDL security guard is missing.")
    if not snapshot.security.placeholder_present:
        return unknown_result(as_of, "PLACEHOLDER_MISSING", "The required empty PostgREST schema is missing.")
    findings: list[Finding] = []

    def error(code: str, message: str, month: str | None = None) -> None:
        finding = Finding(code, Severity.ERROR, message, month)
        if finding not in findings:
            findings.append(finding)

    security = snapshot.security
    if security.unsafe_client_roles:
        error("UNSAFE_CLIENT_ROLE", "A client role has superuser or RLS-bypass capabilities.")
    if not security.guard_enabled or not security.guard_identity_valid:
        error("GUARD_INVALID", "The DDL security guard is disabled or has unexpected identity.")
    if not security.placeholder_owned_by_postgres or security.placeholder_object_count or security.placeholder_access:
        error("PLACEHOLDER_INVALID", "The PostgREST placeholder must be empty, postgres-owned and client-inaccessible.")
    if not security.global_override_valid or not security.database_override_valid:
        error("AUTHENTICATOR_OVERRIDE_INVALID", "The global or database-specific PostgREST schema override is unexpected.")
    parent = snapshot.parent
    if (
        parent.schema_name != "public"
        or parent.name != "review_events"
        or parent.kind != "p"
        or parent.is_partition
        or parent.parents
        or parent.key != "RANGE (created_at)"
        or not parent.key_is_timestamptz
    ):
        error("PARENT_INVALID", "The review-event parent does not have the expected identity and timestamptz range key.")
    parent_indexes = {index.oid: index for index in parent.indexes}
    if (
        len(parent.indexes) != 3
        or parent.constraints != ["PRIMARY KEY (id, created_at)"]
        or sum(index.primary and index.unique for index in parent.indexes) != 1
        or {index.definition for index in parent.indexes if not index.primary} != EXPECTED_INDEX_DEFINITIONS
        or any(not index.valid or not index.ready or index.parents for index in parent.indexes)
    ):
        error("PARENT_INDEX_INVALID", "The parent primary key or expected valid indexes are missing or changed.")
    valid_months: set[datetime] = set()
    for relation in [parent, *snapshot.children]:
        if relation.owner != "postgres" or not relation.rls or relation.force_rls:
            error("RELATION_SECURITY_INVALID", "A review-event relation has unexpected ownership or RLS state.")
        if relation.client_access or relation.public_access:
            error("CLIENT_PRIVILEGE_EXPOSED", "A client or PUBLIC has effective table or column privileges.")
        if relation.policy_count:
            error("RLS_POLICY_PRESENT", "A review-event relation has an unexpected RLS policy.")
    for child in snapshot.children:
        match = re.fullmatch(r"review_events_(\d{4})_(\d{2})", child.name)
        if match is None:
            error("PARTITION_NAME_INVALID", "An attached partition has an unexpected calendar name.")
            continue
        try:
            start = datetime(int(match[1]), int(match[2]), 1, tzinfo=UTC)
            end = add_months(start, 1)
        except ValueError:
            error("PARTITION_NAME_INVALID", "A partition calendar name is invalid.")
            continue
        label = start.strftime("%Y-%m")
        expected_bound = f"FOR VALUES FROM ('{start:%Y-%m-%d} 00:00:00+00') TO ('{end:%Y-%m-%d} 00:00:00+00')"
        if (
            child.schema_name != "public"
            or child.kind != "r"
            or not child.is_partition
            or child.parents != [parent.oid]
            or child.has_children
            or child.bounds != expected_bound
            or start < HISTORY_START
        ):
            error("PARTITION_INVALID", "A partition has unexpected schema, attachment, type or exact UTC calendar bounds.", label)
            continue
        if (
            len(child.indexes) != 3
            or child.constraints != ["PRIMARY KEY (id, created_at)"]
            or {tuple(index.parents) for index in child.indexes} != {(oid,) for oid in parent_indexes}
            or any(
                not index.valid
                or not index.ready
                or len(index.parents) != 1
                or index.parents[0] not in parent_indexes
                or index.primary != parent_indexes[index.parents[0]].primary
                or index.unique != parent_indexes[index.parents[0]].unique
                for index in child.indexes
            )
        ):
            error("CHILD_INDEX_INVALID", "A child primary key or valid inherited index attachment is missing or changed.", label)
        valid_months.add(start)
    missing: list[str] = []
    cursor = HISTORY_START
    while cursor < required_end:
        if cursor not in valid_months:
            label = cursor.strftime("%Y-%m")
            missing.append(label)
            if cursor < month_start(as_of):
                error("HISTORICAL_MONTH_MISSING", "Historical monthly routing coverage is missing.", label)
            elif cursor == month_start(as_of):
                error("CURRENT_MONTH_MISSING", "Current-month routing coverage is missing.", label)
            else:
                findings.append(Finding("FUTURE_MONTH_MISSING", Severity.WARNING, "Rolling three-month future coverage is missing.", label))
        cursor = add_months(cursor, 1)
    continuous_end = HISTORY_START
    for _ in range(MAX_MONTHS):
        if continuous_end not in valid_months:
            break
        continuous_end = add_months(continuous_end, 1)
    remaining = max(0, math.ceil((continuous_end - as_of).total_seconds() / 86400))
    if continuous_end <= as_of + timedelta(days=7):
        findings.append(Finding("COVERAGE_END_WITHIN_7_DAYS", Severity.CRITICAL, "Continuous routing coverage ends within seven days."))
    elif continuous_end <= as_of + timedelta(days=30):
        error("COVERAGE_END_WITHIN_30_DAYS", "Continuous routing coverage ends within thirty days.")
    elif continuous_end <= as_of + timedelta(days=60):
        findings.append(Finding("COVERAGE_END_WITHIN_60_DAYS", Severity.WARNING, "Continuous routing coverage ends within sixty days."))
    priority = {Severity.INFO: 0, Severity.WARNING: 1, Severity.ERROR: 2, Severity.CRITICAL: 3}
    severity = max((finding.severity for finding in findings), key=priority.__getitem__, default=Severity.INFO)
    status = Status.ERROR if severity in (Severity.ERROR, Severity.CRITICAL) else Status.ADVISORY if findings else Status.OK
    return PartitionCheckResult(status, severity, as_of, required_end, continuous_end, tuple(missing), remaining, tuple(findings))


def normalize_database_url(value: str) -> str:
    if not value or len(value) > 8192 or any(character.isspace() or ord(character) < 32 for character in value):
        raise ValueError("Invalid database URL")
    url = make_url(value)
    if url.drivername not in {"postgresql", "postgres", "postgresql+asyncpg"} or not url.username or not url.database:
        raise ValueError("Invalid database URL")
    allowed = {"host", "port", "ssl", "sslmode", "prepared_statement_cache_size"}
    if set(url.query) - allowed or any(not isinstance(option, str) for option in url.query.values()):
        raise ValueError("Invalid database URL")
    query = dict(url.query)
    if "sslmode" in query:
        if "ssl" in query:
            raise ValueError("Ambiguous SSL settings")
        query["ssl"] = query.pop("sslmode")
    return url.set(drivername="postgresql+asyncpg", query=query).render_as_string(hide_password=False)


async def configure_read_only_transaction(connection: AsyncConnection) -> None:
    # Explicit SQL avoids asyncpg dialect's readonly/SERIALIZABLE option caveat.
    # No SELECT precedes this statement in the transaction.
    await connection.execute(text("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ, READ ONLY"))
    await connection.execute(text("SET LOCAL TIME ZONE 'UTC'"))
    await connection.execute(text(f"SET LOCAL statement_timeout = '{STATEMENT_TIMEOUT_MS}ms'"))
    await connection.execute(text(f"SET LOCAL lock_timeout = '{LOCK_TIMEOUT_MS}ms'"))
    await connection.execute(text("SET LOCAL search_path = pg_catalog"))


async def read_catalog_snapshot(connection: AsyncConnection) -> CatalogSnapshot:
    result = await connection.scalar(text(CATALOG_SQL))
    return CatalogSnapshot.model_validate(result)


CLEANUP_TIMEOUT_SECONDS = 1.0


def _consume_task(task: asyncio.Future[Any]) -> None:
    if not task.cancelled():
        task.exception()


def _terminate_connection(connection: AsyncConnection | None) -> None:
    if connection is not None:
        with suppress(Exception):
            # asyncpg terminate is synchronous and closes this owned socket;
            # unlike graceful close it cannot wait for a network round trip.
            synchronous = connection.sync_connection
            if synchronous is not None:
                driver = synchronous.connection.driver_connection
                if driver is not None:
                    driver.terminate()


async def _bounded_await[Result](awaitable: Awaitable[Result], seconds: float) -> Result:
    task = asyncio.ensure_future(awaitable)
    try:
        done, _ = await asyncio.wait({task}, timeout=seconds)
    except BaseException:
        task.cancel()
        task.add_done_callback(_consume_task)
        raise
    if not done:
        task.cancel()
        task.add_done_callback(_consume_task)
        # Do not await cancellation acknowledgement: a stalled driver cleanup
        # may itself ignore cancellation. The owner terminates its socket.
        raise TimeoutError
    return task.result()


async def _collect_snapshot(database_url: str) -> CatalogSnapshot:
    engine = create_async_engine(
        database_url,
        poolclass=NullPool,
        echo=False,
        hide_parameters=True,
        connect_args={"timeout": CONNECT_TIMEOUT_SECONDS, "command_timeout": STATEMENT_TIMEOUT_MS / 1000},
    )
    connection: AsyncConnection | None = None
    transaction: AsyncTransaction | None = None

    async def read() -> CatalogSnapshot:
        nonlocal connection, transaction
        connection = await engine.connect()
        transaction = await connection.begin()
        await configure_read_only_transaction(connection)
        return await read_catalog_snapshot(connection)

    try:
        # Reserve explicit cleanup budgets inside the overall wall-clock bound.
        return await _bounded_await(read(), max(0.001, OVERALL_TIMEOUT_SECONDS - 3 * CLEANUP_TIMEOUT_SECONDS))
    except (TimeoutError, asyncio.CancelledError):
        _terminate_connection(connection)
        raise
    finally:
        cleanups: list[Awaitable[Any]] = []
        if transaction is not None:
            cleanups.append(transaction.rollback())
        if connection is not None:
            cleanups.append(connection.close())
        cleanups.append(engine.dispose())
        cleanup_failed = False
        for cleanup in cleanups:
            try:
                await _bounded_await(cleanup, CLEANUP_TIMEOUT_SECONDS)
            except Exception:
                cleanup_failed = True
                _terminate_connection(connection)
        if cleanup_failed:
            raise RuntimeError("Inspection cleanup could not be verified")


async def inspect_review_partitions(database_url: str, *, as_of: datetime | None = None) -> PartitionCheckResult:
    timestamp = as_of if as_of is not None else datetime.now(UTC)
    try:
        timestamp = validate_as_of(timestamp)
    except (ValueError, OverflowError):
        return unknown_result(datetime.now(UTC), "AS_OF_INVALID", "An aware timestamp within the bounded inspection range is required.")
    try:
        normalized = normalize_database_url(database_url)
    except Exception:
        return unknown_result(timestamp, "DATABASE_URL_INVALID", "An explicit supported PostgreSQL database URL is required.")
    try:
        snapshot = await _collect_snapshot(normalized)
        return evaluate_catalog(snapshot, timestamp)
    except Exception:
        # Never copy a driver exception, DSN, user name or catalog object text
        # into operational output. Missing/partial metadata must not look green.
        return unknown_result(timestamp, "CATALOG_UNAVAILABLE", "The bounded read-only catalog inspection could not be completed.")
