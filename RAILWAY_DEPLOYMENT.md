# Railway 배포 가이드

## ✅ 배포 전 체크리스트

### 1. 완료된 준비사항
- [x] Ruby 버전 호환성 설정 (Ruby ~> 3.3)
- [x] Linux 플랫폼 추가 (x86_64-linux, aarch64-linux)
- [x] nixpacks.toml 구성
- [x] railway.toml 구성
- [x] 빌드 스크립트 생성 (bin/railway-build.sh)
- [x] 실행 권한 설정
- [x] Health check 라우트 구성
- [x] Nokogiri force_ruby_platform 설정

### 2. Railway 환경변수 설정 필요
```bash
# 필수 환경변수
RAILS_ENV=production
RAILS_MASTER_KEY=[config/master.key 파일 내용]
DATABASE_URL=${{Postgres.DATABASE_URL}}
RAILS_SERVE_STATIC_FILES=true
RAILS_LOG_TO_STDOUT=true

# 웹 스크래핑
BROWSERLESS_URL=[Browserless 서비스 URL]
USE_PLAYWRIGHT_OPPADU=true

# AI/이미지 처리
OPENROUTER_API_KEY=[OpenRouter API 키]

# 데이터 수집 API
STACKOVERFLOW_API_KEY=[StackOverflow API 키]
REDDIT_CLIENT_ID=[Reddit 클라이언트 ID]
REDDIT_CLIENT_SECRET=[Reddit 클라이언트 시크릿]
```

## 🚀 배포 순서

### 1. Railway 템플릿으로 PostgreSQL 배포
1. Railway Dashboard → New → Template
2. "pgvector" 검색 → 선택
3. 배포 대기

### 2. Rails 앱 연결
1. New → GitHub Repo → 레포지토리 선택
2. 환경변수 설정 (위 목록 참조)
3. Deploy 클릭

### 3. 배포 후 확인
1. 로그 확인: Railway Dashboard → Logs
2. Health check: https://[your-app].railway.app/health
3. 데이터베이스 마이그레이션 확인

## 🔧 문제 해결

### "bundler: not executable: bin/rails" 오류
```bash
chmod +x bin/rails
git add bin/rails
git commit -m "Make bin/rails executable"
git push
```

### pgvector extension 오류
Railway pgvector 템플릿 사용 시 자동 해결됨

### 메모리 부족
railway.toml에서 memoryReservationMB 증가

## 📊 모니터링

1. Railway Metrics 탭에서 CPU/메모리 사용량 확인
2. Logs 탭에서 실시간 로그 확인
3. Deployments 탭에서 배포 이력 확인

## 🎯 성공 지표

- [ ] Health check 응답 200 OK
- [ ] 데이터베이스 연결 성공
- [ ] Assets 정상 로드
- [ ] 데이터 수집 테스트 성공
- [ ] 이미지 처리 테스트 성공