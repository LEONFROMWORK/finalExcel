<template>
  <div class="notification-center relative">
    <!-- 알림 아이콘 버튼 -->
    <button
      @click="toggleDropdown"
      class="relative p-2 rounded-lg hover:bg-gray-100 transition-colors"
      :class="{ 'bg-gray-100': isOpen }"
    >
      <BellIcon class="h-6 w-6 text-gray-600" />
      
      <!-- 읽지 않은 알림 배지 -->
      <span
        v-if="unreadCount > 0"
        class="absolute -top-1 -right-1 bg-red-500 text-white text-xs rounded-full h-5 w-5 flex items-center justify-center font-bold animate-pulse"
      >
        {{ unreadCount > 99 ? '99+' : unreadCount }}
      </span>
    </button>
    
    <!-- 알림 드롭다운 -->
    <Transition
      enter-active-class="transition ease-out duration-200"
      enter-from-class="transform opacity-0 scale-95"
      enter-to-class="transform opacity-100 scale-100"
      leave-active-class="transition ease-in duration-75"
      leave-from-class="transform opacity-100 scale-100"
      leave-to-class="transform opacity-0 scale-95"
    >
      <div
        v-if="isOpen"
        v-click-outside="closeDropdown"
        class="absolute right-0 mt-2 w-96 bg-white rounded-lg shadow-xl border border-gray-200 z-50"
      >
        <!-- 헤더 -->
        <div class="px-4 py-3 border-b border-gray-200">
          <div class="flex items-center justify-between">
            <h3 class="text-lg font-semibold text-gray-900">알림</h3>
            <div class="flex items-center gap-2">
              <button
                v-if="unreadCount > 0"
                @click="markAllAsRead"
                class="text-sm text-blue-600 hover:text-blue-700"
              >
                모두 읽음
              </button>
              <router-link
                to="/notifications"
                class="text-sm text-gray-500 hover:text-gray-700"
              >
                전체 보기
              </router-link>
            </div>
          </div>
        </div>
        
        <!-- 알림 목록 -->
        <div class="max-h-96 overflow-y-auto">
          <div v-if="loading" class="p-8 text-center">
            <div class="inline-flex items-center justify-center w-8 h-8 border-2 border-blue-500 border-t-transparent rounded-full animate-spin"></div>
          </div>
          
          <div v-else-if="notifications.length === 0" class="p-8 text-center">
            <BellSlashIcon class="h-12 w-12 text-gray-300 mx-auto mb-3" />
            <p class="text-gray-500">새로운 알림이 없습니다</p>
          </div>
          
          <div v-else class="py-2">
            <NotificationItem
              v-for="notification in notifications"
              :key="notification.id"
              :notification="notification"
              @read="handleRead"
              @delete="handleDelete"
            />
          </div>
        </div>
        
        <!-- 푸터 -->
        <div class="px-4 py-3 bg-gray-50 border-t border-gray-200 rounded-b-lg">
          <router-link
            to="/my-account?tab=notifications"
            class="text-sm text-blue-600 hover:text-blue-700 font-medium"
          >
            알림 설정 관리
          </router-link>
        </div>
      </div>
    </Transition>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { BellIcon, BellSlashIcon } from '@heroicons/vue/24/outline'
import NotificationItem from './notifications/NotificationItem.vue'
import { useNotificationStore } from '@/stores/notification'
import { createConsumer } from '@rails/actioncable'

const router = useRouter()
const notificationStore = useNotificationStore()

const isOpen = ref(false)
const loading = ref(false)
const consumer = ref(null)
const subscription = ref(null)

const notifications = computed(() => notificationStore.notifications)
const unreadCount = computed(() => notificationStore.unreadCount)

// 드롭다운 토글
const toggleDropdown = () => {
  isOpen.value = !isOpen.value
  if (isOpen.value && notifications.value.length === 0) {
    loadNotifications()
  }
}

// 드롭다운 닫기
const closeDropdown = () => {
  isOpen.value = false
}

// 알림 불러오기
const loadNotifications = async () => {
  loading.value = true
  try {
    await notificationStore.fetchNotifications()
  } finally {
    loading.value = false
  }
}

// 알림 읽음 처리
const handleRead = async (notificationId) => {
  await notificationStore.markAsRead(notificationId)
}

// 모든 알림 읽음 처리
const markAllAsRead = async () => {
  await notificationStore.markAllAsRead()
}

// 알림 삭제
const handleDelete = async (notificationId) => {
  await notificationStore.deleteNotification(notificationId)
}

// WebSocket 연결 설정
const setupWebSocket = () => {
  consumer.value = createConsumer()
  
  subscription.value = consumer.value.subscriptions.create(
    { channel: 'NotificationsChannel' },
    {
      connected() {
        console.log('Connected to NotificationsChannel')
      },
      
      disconnected() {
        console.log('Disconnected from NotificationsChannel')
      },
      
      received(data) {
        // 새 알림 수신
        if (data.notification) {
          notificationStore.addNotification(data.notification)
          
          // 브라우저 알림 표시 (권한이 있는 경우)
          if (Notification.permission === 'granted') {
            showBrowserNotification(data.notification)
          }
        }
        
        // 읽지 않은 알림 수 업데이트
        if (data.unread_count !== undefined) {
          notificationStore.setUnreadCount(data.unread_count)
        }
      }
    }
  )
}

// 브라우저 알림 표시
const showBrowserNotification = (notification) => {
  const browserNotification = new Notification(notification.title, {
    body: notification.content,
    icon: '/favicon.ico',
    tag: notification.id,
    requireInteraction: notification.priority === 'urgent'
  })
  
  browserNotification.onclick = () => {
    window.focus()
    if (notification.action_url) {
      router.push(notification.action_url)
    }
    browserNotification.close()
  }
}

// 브라우저 알림 권한 요청
const requestNotificationPermission = async () => {
  if ('Notification' in window && Notification.permission === 'default') {
    await Notification.requestPermission()
  }
}

// 컴포넌트 마운트 시
onMounted(() => {
  notificationStore.fetchUnreadCount()
  setupWebSocket()
  requestNotificationPermission()
})

// 컴포넌트 언마운트 시
onUnmounted(() => {
  if (subscription.value) {
    subscription.value.unsubscribe()
  }
  if (consumer.value) {
    consumer.value.disconnect()
  }
})

// v-click-outside 디렉티브
const vClickOutside = {
  mounted(el, binding) {
    el.clickOutsideEvent = (event) => {
      if (!(el === event.target || el.contains(event.target))) {
        binding.value()
      }
    }
    document.addEventListener('click', el.clickOutsideEvent)
  },
  unmounted(el) {
    document.removeEventListener('click', el.clickOutsideEvent)
  }
}
</script>

<style scoped>
/* 커스텀 스크롤바 */
.max-h-96::-webkit-scrollbar {
  width: 6px;
}

.max-h-96::-webkit-scrollbar-track {
  background: #f3f4f6;
}

.max-h-96::-webkit-scrollbar-thumb {
  background: #d1d5db;
  border-radius: 3px;
}

.max-h-96::-webkit-scrollbar-thumb:hover {
  background: #9ca3af;
}
</style>