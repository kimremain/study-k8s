New-Item -ItemType Directory -Force .\tmp | Out-Null

@'
spec:
  template:
    spec:
      containers:
        - name: backend
          readinessProbe:
            httpGet:
              path: /wrong-readyz
              port: http
'@ | Set-Content .\tmp\readiness-failure-patch.yaml -Encoding ascii


#패치 적용:

kubectl patch deployment/kubewatch-backend-local `
  -n kubewatch `
  --type=strategic `
  --patch-file .\tmp\readiness-failure-patch.yaml


# 적용됐는지 확인:
kubectl get deployment kubewatch-backend-local -n kubewatch `
  -o jsonpath="{.spec.template.spec.containers[0].readinessProbe.httpGet.path}"


# /wrong-readyz가 출력되면 성공이야. 이어서 관찰해봐:

kubectl get pods -n kubewatch -w


# 실습 후 복구:
.\infra\scripts\deploy-local.ps1 -ImageTag v1 -SkipPortForward
