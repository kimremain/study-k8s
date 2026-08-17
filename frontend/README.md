# KubeWatch Frontend

React, Vite, TypeScript 기반 대시보드입니다.

```bash
npm install
npm run check
npm run build
npm run dev
```

비밀이 아닌 빌드 설정은 `config/.env`의 공통값과 환경별 파일에서 관리합니다.

```text
config/.env       common
config/.env.loc   local
config/.env.dev   development
config/.env.stg   staging
config/.env.prd   production
```

Vite는 뒤쪽 환경 파일로 공통값을 덮어씁니다. 환경별 이미지는 다음 명령으로
생성하며 기본 `npm run build`는 production 빌드입니다.

```bash
npm run build:loc
npm run build:dev
npm run build:stg
npm run build:prd
```

Frontend 환경변수는 브라우저 번들에 포함되어 공개되므로 Secret을 저장하지 않습니다.
