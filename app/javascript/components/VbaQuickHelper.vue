<template>
  <div class="vba-helper-widget bg-white rounded-lg shadow-md p-6 max-w-2xl mx-auto">
    <div class="mb-6">
      <h3 class="text-2xl font-bold text-gray-800 mb-2">VBA 오류 빠른 해결</h3>
      <p class="text-gray-600 text-sm">오류 메시지를 입력하면 즉시 해결책을 제공합니다</p>
    </div>

    <!-- 자주 발생하는 오류 빠른 선택 -->
    <div v-if="!showResults && commonPatterns.length > 0" class="mb-4">
      <p class="text-sm text-gray-600 mb-2">자주 발생하는 오류:</p>
      <div class="flex flex-wrap gap-2">
        <button
          v-for="pattern in commonPatterns"
          :key="pattern.key"
          @click="selectCommonPattern(pattern)"
          class="px-3 py-1 text-sm bg-blue-50 text-blue-700 rounded-full hover:bg-blue-100 transition-colors"
        >
          {{ pattern.message.split(':')[0] }}
          <span v-if="pattern.usage_count > 0" class="text-xs opacity-75">
            ({{ pattern.usage_count }}회)
          </span>
        </button>
      </div>
    </div>

    <!-- 오류 입력 영역 -->
    <div class="mb-4">
      <textarea
        v-model="errorDescription"
        @keydown.enter.ctrl="getSolution"
        placeholder="오류 메시지를 붙여넣으세요 (예: Run-time error '1004')"
        class="w-full p-3 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
        rows="4"
      />
      <div class="flex justify-between items-center mt-2">
        <span class="text-xs text-gray-500">
          Ctrl+Enter로 빠른 검색
        </span>
        <button
          @click="getSolution"
          :disabled="!errorDescription || loading"
          class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:bg-gray-400 disabled:cursor-not-allowed transition-colors"
        >
          <span v-if="loading" class="flex items-center">
            <svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            검색 중...
          </span>
          <span v-else>해결책 찾기</span>
        </button>
      </div>
    </div>

    <!-- 해결책 표시 영역 -->
    <div v-if="showResults && solution" class="space-y-4">
      <!-- 오류 유형 -->
      <div class="bg-gray-50 rounded-md p-4">
        <h4 class="font-semibold text-gray-800 mb-2">{{ solution.error_type }}</h4>
        
        <!-- 신뢰도 표시 -->
        <div class="flex items-center gap-2 mb-3">
          <div class="flex-1 bg-gray-200 rounded-full h-2">
            <div 
              :class="getConfidenceClass(solution.confidence)"
              :style="`width: ${solution.confidence * 100}%`"
              class="h-2 rounded-full transition-all duration-300"
            ></div>
          </div>
          <span class="text-sm text-gray-600">
            신뢰도: {{ (solution.confidence * 100).toFixed(0) }}%
          </span>
        </div>

        <!-- 해결 방법 -->
        <div class="space-y-2">
          <h5 class="font-medium text-gray-700">해결 방법:</h5>
          <ol class="list-decimal list-inside space-y-1">
            <li v-for="(fix, index) in solution.solutions" :key="index" class="text-gray-700">
              {{ fix }}
            </li>
          </ol>
        </div>
      </div>

      <!-- 예시 코드 (있을 경우) -->
      <div v-if="solution.example_code" class="bg-gray-900 rounded-md p-4">
        <div class="flex justify-between items-center mb-2">
          <h5 class="font-medium text-gray-200">예시 코드:</h5>
          <button
            @click="copyCode"
            class="text-xs px-2 py-1 bg-gray-700 text-gray-300 rounded hover:bg-gray-600 transition-colors"
          >
            {{ copied ? '복사됨!' : '복사' }}
          </button>
        </div>
        <pre class="text-sm text-gray-300 overflow-x-auto"><code>{{ solution.example_code }}</code></pre>
      </div>

      <!-- AI 추가 제안 (있을 경우) -->
      <div v-if="solution.ai_suggestion" class="bg-blue-50 border border-blue-200 rounded-md p-4">
        <div class="flex items-start">
          <span class="text-blue-500 mr-2">💡</span>
          <div>
            <h5 class="font-medium text-blue-900 mb-1">AI 추가 제안:</h5>
            <p class="text-blue-800">{{ solution.ai_suggestion }}</p>
          </div>
        </div>
      </div>

      <!-- 피드백 섹션 -->
      <div class="border-t pt-4">
        <p class="text-gray-700 mb-2">이 해결책이 도움이 되었나요?</p>
        <div class="flex gap-2">
          <button
            @click="sendFeedback(true)"
            :disabled="feedbackSent"
            class="flex-1 px-4 py-2 bg-green-50 text-green-700 border border-green-200 rounded-md hover:bg-green-100 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            👍 도움됨
          </button>
          <button
            @click="sendFeedback(false)"
            :disabled="feedbackSent"
            class="flex-1 px-4 py-2 bg-red-50 text-red-700 border border-red-200 rounded-md hover:bg-red-100 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            👎 도움 안됨
          </button>
        </div>
        
        <!-- 추가 피드백 입력 (도움 안됨 선택 시) -->
        <div v-if="showFeedbackInput" class="mt-3">
          <textarea
            v-model="feedbackText"
            placeholder="어떤 부분이 도움이 되지 않았나요?"
            class="w-full p-2 text-sm border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500"
            rows="2"
          />
          <button
            @click="submitDetailedFeedback"
            class="mt-2 px-3 py-1 text-sm bg-blue-600 text-white rounded-md hover:bg-blue-700"
          >
            피드백 전송
          </button>
        </div>
      </div>

      <!-- 새로운 검색 버튼 -->
      <button
        @click="resetSearch"
        class="w-full px-4 py-2 bg-gray-100 text-gray-700 rounded-md hover:bg-gray-200 transition-colors"
      >
        새로운 오류 검색
      </button>
    </div>

    <!-- 오류 메시지 -->
    <div v-if="error" class="mt-4 p-4 bg-red-50 border border-red-200 rounded-md">
      <p class="text-red-700">{{ error }}</p>
    </div>
  </div>
</template>

<script>
import { ref, onMounted } from 'vue'
import { useToast } from '@/composables/useToast'
import api from '@/services/api'

export default {
  name: 'VbaQuickHelper',
  
  setup() {
    const { showToast } = useToast()
    
    // 상태
    const errorDescription = ref('')
    const solution = ref(null)
    const loading = ref(false)
    const error = ref('')
    const showResults = ref(false)
    const feedbackSent = ref(false)
    const showFeedbackInput = ref(false)
    const feedbackText = ref('')
    const copied = ref(false)
    const commonPatterns = ref([])
    
    // 자주 발생하는 패턴 로드
    const loadCommonPatterns = async () => {
      try {
        const response = await api.get('/vba/common_patterns')
        if (response.data.success) {
          commonPatterns.value = response.data.patterns
        }
      } catch (err) {
        console.error('Failed to load common patterns:', err)
      }
    }
    
    // 일반 패턴 선택
    const selectCommonPattern = (pattern) => {
      errorDescription.value = pattern.message
      getSolution()
    }
    
    // 해결책 검색
    const getSolution = async () => {
      if (!errorDescription.value.trim()) {
        error.value = '오류 설명을 입력해주세요'
        return
      }
      
      loading.value = true
      error.value = ''
      
      try {
        const response = await api.post('/vba/solve', {
          error_description: errorDescription.value
        })
        
        if (response.data.success) {
          solution.value = response.data.data
          showResults.value = true
          feedbackSent.value = false
          showFeedbackInput.value = false
        } else {
          error.value = response.data.error || '해결책을 찾을 수 없습니다'
        }
      } catch (err) {
        error.value = '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.'
        console.error('VBA Helper error:', err)
      } finally {
        loading.value = false
      }
    }
    
    // 피드백 전송
    const sendFeedback = async (helpful) => {
      if (!solution.value || feedbackSent.value) return
      
      if (!helpful) {
        showFeedbackInput.value = true
        return
      }
      
      await submitFeedback(helpful)
    }
    
    // 상세 피드백 전송
    const submitDetailedFeedback = async () => {
      await submitFeedback(false, feedbackText.value)
      showFeedbackInput.value = false
    }
    
    // 피드백 제출
    const submitFeedback = async (helpful, text = '') => {
      try {
        const response = await api.post('/vba/feedback', {
          error_type: solution.value.error_type,
          solution_used: solution.value.solutions?.[0] || '',
          was_helpful: helpful,
          confidence: solution.value.confidence,
          match_type: solution.value.match_type,
          feedback_text: text
        })
        
        if (response.data.success) {
          showToast(response.data.message, 'success')
          feedbackSent.value = true
        }
      } catch (err) {
        console.error('Feedback error:', err)
        showToast('피드백 전송 중 오류가 발생했습니다', 'error')
      }
    }
    
    // 코드 복사
    const copyCode = async () => {
      if (!solution.value?.example_code) return
      
      try {
        await navigator.clipboard.writeText(solution.value.example_code)
        copied.value = true
        setTimeout(() => {
          copied.value = false
        }, 2000)
      } catch (err) {
        showToast('복사 실패. 수동으로 복사해주세요.', 'error')
      }
    }
    
    // 검색 초기화
    const resetSearch = () => {
      errorDescription.value = ''
      solution.value = null
      showResults.value = false
      feedbackSent.value = false
      showFeedbackInput.value = false
      feedbackText.value = ''
      error.value = ''
    }
    
    // 신뢰도에 따른 색상 클래스
    const getConfidenceClass = (confidence) => {
      if (confidence >= 0.8) return 'bg-green-500'
      if (confidence >= 0.6) return 'bg-yellow-500'
      return 'bg-red-500'
    }
    
    // 컴포넌트 마운트 시 패턴 로드
    onMounted(() => {
      loadCommonPatterns()
    })
    
    return {
      errorDescription,
      solution,
      loading,
      error,
      showResults,
      feedbackSent,
      showFeedbackInput,
      feedbackText,
      copied,
      commonPatterns,
      getSolution,
      sendFeedback,
      submitDetailedFeedback,
      copyCode,
      resetSearch,
      getConfidenceClass,
      selectCommonPattern
    }
  }
}
</script>

<style scoped>
/* 애니메이션 효과 */
.vba-helper-widget {
  animation: fadeIn 0.3s ease-in;
}

@keyframes fadeIn {
  from {
    opacity: 0;
    transform: translateY(10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

/* 코드 블록 스타일 */
pre {
  white-space: pre-wrap;
  word-wrap: break-word;
}

/* 스크롤바 스타일 */
pre::-webkit-scrollbar {
  height: 6px;
}

pre::-webkit-scrollbar-track {
  background: #374151;
}

pre::-webkit-scrollbar-thumb {
  background: #6B7280;
  border-radius: 3px;
}

pre::-webkit-scrollbar-thumb:hover {
  background: #9CA3AF;
}
</style>