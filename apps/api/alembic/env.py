import asyncio
from logging.config import fileConfig

from sqlalchemy import pool
from sqlalchemy.ext.asyncio import async_engine_from_config

# Import all models to register them with Base.metadata
import app.models  # noqa: F401
from alembic import context
from app.config import settings
from app.db.base import Base

config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def _ignore_prisma_type_diffs(type1, type2, directive):
    """Prisma가 사용하는 타입(TIMESTAMP(3), JSONB)과 SQLAlchemy 기본 타입 차이를 무시."""
    return False


def run_migrations_offline() -> None:
    url = settings.DATABASE_URL
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=_ignore_prisma_type_diffs,
    )
    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection):
    context.configure(
        connection=connection,
        target_metadata=target_metadata,
        compare_type=_ignore_prisma_type_diffs,
    )
    with context.begin_transaction():
        context.run_migrations()


async def run_async_migrations():
    configuration = {"sqlalchemy.url": settings.DATABASE_URL}
    connectable = async_engine_from_config(
        configuration,
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)
    await connectable.dispose()


def run_migrations_online() -> None:
    asyncio.run(run_async_migrations())


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
