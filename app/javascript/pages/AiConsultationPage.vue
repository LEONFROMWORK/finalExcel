<template>
  <div class="ai-consultation-page h-screen flex">
    <!-- Sidebar -->
    <div 
      :class="[
        'sidebar-container bg-gray-900 transition-all duration-300',
        sidebarOpen ? 'w-80' : 'w-0'
      ]"
    >
      <div v-if="sidebarOpen" class="w-80 h-full">
        <ChatSidebar
          :current-session-id="currentSessionId"
          @session-selected="handleSessionSelected"
          @new-session="handleNewSession"
        />
      </div>
    </div>

    <!-- Main Chat Area -->
    <div class="flex-1 flex flex-col">
      <!-- Empty state when no session -->
      <div v-if="!currentSessionId" class="flex-1 flex items-center justify-center bg-gray-50">
        <div class="text-center max-w-md">
          <svg class="w-24 h-24 mx-auto mb-6 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"></path>
          </svg>
          
          <h2 class="text-2xl font-semibold text-gray-700 mb-3">
            Excel AI 상담 서비스
          </h2>
          
          <p class="text-gray-500 mb-6">
            Excel 관련 질문이나 문제를 AI 어시스턴트와 함께 해결해보세요.
            수식 오류, 데이터 분석, 차트 생성 등 다양한 도움을 받을 수 있습니다.
          </p>
          
          <Button
            label="새 대화 시작하기"
            icon="pi pi-plus"
            @click="createNewSession"
          />
          
          <div class="mt-8 grid grid-cols-1 md:grid-cols-3 gap-4 text-left">
            <Card>
              <template #content>
                <i class="pi pi-chart-bar text-4xl text-blue-600 mb-2"></i>
                <h3 class="font-semibold mb-1">수식 도움</h3>
                <p class="text-sm text-gray-600">복잡한 수식 작성과 오류 해결</p>
              </template>
            </Card>
            
            <Card>
              <template #content>
                <i class="pi pi-chart-line text-4xl text-green-600 mb-2"></i>
                <h3 class="font-semibold mb-1">데이터 분석</h3>
                <p class="text-sm text-gray-600">데이터 정리와 분석 방법 안내</p>
              </template>
            </Card>
            
            <Card>
              <template #content>
                <i class="pi pi-image text-4xl text-purple-600 mb-2"></i>
                <h3 class="font-semibold mb-1">스크린샷 분석</h3>
                <p class="text-sm text-gray-600">Excel 화면을 업로드하여 문제 진단</p>
              </template>
            </Card>
          </div>
        </div>
      </div>

      <!-- Chat Interface -->
      <ChatInterface
        v-else
        :session-id="currentSessionId"
        @toggle-sidebar="toggleSidebar"
        @session-deleted="handleSessionDeleted"
      />
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, watch, onBeforeUnmount } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useChatStore } from '../domains/ai_consultation/stores/chatStore'
import ChatSidebar from '../domains/ai_consultation/components/ChatSidebar.vue'
import ChatInterface from '../domains/ai_consultation/components/ChatInterface.vue'
import Button from 'primevue/button'
import Card from 'primevue/card'

const route = useRoute()
const router = useRouter()
const chatStore = useChatStore()

const currentSessionId = ref(null)
const sidebarOpen = ref(true)

// Methods
const handleSessionSelected = (sessionId) => {
  currentSessionId.value = sessionId
  router.push({ name: 'ai-consultation', query: { session: sessionId } })
  
  // Close sidebar on mobile after selection
  if (window.innerWidth < 1024) {
    sidebarOpen.value = false
  }
}

const handleNewSession = (sessionId) => {
  handleSessionSelected(sessionId)
}

const createNewSession = async () => {
  try {
    const { session } = await chatStore.createSession()
    handleSessionSelected(session.id)
  } catch (error) {
    console.error('Failed to create new session:', error)
  }
}

const handleSessionDeleted = () => {
  currentSessionId.value = null
  router.push({ name: 'ai-consultation' })
}

const toggleSidebar = () => {
  sidebarOpen.value = !sidebarOpen.value
}

// Handle route query params
watch(() => route.query.session, (sessionId) => {
  if (sessionId) {
    currentSessionId.value = sessionId
  }
}, { immediate: true })

// Responsive sidebar
onMounted(() => {
  // Close sidebar on mobile by default
  if (window.innerWidth < 1024) {
    sidebarOpen.value = false
  }
  
  // Listen for resize events
  const handleResize = () => {
    if (window.innerWidth >= 1024) {
      sidebarOpen.value = true
    }
  }
  
  window.addEventListener('resize', handleResize)
  
  // Cleanup
  onBeforeUnmount(() => {
    window.removeEventListener('resize', handleResize)
  })
})
</script>

<style scoped>
.sidebar-container {
  overflow: hidden;
}

@media (max-width: 1023px) {
  .sidebar-container {
    position: fixed;
    left: 0;
    top: 0;
    height: 100%;
    z-index: 40;
    box-shadow: 2px 0 8px rgba(0, 0, 0, 0.15);
  }
  
  .sidebar-container.w-80 {
    width: 20rem;
  }
}
</style>