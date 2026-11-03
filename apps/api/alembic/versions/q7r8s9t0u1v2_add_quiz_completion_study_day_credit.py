"""Separate delayed completion rewards from study-day credit without backfill.

Revision ID: q7r8s9t0u1v2
Revises: p6q7r8s9t0u1
"""

from collections.abc import Sequence

from alembic import op

revision: str = "q7r8s9t0u1v2"
down_revision: str | None = "p6q7r8s9t0u1"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_ADD_CREDIT = """
DO $add_quiz_completion_study_day_credit$
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
               WHERE attrelid=target_oid AND attname='study_day_credited' AND NOT attisdropped) THEN
        RAISE EXCEPTION 'study_day_credited already exists; refusing to overwrite';
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
    ALTER TABLE public.daily_progress ADD COLUMN study_day_credited BOOLEAN NULL;

    FOREACH client_role IN ARRAY ARRAY['anon','authenticated'] LOOP
        IF EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname=client_role) AND
           pg_catalog.has_column_privilege(client_role,target_oid,'study_day_credited','SELECT,INSERT,UPDATE,REFERENCES')
        THEN
            RAISE EXCEPTION 'Unexpected study-day credit privilege for %',client_role;
        END IF;
    END LOOP;
    SELECT jsonb_build_object(
        'owner',c.relowner,'acl',c.relacl::text,'rls',c.relrowsecurity,
        'force_rls',c.relforcerowsecurity,'options',c.reloptions,
        'columns',(SELECT jsonb_agg(jsonb_build_array(a.attnum,a.attacl::text) ORDER BY a.attnum)
                   FROM pg_catalog.pg_attribute a
                   WHERE a.attrelid=target_oid AND a.attnum>0 AND NOT a.attisdropped
                     AND a.attname<>'study_day_credited')
    ) INTO security_after FROM pg_catalog.pg_class c WHERE c.oid=target_oid;
    IF security_after IS DISTINCT FROM security_before OR EXISTS (
        SELECT 1 FROM pg_catalog.pg_attribute
        WHERE attrelid=target_oid AND attname='study_day_credited' AND attacl IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'Existing daily progress ACL or RLS changed unexpectedly';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname='service_role') THEN
        SELECT array_agg(pg_catalog.has_table_privilege('service_role',target_oid,p.privilege) ORDER BY p.ordinal)
          INTO service_table_rights_after
          FROM unnest(ARRAY['SELECT','INSERT','UPDATE','REFERENCES','DELETE','TRUNCATE','TRIGGER'])
               WITH ORDINALITY AS p(privilege,ordinal);
        SELECT array_agg(pg_catalog.has_column_privilege('service_role',target_oid,'study_day_credited',p.privilege) ORDER BY p.ordinal)
          INTO service_marker_rights
          FROM unnest(ARRAY['SELECT','INSERT','UPDATE','REFERENCES']) WITH ORDINALITY AS p(privilege,ordinal);
        IF service_table_rights_after IS DISTINCT FROM service_table_rights
          OR service_marker_rights IS DISTINCT FROM service_table_rights[1:4]
        THEN
            RAISE EXCEPTION 'Trusted service role privileges changed unexpectedly';
        END IF;
    END IF;
END
$add_quiz_completion_study_day_credit$;
"""


def upgrade() -> None:
    op.execute("SET LOCAL lock_timeout = '2s'")
    op.execute("SET LOCAL statement_timeout = '15s'")
    op.execute(_ADD_CREDIT)


def downgrade() -> None:
    op.execute("SET LOCAL lock_timeout = '2s'")
    op.execute("SET LOCAL statement_timeout = '15s'")
    op.execute("""
        DO $remove_unused_study_day_credit$
        BEGIN
            LOCK TABLE ONLY public.daily_progress IN ACCESS EXCLUSIVE MODE;
            IF NOT EXISTS (
                SELECT 1 FROM pg_catalog.pg_class c JOIN pg_catalog.pg_attribute a ON a.attrelid=c.oid
                WHERE c.oid='public.daily_progress'::regclass AND c.relowner='postgres'::regrole
                  AND c.relowner=current_user::regrole AND c.relkind='r' AND NOT c.relispartition
                  AND c.relrowsecurity AND NOT c.relforcerowsecurity
                  AND a.attname='study_day_credited' AND a.atttypid='boolean'::regtype AND NOT a.attnotnull
                  AND NOT a.attisdropped AND a.attacl IS NULL AND NOT a.atthasdef
            ) THEN
                RAISE EXCEPTION 'Unexpected study-day credit column; refusing downgrade';
            END IF;
            IF EXISTS (SELECT 1 FROM public.daily_progress WHERE study_day_credited IS NOT NULL) THEN
                RAISE EXCEPTION 'Study-day decisions exist; retain column and deploy a compatible reader';
            END IF;
            ALTER TABLE public.daily_progress DROP COLUMN study_day_credited RESTRICT;
        END
        $remove_unused_study_day_credit$;
    """)
