# 가짜 API 키로 Secret을 만들자:
kubectl create secret generic kubewatch-backend-secret `
  -n kubewatch `
  --from-literal=KUBEWATCH_API_KEY='lab-secret-123'

kubectl get secret kubewatch-backend-secret -n kubewatch


# 저장된 값을 확인해보자:
kubectl get secret kubewatch-backend-secret -n kubewatch `
  -o jsonpath="{.data.KUBEWATCH_API_KEY}"


# 출력은 평문이 아니라 Base64 형태일 거야. 디코딩하면 원문이 그대로 나온다:
$encoded = kubectl get secret kubewatch-backend-secret -n kubewatch `
  -o jsonpath="{.data.KUBEWATCH_API_KEY}"

[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encoded))


#클러스터 종류와 API Server 설정 노출 여부를 확인하자. Secret 값은 출력하지 않을 거야.

kubectl config current-context
kubectl get nodes -o wide
kubectl get pods -n kube-system -l component=kube-apiserver


#마지막 명령에서 API Server Pod가 보이면 암호화 설정 플래그를 확인해:

$apiPod = kubectl get pods -n kube-system `
  -l component=kube-apiserver `
  -o jsonpath="{.items[0].metadata.name}"
kubectl get pod $apiPod -n kube-system `
  -o jsonpath="{.spec.containers[0].command}" |
  Select-String "encryption-provider-config"


# 최소 권한 RBAC를 실습하자. 먼저 권한 없는 ServiceAccount를 생성해:

kubectl create serviceaccount secret-reader-lab -n kubewatch

kubectl auth can-i get secret/kubewatch-backend-secret `
  -n kubewatch `
  --as=system:serviceaccount:kubewatch:secret-reader-lab

# 예상 결과:
# no


# 특정 Secret 하나만 읽도록 Role과 RoleBinding을 생성해:
kubectl apply -f .\tmp\secret-reader-rbac.yaml


# 권한을 다시 확인해:

kubectl auth can-i get secret/kubewatch-backend-secret `
  -n kubewatch `
  --as=system:serviceaccount:kubewatch:secret-reader-lab

kubectl auth can-i list secrets `
  -n kubewatch `
  --as=system:serviceaccount:kubewatch:secret-reader-lab
