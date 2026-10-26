"""Restore bounded UTC review-event coverage without changing historical rows.

Revision ID: m3n4o5p6q7r8
Revises: l2m3n4o5p6q7

Only the seven dated partitions are added. Unexpected catalog/security state
aborts the transaction. Automatic rollback never drops populated partitions.
"""

from collections.abc import Sequence

from alembic import op

revision: str = "m3n4o5p6q7r8"
down_revision: str | None = "l2m3n4o5p6q7"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# Keep this SQL self-contained so `alembic upgrade old:new --sql` is exactly
# reviewable and executable, including checks in offline/deployment mode.
_REPAIR = """
DO $repair_review_partitions$
DECLARE
    saved_search_path text := pg_catalog.current_setting('search_path');
    parent_oid oid;
    parent_owner oid;
    parent_key smallint;
    child_record record;
    month_start date;
    month_end date;
    child_name text;
    expected_bound text;
    target_oid oid;
    client_role text;
    column_record record;
    parent_index_count integer;
BEGIN
    PERFORM pg_catalog.set_config('search_path', 'pg_catalog', true);
    -- Bound the parent lock before catalog inspection; concurrent repair or
    -- DDL cannot invalidate the checked inventory between validation and CREATE.
    LOCK TABLE ONLY public.review_events IN ACCESS EXCLUSIVE MODE;
    SELECT c.oid, c.relowner, a.attnum
      INTO parent_oid, parent_owner, parent_key
      FROM pg_catalog.pg_class c
      JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
      JOIN pg_catalog.pg_attribute a ON a.attrelid = c.oid AND a.attname = 'created_at'
     WHERE n.nspname = 'public' AND c.relname = 'review_events'
       AND c.relkind = 'p' AND NOT c.relispartition
       AND c.relowner = 'postgres'::regrole AND c.relrowsecurity AND NOT c.relforcerowsecurity
       AND a.atttypid = 'timestamp with time zone'::regtype AND a.attnotnull AND NOT a.attisdropped;
    IF parent_oid IS NULL OR NOT EXISTS (
        SELECT 1 FROM pg_catalog.pg_partitioned_table p
         WHERE p.partrelid = parent_oid AND p.partstrat = 'r' AND p.partnatts = 1
           AND p.partattrs::text = parent_key::text AND p.partdefid = 0 AND p.partexprs IS NULL
           AND pg_catalog.pg_get_partkeydef(parent_oid) = 'RANGE (created_at)'
    ) OR EXISTS (
        SELECT 1 FROM pg_catalog.pg_depend d WHERE d.classid = 'pg_catalog.pg_class'::regclass
          AND d.objid = parent_oid AND d.deptype = 'e'
    ) THEN
        RAISE EXCEPTION 'Unexpected public.review_events parent, owner, security or UTC range key';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_catalog.pg_event_trigger e
        JOIN pg_catalog.pg_proc f ON f.oid = e.evtfoid
        JOIN pg_catalog.pg_namespace n ON n.oid = f.pronamespace
        WHERE e.evtname = 'zz_harukoto_secure_public_ddl' AND e.evtenabled IN ('O', 'A')
          AND e.evtevent = 'ddl_command_end' AND n.nspname = 'public'
          AND f.proname = 'harukoto_secure_public_ddl' AND f.proowner = parent_owner AND f.prosecdef
    ) THEN
        RAISE EXCEPTION 'Expected enabled public DDL security guard is missing';
    END IF;
    -- These are the actual original constraints/indexes, not assumed FKs. A
    -- PARTITION OF inherits each automatically; verify their index attachments.
    SELECT count(*) INTO parent_index_count FROM pg_catalog.pg_index WHERE indrelid = parent_oid;
    IF parent_index_count <> 3 OR EXISTS (
        SELECT 1 FROM pg_catalog.pg_index WHERE indrelid = parent_oid AND (NOT indisvalid OR NOT indisready)
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_catalog.pg_constraint c WHERE c.conrelid = parent_oid AND c.contype = 'p'
          AND pg_catalog.pg_get_constraintdef(c.oid) = 'PRIMARY KEY (id, created_at)'
    ) OR EXISTS (
        SELECT 1 FROM pg_catalog.pg_constraint WHERE conrelid = parent_oid AND contype <> 'p'
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_catalog.pg_index i JOIN pg_catalog.pg_class c ON c.oid = i.indexrelid
        WHERE i.indrelid = parent_oid AND c.relname = 'idx_review_events_user'
          AND pg_catalog.pg_get_indexdef(i.indexrelid) =
              'CREATE INDEX idx_review_events_user ON ONLY public.review_events USING btree (user_id, created_at DESC)'
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_catalog.pg_index i JOIN pg_catalog.pg_class c ON c.oid = i.indexrelid
        WHERE i.indrelid = parent_oid AND c.relname = 'idx_review_events_user_day'
          AND pg_catalog.pg_get_indexdef(i.indexrelid) =
              ('CREATE INDEX idx_review_events_user_day ON ONLY public.review_events USING btree ' ||
               '(user_id, reviewed_on) WHERE (is_new_card = true)')
    ) THEN
        RAISE EXCEPTION 'Unexpected review_events parent constraints or indexes';
    END IF;
    -- Reject DEFAULT, overlapping/renamed partitions, subpartitions and foreign
    -- schemas rather than accepting a superficially matching table name.
    FOR child_record IN
        SELECT c.oid, c.relname, n.nspname, c.relkind, c.relispartition, c.relowner,
               pg_catalog.pg_get_expr(c.relpartbound, c.oid) AS bounds
          FROM pg_catalog.pg_inherits i JOIN pg_catalog.pg_class c ON c.oid = i.inhrelid
          JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace WHERE i.inhparent = parent_oid
    LOOP
        IF child_record.nspname <> 'public' OR child_record.relkind <> 'r' OR NOT child_record.relispartition
           OR child_record.relowner <> parent_owner
           OR child_record.relname !~ '^review_events_(2026_(0[3-9]|1[0-2])|2027_01)$' THEN
            RAISE EXCEPTION 'Unexpected existing review_events child: %', child_record.relname;
        END IF;
        month_start := to_date(right(child_record.relname, 7), 'YYYY_MM');
        month_end := (month_start + interval '1 month')::date;
        expected_bound := format('FOR VALUES FROM (%L) TO (%L)',
            month_start::text || ' 00:00:00+00', month_end::text || ' 00:00:00+00');
        IF child_record.bounds <> expected_bound THEN
            RAISE EXCEPTION 'Unexpected UTC bounds for %', child_record.relname;
        END IF;
    END LOOP;
    -- Require the known historical inventory; no legacy object is modified.
    FOR month_start IN SELECT generate_series('2026-03-01'::date, '2027-01-01'::date, interval '1 month')::date LOOP
        month_end := (month_start + interval '1 month')::date;
        child_name := 'review_events_' || to_char(month_start, 'YYYY_MM');
        expected_bound := format('FOR VALUES FROM (%L) TO (%L)',
            month_start::text || ' 00:00:00+00', month_end::text || ' 00:00:00+00');
        target_oid := pg_catalog.to_regclass(format('public.%I', child_name));
        IF target_oid IS NULL THEN
            IF month_start < '2026-07-01'::date THEN
                RAISE EXCEPTION 'Historical review partition is missing: %', child_name;
            END IF;
            EXECUTE format('CREATE TABLE public.%I PARTITION OF public.review_events FOR VALUES FROM (%L) TO (%L)',
                child_name, month_start::text || ' 00:00:00+00', month_end::text || ' 00:00:00+00');
            EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', child_name);
            FOREACH client_role IN ARRAY ARRAY['PUBLIC', 'anon', 'authenticated'] LOOP
                IF client_role = 'PUBLIC' OR EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = client_role) THEN
                    EXECUTE format('REVOKE ALL PRIVILEGES ON TABLE public.%I FROM %s', child_name,
                        CASE WHEN client_role = 'PUBLIC' THEN 'PUBLIC' ELSE quote_ident(client_role) END);
                    FOR column_record IN
                        SELECT attname FROM pg_catalog.pg_attribute
                         WHERE attrelid = pg_catalog.to_regclass(format('public.%I', child_name))
                           AND attnum > 0 AND NOT attisdropped AND attacl IS NOT NULL
                    LOOP
                        EXECUTE format('REVOKE ALL PRIVILEGES (%I) ON TABLE public.%I FROM %s',
                            column_record.attname, child_name,
                            CASE WHEN client_role = 'PUBLIC' THEN 'PUBLIC' ELSE quote_ident(client_role) END);
                    END LOOP;
                END IF;
            END LOOP;
            target_oid := pg_catalog.to_regclass(format('public.%I', child_name));
        END IF;
        IF NOT EXISTS (
            SELECT 1 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
            WHERE c.oid = target_oid AND n.nspname = 'public' AND c.relkind = 'r' AND c.relispartition
              AND c.relowner = parent_owner AND c.relrowsecurity AND NOT c.relforcerowsecurity
              AND pg_catalog.pg_get_expr(c.relpartbound, c.oid) = expected_bound
        ) OR (SELECT count(*) FROM pg_catalog.pg_inherits WHERE inhrelid = target_oid) <> 1
          OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_inherits WHERE inhparent = parent_oid AND inhrelid = target_oid)
          OR EXISTS (SELECT 1 FROM pg_catalog.pg_inherits WHERE inhparent = target_oid)
          OR EXISTS (SELECT 1 FROM pg_catalog.pg_policy WHERE polrelid = target_oid)
          OR (SELECT count(*) FROM pg_catalog.pg_index WHERE indrelid = target_oid) <> parent_index_count
          OR EXISTS (
              SELECT 1 FROM pg_catalog.pg_index pi WHERE pi.indrelid = parent_oid AND NOT EXISTS (
                  SELECT 1 FROM pg_catalog.pg_inherits ii JOIN pg_catalog.pg_index ci ON ci.indexrelid = ii.inhrelid
                  WHERE ii.inhparent = pi.indexrelid AND ci.indrelid = target_oid AND ci.indisvalid AND ci.indisready
                    AND ci.indisprimary = pi.indisprimary AND ci.indisunique = pi.indisunique
              )
          ) OR (SELECT count(*) FROM pg_catalog.pg_constraint WHERE conrelid = target_oid) <> 1
          OR NOT EXISTS (
              SELECT 1 FROM pg_catalog.pg_constraint cc JOIN pg_catalog.pg_constraint pc ON pc.oid = cc.conparentid
              WHERE cc.conrelid = target_oid AND cc.contype = 'p' AND pc.conrelid = parent_oid
                AND pg_catalog.pg_get_constraintdef(cc.oid) = 'PRIMARY KEY (id, created_at)'
          ) THEN
            RAISE EXCEPTION 'Review partition parent, bounds, security, indexes or constraints mismatch: %', child_name;
        END IF;
    END LOOP;
    -- Check effective privileges too, including role membership and column
    -- grants. Parent and historical ACLs are checked, never silently rewritten.
    FOR target_oid IN
        SELECT parent_oid UNION ALL SELECT inhrelid FROM pg_catalog.pg_inherits WHERE inhparent = parent_oid
    LOOP
        IF EXISTS (SELECT 1 FROM pg_catalog.pg_policy WHERE polrelid = target_oid) OR EXISTS (
            SELECT 1 FROM pg_catalog.pg_class c, LATERAL pg_catalog.aclexplode(c.relacl) acl
             WHERE c.oid = target_oid AND acl.grantee = 0
        ) OR EXISTS (
            SELECT 1 FROM pg_catalog.pg_attribute a, LATERAL pg_catalog.aclexplode(a.attacl) acl
             WHERE a.attrelid = target_oid AND acl.grantee = 0
        ) THEN
            RAISE EXCEPTION 'Review-event PUBLIC privilege or RLS policy found on %', target_oid::regclass;
        END IF;
        FOREACH client_role IN ARRAY ARRAY['anon', 'authenticated'] LOOP
            IF EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = client_role) AND (
                pg_catalog.has_table_privilege(client_role, target_oid, 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
                OR pg_catalog.has_any_column_privilege(client_role, target_oid, 'SELECT,INSERT,UPDATE,REFERENCES')
            ) THEN
                RAISE EXCEPTION 'Review-event client privilege found on % for %', target_oid::regclass, client_role;
            END IF;
        END LOOP;
    END LOOP;
    -- Alembic updates its version table by an unqualified name after this DO.
    PERFORM pg_catalog.set_config('search_path', saved_search_path, true);
END
$repair_review_partitions$;
"""


def upgrade() -> None:
    op.execute("SET LOCAL lock_timeout = '2s'")
    op.execute("SET LOCAL statement_timeout = '15s'")
    op.execute("SET LOCAL TIME ZONE 'UTC'")
    op.execute(_REPAIR)


def downgrade() -> None:
    raise RuntimeError(
        "Automatic downgrade would drop or detach review-event partitions and is intentionally blocked. "
        "Retain the partitions during application rollback; use a separately reviewed data-preserving procedure for removal."
    )
