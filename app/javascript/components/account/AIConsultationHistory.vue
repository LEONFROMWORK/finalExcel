<template>
  <div class="ai-consultation-history">
    <!-- Header with filters -->
    <div class="bg-white rounded-2xl shadow-sm p-6 mb-6">
      <div class="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
        <div>
          <h3 class="text-xl font-bold text-gray-900">AI 상담 내역</h3>
          <p class="text-sm text-gray-500 mt-1">총 {{ consultations.length }}개의 상담 세션</p>
        </div>
        
        <div class="flex gap-3">
          <div class="relative">
            <input
              v-model="searchQuery"
              type="text"
              placeholder="검색..."
              class="pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            >
            <svg class="absolute left-3 top-2.5 w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
            </svg>
          </div>
          
          <select
            v-model="filterStatus"
            class="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          >
            <option value="all">모든 상담</option>
            <option value="active">진행 중</option>
            <option value="completed">완료됨</option>
            <option value="starred">즐겨찾기</option>
          </select>
        </div>
      </div>
    </div>
    
    <!-- Consultation List -->
    <div v-if="filteredConsultations.length > 0" class="space-y-4">
      <div
        v-for="consultation in filteredConsultations"
        :key="consultation.id"
        class="bg-white rounded-2xl shadow-sm hover:shadow-md transition-all duration-300"
      >
        <div class="p-6">
          <div class="flex items-start justify-between">
            <div class="flex-1">
              <div class="flex items-center gap-3 mb-2">
                <h4 class="text-lg font-semibold text-gray-900">
                  {{ consultation.title || `상담 #${consultation.id}` }}
                </h4>
                <span
                  v-if="consultation.unread"
                  class="px-2 py-0.5 bg-blue-100 text-blue-700 text-xs font-medium rounded-full"
                >
                  새 메시지
                </span>
                <button
                  @click="toggleStar(consultation.id)"
                  class="text-gray-400 hover:text-yellow-500 transition-colors"
                >
                  <svg
                    class="w-5 h-5"
                    :fill="consultation.starred ? 'currentColor' : 'none'"
                    :class="consultation.starred ? 'text-yellow-500' : ''"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z"></path>
                  </svg>
                </button>
              </div>
              
              <p class="text-gray-600 mb-3 line-clamp-2">
                {{ consultation.last_message || '대화를 시작하세요...' }}
              </p>
              
              <div class="flex items-center gap-4 text-sm text-gray-500">
                <div class="flex items-center gap-1">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 10h.01M12 10h.01M16 10h.01M9 16H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-5l-5 5v-5z"></path>
                  </svg>
                  <span>{{ consultation.message_count }} 메시지</span>
                </div>
                <div class="flex items-center gap-1">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                  </svg>
                  <span>{{ formatDate(consultation.updated_at) }}</span>
                </div>
                <div class="flex items-center gap-1">
                  <div
                    class="w-2 h-2 rounded-full"
                    :class="consultation.status === 'active' ? 'bg-green-500' : 'bg-gray-400'"
                  ></div>
                  <span>{{ consultation.status === 'active' ? '진행 중' : '완료' }}</span>
                </div>
              </div>
            </div>
            
            <div class="flex gap-2 ml-4">
              <button
                @click="$emit('view', consultation.id)"
                class="px-4 py-2 text-sm font-medium text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
              >
                보기
              </button>
              <button
                v-if="consultation.status === 'active'"
                @click="$emit('continue', consultation.id)"
                class="px-4 py-2 text-sm font-medium bg-blue-600 text-white hover:bg-blue-700 rounded-lg transition-colors"
              >
                계속하기
              </button>
            </div>
          </div>
          
          <!-- Tags -->
          <div v-if="consultation.tags && consultation.tags.length > 0" class="flex gap-2 mt-4">
            <span
              v-for="tag in consultation.tags"
              :key="tag"
              class="px-2 py-1 bg-gray-100 text-gray-600 text-xs rounded-md"
            >
              {{ tag }}
            </span>
          </div>
        </div>
        
        <!-- Progress Bar for active sessions -->
        <div
          v-if="consultation.status === 'active' && consultation.progress"
          class="px-6 pb-4"
        >
          <div class="flex justify-between text-xs text-gray-500 mb-1">
            <span>진행률</span>
            <span>{{ consultation.progress }}%</span>
          </div>
          <div class="w-full h-2 bg-gray-200 rounded-full overflow-hidden">
            <div
              class="h-full bg-gradient-to-r from-blue-500 to-blue-600 transition-all duration-500"
              :style="{ width: `${consultation.progress}%` }"
            ></div>
          </div>
        </div>
      </div>
    </div>
    
    <!-- Empty State -->
    <div v-else class="bg-white rounded-2xl shadow-sm p-12 text-center">
      <div class="w-20 h-20 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
        <svg class="w-10 h-10 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"></path>
        </svg>
      </div>
      <h4 class="text-lg font-medium text-gray-900 mb-2">상담 내역이 없습니다</h4>
      <p class="text-sm text-gray-500 mb-6">AI와 Excel 관련 대화를 시작해보세요</p>
      <button
        @click="$router.push('/ai-chat')"
        class="px-6 py-3 bg-blue-600 text-white rounded-lg font-medium hover:bg-blue-700 transition-colors"
      >
        새 상담 시작하기
      </button>
    </div>
    
    <!-- Load More -->
    <div v-if="hasMore && filteredConsultations.length > 0" class="mt-6 text-center">
      <button
        @click="loadMore"
        class="px-6 py-2 text-blue-600 hover:bg-blue-50 rounded-lg transition-colors font-medium"
      >
        더 보기
      </button>
    </div>
  </div>
</template>

<script>
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useToast } from '@/composables/useToast'

export default {
  name: 'AIConsultationHistory',
  
  props: {
    consultations: {
      type: Array,
      default: () => []
    }
  },
  
  emits: ['view', 'continue'],
  
  setup(props, { emit }) {
    const router = useRouter()
    const { showToast } = useToast()
    
    const searchQuery = ref('')
    const filterStatus = ref('all')
    const hasMore = ref(false)
    
    const filteredConsultations = computed(() => {
      let filtered = [...props.consultations]
      
      // Search filter
      if (searchQuery.value) {
        const query = searchQuery.value.toLowerCase()
        filtered = filtered.filter(c => 
          c.title?.toLowerCase().includes(query) ||
          c.last_message?.toLowerCase().includes(query) ||
          c.tags?.some(tag => tag.toLowerCase().includes(query))
        )
      }
      
      // Status filter
      if (filterStatus.value !== 'all') {
        switch (filterStatus.value) {
          case 'active':
            filtered = filtered.filter(c => c.status === 'active')
            break
          case 'completed':
            filtered = filtered.filter(c => c.status !== 'active')
            break
          case 'starred':
            filtered = filtered.filter(c => c.starred)
            break
        }
      }
      
      return filtered
    })
    
    const toggleStar = (consultationId) => {
      // In real app, this would make an API call
      const consultation = props.consultations.find(c => c.id === consultationId)
      if (consultation) {
        consultation.starred = !consultation.starred
        showToast(consultation.starred ? '즐겨찾기에 추가되었습니다' : '즐겨찾기에서 제거되었습니다', 'success')
      }
    }
    
    const formatDate = (date) => {
      const now = new Date()
      const consultationDate = new Date(date)
      const diffTime = Math.abs(now - consultationDate)
      const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24))
      const diffHours = Math.floor(diffTime / (1000 * 60 * 60))
      const diffMinutes = Math.floor(diffTime / (1000 * 60))
      
      if (diffMinutes < 60) {
        return `${diffMinutes}분 전`
      } else if (diffHours < 24) {
        return `${diffHours}시간 전`
      } else if (diffDays < 7) {
        return `${diffDays}일 전`
      } else {
        return consultationDate.toLocaleDateString('ko-KR', {
          year: 'numeric',
          month: 'short',
          day: 'numeric'
        })
      }
    }
    
    const loadMore = () => {
      // In real app, this would load more consultations
      showToast('추가 상담 내역을 불러오는 중...', 'info')
    }
    
    return {
      searchQuery,
      filterStatus,
      hasMore,
      filteredConsultations,
      toggleStar,
      formatDate,
      loadMore
    }
  }
}
</script>

<style scoped>
.line-clamp-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
</style>