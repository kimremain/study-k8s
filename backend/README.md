# KubeWatch Backend

API, Scheduler, Worker가 같은 도메인 코드를 공유하는 Python 패키지입니다.

```bash
uv sync --dev
uv run ruff check .
uv run pytest
uv run kubewatch-api
```

아직 Scheduler와 Worker는 실행 경계만 있으며, Redis 큐를 도입하는 단계에서
구현합니다.
