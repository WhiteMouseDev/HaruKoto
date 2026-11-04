"""Allow private kana card receipts without changing rows, columns, or grants.

Revision ID: r8s9t0u1v2w3
Revises: q7r8s9t0u1v2
"""

from collections.abc import Sequence

from alembic import op

revision: str = "r8s9t0u1v2w3"
down_revision: str | None = "q7r8s9t0u1v2"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_OLD = "'LESSON_ANSWER','KANA_QUIZ_ANSWER'"
_NEW = "'LESSON_ANSWER','KANA_QUIZ_ANSWER','KANA_CARD_PROGRESS'"


def _replace_source_constraint(*, removing: bool) -> None:
    old_values, new_values = (_NEW, _OLD) if removing else (_OLD, _NEW)
    expected_definition = "CHECK ((source_kind = ANY (ARRAY[" + ", ".join(f"{v}::text" for v in old_values.split(",")) + "])))"
    escaped_definition = expected_definition.replace("'", "''")
    refuse_receipts = (
        "IF EXISTS (SELECT 1 FROM public.study_activity_receipts WHERE source_kind='KANA_CARD_PROGRESS') THEN "
        "RAISE EXCEPTION 'Accepted kana card receipts exist; retain the expanded constraint'; END IF;"
        if removing
        else ""
    )
    op.execute("SET LOCAL lock_timeout = '2s'")
    op.execute("SET LOCAL statement_timeout = '15s'")
    op.execute(f"""
        DO $kana_card_receipt_sources$
        DECLARE
            target_oid oid := pg_catalog.to_regclass('public.study_activity_receipts');
            client_role text;
            before_security jsonb;
            after_security jsonb;
        BEGIN
            LOCK TABLE ONLY public.study_activity_receipts IN ACCESS EXCLUSIVE MODE;
            IF NOT EXISTS (
                SELECT 1 FROM pg_catalog.pg_class
                WHERE oid=target_oid AND relowner='postgres'::regrole
                  AND relowner=current_user::regrole AND relkind='r' AND NOT relispartition
                  AND relrowsecurity AND NOT relforcerowsecurity
            ) OR EXISTS (SELECT 1 FROM pg_catalog.pg_policy WHERE polrelid=target_oid) THEN
                RAISE EXCEPTION 'Unexpected private receipt owner or RLS; refusing migration';
            END IF;
            IF NOT EXISTS (
                SELECT 1 FROM pg_catalog.pg_constraint WHERE conrelid=target_oid
                  AND conname='ck_study_activity_source_kind' AND contype='c' AND convalidated
                  AND pg_catalog.pg_get_constraintdef(oid)='{escaped_definition}'
            ) THEN
                RAISE EXCEPTION 'Unexpected receipt source constraint; refusing replacement';
            END IF;
            IF EXISTS (SELECT 1 FROM pg_catalog.pg_class c, LATERAL pg_catalog.aclexplode(c.relacl) acl
                       WHERE c.oid=target_oid AND acl.grantee=0)
              OR EXISTS (SELECT 1 FROM pg_catalog.pg_attribute a, LATERAL pg_catalog.aclexplode(a.attacl) acl
                         WHERE a.attrelid=target_oid AND acl.grantee=0) THEN
                RAISE EXCEPTION 'Unexpected public receipt privilege';
            END IF;
            FOREACH client_role IN ARRAY ARRAY['anon','authenticated','service_role'] LOOP
                IF EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname=client_role) AND (
                    pg_catalog.has_table_privilege(client_role,target_oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
                    OR pg_catalog.has_any_column_privilege(client_role,target_oid,'SELECT,INSERT,UPDATE,REFERENCES')
                ) THEN
                    RAISE EXCEPTION 'Unexpected private receipt access for %',client_role;
                END IF;
            END LOOP;
            IF NOT EXISTS (
                SELECT 1 FROM pg_catalog.pg_namespace n
                WHERE n.nspname='pgrst_no_exposed_schemas' AND n.nspowner='postgres'::regrole
                  AND NOT EXISTS (SELECT 1 FROM pg_catalog.pg_depend d
                    WHERE d.refclassid='pg_catalog.pg_namespace'::regclass AND d.refobjid=n.oid)
            ) OR (EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname='authenticator') AND NOT EXISTS (
                SELECT 1 FROM pg_catalog.pg_roles r, LATERAL unnest(r.rolconfig) setting
                WHERE r.rolname='authenticator' AND setting='pgrst.db_schemas=pgrst_no_exposed_schemas'
            )) THEN
                RAISE EXCEPTION 'Expected disabled Data API boundary is missing';
            END IF;
            {refuse_receipts}
            SELECT jsonb_build_object(
                'owner',c.relowner,'acl',c.relacl::text,'rls',c.relrowsecurity,'force',c.relforcerowsecurity,
                'columns',(SELECT jsonb_agg(to_jsonb(a) ORDER BY a.attnum) FROM pg_catalog.pg_attribute a
                           WHERE a.attrelid=target_oid AND a.attnum>0 AND NOT a.attisdropped),
                'indexes',(SELECT jsonb_agg(pg_catalog.pg_get_indexdef(i.indexrelid) ORDER BY i.indexrelid)
                           FROM pg_catalog.pg_index i WHERE i.indrelid=target_oid)
            ) INTO before_security FROM pg_catalog.pg_class c WHERE c.oid=target_oid;

            ALTER TABLE public.study_activity_receipts DROP CONSTRAINT ck_study_activity_source_kind;
            ALTER TABLE public.study_activity_receipts ADD CONSTRAINT ck_study_activity_source_kind
              CHECK (source_kind IN ({new_values}));

            SELECT jsonb_build_object(
                'owner',c.relowner,'acl',c.relacl::text,'rls',c.relrowsecurity,'force',c.relforcerowsecurity,
                'columns',(SELECT jsonb_agg(to_jsonb(a) ORDER BY a.attnum) FROM pg_catalog.pg_attribute a
                           WHERE a.attrelid=target_oid AND a.attnum>0 AND NOT a.attisdropped),
                'indexes',(SELECT jsonb_agg(pg_catalog.pg_get_indexdef(i.indexrelid) ORDER BY i.indexrelid)
                           FROM pg_catalog.pg_index i WHERE i.indrelid=target_oid)
            ) INTO after_security FROM pg_catalog.pg_class c WHERE c.oid=target_oid;
            IF after_security IS DISTINCT FROM before_security THEN
                RAISE EXCEPTION 'Private receipt metadata changed unexpectedly';
            END IF;
        END
        $kana_card_receipt_sources$;
    """)


def upgrade() -> None:
    _replace_source_constraint(removing=False)


def downgrade() -> None:
    _replace_source_constraint(removing=True)
