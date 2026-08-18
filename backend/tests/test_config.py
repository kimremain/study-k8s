import pytest

from kubewatch.config import Settings, get_environment_files, get_settings


def test_settings_load_config_and_secret_from_environment(monkeypatch):
  monkeypatch.setenv("KUBEWATCH_APP_NAME", "KubeWatch Test")
  monkeypatch.setenv("KUBEWATCH_LOG_LEVEL", "warning")
  monkeypatch.setenv("KUBEWATCH_API_KEY", "local-test-key")
  monkeypatch.setenv("KUBEWATCH_DATABASE_PASSWORD", "database-test-password")
  settings = Settings()

  assert settings.app_name == "KubeWatch Test"
  assert settings.log_level == "warning"
  assert settings.api_key is not None
  assert settings.api_key.get_secret_value() == "local-test-key"
  assert settings.database_password is not None
  assert settings.database_password.get_secret_value() == "database-test-password"

  # SecretStr must not expose the plaintext value through repr().
  assert "local-test-key" not in repr(settings)
  assert "database-test-password" not in repr(settings)

def test_api_key_is_optional(monkeypatch):
  monkeypatch.delenv("KUBEWATCH_API_KEY", raising=False)

  settings = Settings()
  assert settings.api_key is None


def test_local_environment_loads_common_and_local_files(monkeypatch):
  monkeypatch.setenv("KUBEWATCH_ENV", "loc")
  monkeypatch.delenv("KUBEWATCH_APP_NAME", raising=False)
  monkeypatch.delenv("KUBEWATCH_HOST", raising=False)
  monkeypatch.delenv("KUBEWATCH_PORT", raising=False)
  monkeypatch.delenv("KUBEWATCH_LOG_LEVEL", raising=False)
  get_settings.cache_clear()

  settings = get_settings()

  assert settings.app_name == "KubeWatch API Local"
  assert settings.host == "0.0.0.0"
  assert settings.port == 8000
  assert settings.log_level == "debug"
  get_settings.cache_clear()


def test_environment_variable_overrides_environment_file(monkeypatch):
  monkeypatch.setenv("KUBEWATCH_ENV", "prd")
  monkeypatch.setenv("KUBEWATCH_LOG_LEVEL", "critical")
  get_settings.cache_clear()

  settings = get_settings()

  assert settings.log_level == "critical"
  get_settings.cache_clear()


def test_unknown_environment_is_rejected():
  with pytest.raises(ValueError, match="Unsupported KUBEWATCH_ENV"):
    get_environment_files("unknown")
