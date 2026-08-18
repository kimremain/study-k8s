from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from kubewatch import __version__
from kubewatch.api.routes.health import router as health_router
from kubewatch.api.routes.snapshots import router as snapshots_router
from kubewatch.api.routes.status import router as status_router
from kubewatch.config import get_settings
from kubewatch.db.session import close_database


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    yield
    await close_database()


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(
        title=settings.app_name,
        version=__version__,
        lifespan=lifespan,
    )
    app.include_router(health_router)
    app.include_router(snapshots_router)
    app.include_router(status_router)
    return app


app = create_app()
