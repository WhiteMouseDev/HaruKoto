"""Add empty private completed lesson receipts; preserve existing learning rows.

Revision ID: o5p6q7r8s9t0
Revises: n4o5p6q7r8s9
"""

from collections.abc import Sequence

from alembic import op

revision: str = "o5p6q7r8s9t0"
down_revision: str | None = "n4o5p6q7r8s9"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_CREATE_RECEIPTS = """
DO $create_lesson_submission_receipts$
DECLARE
    owner_oid oid;
    target_oid oid;
    client_role text;
    role_sql text;
    column_record record;
BEGIN
    SELECT c.relowner INTO owner_oid FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relname='users' AND c.relkind='r';
    IF owner_oid IS DISTINCT FROM 'postgres'::regrole::oid OR current_user::regrole::oid <> owner_oid THEN
        RAISE EXCEPTION 'Unexpected lesson submission table owner/migration role';
    END IF;
    IF pg_catalog.to_regclass('public.lesson_submissions') IS NOT NULL THEN
        RAISE EXCEPTION 'public.lesson_submissions already exists; refusing to overwrite';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_catalog.pg_event_trigger e
        JOIN pg_catalog.pg_proc f ON f.oid=e.evtfoid
        JOIN pg_catalog.pg_namespace n ON n.oid=f.pronamespace
        WHERE e.evtname='zz_harukoto_secure_public_ddl' AND e.evtenabled IN ('O','A')
          AND e.evtevent='ddl_command_end' AND n.nspname='public'
          AND f.proname='harukoto_secure_public_ddl' AND f.proowner=owner_oid AND f.prosecdef
          AND COALESCE(f.proconfig @> ARRAY['search_path=pg_catalog'],false)
          AND (e.evttags IS NULL OR e.evttags @> ARRAY['CREATE TABLE'])
    ) THEN
        RAISE EXCEPTION 'Expected enabled public DDL security guard is missing';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_catalog.pg_namespace n
        WHERE n.nspname='pgrst_no_exposed_schemas' AND n.nspowner=owner_oid
          AND NOT EXISTS (SELECT 1 FROM pg_catalog.pg_depend d
                          WHERE d.refclassid='pg_catalog.pg_namespace'::regclass AND d.refobjid=n.oid)
    ) THEN
        RAISE EXCEPTION 'Expected empty PostgREST schema is missing or not empty';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname='authenticator') AND NOT EXISTS (
        SELECT 1 FROM pg_catalog.pg_roles r, LATERAL unnest(r.rolconfig) setting
         WHERE r.rolname='authenticator' AND setting='pgrst.db_schemas=pgrst_no_exposed_schemas'
    ) THEN
        RAISE EXCEPTION 'Expected disabled Data API schema setting is missing';
    END IF;

    CREATE TABLE public.lesson_submissions (
        user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
        submission_id UUID NOT NULL,
        lesson_id UUID NOT NULL,
        request_fingerprint TEXT NOT NULL,
        fingerprint_version SMALLINT NOT NULL,
        response_schema_version SMALLINT NOT NULL,
        response_body JSONB NOT NULL,
        processed_at TIMESTAMPTZ NOT NULL,
        CONSTRAINT lesson_submissions_pkey PRIMARY KEY (user_id,submission_id),
        CONSTRAINT ck_lesson_submissions_fingerprint CHECK (request_fingerprint ~ '^[0-9a-f]{64}$'),
        CONSTRAINT ck_lesson_submissions_response_object CHECK (jsonb_typeof(response_body)='object')
    );
    CREATE INDEX idx_lesson_submissions_user_lesson_processed
        ON public.lesson_submissions(user_id,lesson_id,processed_at);
    ALTER TABLE public.lesson_submissions ENABLE ROW LEVEL SECURITY;
    target_oid := 'public.lesson_submissions'::regclass;
    FOREACH client_role IN ARRAY ARRAY['PUBLIC','anon','authenticated','service_role'] LOOP
        IF client_role='PUBLIC' OR EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname=client_role) THEN
            role_sql := CASE WHEN client_role='PUBLIC' THEN 'PUBLIC' ELSE quote_ident(client_role) END;
            EXECUTE format('REVOKE ALL PRIVILEGES ON TABLE public.lesson_submissions FROM %s',role_sql);
            FOR column_record IN SELECT attname FROM pg_catalog.pg_attribute
                WHERE attrelid=target_oid AND attnum>0 AND NOT attisdropped AND attacl IS NOT NULL
            LOOP
                EXECUTE format('REVOKE ALL PRIVILEGES (%I) ON TABLE public.lesson_submissions FROM %s',
                               column_record.attname,role_sql);
            END LOOP;
        END IF;
    END LOOP;
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_class WHERE oid=target_oid AND relowner=owner_oid
                   AND relrowsecurity AND NOT relforcerowsecurity AND relkind='r' AND NOT relispartition)
      OR EXISTS (SELECT 1 FROM pg_catalog.pg_policy WHERE polrelid=target_oid)
      OR EXISTS (SELECT 1 FROM pg_catalog.pg_class c, LATERAL pg_catalog.aclexplode(c.relacl) acl
                 WHERE c.oid=target_oid AND acl.grantee=0)
      OR EXISTS (SELECT 1 FROM pg_catalog.pg_attribute a, LATERAL pg_catalog.aclexplode(a.attacl) acl
                 WHERE a.attrelid=target_oid AND acl.grantee=0)
    THEN
        RAISE EXCEPTION 'Unexpected lesson submission security state';
    END IF;
    FOREACH client_role IN ARRAY ARRAY['anon','authenticated','service_role'] LOOP
        IF EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname=client_role) AND (
            pg_catalog.has_table_privilege(client_role,target_oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
            OR pg_catalog.has_any_column_privilege(client_role,target_oid,'SELECT,INSERT,UPDATE,REFERENCES')
        ) THEN
            RAISE EXCEPTION 'Unexpected effective lesson submission privilege for %',client_role;
        END IF;
    END LOOP;
END
$create_lesson_submission_receipts$;
"""


def upgrade() -> None:
    op.execute("SET LOCAL lock_timeout = '2s'")
    op.execute("SET LOCAL statement_timeout = '15s'")
    op.execute(_CREATE_RECEIPTS)


def downgrade() -> None:
    # Empty pre-release installations can round-trip. Once a receipt exists,
    # application rollback must retain it and a compatible reader, never drop it.
    op.execute("SET LOCAL lock_timeout = '2s'")
    op.execute("SET LOCAL statement_timeout = '15s'")
    op.execute("""
        DO $remove_empty_receipt_table$
        BEGIN
            LOCK TABLE ONLY public.lesson_submissions IN ACCESS EXCLUSIVE MODE;
            IF NOT EXISTS (
                SELECT 1 FROM pg_catalog.pg_class WHERE oid='public.lesson_submissions'::regclass
                  AND relowner='postgres'::regrole AND relowner=current_user::regrole
                  AND relkind='r' AND NOT relispartition AND relrowsecurity AND NOT relforcerowsecurity
            ) OR (SELECT array_agg(attname::text ORDER BY attnum) FROM pg_catalog.pg_attribute
                   WHERE attrelid='public.lesson_submissions'::regclass AND attnum>0 AND NOT attisdropped)
                 IS DISTINCT FROM ARRAY['user_id','submission_id','lesson_id','request_fingerprint',
                                        'fingerprint_version','response_schema_version','response_body','processed_at']
              OR (SELECT count(*) FROM pg_catalog.pg_constraint WHERE conrelid='public.lesson_submissions'::regclass)<>4
              OR EXISTS (SELECT 1 FROM pg_catalog.pg_policy WHERE polrelid='public.lesson_submissions'::regclass)
            THEN
                RAISE EXCEPTION 'Unexpected lesson receipt table; refusing destructive downgrade';
            END IF;
            IF EXISTS (SELECT 1 FROM public.lesson_submissions) THEN
                RAISE EXCEPTION 'Completed lesson receipts exist; retain table and deploy a compatible reader';
            END IF;
            DROP TABLE public.lesson_submissions RESTRICT;
        END
        $remove_empty_receipt_table$;
    """)
