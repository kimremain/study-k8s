import asyncio
from collections.abc import AsyncIterator
from functools import lru_cache

from sqlalchemy import URL, text
from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from kubewatch.config import Settings, get_settings


def build_database_url(settings: Settings) -> URL:
    if settings.database_password is None:
        raise RuntimeError("KUBEWATCH_DATABASE_PASSWORD is required")

    return URL.create(
        drivername="postgresql+asyncpg",
        username=settings.database_user,
        password=settings.database_password.get_secret_value(),
        host=settings.database_host,
        port=settings.database_port,
        database=settings.database_name,
    )


@lru_cache
def get_engine() -> AsyncEngine:
    settings = get_settings()
    return create_async_engine(
        build_database_url(settings),
        pool_pre_ping=True,
        pool_size=settings.database_pool_size,
    )


@lru_cache
def get_session_factory() -> async_sessionmaker[AsyncSession]:
    return async_sessionmaker(get_engine(), expire_on_commit=False)


async def get_db_session() -> AsyncIterator[AsyncSession]:
    async with get_session_factory()() as session:
        yield session


async def database_is_ready() -> bool:
    settings = get_settings()
    try:
        async with asyncio.timeout(settings.database_connect_timeout_seconds):
            async with get_engine().connect() as connection:
                # Keep the Pod out of Service endpoints until both PostgreSQL
                # and this release's initial schema are available.
                await connection.execute(text("SELECT 1 FROM resource_snapshots LIMIT 1"))
    except (TimeoutError, OSError, RuntimeError):
        return False
    except Exception:
        # Driver and SQLAlchemy connection errors intentionally become a failed
        # readiness result. The exception text can contain connection details.
        return False
    return True


async def close_database() -> None:
    if get_engine.cache_info().currsize:
        await get_engine().dispose()
    get_session_factory.cache_clear()
    get_engine.cache_clear()
