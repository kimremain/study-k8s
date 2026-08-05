from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from kubewatch import __version__
from kubewatch.api.routes.health import router as health_router
from kubewatch.config import get_settings


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    app.state.ready = True
    yield
    app.state.ready = False


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(
        title=settings.app_name,
        version=__version__,
        lifespan=lifespan,
    )
    app.include_router(health_router)
    return app


app = create_app()
