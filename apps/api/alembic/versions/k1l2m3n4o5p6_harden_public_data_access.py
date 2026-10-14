"""Close direct client access to server-owned public objects.

Revision ID: k1l2m3n4o5p6
Revises: 9f1e2d3c4b5a

The application connects as the table owner / a trusted BYPASSRLS role and
continues to enforce user authorization in its API. No client RLS policies are
opened. Supabase-managed schemas, extension members and other owners are excluded.

Rollback is deliberately fail-closed: restoring exposed privileges requires a
reviewed, pre-deployment metadata snapshot. Keep the Data API disabled during
manual recovery. No application data or permanent backup table is created.
"""

from collections.abc import Sequence

from alembic import op

revision: str = "k1l2m3n4o5p6"
down_revision: str | None = "9f1e2d3c4b5a"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# Used for the initial inventory and for the exact object reported by a DDL
# event. Each lookup independently checks schema, owner and extension membership.
_RELATION_LOOKUP = """
    SELECT c.oid, c.relname, c.relkind, c.relrowsecurity
    FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_catalog.pg_roles owner_role ON owner_role.oid = c.relowner
    WHERE n.nspname = 'public' AND owner_role.rolname = 'postgres'
      AND c.relkind IN ('r', 'p', 'v', 'm', 'S', 'f')
      AND NOT EXISTS (
          SELECT 1 FROM pg_catalog.pg_depend d
          WHERE d.classid = 'pg_catalog.pg_class'::regclass
            AND d.objid = c.oid AND d.deptype = 'e'
      )
"""
_FUNCTION_LOOKUP = """
    SELECT p.oid, p.proname, pg_catalog.pg_get_function_identity_arguments(p.oid) AS arguments
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
    JOIN pg_catalog.pg_roles owner_role ON owner_role.oid = p.proowner
    WHERE n.nspname = 'public' AND owner_role.rolname = 'postgres'
      AND p.prokind IN ('f', 'p', 'w')
      AND NOT EXISTS (
          SELECT 1 FROM pg_catalog.pg_depend d
          WHERE d.classid = 'pg_catalog.pg_proc'::regclass
            AND d.objid = p.oid AND d.deptype = 'e'
      )
"""
_RELATION_HARDENING = """
    IF object_record.relkind IN ('r', 'p') AND NOT object_record.relrowsecurity THEN
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', object_record.relname);
    ELSIF object_record.relkind = 'v' THEN
        EXECUTE format('ALTER VIEW public.%I SET (security_invoker = true)', object_record.relname);
    END IF;
    FOREACH client_role IN ARRAY ARRAY['PUBLIC', 'anon', 'authenticated'] LOOP
        IF client_role = 'PUBLIC' OR EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = client_role) THEN
            role_sql := CASE WHEN client_role = 'PUBLIC' THEN 'PUBLIC' ELSE quote_ident(client_role) END;
            object_type := CASE WHEN object_record.relkind = 'S' THEN 'SEQUENCE' ELSE 'TABLE' END;
            EXECUTE format('REVOKE ALL PRIVILEGES ON %s public.%I FROM %s', object_type, object_record.relname, role_sql);
            IF object_record.relkind <> 'S' THEN
                FOR column_record IN
                    SELECT attname FROM pg_catalog.pg_attribute
                    WHERE attrelid = object_record.oid AND attnum > 0 AND NOT attisdropped AND attacl IS NOT NULL
                LOOP
                    EXECUTE format('REVOKE ALL PRIVILEGES (%I) ON TABLE public.%I FROM %s',
                        column_record.attname, object_record.relname, role_sql);
                END LOOP;
            END IF;
        END IF;
    END LOOP;
"""
_FUNCTION_HARDENING = """
    FOREACH client_role IN ARRAY ARRAY['PUBLIC', 'anon', 'authenticated'] LOOP
        IF client_role = 'PUBLIC' OR EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = client_role) THEN
            role_sql := CASE WHEN client_role = 'PUBLIC' THEN 'PUBLIC' ELSE quote_ident(client_role) END;
            EXECUTE format('REVOKE ALL PRIVILEGES ON ROUTINE public.%I(%s) FROM %s',
                object_record.proname, object_record.arguments, role_sql);
        END IF;
    END LOOP;
"""
_DECLARATIONS = """
    object_record record;
    column_record record;
    client_role text;
    role_sql text;
    object_type text;
"""


def upgrade() -> None:
    # Do not change global defaults: they also affect managed schemas such as
    # storage. The DDL guard below removes built-in PUBLIC function EXECUTE for
    # new public application functions, which schema-only defaults cannot revoke.
    op.execute("""
        DO $defaults$
        DECLARE client_role text; role_sql text; object_type text;
        BEGIN
            FOREACH client_role IN ARRAY ARRAY['PUBLIC', 'anon', 'authenticated'] LOOP
                IF client_role = 'PUBLIC' OR EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = client_role) THEN
                    role_sql := CASE WHEN client_role = 'PUBLIC' THEN 'PUBLIC' ELSE quote_ident(client_role) END;
                    FOREACH object_type IN ARRAY ARRAY['TABLES', 'SEQUENCES', 'FUNCTIONS'] LOOP
                        EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON %s FROM %s',
                            object_type, role_sql);
                    END LOOP;
                END IF;
            END LOOP;
        END
        $defaults$;
    """)
    op.execute(f"""
        CREATE OR REPLACE FUNCTION public.harukoto_secure_public_ddl()
        RETURNS event_trigger
        LANGUAGE plpgsql
        SECURITY DEFINER
        SET search_path = pg_catalog
        AS $guard$
        DECLARE command_record record; {_DECLARATIONS}
        BEGIN
            FOR command_record IN SELECT * FROM pg_catalog.pg_event_trigger_ddl_commands() LOOP
                IF command_record.in_extension OR command_record.schema_name IS DISTINCT FROM 'public' THEN
                    CONTINUE;
                END IF;
                IF command_record.classid = 'pg_catalog.pg_class'::regclass THEN
                    FOR object_record IN {_RELATION_LOOKUP} AND c.oid = command_record.objid LOOP
                        {_RELATION_HARDENING}
                    END LOOP;
                ELSIF command_record.classid = 'pg_catalog.pg_proc'::regclass THEN
                    FOR object_record IN {_FUNCTION_LOOKUP} AND p.oid = command_record.objid LOOP
                        {_FUNCTION_HARDENING}
                    END LOOP;
                END IF;
            END LOOP;
        END
        $guard$;
    """)
    op.execute(f"""
        DO $existing$
        DECLARE {_DECLARATIONS}
        BEGIN
            FOR object_record IN {_RELATION_LOOKUP} LOOP
                {_RELATION_HARDENING}
            END LOOP;
            FOR object_record IN {_FUNCTION_LOOKUP} LOOP
                {_FUNCTION_HARDENING}
            END LOOP;
        END
        $existing$;
    """)
    # A distinct name leaves Supabase's existing event triggers untouched. Run
    # after its named DDL hooks so later platform grants cannot reopen an object.
    op.execute("""
        DO $install_guard$
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_event_trigger WHERE evtname = 'zz_harukoto_secure_public_ddl') THEN
                CREATE EVENT TRIGGER zz_harukoto_secure_public_ddl ON ddl_command_end
                WHEN TAG IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO', 'CREATE FOREIGN TABLE',
                    'CREATE VIEW', 'CREATE MATERIALIZED VIEW', 'CREATE SEQUENCE', 'CREATE FUNCTION', 'CREATE PROCEDURE')
                EXECUTE FUNCTION public.harukoto_secure_public_ddl();
            END IF;
            ALTER EVENT TRIGGER zz_harukoto_secure_public_ddl ENABLE;
        END
        $install_guard$;
    """)


def downgrade() -> None:
    raise RuntimeError(
        "Automatic downgrade would reopen public data access and is intentionally blocked. "
        "Keep the Data API disabled and use the reviewed pre-deployment ACL/RLS/default-privilege "
        "snapshot for explicit manual recovery. Application data is unchanged."
    )
