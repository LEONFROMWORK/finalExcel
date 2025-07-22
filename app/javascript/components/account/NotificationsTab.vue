<template>
  <div class="notifications-tab">
    <!-- 헤더 -->
    <div class="flex items-center justify-between mb-6">
      <h2 class="text-2xl font-bold text-gray-900">알림</h2>
      <div class="flex items-center gap-3">
        <button
          v-if="unreadCount > 0"
          @click="markAllAsRead"
          class="text-sm text-blue-600 hover:text-blue-700 font-medium"
        >
          모두 읽음 표시
        </button>
        <button
          @click="showPreferences = true"
          class="flex items-center gap-2 px-4 py-2 bg-gray-100 hover:bg-gray-200 rounded-lg transition-colors"
        >
          <CogIcon class="h-4 w-4" />
          <span>알림 설정</span>
        </button>
      </div>
    </div>
    
    <!-- 필터 탭 -->
    <div class="flex gap-2 mb-6 border-b border-gray-200">
      <button
        v-for="filter in filters"
        :key="filter.value"
        @click="currentFilter = filter.value"
        class="px-4 py-2 text-sm font-medium transition-colors relative"
        :class="currentFilter === filter.value 
          ? 'text-blue-600 border-b-2 border-blue-600' 
          : 'text-gray-600 hover:text-gray-900'"
      >
        {{ filter.label }}
        <span 
          v-if="filter.value === 'unread' && unreadCount > 0"
          class="ml-2 bg-blue-100 text-blue-600 px-2 py-0.5 rounded-full text-xs"
        >
          {{ unreadCount }}
        </span>
      </button>
    </div>
    
    <!-- 알림 목록 -->
    <div v-if="loading" class="flex justify-center py-12">
      <div class="inline-flex items-center justify-center w-12 h-12 border-4 border-blue-200 border-t-blue-600 rounded-full animate-spin"></div>
    </div>
    
    <div v-else-if="filteredNotifications.length === 0" class="text-center py-12">
      <BellSlashIcon class="h-16 w-16 text-gray-300 mx-auto mb-4" />
      <p class="text-gray-500 text-lg">
        {{ currentFilter === 'unread' ? '읽지 않은 알림이 없습니다' : '알림이 없습니다' }}
      </p>
    </div>
    
    <div v-else class="space-y-4">
      <transition-group name="notification" tag="div">
        <div
          v-for="notification in filteredNotifications"
          :key="notification.id"
          class="bg-white rounded-lg shadow-sm border border-gray-200 p-4 hover:shadow-md transition-shadow"
          :class="{ 'border-l-4 border-blue-500': !notification.read }"
        >
          <NotificationItem
            :notification="notification"
            @read="handleRead"
            @delete="handleDelete"
            class="w-full"
          />
        </div>
      </transition-group>
      
      <!-- 페이지네이션 -->
      <div v-if="totalPages > 1" class="flex justify-center mt-8">
        <nav class="flex items-center gap-2">
          <button
            @click="currentPage = currentPage - 1"
            :disabled="currentPage === 1"
            class="px-3 py-1 rounded-lg bg-gray-100 hover:bg-gray-200 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <ChevronLeftIcon class="h-5 w-5" />
          </button>
          
          <template v-for="page in pageNumbers" :key="page">
            <button
              v-if="page !== '...'"
              @click="currentPage = page"
              class="px-3 py-1 rounded-lg transition-colors"
              :class="currentPage === page 
                ? 'bg-blue-600 text-white' 
                : 'bg-gray-100 hover:bg-gray-200'"
            >
              {{ page }}
            </button>
            <span v-else class="px-2 text-gray-500">...</span>
          </template>
          
          <button
            @click="currentPage = currentPage + 1"
            :disabled="currentPage === totalPages"
            class="px-3 py-1 rounded-lg bg-gray-100 hover:bg-gray-200 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <ChevronRightIcon class="h-5 w-5" />
          </button>
        </nav>
      </div>
    </div>
    
    <!-- 알림 설정 모달 -->
    <Teleport to="body">
      <div v-if="showPreferences" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <div class="bg-white rounded-lg shadow-xl max-w-md w-full mx-4">
          <div class="p-6">
            <h3 class="text-lg font-semibold text-gray-900 mb-4">알림 설정</h3>
            
            <div class="space-y-4">
              <!-- 이메일 알림 -->
              <div class="flex items-center justify-between">
                <div>
                  <h4 class="font-medium text-gray-900">이메일 알림</h4>
                  <p class="text-sm text-gray-500">중요한 알림을 이메일로 받습니다</p>
                </div>
                <label class="relative inline-flex items-center cursor-pointer">
                  <input
                    type="checkbox"
                    v-model="preferences.email_notifications"
                    class="sr-only peer"
                  >
                  <div class="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
                </label>
              </div>
              
              <!-- 푸시 알림 -->
              <div class="flex items-center justify-between">
                <div>
                  <h4 class="font-medium text-gray-900">브라우저 알림</h4>
                  <p class="text-sm text-gray-500">실시간 알림을 브라우저로 받습니다</p>
                </div>
                <label class="relative inline-flex items-center cursor-pointer">
                  <input
                    type="checkbox"
                    v-model="preferences.push_notifications"
                    class="sr-only peer"
                  >
                  <div class="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
                </label>
              </div>
              
              <!-- 알림 카테고리 -->
              <div class="border-t pt-4">
                <h4 class="font-medium text-gray-900 mb-3">알림 유형</h4>
                <div class="space-y-2">
                  <label
                    v-for="category in notificationCategories"
                    :key="category.value"
                    class="flex items-center gap-3 cursor-pointer"
                  >
                    <input
                      type="checkbox"
                      :value="category.value"
                      v-model="preferences.categories"
                      class="w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 rounded focus:ring-blue-500"
                    >
                    <div class="flex-1">
                      <p class="text-sm font-medium text-gray-900">{{ category.label }}</p>
                      <p class="text-xs text-gray-500">{{ category.description }}</p>
                    </div>
                  </label>
                </div>
              </div>
            </div>
          </div>
          
          <div class="bg-gray-50 px-6 py-3 flex justify-end gap-3 rounded-b-lg">
            <button
              @click="showPreferences = false"
              class="px-4 py-2 text-gray-700 hover:text-gray-900"
            >
              취소
            </button>
            <button
              @click="savePreferences"
              class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
            >
              저장
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { 
  BellSlashIcon, 
  CogIcon,
  ChevronLeftIcon,
  ChevronRightIcon
} from '@heroicons/vue/24/outline'
import NotificationItem from '../notifications/NotificationItem.vue'
import { useNotificationStore } from '@/stores/notification'

const notificationStore = useNotificationStore()

// State
const loading = ref(false)
const currentFilter = ref('all')
const currentPage = ref(1)
const totalPages = ref(1)
const showPreferences = ref(false)
const preferences = ref({
  email_notifications: true,
  push_notifications: true,
  categories: []
})

// 필터 옵션
const filters = [
  { label: '전체', value: 'all' },
  { label: '읽지 않음', value: 'unread' },
  { label: '중요', value: 'important' }
]

// 알림 카테고리
const notificationCategories = [
  {
    value: 'referral_rewards',
    label: '추천 보상',
    description: '추천인 가입 및 구매 보상 알림'
  },
  {
    value: 'credit_transactions',
    label: '크레딧 거래',
    description: '크레딧 구매, 사용, 환불 알림'
  },
  {
    value: 'system_announcements',
    label: '시스템 공지',
    description: '서비스 업데이트 및 공지사항'
  },
  {
    value: 'ai_consultations',
    label: 'AI 상담',
    description: 'AI 상담 답변 및 완료 알림'
  },
  {
    value: 'vba_solutions',
    label: 'VBA 솔루션',
    description: 'VBA 문제 해결 완료 알림'
  }
]

// Computed
const notifications = computed(() => notificationStore.notifications)
const unreadCount = computed(() => notificationStore.unreadCount)

const filteredNotifications = computed(() => {
  let filtered = notifications.value
  
  if (currentFilter.value === 'unread') {
    filtered = filtered.filter(n => !n.read)
  } else if (currentFilter.value === 'important') {
    filtered = filtered.filter(n => n.priority === 'high' || n.priority === 'urgent')
  }
  
  return filtered
})

const pageNumbers = computed(() => {
  const pages = []
  const total = totalPages.value
  const current = currentPage.value
  
  if (total <= 7) {
    for (let i = 1; i <= total; i++) {
      pages.push(i)
    }
  } else {
    if (current <= 3) {
      for (let i = 1; i <= 5; i++) {
        pages.push(i)
      }
      pages.push('...')
      pages.push(total)
    } else if (current >= total - 2) {
      pages.push(1)
      pages.push('...')
      for (let i = total - 4; i <= total; i++) {
        pages.push(i)
      }
    } else {
      pages.push(1)
      pages.push('...')
      for (let i = current - 1; i <= current + 1; i++) {
        pages.push(i)
      }
      pages.push('...')
      pages.push(total)
    }
  }
  
  return pages
})

// Methods
const loadNotifications = async () => {
  loading.value = true
  try {
    const result = await notificationStore.fetchNotifications(
      currentPage.value,
      currentFilter.value === 'unread'
    )
    totalPages.value = result.meta.total_pages
  } catch (error) {
    console.error('Failed to load notifications:', error)
  } finally {
    loading.value = false
  }
}

const handleRead = async (notificationId) => {
  await notificationStore.markAsRead(notificationId)
}

const handleDelete = async (notificationId) => {
  await notificationStore.deleteNotification(notificationId)
}

const markAllAsRead = async () => {
  await notificationStore.markAllAsRead()
}

const loadPreferences = async () => {
  await notificationStore.fetchPreferences()
  preferences.value = { ...notificationStore.preferences }
}

const savePreferences = async () => {
  await notificationStore.updatePreferences(preferences.value)
  showPreferences.value = false
}

// Watchers
watch(currentFilter, () => {
  currentPage.value = 1
  loadNotifications()
})

watch(currentPage, () => {
  loadNotifications()
})

// Lifecycle
onMounted(() => {
  loadNotifications()
  loadPreferences()
})
</script>

<style scoped>
.notification-enter-active,
.notification-leave-active {
  transition: all 0.3s ease;
}

.notification-enter-from {
  transform: translateX(-20px);
  opacity: 0;
}

.notification-leave-to {
  transform: translateX(20px);
  opacity: 0;
}
</style>