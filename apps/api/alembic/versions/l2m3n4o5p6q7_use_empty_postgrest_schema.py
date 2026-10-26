"""Point disabled PostgREST at an empty, inaccessible schema.

Revision ID: l2m3n4o5p6q7
Revises: k1l2m3n4o5p6

Supabase keeps PostgREST running when the Data API is disabled. Its reserved
missing-schema sentinel produces repeated log entries. This official workaround
changes only PostgREST's in-database schema override; it does not enable the Data
API, grant client access, or change application/auth/storage objects.

https://supabase.com/docs/guides/troubleshooting/schema-pg_pgrst_no_exposed_schemas-does-not-exist
"""

from collections.abc import Sequence

from alembic import op

revision: str = "l2m3n4o5p6q7"
down_revision: str | None = "k1l2m3n4o5p6"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

_SCHEMA_CHECK = """
    SELECT oid, nspowner INTO schema_oid, schema_owner
    FROM pg_catalog.pg_namespace WHERE nspname = 'pgrst_no_exposed_schemas';
    IF schema_owner IS DISTINCT FROM 'postgres'::regrole::oid THEN
        RAISE EXCEPTION 'The empty PostgREST schema must be owned by postgres';
    END IF;
    -- Namespace dependencies cover relations, routines, types, operators,
    -- collations and other schema objects, including extension members.
    IF EXISTS (
        SELECT 1 FROM pg_catalog.pg_depend
        WHERE refclassid = 'pg_catalog.pg_namespace'::regclass AND refobjid = schema_oid
    ) THEN
        RAISE EXCEPTION 'The PostgREST placeholder schema is not empty; refusing to expose or drop it';
    END IF;
"""


def upgrade() -> None:
    op.execute("CREATE SCHEMA IF NOT EXISTS pgrst_no_exposed_schemas AUTHORIZATION postgres")
    op.execute(f"""
        DO $secure_empty_schema$
        DECLARE schema_oid oid; schema_owner oid; grantee_oid oid; role_sql text;
        BEGIN
            {_SCHEMA_CHECK}
            -- Revoke pre-existing ACLs too, without touching any other schema.
            -- No client gets USAGE or CREATE, even if future owner DDL were to
            -- put something here by mistake. PUBLIC covers future roles as well.
            FOR grantee_oid IN
                SELECT DISTINCT acl.grantee
                FROM pg_catalog.pg_namespace n,
                    LATERAL pg_catalog.aclexplode(COALESCE(n.nspacl, pg_catalog.acldefault('n', n.nspowner))) acl
                WHERE n.oid = schema_oid AND acl.grantee <> schema_owner
            LOOP
                role_sql := CASE WHEN grantee_oid = 0 THEN 'PUBLIC' ELSE quote_ident(pg_catalog.pg_get_userbyid(grantee_oid)) END;
                EXECUTE format('REVOKE ALL PRIVILEGES ON SCHEMA pgrst_no_exposed_schemas FROM %s', role_sql);
            END LOOP;
            REVOKE ALL PRIVILEGES ON SCHEMA pgrst_no_exposed_schemas FROM PUBLIC;
            -- Plain PostgreSQL test/dev environments need not have Supabase's
            -- managed authenticator role. Never create or redefine that role.
            IF EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'authenticator') THEN
                ALTER ROLE authenticator SET pgrst.db_schemas = 'pgrst_no_exposed_schemas';
            END IF;
        END
        $secure_empty_schema$;
    """)
    # An empty payload reloads both PostgREST configuration and its schema cache.
    # PostgreSQL delivers NOTIFY only when this migration transaction commits.
    op.execute("NOTIFY pgrst")


def downgrade() -> None:
    op.execute(f"""
        DO $restore_disabled_sentinel$
        DECLARE schema_oid oid; schema_owner oid;
        BEGIN
            {_SCHEMA_CHECK}
            IF EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'authenticator') THEN
                -- RESET may fall back to public. Keep a fail-closed explicit
                -- sentinel instead; the original missing-schema logs can recur.
                ALTER ROLE authenticator SET pgrst.db_schemas = 'pg_pgrst_no_exposed_schemas';
            END IF;
            DROP SCHEMA pgrst_no_exposed_schemas RESTRICT;
        END
        $restore_disabled_sentinel$;
    """)
    op.execute("NOTIFY pgrst")
