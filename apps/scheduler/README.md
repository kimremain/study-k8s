# Scheduler

점검 주기가 도래한 모니터를 찾아 작업 큐에 넣습니다.

초기에는 Kubernetes CronJob으로 실행하고, 이후 필요하면 상시 실행되는
스케줄러 Deployment와 비교합니다.
