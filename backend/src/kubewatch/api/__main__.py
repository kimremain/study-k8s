import uvicorn

from kubewatch.config import get_settings


def main() -> None:
    settings = get_settings()
    uvicorn.run(
        "kubewatch.api.app:create_app",
        factory=True,
        host=settings.host,
        port=settings.port,
        log_level=settings.log_level,
    )


if __name__ == "__main__":
    main()
