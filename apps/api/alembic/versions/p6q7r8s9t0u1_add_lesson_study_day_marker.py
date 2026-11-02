"""Add answered study-day recognition and private receipts without backfill.

Revision ID: p6q7r8s9t0u1
Revises: o5p6q7r8s9t0
"""

from collections.abc import Sequence

from alembic import op

revision: str = "p6q7r8s9t0u1"
down_revision: str | None = "o5p6q7r8s9t0"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_ADD_MARKER = """
DO $add_lesson_study_day_marker$
DECLARE
    target_oid oid := pg_catalog.to_regclass('public.daily_progress');
    owner_oid oid;
    client_role text;
    security_before jsonb;
    security_after jsonb;
    service_table_rights boolean[];
    service_table_rights_after boolean[];
    service_marker_rights boolean[];
BEGIN
    SELECT c.relowner INTO owner_oid FROM pg_catalog.pg_class c
      WHERE c.oid=target_oid AND c.relkind='r' AND NOT c.relispartition
        AND c.relrowsecurity AND NOT c.relforcerowsecurity;
    IF owner_oid IS DISTINCT FROM 'postgres'::regrole::oid OR current_user::regrole::oid <> owner_oid THEN
        RAISE EXCEPTION 'Unexpected daily progress owner, RLS, or migration role';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_attribute
               WHERE attrelid=target_oid AND attname IN ('activity_recorded','lesson_completed') AND NOT attisdropped) THEN
        RAISE EXCEPTION 'activity_recorded already exists; refusing to overwrite';
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
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_class c, LATERAL pg_catalog.aclexplode(c.relacl) acl
               WHERE c.oid=target_oid AND acl.grantee=0)
      OR EXISTS (SELECT 1 FROM pg_catalog.pg_attribute a, LATERAL pg_catalog.aclexplode(a.attacl) acl
                 WHERE a.attrelid=target_oid AND acl.grantee=0)
    THEN
        RAISE EXCEPTION 'Unexpected public daily progress privilege';
    END IF;
    FOREACH client_role IN ARRAY ARRAY['anon','authenticated'] LOOP
        IF EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname=client_role) AND (
            pg_catalog.has_table_privilege(client_role,target_oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
            OR pg_catalog.has_any_column_privilege(client_role,target_oid,'SELECT,INSERT,UPDATE,REFERENCES')
        ) THEN
            RAISE EXCEPTION 'Unexpected effective daily progress privilege for %',client_role;
        END IF;
    END LOOP;

    -- k1 deliberately retains trusted service_role grants. Preserve the exact
    -- existing ACLs instead of treating that server role as an anonymous client.
    SELECT jsonb_build_object(
        'owner',c.relowner,'acl',c.relacl::text,'rls',c.relrowsecurity,
        'force_rls',c.relforcerowsecurity,'options',c.reloptions,
        'columns',(SELECT jsonb_agg(jsonb_build_array(a.attnum,a.attacl::text) ORDER BY a.attnum)
                   FROM pg_catalog.pg_attribute a
                   WHERE a.attrelid=target_oid AND a.attnum>0 AND NOT a.attisdropped)
    ) INTO security_before FROM pg_catalog.pg_class c WHERE c.oid=target_oid;
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname='service_role') THEN
        SELECT array_agg(pg_catalog.has_table_privilege('service_role',target_oid,p.privilege) ORDER BY p.ordinal)
          INTO service_table_rights
          FROM unnest(ARRAY['SELECT','INSERT','UPDATE','REFERENCES','DELETE','TRUNCATE','TRIGGER'])
               WITH ORDINALITY AS p(privilege,ordinal);
    END IF;

    -- No UPDATE/backfill: old-column values and every existing row remain intact.
    ALTER TABLE public.daily_progress ADD COLUMN activity_recorded BOOLEAN NOT NULL DEFAULT FALSE;

    FOREACH client_role IN ARRAY ARRAY['anon','authenticated'] LOOP
        IF EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname=client_role) AND
           pg_catalog.has_column_privilege(client_role,target_oid,'activity_recorded','SELECT,INSERT,UPDATE,REFERENCES')
        THEN
            RAISE EXCEPTION 'Unexpected lesson marker privilege for %',client_role;
        END IF;
    END LOOP;
    SELECT jsonb_build_object(
        'owner',c.relowner,'acl',c.relacl::text,'rls',c.relrowsecurity,
        'force_rls',c.relforcerowsecurity,'options',c.reloptions,
        'columns',(SELECT jsonb_agg(jsonb_build_array(a.attnum,a.attacl::text) ORDER BY a.attnum)
                   FROM pg_catalog.pg_attribute a
                   WHERE a.attrelid=target_oid AND a.attnum>0 AND NOT a.attisdropped
                     AND a.attname<>'activity_recorded')
    ) INTO security_after FROM pg_catalog.pg_class c WHERE c.oid=target_oid;
    IF security_after IS DISTINCT FROM security_before OR EXISTS (
        SELECT 1 FROM pg_catalog.pg_attribute
        WHERE attrelid=target_oid AND attname='activity_recorded' AND attacl IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'Existing daily progress ACL or RLS changed unexpectedly';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname='service_role') THEN
        SELECT array_agg(pg_catalog.has_table_privilege('service_role',target_oid,p.privilege) ORDER BY p.ordinal)
          INTO service_table_rights_after
          FROM unnest(ARRAY['SELECT','INSERT','UPDATE','REFERENCES','DELETE','TRUNCATE','TRIGGER'])
               WITH ORDINALITY AS p(privilege,ordinal);
        SELECT array_agg(pg_catalog.has_column_privilege('service_role',target_oid,'activity_recorded',p.privilege) ORDER BY p.ordinal)
          INTO service_marker_rights
          FROM unnest(ARRAY['SELECT','INSERT','UPDATE','REFERENCES']) WITH ORDINALITY AS p(privilege,ordinal);
        IF service_table_rights_after IS DISTINCT FROM service_table_rights
          OR service_marker_rights IS DISTINCT FROM service_table_rights[1:4]
        THEN
            RAISE EXCEPTION 'Trusted service role privileges changed unexpectedly';
        END IF;
    END IF;
END
$add_lesson_study_day_marker$;
"""


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
        RAISE EXCEPTION 'Unexpected study activity table owner/migration role';
    END IF;
    IF pg_catalog.to_regclass('public.study_activity_receipts') IS NOT NULL THEN
        RAISE EXCEPTION 'public.study_activity_receipts already exists; refusing to overwrite';
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

    CREATE TABLE public.study_activity_receipts (
        user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
        activity_id UUID NOT NULL,
        source_kind TEXT NOT NULL,
        source_scope_id UUID NOT NULL,
        attempt_id UUID NOT NULL,
        source_item_key TEXT NOT NULL,
        content_version TEXT NOT NULL,
        request_fingerprint TEXT NOT NULL,
        fingerprint_version SMALLINT NOT NULL,
        response_schema_version SMALLINT NOT NULL,
        response_body JSONB NOT NULL,
        processed_at TIMESTAMPTZ NOT NULL,
        study_date DATE NOT NULL,
        CONSTRAINT study_activity_receipts_pkey PRIMARY KEY (user_id,activity_id),
        CONSTRAINT ck_study_activity_source_kind CHECK (source_kind IN ('LESSON_ANSWER','KANA_QUIZ_ANSWER')),
        CONSTRAINT ck_study_activity_fingerprint CHECK (request_fingerprint ~ '^[0-9a-f]{64}$'),
        CONSTRAINT ck_study_activity_content_version CHECK (content_version ~ '^[0-9a-f]{64}$'),
        CONSTRAINT ck_study_activity_response_object CHECK (jsonb_typeof(response_body)='object')
    );
    CREATE INDEX idx_study_activity_user_scope_processed ON public.study_activity_receipts(user_id,source_scope_id,processed_at);
    CREATE UNIQUE INDEX uq_study_activity_kana_first_answer
      ON public.study_activity_receipts(user_id,source_scope_id,source_item_key) WHERE source_kind='KANA_QUIZ_ANSWER';
    ALTER TABLE public.study_activity_receipts ENABLE ROW LEVEL SECURITY;
    target_oid := 'public.study_activity_receipts'::regclass;
    FOREACH client_role IN ARRAY ARRAY['PUBLIC','anon','authenticated','service_role'] LOOP
        IF client_role='PUBLIC' OR EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname=client_role) THEN
            role_sql := CASE WHEN client_role='PUBLIC' THEN 'PUBLIC' ELSE quote_ident(client_role) END;
            EXECUTE format('REVOKE ALL PRIVILEGES ON TABLE public.study_activity_receipts FROM %s',role_sql);
            FOR column_record IN SELECT attname FROM pg_catalog.pg_attribute
                WHERE attrelid=target_oid AND attnum>0 AND NOT attisdropped AND attacl IS NOT NULL
            LOOP
                EXECUTE format('REVOKE ALL PRIVILEGES (%I) ON TABLE public.study_activity_receipts FROM %s',
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
        RAISE EXCEPTION 'Unexpected study activity security state';
    END IF;
    FOREACH client_role IN ARRAY ARRAY['anon','authenticated','service_role'] LOOP
        IF EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname=client_role) AND (
            pg_catalog.has_table_privilege(client_role,target_oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
            OR pg_catalog.has_any_column_privilege(client_role,target_oid,'SELECT,INSERT,UPDATE,REFERENCES')
        ) THEN
            RAISE EXCEPTION 'Unexpected effective study activity privilege for %',client_role;
        END IF;
    END LOOP;
END
$create_lesson_submission_receipts$;
"""


def upgrade() -> None:
    op.execute("SET LOCAL lock_timeout = '2s'")
    op.execute("SET LOCAL statement_timeout = '15s'")
    op.execute(_ADD_MARKER)
    op.execute(_CREATE_RECEIPTS)


def downgrade() -> None:
    op.execute("SET LOCAL lock_timeout = '2s'")
    op.execute("SET LOCAL statement_timeout = '15s'")
    op.execute("""
        DO $remove_unused_lesson_marker$
        BEGIN
            LOCK TABLE ONLY public.daily_progress IN ACCESS EXCLUSIVE MODE;
            LOCK TABLE ONLY public.study_activity_receipts IN ACCESS EXCLUSIVE MODE;
            IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_class WHERE oid='public.study_activity_receipts'::regclass
                AND relowner='postgres'::regrole AND relowner=current_user::regrole
                AND relrowsecurity AND NOT relforcerowsecurity AND relkind='r')
            THEN RAISE EXCEPTION 'Unexpected activity receipt security; refusing downgrade'; END IF;
            IF EXISTS(SELECT 1 FROM public.study_activity_receipts) THEN
                RAISE EXCEPTION 'Accepted activity receipts exist; retain receipts and deploy a compatible reader';
            END IF;
            IF NOT EXISTS (
                SELECT 1 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_attribute a ON a.attrelid=c.oid
                JOIN pg_catalog.pg_attrdef d ON d.adrelid=c.oid AND d.adnum=a.attnum
                WHERE c.oid='public.daily_progress'::regclass AND c.relowner='postgres'::regrole
                  AND c.relowner=current_user::regrole AND c.relkind='r' AND NOT c.relispartition
                  AND c.relrowsecurity AND NOT c.relforcerowsecurity
                  AND a.attname='activity_recorded' AND a.atttypid='boolean'::regtype AND a.attnotnull
                  AND NOT a.attisdropped AND a.attacl IS NULL
                  AND pg_catalog.pg_get_expr(d.adbin,d.adrelid)='false'
            ) THEN
                RAISE EXCEPTION 'Unexpected answered study-day marker; refusing destructive downgrade';
            END IF;
            IF EXISTS (SELECT 1 FROM public.daily_progress WHERE activity_recorded) THEN
                RAISE EXCEPTION 'Recognized study days exist; retain marker and deploy a compatible reader';
            END IF;
            DROP TABLE public.study_activity_receipts RESTRICT;
            ALTER TABLE public.daily_progress DROP COLUMN activity_recorded RESTRICT;
        END
        $remove_unused_lesson_marker$;
    """)
