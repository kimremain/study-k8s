# KubeWatch Backend

API, Scheduler, Worker가 같은 도메인 코드를 공유하는 Python 패키지입니다.

```bash
uv sync --dev
uv run ruff check .
uv run pytest
uv run kubewatch-api
```

환경별 비밀이 아닌 설정은 `config/base/common.env`와
`config/overlays/{loc,dev,stg,prd}/*.env`에서 관리합니다. 로컬 프로세스는
환경 선택 변수만 지정하면 공통 설정 뒤에 해당 환경 설정을 적용합니다.

```powershell
$env:KUBEWATCH_ENV = "loc"
uv run kubewatch-api
```

실제 환경변수는 파일 값보다 우선합니다. `KUBEWATCH_API_KEY` 같은 비밀값은
이 파일에 저장하지 않고 로컬 비추적 파일이나 Secret 관리 시스템으로 주입합니다.

아직 Scheduler와 Worker는 실행 경계만 있으며, Redis 큐를 도입하는 단계에서
구현합니다.
