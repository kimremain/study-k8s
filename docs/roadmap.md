# Learning Roadmap

## 0. Repository skeleton

- FastAPI Backend와 React/Vite Frontend 경계 확정
- uv와 npm lockfile로 도구·의존성 고정
- Kustomize base/overlay 생성

## 1. First workload

- FastAPI와 `/healthz`, `/readyz` 구현
- 컨테이너 이미지 빌드
- kind에 Deployment와 ClusterIP Service 배포
- rollout, logs, exec, port-forward 실습

## 2. Configuration and ingress

- ConfigMap과 Secret 주입
- resource request/limit 및 probe 구성
- Ingress Controller와 로컬 호스트명 연결

## 3. Persistence

- PostgreSQL과 PVC 도입
- migration Job과 장애 복구 실습
- API 무중단 롤링 업데이트

## 4. Asynchronous checks

- Redis, Scheduler CronJob, Worker 도입
- 재시도와 멱등성 구현
- 큐 적체를 만들어 수평 확장 관찰

## 5. Operations

- Metrics Server와 HPA
- Prometheus/Grafana 및 로그 수집
- NetworkPolicy, PodDisruptionBudget, 백업 복원

## 6. Packaging and delivery

- Helm chart 작성
- GitHub Actions 이미지 빌드·테스트
- GitOps 기반 배포 실습
