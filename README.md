# KubeWatch

Kubernetes를 단계적으로 학습하기 위한 웹사이트 상태 모니터링 토이 프로젝트입니다.

사용자가 등록한 URL을 주기적으로 확인하고 HTTP 상태와 응답 시간을 저장해
대시보드로 보여주는 서비스를 목표로 합니다.

## 기술 구성

- Backend: Python 3.12, FastAPI, Pydantic, Uvicorn, uv
- Frontend: React, Vite, TypeScript
- Test/Lint: pytest, Ruff, TypeScript compiler
- Infrastructure: Kubernetes, Kustomize
- Persistence: PostgreSQL, PVC, SQLAlchemy, Alembic
- Later milestones: Redis, Dramatiq

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
- Resource snapshots: <http://127.0.0.1:8000/api/v1/resource-snapshots>

## Frontend 실행

```bash
cd frontend
npm install
npm run dev
```

## 로컬 이미지와 Kubernetes 배포

롤백할 수 있도록 `local` 같은 재사용 태그 대신 `v1`, `v2`처럼 버전마다 다른
이미지 태그를 사용합니다. 한 번 배포한 태그를 다른 내용으로 다시 빌드하지 않습니다.

첫 배포 전 PostgreSQL 비밀번호를 Kubernetes Secret으로 입력합니다. 비밀번호는
Git이나 PowerShell 명령 기록에 저장되지 않습니다.

```powershell
.\infra\scripts\set-local-database-secret.ps1
```

로컬 overlay는 PostgreSQL StatefulSet과 1Gi PVC를 만들고, 배포 스크립트는
Alembic migration Job이 성공한 뒤 애플리케이션 rollout을 완료합니다.

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

## GKE dev Frontend 배포

`dev` overlay는 GKE의 `kubewatch-dev` namespace에 Frontend Deployment와 내부
`ClusterIP` Service만 배포합니다. Backend, Cloud SQL, 외부 Load Balancer는 이
단계에 포함하지 않습니다.

Artifact Registry에 push된 이미지는 변경 가능한 태그 대신 digest로 지정합니다.
배포할 digest는 `infra/k8s/overlays/dev/kustomization.yaml`에 선언되어 있으므로
배포할 때 별도의 이미지 인자를 전달하지 않습니다.

```bash
./infra/scripts/deploy-dev-frontend.sh
```

스크립트는 Kustomize 렌더링과 client-side dry run을 먼저 수행하고, 적용 후
Deployment rollout과 실제 Pod template의 digest를 확인합니다.

## GKE dev Backend 이미지 빌드

Backend 이미지는 Cloud Build에서 빌드해 서울 리전 Artifact Registry에 push합니다.
빌드 스크립트는 현재 Git 커밋으로 태그를 만들며, 로컬 변경이 남아 있거나 현재
GCP 프로젝트가 `study-gcp-cicd`가 아니면 실행을 중단합니다.

```bash
./infra/scripts/build-dev-backend.sh
```

빌드가 성공하면 이후 Kustomize 배포에 사용할 수 있는 변경 불가능한 image digest를
출력합니다. 태그는 소스 추적용이며 실제 배포 설정에는 출력된 digest를 사용합니다.

## GKE dev Backend 배포

Backend는 전용 Kubernetes ServiceAccount와 Google Service Account를 Workload
Identity로 연결하고, Cloud SQL Auth Proxy sidecar를 통해 PostgreSQL에 접속합니다.
Google Service Account에는 `roles/cloudsql.client`만 부여합니다.

Cloud SQL의 `kubewatch` 데이터베이스와 사용자, 그리고
`kubewatch-dev/kubewatch-database-secret`을 먼저 만든 뒤 identity를 초기화합니다.

```bash
./infra/scripts/bootstrap-dev-backend-identity.sh
./infra/scripts/deploy-dev-backend.sh
```

배포 스크립트는 Secret과 immutable Backend image를 확인하고, Alembic migration
Job이 완료된 뒤 Backend rollout과 실제 Deployment image digest를 검증합니다.

## GKE dev Gateway 배포

Frontend와 Backend가 모두 준비된 뒤 GKE Gateway API를 활성화하고, 하나의 외부
주소에서 `/api/v1/status`만 Backend로, 나머지 경로는 Frontend로 전달할 수
있습니다. 데이터 조회·쓰기 API는 외부 Gateway를 통해 Backend에 도달하지 않습니다.
Gateway API 활성화 자체에는 별도 요금이 없지만 Gateway를 적용하면 public
Application Load Balancer와 관련 Compute Engine 리소스에 요금이 발생합니다.

```bash
./infra/scripts/bootstrap-dev-gateway.sh
./infra/scripts/deploy-dev-gateway.sh --confirm-public-load-balancer
```

dev Gateway는 `gke-l7-global-external-managed` GatewayClass를 사용합니다. HTTP만
열며 도메인과 TLS 인증서는 아직 구성하지 않습니다. 배포 스크립트는 Gateway와
HTTPRoute가 준비될 때까지 기다린 뒤 외부 주소의 Frontend와 `/api/v1/status`를
모두 검증합니다.

학습을 마치고 외부 Load Balancer를 제거할 때는 다음 명령을 실행합니다.

```bash
./infra/scripts/delete-dev-gateway.sh --confirm-delete-public-load-balancer
```

## 전체 확인

```bash
cd backend && uv run ruff check . && uv run pytest
cd frontend && npm run check && npm run build
```

전체 학습 순서는 [docs/roadmap.md](docs/roadmap.md)를 참고하세요.
