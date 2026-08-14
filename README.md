# KubeWatch

Kubernetes를 단계적으로 학습하기 위한 웹사이트 상태 모니터링 토이 프로젝트입니다.

사용자가 등록한 URL을 주기적으로 확인하고 HTTP 상태와 응답 시간을 저장해
대시보드로 보여주는 서비스를 목표로 합니다.

## 기술 구성

- Backend: Python 3.12, FastAPI, Pydantic, Uvicorn, uv
- Frontend: React, Vite, TypeScript
- Test/Lint: pytest, Ruff, TypeScript compiler
- Infrastructure: Kubernetes, Kustomize
- Later milestones: PostgreSQL, Redis, SQLAlchemy, Alembic, Dramatiq

## 저장소 구조

```text
backend/
  src/kubewatch/
    api/          HTTP API와 probe
    domain/       프레임워크 독립 비즈니스 규칙
    scheduler/    점검 작업 생성 진입점
    worker/       URL 점검 실행 진입점
  tests/
frontend/         React 대시보드
infra/
  k8s/
    base/         공통 Kubernetes 리소스
    overlays/     환경별 Kustomize 설정
docs/             아키텍처와 학습 로드맵
```

Backend는 하나의 Python 패키지를 공유하지만 API, Worker, Scheduler를 서로 다른
프로세스와 Kubernetes workload로 실행합니다. 프런트 계약은 FastAPI OpenAPI
문서에서 TypeScript 타입과 클라이언트를 생성하는 방향으로 발전시킵니다.

## Backend 실행

```bash
cd backend
uv sync --dev
uv run kubewatch-api
```

- API: <http://127.0.0.1:8000>
- OpenAPI UI: <http://127.0.0.1:8000/docs>
- Liveness: <http://127.0.0.1:8000/healthz>
- Readiness: <http://127.0.0.1:8000/readyz>

## Frontend 실행

```bash
cd frontend
npm install
npm run dev
```

## 로컬 이미지와 Kubernetes 배포

롤백할 수 있도록 `local` 같은 재사용 태그 대신 `v1`, `v2`처럼 버전마다 다른
이미지 태그를 사용합니다. 한 번 배포한 태그를 다른 내용으로 다시 빌드하지 않습니다.

```powershell
.\infra\scripts\build-local.ps1 -ImageTag v1
.\infra\scripts\run-local.ps1 -ImageTag v1
.\infra\scripts\deploy-local.ps1 -ImageTag v1
```

새 버전을 배포한 뒤 이전 이미지로 되돌릴 때도 revision을 명령형으로 복원하지
않고, 검증된 이전 태그를 Kustomize로 다시 적용합니다.

```powershell
.\infra\scripts\build-local.ps1 -ImageTag v2
.\infra\scripts\deploy-local.ps1 -ImageTag v2
.\infra\scripts\rollback-local.ps1 -ImageTag v1
```

## 전체 확인

```bash
cd backend && uv run ruff check . && uv run pytest
cd frontend && npm run check && npm run build
```

전체 학습 순서는 [docs/roadmap.md](docs/roadmap.md)를 참고하세요.
