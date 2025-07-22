<template>
  <div class="dashboard-page min-h-screen bg-gray-50">
    <div class="container mx-auto px-4 py-8">
      <!-- Header -->
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-gray-900">
          안녕하세요, {{ userName }}님!
        </h1>
        <p class="mt-2 text-gray-600">
          Excel 작업을 도와드릴 준비가 되어있습니다.
        </p>
      </div>

      <!-- Quick Actions -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <Card 
          class="bg-gradient-to-br from-green-500 to-green-600 text-white cursor-pointer hover:shadow-lg transition-shadow"
          @click="router.push('/excel-analysis/upload')"
        >
          <template #content>
            <div class="flex items-center justify-between">
              <div>
                <h3 class="text-xl font-semibold mb-2">Excel 파일 분석</h3>
                <p class="text-green-100">파일을 업로드하여 분석 시작</p>
              </div>
              <i class="pi pi-upload text-5xl text-green-200"></i>
            </div>
          </template>
        </Card>

        <Card 
          class="bg-gradient-to-br from-blue-500 to-blue-600 text-white cursor-pointer hover:shadow-lg transition-shadow"
          @click="router.push('/consultation')"
        >
          <template #content>
            <div class="flex items-center justify-between">
              <div>
                <h3 class="text-xl font-semibold mb-2">AI 상담 시작</h3>
                <p class="text-blue-100">Excel 관련 질문하기</p>
              </div>
              <i class="pi pi-comments text-5xl text-blue-200"></i>
            </div>
          </template>
        </Card>

        <Card 
          class="bg-gradient-to-br from-purple-500 to-purple-600 text-white cursor-pointer hover:shadow-lg transition-shadow"
          @click="router.push('/knowledge-base')"
        >
          <template #content>
            <div class="flex items-center justify-between">
              <div>
                <h3 class="text-xl font-semibold mb-2">지식 검색</h3>
                <p class="text-purple-100">Excel 팁과 해결책 찾기</p>
              </div>
              <i class="pi pi-search text-5xl text-purple-200"></i>
            </div>
          </template>
        </Card>
      </div>

      <!-- Statistics Overview -->
      <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
        <Card>
          <template #content>
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-gray-600">분석한 파일</p>
                <p class="text-2xl font-bold text-gray-900 mt-1">{{ stats.filesAnalyzed }}</p>
              </div>
              <div class="p-3 bg-green-100 rounded-full">
                <i class="pi pi-file text-2xl text-green-600"></i>
              </div>
            </div>
          </template>
        </Card>

        <Card>
          <template #content>
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-gray-600">상담 세션</p>
                <p class="text-2xl font-bold text-gray-900 mt-1">{{ stats.consultations }}</p>
              </div>
              <div class="p-3 bg-blue-100 rounded-full">
                <i class="pi pi-comments text-2xl text-blue-600"></i>
              </div>
            </div>
          </template>
        </Card>

        <Card>
          <template #content>
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-gray-600">검색한 지식</p>
                <p class="text-2xl font-bold text-gray-900 mt-1">{{ stats.searches }}</p>
              </div>
              <div class="p-3 bg-purple-100 rounded-full">
                <i class="pi pi-book text-2xl text-purple-600"></i>
              </div>
            </div>
          </template>
        </Card>

        <Card>
          <template #content>
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-gray-600">해결된 문제</p>
                <p class="text-2xl font-bold text-gray-900 mt-1">{{ stats.solvedProblems }}</p>
              </div>
              <div class="p-3 bg-orange-100 rounded-full">
                <i class="pi pi-check-circle text-2xl text-orange-600"></i>
              </div>
            </div>
          </template>
        </Card>
      </div>

      <!-- Recent Activity -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
        <!-- Recent Files -->
        <Card>
          <template #header>
            <div class="p-6 border-b">
              <h2 class="text-lg font-semibold text-gray-900">최근 분석한 파일</h2>
            </div>
          </template>
          <template #content>
            <div v-if="recentFiles.length === 0" class="text-center py-8 text-gray-500">
              아직 분석한 파일이 없습니다.
            </div>
            <div v-else class="space-y-4">
              <div
                v-for="file in recentFiles"
                :key="file.id"
                class="flex items-center justify-between p-4 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors"
              >
                <div class="flex items-center space-x-3">
                  <div class="p-2 bg-green-100 rounded">
                    <i class="pi pi-file text-xl text-green-600"></i>
                  </div>
                  <div>
                    <h4 class="font-medium text-gray-900">{{ file.filename }}</h4>
                    <p class="text-sm text-gray-500">{{ formatDate(file.created_at) }}</p>
                  </div>
                </div>
                <Button
                  label="보기"
                  class="p-button-text p-button-sm"
                  @click="router.push(`/excel-analysis/${file.id}`)"
                />
              </div>
            </div>
          </template>
        </Card>

        <!-- Recent Consultations -->
        <Card>
          <template #header>
            <div class="p-6 border-b">
              <h2 class="text-lg font-semibold text-gray-900">최근 상담 내역</h2>
            </div>
          </template>
          <template #content>
            <div v-if="recentConsultations.length === 0" class="text-center py-8 text-gray-500">
              아직 상담 내역이 없습니다.
            </div>
            <div v-else class="space-y-4">
              <div
                v-for="consultation in recentConsultations"
                :key="consultation.id"
                class="flex items-center justify-between p-4 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors"
              >
                <div class="flex items-center space-x-3">
                  <div class="p-2 bg-blue-100 rounded">
                    <i class="pi pi-comments text-xl text-blue-600"></i>
                  </div>
                  <div>
                    <h4 class="font-medium text-gray-900">{{ consultation.title }}</h4>
                    <p class="text-sm text-gray-500">
                      {{ consultation.message_count }}개 메시지 · {{ formatDate(consultation.last_activity) }}
                    </p>
                  </div>
                </div>
                <Button
                  label="계속"
                  class="p-button-text p-button-sm"
                  @click="router.push(`/consultation?session=${consultation.id}`)"
                />
              </div>
            </div>
          </template>
        </Card>
      </div>

      <!-- Admin Section (only for admin users) -->
      <div v-if="isAdmin" class="mt-8">
        <h2 class="text-2xl font-bold text-gray-900 mb-4">관리자 도구</h2>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <Card class="cursor-pointer hover:shadow-lg transition-shadow" @click="router.push('/admin/pipeline')">
            <template #content>
              <div class="flex items-center space-x-4">
                <div class="p-3 bg-indigo-100 rounded-full">
                  <i class="pi pi-database text-3xl text-indigo-600"></i>
                </div>
                <div>
                  <h3 class="text-lg font-semibold text-gray-900">데이터 파이프라인</h3>
                  <p class="text-gray-600">데이터 수집 작업 관리</p>
                </div>
              </div>
            </template>
          </Card>

          <Card class="cursor-pointer hover:shadow-lg transition-shadow" @click="router.push('/admin/knowledge')">
            <template #content>
              <div class="flex items-center space-x-4">
                <div class="p-3 bg-yellow-100 rounded-full">
                  <i class="pi pi-book text-3xl text-yellow-600"></i>
                </div>
                <div>
                  <h3 class="text-lg font-semibold text-gray-900">지식 베이스 관리</h3>
                  <p class="text-gray-600">Q&A 데이터 관리</p>
                </div>
              </div>
            </template>
          </Card>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../domains/authentication/stores/authStore'
import { useExcelStore } from '../domains/excel_analysis/stores/excelStore'
import { useChatStore } from '../domains/ai_consultation/stores/chatStore'
import Card from 'primevue/card'
import Button from 'primevue/button'

const router = useRouter()
const authStore = useAuthStore()
const excelStore = useExcelStore()
const chatStore = useChatStore()

// Computed
const userName = computed(() => authStore.user?.name || '사용자')
const isAdmin = computed(() => authStore.user?.role === 'admin')

// State
const stats = ref({
  filesAnalyzed: 0,
  consultations: 0,
  searches: 0,
  solvedProblems: 0
})

const recentFiles = ref([])
const recentConsultations = ref([])

// Methods
const formatDate = (dateString) => {
  const date = new Date(dateString)
  const now = new Date()
  const diff = now - date
  
  const minutes = Math.floor(diff / 60000)
  const hours = Math.floor(minutes / 60)
  const days = Math.floor(hours / 24)
  
  if (days > 0) return `${days}일 전`
  if (hours > 0) return `${hours}시간 전`
  if (minutes > 0) return `${minutes}분 전`
  return '방금 전'
}

const loadDashboardData = async () => {
  try {
    // Load recent files
    const filesResponse = await excelStore.fetchFiles({ limit: 5 })
    recentFiles.value = filesResponse.files || []
    stats.value.filesAnalyzed = filesResponse.total || 0
    
    // Load recent consultations
    const sessionsResponse = await chatStore.fetchSessions({ limit: 5 })
    recentConsultations.value = sessionsResponse.sessions || []
    stats.value.consultations = sessionsResponse.total || 0
    
    // Load statistics
    const chatStats = await chatStore.fetchStatistics()
    stats.value.searches = chatStats.total_messages || 0
    stats.value.solvedProblems = Math.floor((chatStats.total_sessions || 0) * 0.85) // Mock calculation
  } catch (error) {
    console.error('Failed to load dashboard data:', error)
  }
}

// Load data on mount
onMounted(() => {
  loadDashboardData()
})
</script>