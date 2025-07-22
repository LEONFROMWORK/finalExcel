# PrimeVue Integration Plan

## 현재 상황 분석

### 기존 기술 스택
- **Frontend Framework**: Vue.js 3 with Vite
- **CSS Framework**: Tailwind CSS (tailwindcss-rails gem)
- **Build Tool**: Vite with vite-plugin-ruby
- **State Management**: Pinia
- **Router**: Vue Router

### 프로젝트 구조
- Vertical Slice Architecture with Domain-Driven Design
- 5개 도메인: authentication, excel_analysis, knowledge_base, ai_consultation, data_pipeline

## PrimeVue 통합 전략

### 1단계: 디자인 시스템 결정
PrimeFlex는 2024년 기준으로 더 이상 적극적으로 유지보수되지 않으며, PrimeTek 팀에서도 Tailwind CSS 사용을 권장하고 있습니다.

**권장 접근 방식:**
- PrimeVue 컴포넌트 라이브러리 사용
- Tailwind CSS를 기본 유틸리티 프레임워크로 유지
- PrimeVue의 Tailwind 통합 플러그인 활용

### 2단계: 설치 계획

#### 필요한 패키지
```bash
# PrimeVue 핵심 패키지
npm install primevue @primeuix/themes

# PrimeVue Icons (선택사항)
npm install primeicons

# Tailwind CSS 통합 (선택사항)
npm install tailwindcss-primeui
```

#### Vite 설정 업데이트
`vite.config.ts`에 특별한 설정 변경은 필요하지 않음

### 3단계: 구성 및 설정

#### Main Application 설정
```javascript
// app/javascript/entrypoints/application.js 수정
import { createApp } from 'vue'
import { createPinia } from 'pinia'
import router from '@/router'
import App from '@/App.vue'
import PrimeVue from 'primevue/config'
import Aura from '@primeuix/themes/aura'

// Import Tailwind styles
import '@/styles/application.css'

// Import PrimeVue styles (선택사항)
import 'primeicons/primeicons.css'

const app = createApp(App)

// PrimeVue 설정
app.use(PrimeVue, {
  theme: {
    preset: Aura,
    options: {
      darkModeSelector: '.dark',
      cssLayer: {
        name: 'primevue',
        order: 'tailwind-base, primevue, tailwind-utilities'
      }
    }
  }
})

app.use(createPinia())
app.use(router)
```

#### Tailwind CSS 통합 설정
```javascript
// tailwind.config.js 생성
module.exports = {
  content: [
    './app/javascript/**/*.{js,vue}',
    './app/views/**/*.html.erb',
    './node_modules/primevue/**/*.{vue,js,ts,jsx,tsx}'
  ],
  plugins: [
    require('tailwindcss-primeui')
  ],
  // PrimeVue와의 충돌 방지
  corePlugins: {
    preflight: false // PrimeVue 스타일과 충돌 방지
  }
}
```

### 4단계: 컴포넌트 마이그레이션 전략

#### 우선순위별 마이그레이션
1. **High Priority (즉시 변경)**
   - Button 컴포넌트
   - Form 입력 요소 (Input, Select, Checkbox)
   - Modal/Dialog
   - Table/DataTable

2. **Medium Priority (단계적 변경)**
   - Navigation 컴포넌트
   - Card 컴포넌트
   - Loading indicators
   - Toast/Notification

3. **Low Priority (필요시 변경)**
   - 커스텀 스타일링된 컴포넌트
   - 특수 목적 컴포넌트

#### 도메인별 적용 계획

**1. Authentication 도메인**
- LoginForm.vue: PrimeVue InputText, Password, Button 적용
- OAuth 버튼: PrimeVue Button with custom styling

**2. Excel Analysis 도메인**
- FileUploader.vue: PrimeVue FileUpload 컴포넌트 사용
- 결과 테이블: PrimeVue DataTable 적용

**3. Knowledge Base 도메인**
- SearchBox.vue: PrimeVue InputText with search icon
- QA 목록: PrimeVue DataView or Card 컴포넌트

**4. AI Consultation 도메인**
- ChatInterface.vue: 기존 유지 (특수 UI)
- ChatMessage.vue: PrimeVue Card 활용 가능

**5. Data Pipeline 도메인**
- TaskList.vue: PrimeVue DataTable with status badges
- CreateTaskModal.vue: PrimeVue Dialog 사용

### 5단계: 구현 로드맵

#### Phase 1: 기초 설정 (1-2일)
- [ ] PrimeVue 패키지 설치
- [ ] Main application 파일 설정
- [ ] 테마 구성 및 커스터마이징
- [ ] 샘플 컴포넌트로 통합 테스트

#### Phase 2: 핵심 컴포넌트 교체 (3-5일)
- [ ] 공통 컴포넌트 (Button, Input) 마이그레이션
- [ ] Form 관련 컴포넌트 업데이트
- [ ] Modal/Dialog 컴포넌트 교체
- [ ] 각 도메인별 주요 컴포넌트 1개씩 적용

#### Phase 3: 전체 마이그레이션 (1-2주)
- [ ] 모든 도메인 컴포넌트 순차적 업데이트
- [ ] 커스텀 스타일링 조정
- [ ] 다크 모드 지원 추가
- [ ] 성능 최적화

#### Phase 4: 최적화 및 정리 (3-5일)
- [ ] 미사용 Tailwind 클래스 제거
- [ ] PrimeVue 컴포넌트 tree-shaking 최적화
- [ ] 문서화 및 가이드라인 작성
- [ ] 팀 교육 자료 준비

### 6단계: 주의사항 및 고려사항

#### 기술적 고려사항
1. **번들 크기**: PrimeVue 전체를 import하지 않고 필요한 컴포넌트만 개별 import
2. **스타일 충돌**: Tailwind reset과 PrimeVue 기본 스타일 간 충돌 주의
3. **테마 일관성**: 기존 오렌지색 브랜드 컬러를 PrimeVue 테마에 반영
4. **성능**: 대용량 데이터를 다루는 DataTable의 경우 가상 스크롤링 활용

#### 비즈니스 고려사항
1. **사용자 경험**: UI 변경 최소화로 사용자 혼란 방지
2. **점진적 배포**: 도메인별로 단계적 배포
3. **롤백 계획**: 문제 발생시 이전 버전으로 빠른 복구

### 7단계: 예상 효과

#### 장점
- 일관된 디자인 시스템
- 풍부한 UI 컴포넌트 (80+ 컴포넌트)
- 접근성(Accessibility) 기본 지원
- 테마 커스터마이징 용이
- 활발한 커뮤니티 및 지원

#### 단점
- 초기 번들 크기 증가 (최적화로 해결 가능)
- 학습 곡선
- 기존 커스텀 스타일과의 조정 필요

## 결론

PrimeVue는 현재 프로젝트에 적합한 선택입니다. Vite와의 완벽한 호환성, Vue 3 지원, 그리고 Tailwind CSS와의 통합 가능성을 고려할 때, 점진적이고 체계적인 마이그레이션을 통해 더 나은 사용자 경험과 개발 생산성을 달성할 수 있을 것으로 예상됩니다.

**다음 단계**: Phase 1 기초 설정부터 시작하여 단계별로 진행하는 것을 권장합니다.