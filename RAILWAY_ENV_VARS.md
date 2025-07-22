# Railway 환경 변수 설정 가이드

Railway 배포 시 설정해야 할 환경 변수 목록입니다.

## 필수 환경 변수

### Rails 기본 설정
```
RAILS_ENV=production
RAILS_MASTER_KEY=[config/master.key 파일의 내용]
RAILS_SERVE_STATIC_FILES=true
RAILS_LOG_TO_STDOUT=true
```

### 데이터베이스
```
DATABASE_URL=${{Postgres.DATABASE_URL}}
```

### Redis (선택사항)
```
REDIS_URL=${{Redis.REDIS_URL}}
```

### API 키
```
# OpenAI API (임베딩 생성용)
OPENAI_API_KEY=[OpenAI API 키를 여기에 입력]

# OpenRouter API (LLM 및 이미지 처리용)
OPENROUTER_API_KEY=[OpenRouter API 키를 여기에 입력]

# Stack Overflow API
STACKOVERFLOW_API_KEY=[Stack Overflow API 키를 여기에 입력]

# Reddit API
REDDIT_CLIENT_ID=[Reddit Client ID를 여기에 입력]
REDDIT_CLIENT_SECRET=[Reddit Client Secret을 여기에 입력]
```

### Python 서비스 (선택사항)
```
PYTHON_SERVICE_URL=http://localhost:8000
```

### Google OAuth (선택사항)
```
GOOGLE_CLIENT_ID=[Google Cloud Console에서 발급]
GOOGLE_CLIENT_SECRET=[Google Cloud Console에서 발급]
```

### 애플리케이션 URL
```
APP_URL=https://[your-app-name].railway.app
RAILWAY_STATIC_URL=https://[your-app-name].railway.app
```

## 설정 방법

1. Railway Dashboard에서 프로젝트 선택
2. Variables 탭 클릭
3. "Add Variable" 버튼으로 각 변수 추가
4. DATABASE_URL과 REDIS_URL은 Railway가 자동으로 제공하는 변수 선택

## 주의사항

- RAILS_MASTER_KEY는 반드시 로컬의 config/master.key 파일 내용과 일치해야 함
- API 키들은 외부에 노출되지 않도록 주의
- Production 환경에서는 새로운 SECRET_KEY_BASE 생성 권장:
  ```bash
  rails secret
  ```