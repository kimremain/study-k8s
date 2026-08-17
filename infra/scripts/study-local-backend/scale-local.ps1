# Pod를 3개로 확장
kubectl scale deployment/kubewatch-backend-local -n kubewatch --replicas=3

kubectl get pods -n kubewatch -w

# Running Pod 하나의 이름을 복사해서 강제 삭제:
kubectl delete pod <pod-name> -n kubewatch

# Kubernetes가 자동으로 새 Pod를 생성하는지 관찰
kubectl get pods -n kubewatch -w

# 1개로 복구
kubectl scale deployment/kubewatch-backend-local -n kubewatch --replicas=1
