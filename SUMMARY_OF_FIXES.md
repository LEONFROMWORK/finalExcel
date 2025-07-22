# 이미지 처리 및 데이터 수집 개선 요약

## 완료된 작업 목록

### 1. 이미지 처리 시스템 개선
- ✅ Base64 이미지 처리 구현
- ✅ 3-tier 이미지 처리 시스템 (OCR → Table Detection → AI Enhancement)
- ✅ OpenRouter API 통합 (API Key: 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)
- ✅ 캐시 최적화 - base64 이미지와 오류 응답은 캐시하지 않음
- ✅ MIME 타입 자동 감지
- ✅ 이미지 크기 최적화 (최대 768x2000px)
- ✅ 재시도 로직 with exponential backoff
- ✅ 'detail: high' 파라미터 추가로 더 나은 분석

### 2. Oppadu 수집기 개선
- ✅ Enhanced Selenium 수집기 구현 (페이지네이션 지원)
- ✅ 타임아웃 처리 개선 (60초 제한)
- ✅ 경량 HTTP 수집기 구현 (Selenium 실패 시 fallback)
- ✅ Nokogiri 기반 수집 (최종 fallback)
- ✅ 재시도 로직 (최대 3회, exponential backoff)
- ✅ WebDriverWait으로 명시적 대기

### 3. 다른 플랫폼 개선
- ✅ Stack Overflow: 모든 답변 수집 (accepted + 높은 점수)
- ✅ Reddit: 봇 댓글 필터링
- ✅ MrExcel: 새로운 수집기 추가
- ✅ 품질 점수 계산 로직 개선

### 4. 데이터 관리
- ✅ 중복 제거 시스템
- ✅ 일일 파일 누적 기능
- ✅ JSON 파일 기반 저장
- ✅ 데이터베이스 임포트 스크립트

## 알려진 문제 및 해결 방법

### 1. OpenRouter 이미지 분석 오류
일부 이미지에서 "I'm unable to analyze" 메시지가 반환됨:
- 원인: 특정 이미지 형식이나 API 제한
- 해결: 재시도 로직, 이미지 최적화, 대체 모델 사용

### 2. Oppadu 타임아웃
Selenium 수집 시 타임아웃 발생:
- 원인: 사이트 응답 속도 또는 JavaScript 렌더링 지연
- 해결: 타임아웃 설정, fallback 수집기, 명시적 대기

## 사용 방법

### 개별 플랫폼 수집
```ruby
# 특정 플랫폼만 수집
collector = PlatformDataCollector.new('oppadu')
result = collector.collect_data(30)
```

### 모든 플랫폼 수집
```ruby
bundle exec ruby final_collection_all_platforms.rb
```

### 데이터베이스 임포트
```ruby
bundle exec ruby lib/tasks/scripts/import_collected_to_db.rb
```

## 환경 변수
```bash
# .env 파일에 추가
OPENROUTER_API_KEY=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
USE_ENHANCED_SELENIUM=true  # Enhanced Selenium 사용 (옵션)
```

## 추가 개선 사항 제안

1. **이미지 처리**
   - Claude 3.5 Sonnet 또는 다른 비전 모델 테스트
   - 이미지 전처리 (contrast, brightness 조정)
   - OCR 품질 개선

2. **수집 성능**
   - 병렬 처리 구현
   - 비동기 수집
   - 더 많은 fallback 옵션

3. **데이터 품질**
   - 자동 품질 검증
   - 중복 감지 개선
   - 메타데이터 추가 수집

## 테스트 명령어

```bash
# 캐시 초기화
Rails.cache.clear

# Oppadu 테스트
bundle exec ruby test_oppadu_final.rb

# 전체 수집
bundle exec ruby clear_and_recollect_all.rb

# 경량 수집기 테스트
bundle exec ruby test_lightweight_oppadu.rb
```

## 모니터링

로그 확인:
```bash
tail -f log/development.log | grep -E "(Collected|Failed|Image processing|Timeout)"
```

## 참고사항

- 이미지 처리는 비용이 발생할 수 있음 (OpenRouter API)
- Selenium은 Chrome/Chromium이 설치되어 있어야 함
- 일부 사이트는 스크래핑 방지 기능이 있을 수 있음