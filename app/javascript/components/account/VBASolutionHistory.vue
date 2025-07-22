<template>
  <div class="vba-solution-history">
    <!-- Stats Overview -->
    <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
      <div class="bg-white rounded-xl shadow-sm p-6 text-center">
        <div class="text-3xl font-bold text-gray-900 mb-1">{{ totalSolutions }}</div>
        <div class="text-sm text-gray-600">총 해결 수</div>
      </div>
      <div class="bg-white rounded-xl shadow-sm p-6 text-center">
        <div class="text-3xl font-bold text-green-600 mb-1">{{ successRate }}%</div>
        <div class="text-sm text-gray-600">성공률</div>
      </div>
      <div class="bg-white rounded-xl shadow-sm p-6 text-center">
        <div class="text-3xl font-bold text-blue-600 mb-1">{{ averageTime }}</div>
        <div class="text-sm text-gray-600">평균 해결시간</div>
      </div>
      <div class="bg-white rounded-xl shadow-sm p-6 text-center">
        <div class="text-3xl font-bold text-purple-600 mb-1">{{ savedCredits }}</div>
        <div class="text-sm text-gray-600">절약한 크레딧</div>
      </div>
    </div>

    <!-- Filter and Search -->
    <div class="bg-white rounded-2xl shadow-sm p-6 mb-6">
      <div class="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
        <h3 class="text-xl font-bold text-gray-900">VBA 해결 내역</h3>
        
        <div class="flex gap-3">
          <div class="relative">
            <input
              v-model="searchQuery"
              type="text"
              placeholder="오류 검색..."
              class="pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent"
            >
            <svg class="absolute left-3 top-2.5 w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
            </svg>
          </div>
          
          <select
            v-model="filterType"
            class="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent"
          >
            <option value="all">모든 오류</option>
            <option value="runtime">런타임 오류</option>
            <option value="compile">컴파일 오류</option>
            <option value="logic">로직 오류</option>
            <option value="solved">해결됨</option>
            <option value="pending">대기중</option>
          </select>
        </div>
      </div>
    </div>

    <!-- Solutions List -->
    <div v-if="filteredSolutions.length > 0" class="space-y-4">
      <div
        v-for="solution in filteredSolutions"
        :key="solution.id"
        class="bg-white rounded-2xl shadow-sm hover:shadow-md transition-all duration-300"
      >
        <div class="p-6">
          <!-- Error Header -->
          <div class="flex items-start justify-between mb-4">
            <div class="flex-1">
              <div class="flex items-center gap-3 mb-2">
                <span :class="getErrorTypeClass(solution.error_type)" class="px-3 py-1 text-xs font-medium rounded-full">
                  {{ getErrorTypeLabel(solution.error_type) }}
                </span>
                <span :class="getSolutionStatusClass(solution.solution_type)" class="px-3 py-1 text-xs font-medium rounded-full">
                  {{ getSolutionStatusLabel(solution.solution_type) }}
                </span>
                <div v-if="solution.was_helpful !== null" class="flex items-center gap-1">
                  <svg v-if="solution.was_helpful" class="w-5 h-5 text-green-500" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M2 10.5a1.5 1.5 0 113 0v6a1.5 1.5 0 01-3 0v-6zM6 10.333v5.43a2 2 0 001.106 1.79l.05.025A4 4 0 008.943 18h5.416a2 2 0 001.962-1.608l1.2-6A2 2 0 0015.56 8H12V4a2 2 0 00-2-2 1 1 0 00-1 1v.667a4 4 0 01-.8 2.4L6.8 7.933a4 4 0 00-.8 2.4z"></path>
                  </svg>
                  <svg v-else class="w-5 h-5 text-red-500" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M18 9.5a1.5 1.5 0 11-3 0v-6a1.5 1.5 0 013 0v6zM14 9.667v-5.43a2 2 0 00-1.105-1.79l-.05-.025A4 4 0 0011.055 2H5.64a2 2 0 00-1.962 1.608l-1.2 6A2 2 0 004.44 12H8v4a2 2 0 002 2 1 1 0 001-1v-.667a4 4 0 01.8-2.4l1.4-1.866a4 4 0 00.8-2.4z"></path>
                  </svg>
                </div>
              </div>
              
              <h4 class="text-lg font-semibold text-gray-900 mb-2">
                오류 {{ solution.error_code || solution.error_message.split(':')[0] }}
              </h4>
              
              <p class="text-gray-700 font-mono text-sm bg-gray-50 rounded-lg p-3 mb-3">
                {{ solution.error_message }}
              </p>
            </div>
          </div>

          <!-- Solution Details -->
          <div v-if="expandedSolutions.includes(solution.id)" class="space-y-4">
            <!-- Problem Code -->
            <div v-if="solution.problem_code">
              <h5 class="text-sm font-medium text-gray-700 mb-2">문제 코드:</h5>
              <pre class="bg-red-50 border border-red-200 rounded-lg p-4 text-sm overflow-x-auto">
                <code class="language-vb">{{ solution.problem_code }}</code>
              </pre>
            </div>
            
            <!-- Solution -->
            <div v-if="solution.solution">
              <h5 class="text-sm font-medium text-gray-700 mb-2">해결 방법:</h5>
              <div class="bg-green-50 border border-green-200 rounded-lg p-4">
                <p class="text-gray-700 whitespace-pre-wrap">{{ solution.solution }}</p>
              </div>
            </div>
            
            <!-- Fixed Code -->
            <div v-if="solution.fixed_code">
              <h5 class="text-sm font-medium text-gray-700 mb-2">수정된 코드:</h5>
              <pre class="bg-green-50 border border-green-200 rounded-lg p-4 text-sm overflow-x-auto">
                <code class="language-vb">{{ solution.fixed_code }}</code>
              </pre>
            </div>
          </div>

          <!-- Actions -->
          <div class="flex items-center justify-between mt-4">
            <div class="flex items-center gap-2 text-sm text-gray-500">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
              </svg>
              <span>{{ formatDate(solution.created_at) }}</span>
              <span v-if="solution.resolution_time" class="ml-3">
                • {{ formatResolutionTime(solution.resolution_time) }} 소요
              </span>
            </div>
            
            <div class="flex gap-2">
              <button
                @click="toggleExpand(solution.id)"
                class="px-4 py-2 text-sm font-medium text-purple-600 hover:bg-purple-50 rounded-lg transition-colors"
              >
                {{ expandedSolutions.includes(solution.id) ? '접기' : '자세히 보기' }}
              </button>
              
              <div v-if="solution.was_helpful === null" class="flex gap-1">
                <button
                  @click="$emit('rate', { id: solution.id, helpful: true })"
                  class="px-3 py-2 text-sm font-medium text-gray-600 hover:bg-gray-100 rounded-lg transition-colors"
                  title="도움이 되었어요"
                >
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 10h4.764a2 2 0 011.789 2.894l-3.5 7A2 2 0 0115.263 21h-4.017c-.163 0-.326-.02-.485-.06L7 20m7-10V5a2 2 0 00-2-2h-.095c-.5 0-.905.405-.905.905 0 .714-.211 1.412-.608 2.006L7 11v9m7-10h-2M7 20H5a2 2 0 01-2-2v-6a2 2 0 012-2h2.5"></path>
                  </svg>
                </button>
                <button
                  @click="$emit('rate', { id: solution.id, helpful: false })"
                  class="px-3 py-2 text-sm font-medium text-gray-600 hover:bg-gray-100 rounded-lg transition-colors"
                  title="도움이 안 되었어요"
                >
                  <svg class="w-5 h-5 rotate-180" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 10h4.764a2 2 0 011.789 2.894l-3.5 7A2 2 0 0115.263 21h-4.017c-.163 0-.326-.02-.485-.06L7 20m7-10V5a2 2 0 00-2-2h-.095c-.5 0-.905.405-.905.905 0 .714-.211 1.412-.608 2.006L7 11v9m7-10h-2M7 20H5a2 2 0 01-2-2v-6a2 2 0 012-2h2.5"></path>
                  </svg>
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Empty State -->
    <div v-else class="bg-white rounded-2xl shadow-sm p-12 text-center">
      <div class="w-20 h-20 bg-purple-100 rounded-full flex items-center justify-center mx-auto mb-4">
        <svg class="w-10 h-10 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"></path>
        </svg>
      </div>
      <h4 class="text-lg font-medium text-gray-900 mb-2">VBA 해결 내역이 없습니다</h4>
      <p class="text-sm text-gray-500 mb-6">VBA 오류를 해결하면 여기에 표시됩니다</p>
      <button
        @click="$router.push('/vba-helper')"
        class="px-6 py-3 bg-purple-600 text-white rounded-lg font-medium hover:bg-purple-700 transition-colors"
      >
        VBA 도우미 시작하기
      </button>
    </div>
  </div>
</template>

<script>
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useToast } from '@/composables/useToast'

export default {
  name: 'VBASolutionHistory',
  
  props: {
    solutions: {
      type: Array,
      default: () => []
    }
  },
  
  emits: ['view', 'rate'],
  
  setup(props, { emit }) {
    const router = useRouter()
    const { showToast } = useToast()
    
    const searchQuery = ref('')
    const filterType = ref('all')
    const expandedSolutions = ref([])
    
    // Stats calculations
    const totalSolutions = computed(() => props.solutions.length)
    
    const successRate = computed(() => {
      if (props.solutions.length === 0) return 0
      const successful = props.solutions.filter(s => s.was_helpful === true).length
      return Math.round((successful / props.solutions.length) * 100)
    })
    
    const averageTime = computed(() => {
      const times = props.solutions.filter(s => s.resolution_time).map(s => s.resolution_time)
      if (times.length === 0) return '0초'
      const avg = times.reduce((a, b) => a + b, 0) / times.length
      return formatResolutionTime(avg)
    })
    
    const savedCredits = computed(() => {
      // Estimate: Each instant solution saves ~5 credits vs AI solution
      return props.solutions.filter(s => s.solution_type === 'instant').length * 5
    })
    
    const filteredSolutions = computed(() => {
      let filtered = [...props.solutions]
      
      // Search filter
      if (searchQuery.value) {
        const query = searchQuery.value.toLowerCase()
        filtered = filtered.filter(s => 
          s.error_message.toLowerCase().includes(query) ||
          s.error_code?.toLowerCase().includes(query) ||
          s.solution?.toLowerCase().includes(query)
        )
      }
      
      // Type filter
      switch (filterType.value) {
        case 'runtime':
          filtered = filtered.filter(s => s.error_type === 'runtime')
          break
        case 'compile':
          filtered = filtered.filter(s => s.error_type === 'compile')
          break
        case 'logic':
          filtered = filtered.filter(s => s.error_type === 'logic')
          break
        case 'solved':
          filtered = filtered.filter(s => s.was_helpful === true)
          break
        case 'pending':
          filtered = filtered.filter(s => s.was_helpful === null)
          break
      }
      
      return filtered.sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
    })
    
    const toggleExpand = (solutionId) => {
      const index = expandedSolutions.value.indexOf(solutionId)
      if (index > -1) {
        expandedSolutions.value.splice(index, 1)
      } else {
        expandedSolutions.value.push(solutionId)
      }
    }
    
    const getErrorTypeClass = (type) => {
      const classes = {
        runtime: 'bg-red-100 text-red-700',
        compile: 'bg-orange-100 text-orange-700',
        logic: 'bg-yellow-100 text-yellow-700',
        syntax: 'bg-purple-100 text-purple-700'
      }
      return classes[type] || 'bg-gray-100 text-gray-700'
    }
    
    const getErrorTypeLabel = (type) => {
      const labels = {
        runtime: '런타임 오류',
        compile: '컴파일 오류',
        logic: '로직 오류',
        syntax: '구문 오류'
      }
      return labels[type] || type
    }
    
    const getSolutionStatusClass = (type) => {
      const classes = {
        instant: 'bg-green-100 text-green-700',
        ai_basic: 'bg-blue-100 text-blue-700',
        ai_advanced: 'bg-indigo-100 text-indigo-700'
      }
      return classes[type] || 'bg-gray-100 text-gray-700'
    }
    
    const getSolutionStatusLabel = (type) => {
      const labels = {
        instant: '즉시 해결',
        ai_basic: 'AI 기본',
        ai_advanced: 'AI 고급'
      }
      return labels[type] || type
    }
    
    const formatDate = (date) => {
      return new Date(date).toLocaleDateString('ko-KR', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
      })
    }
    
    const formatResolutionTime = (seconds) => {
      if (seconds < 60) return `${Math.round(seconds)}초`
      if (seconds < 3600) return `${Math.round(seconds / 60)}분`
      return `${Math.round(seconds / 3600)}시간`
    }
    
    return {
      searchQuery,
      filterType,
      expandedSolutions,
      totalSolutions,
      successRate,
      averageTime,
      savedCredits,
      filteredSolutions,
      toggleExpand,
      getErrorTypeClass,
      getErrorTypeLabel,
      getSolutionStatusClass,
      getSolutionStatusLabel,
      formatDate,
      formatResolutionTime,
      router
    }
  }
}
</script>

<style scoped>
pre code {
  font-family: 'Consolas', 'Monaco', 'Courier New', monospace;
  font-size: 0.875rem;
  line-height: 1.5;
}
</style>