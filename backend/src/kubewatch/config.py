from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "KubeWatch API"
    host: str = "0.0.0.0"
    port: int = 8000
    log_level: str = "info"

    model_config = SettingsConfigDict(
        env_prefix="KUBEWATCH_",
        case_sensitive=False,
        extra="ignore",
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()
