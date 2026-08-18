# Architecture

## 목표

KubeWatch는 URL 점검이라는 단순한 문제를 이용해 Kubernetes의 배포, 서비스
디스커버리, 상태 확인, 스케줄링, 영속성, 자동 확장을 순서대로 학습합니다.

## 컴포넌트 경계

- **Web**: React 사용자 인터페이스. API만 호출합니다.
- **API**: FastAPI로 모니터 설정과 측정 결과를 제공합니다.
- **Scheduler**: Python 프로세스로 실행 시점이 된 점검을 찾아 큐에 발행합니다.
- **Worker**: Python 프로세스로 URL을 점검하고 결과를 저장합니다.
- **PostgreSQL**: 모니터 설정과 측정 결과를 영속화합니다.
- **Redis**: Scheduler와 Worker 사이의 작업 큐로 사용합니다.

## 의존 방향

```text
Web -> API -> PostgreSQL
Scheduler -> PostgreSQL -> Redis -> Worker -> PostgreSQL
```

API, Scheduler, Worker는 `backend`의 도메인 코드를 공유하지만 서로의 실행
진입점에 의존하지 않습니다. Web은 Backend 내부 모듈을 import하지 않고
OpenAPI로 생성한 TypeScript 계약만 사용합니다.

## 배포 원칙

- 각 앱은 별도 이미지와 Deployment 또는 CronJob으로 배포합니다.
- 설정은 ConfigMap, 민감정보는 Secret으로 주입합니다.
- PostgreSQL은 로컬 학습 overlay에서만 StatefulSet/PVC로 실행하며, 상위 환경의
  DB 운영 방식은 환경별로 별도 결정합니다.
- 스키마 변경은 애플리케이션 rollout 전에 Alembic Job으로 적용합니다.
- 모든 장기 실행 앱에 startup/readiness/liveness probe를 둡니다.
- 로컬 환경은 Kustomize overlay로 시작하고 Helm은 구조가 안정된 뒤 도입합니다.
