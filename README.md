# KubeWatch

Kubernetes를 단계적으로 학습하기 위한 웹사이트 상태 모니터링 토이 프로젝트입니다.

사용자가 등록한 URL을 주기적으로 확인하고, HTTP 상태와 응답 시간을 저장해
대시보드로 보여주는 서비스를 목표로 합니다.

## 저장소 구조

```text
apps/
  api/          모니터 등록·조회 API
  scheduler/    점검 작업 생성
  worker/       URL 점검 실행
  web/          사용자 대시보드
packages/
  contracts/    서비스 간 요청·이벤트 계약
infra/
  k8s/
    base/       공통 Kubernetes 리소스
    overlays/   환경별 Kustomize 설정
docs/
  architecture.md
  roadmap.md
```

각 애플리케이션을 독립적으로 컨테이너화하고 배포할 수 있게 유지합니다. 공유
패키지에는 서비스 구현 코드를 넣지 않고, 경계를 넘는 계약만 둡니다.

## 현재 단계

지금은 패키지 경계와 Kubernetes 디렉터리만 확정한 상태입니다. 프레임워크와
데이터베이스를 붙이기 전에 작은 HTTP API를 배포해 Deployment, Service,
probe부터 학습합니다.

## 로컬 확인

Node.js 20 이상과 npm이 필요합니다.

```bash
npm install
npm run check
```

전체 학습 순서는 [docs/roadmap.md](docs/roadmap.md)를 참고하세요.
