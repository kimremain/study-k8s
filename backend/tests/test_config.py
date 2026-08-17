from kubewatch.config import Settings

def test_settings_load_config_and_secret_from_environment(monkeypatch):
  monkeypatch.setenv("KUBEWATCH_APP_NAME", "KubeWatch Test")
  monkeypatch.setenv("KUBEWATCH_LOG_LEVEL", "warning")
  monkeypatch.setenv("KUBEWATCH_API_KEY", "local-test-key")
  settings = Settings()

  assert settings.app_name == "KubeWatch Test"
  assert settings.log_level == "warning"
  assert settings.api_key is not None
  assert settings.api_key.get_secret_value() == "local-test-key"

  # SecretStr must not expose the plaintext value through repr().
  assert "local-test-key" not in repr(settings)

def test_api_key_is_optional(monkeypatch):
  monkeypatch.delenv("KUBEWATCH_API_KEY", raising=False)

  settings = Settings()
  assert settings.api_key is None
