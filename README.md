# Excel Unified

Excel 파일 분석 및 오류 해결을 위한 통합 플랫폼입니다.

## 주요 기능

### 1. Excel 분석
- 파일 구조 및 내용 분석
- 오류 탐지 및 자동 수정
- 데이터 시각화

### 2. AI 상담
- Excel 관련 질문 답변
- 맞춤형 해결책 제공
- 코드 생성 지원

### 3. VBA 오류 도우미 (NEW!)
- 90% 이상의 VBA 오류 즉시 해결
- 10개 주요 오류 패턴 커버
- 실시간 피드백 시스템
- 평균 응답 시간 < 200ms

### 4. 지식 베이스
- Stack Overflow, Reddit 등에서 수집한 실제 Q&A
- pgvector 기반 유사도 검색
- 지속적인 학습 및 개선

## 시스템 요구사항

- Ruby 3.3.0
- Rails 8.0.2
- PostgreSQL 14+ (pgvector 확장 필요)
- Node.js 18.x
- Redis (캐싱 및 백그라운드 작업용)

## 설치 방법

### 1. 저장소 클론
```bash
git clone https://github.com/your-repo/excel-unified.git
cd excel-unified/rails-app
```

### 2. 의존성 설치
```bash
bundle install
npm install
```

### 3. 데이터베이스 설정
```bash
bin/rails db:create
bin/rails db:migrate
```

### 4. 환경 변수 설정
```bash
# .env.local 파일 생성
OPENROUTER_API_KEY=your_api_key
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret
```

### 5. 개발 서버 실행
```bash
bin/dev
```

## VBA 도우미 사용법

### API 엔드포인트

#### 오류 해결
```bash
POST /api/v1/vba/solve
Content-Type: application/json

{
  "error_description": "Run-time error '1004'"
}
```

#### 피드백 전송
```bash
POST /api/v1/vba/feedback
Content-Type: application/json

{
  "error_type": "실행 시간 오류 '1004'",
  "solution_used": "ActiveSheet.Unprotect",
  "was_helpful": true
}
```

#### 자주 발생하는 패턴
```bash
GET /api/v1/vba/common_patterns
```

### 지원하는 VBA 오류

1. **Error 1004**: 응용 프로그램 정의 또는 개체 정의 오류
2. **Error 9**: 첨자가 범위를 벗어났습니다
3. **Error 13**: 형식이 일치하지 않습니다
4. **Error 424**: 개체가 필요합니다
5. **Error 91**: 개체 변수가 설정되지 않았습니다
6. **Error 438**: 속성 또는 메서드를 지원하지 않습니다
7. **Error 6**: 오버플로
8. **Compile Error**: 컴파일 오류
9. **ByRef Argument**: 인수 형식 불일치
10. **Performance Issues**: 성능 최적화

## 배포 (Railway)

### 사전 준비
- Railway CLI 설치
- Railway 계정 생성
- PostgreSQL, Redis 서비스 추가

### 배포 명령
```bash
railway up
```

### 환경 변수 설정
Railway 대시보드에서 다음 환경 변수 설정:
- `RAILS_MASTER_KEY`
- `OPENROUTER_API_KEY`
- `GOOGLE_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET`

자세한 내용은 [RAILWAY_DEPLOYMENT.md](RAILWAY_DEPLOYMENT.md) 참조

## 테스트

### 전체 테스트 실행
```bash
bundle exec rspec
```

### VBA 도우미 테스트
```bash
bin/rails vba_helper:quick_start
```

### 코드 품질 검사
```bash
bin/rubocop
bin/brakeman
```

## 아키텍처

### 도메인 주도 설계
- `authentication`: 사용자 인증
- `excel_analysis`: Excel 파일 분석
- `ai_consultation`: AI 상담 서비스
- `knowledge_base`: Q&A 지식 베이스
- `data_pipeline`: 데이터 수집 파이프라인

### 기술 스택
- **Backend**: Rails 8.0.2 (API mode)
- **Frontend**: Vue.js 3 + Vite
- **Database**: PostgreSQL + pgvector
- **Cache**: Redis
- **Background Jobs**: Sidekiq
- **Search**: pgvector + PostgreSQL FTS
- **AI**: OpenRouter (GPT-4, Claude, etc.)

## 성능 최적화

- 응답 캐싱 (Redis)
- 데이터베이스 인덱싱
- 비동기 작업 처리
- CDN 활용 (프로덕션)

## 기여 방법

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 라이선스

This project is licensed under the MIT License.

## 문의

- Issue Tracker: https://github.com/your-repo/excel-unified/issues
- Email: support@excel-unified.com