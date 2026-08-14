# requests: Pod가 필요하다고 예약하는 최소 자원. 스케줄러가 노드 배치를 결정할 때 사용
# limits: 컨테이너가 사용할 수 있는 최대 자원
# CPU limit 초과: 실행 속도가 제한됨(throttling)
# Memory limit 초과: 컨테이너가 종료되어 OOMKilled 발생

# 현재 Pod의 QoS 등급을 확인:

$pod = kubectl get pods -n kubewatch `
  -l app.kubernetes.io/name=kubewatch-backend `
  -o jsonpath="{.items[0].metadata.name}"

kubectl get pod $pod -n kubewatch `
  -o jsonpath="{.status.qosClass}"

# QoS 등급은 세 가지:
# BestEffort: requests/limits가 전혀 없음. 자원 부족 시 가장 먼저 퇴출될 수 있음
# Burstable: 일부 requests/limits를 지정하거나 서로 다르게 설정
# Guaranteed: 모든 컨테이너의 CPU·메모리 request와 limit이 동일

# Burstable 패치 적용
kubectl patch deployment/kubewatch-backend-local `
  -n kubewatch `
  --type=strategic `
  --patch-file .\tmp\resources-burstable-patch.yaml

kubectl rollout status deployment/kubewatch-backend-local -n kubewatch

# 새 Pod와 QoS 확인
$pod = kubectl get pods -n kubewatch `
  -l app.kubernetes.io/name=kubewatch-backend `
  -o jsonpath="{.items[0].metadata.name}"

kubectl get pod $pod -n kubewatch `
  -o jsonpath="{.status.qosClass}"

kubectl describe pod $pod -n kubewatch

# Guaranteed 패치 적용
kubectl patch deployment/kubewatch-backend-local `
  -n kubewatch `
  --type=strategic `
  --patch-file .\tmp\resources-guaranteed-patch.yaml
kubectl rollout status deployment/kubewatch-backend-local -n kubewatch

$pod = kubectl get pods -n kubewatch `
  -l app.kubernetes.io/name=kubewatch-backend `
  -o jsonpath="{.items[0].metadata.name}"

kubectl get pod $pod -n kubewatch `
  -o jsonpath="{.status.qosClass}"
