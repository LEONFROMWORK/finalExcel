<template>
  <div
    class="px-4 py-3 hover:bg-gray-50 transition-colors cursor-pointer border-b border-gray-100 last:border-0"
    :class="{ 'bg-blue-50': !notification.read }"
    @click="handleClick"
  >
    <div class="flex items-start gap-3">
      <!-- 아이콘 -->
      <div
        class="flex-shrink-0 w-10 h-10 rounded-full flex items-center justify-center"
        :class="iconClass"
      >
        <component :is="icon" class="w-5 h-5" />
      </div>
      
      <!-- 내용 -->
      <div class="flex-1 min-w-0">
        <div class="flex items-start justify-between gap-2">
          <div class="flex-1">
            <h4 class="text-sm font-semibold text-gray-900">
              {{ notification.title }}
            </h4>
            <p class="text-sm text-gray-600 mt-1">
              {{ notification.content }}
            </p>
            
            <!-- 액션 버튼 -->
            <button
              v-if="notification.action_url"
              @click.stop="navigateToAction"
              class="mt-2 text-xs font-medium text-blue-600 hover:text-blue-700"
            >
              {{ notification.action_text || '자세히 보기' }} →
            </button>
          </div>
          
          <!-- 우선순위 배지 -->
          <span
            v-if="notification.priority !== 'normal'"
            class="flex-shrink-0 px-2 py-1 text-xs font-medium rounded-full"
            :class="priorityClass"
          >
            {{ priorityText }}
          </span>
        </div>
        
        <!-- 시간 및 액션 -->
        <div class="flex items-center justify-between mt-2">
          <time class="text-xs text-gray-500">
            {{ formatTime(notification.created_at) }}
          </time>
          
          <div class="flex items-center gap-2">
            <button
              v-if="!notification.read"
              @click.stop="markAsRead"
              class="text-xs text-gray-500 hover:text-gray-700"
            >
              읽음 표시
            </button>
            <button
              @click.stop="deleteNotification"
              class="text-xs text-red-500 hover:text-red-700"
            >
              삭제
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import {
  GiftIcon,
  CurrencyDollarIcon,
  MegaphoneIcon,
  CalendarDaysIcon,
  CodeBracketIcon,
  ChatBubbleLeftRightIcon,
  ExclamationTriangleIcon
} from '@heroicons/vue/24/outline'

const props = defineProps({
  notification: {
    type: Object,
    required: true
  }
})

const emit = defineEmits(['read', 'delete'])
const router = useRouter()

// 아이콘 매핑
const iconMap = {
  ReferralRewardNotification: GiftIcon,
  CreditTransactionNotification: CurrencyDollarIcon,
  SystemAnnouncementNotification: MegaphoneIcon,
  SubscriptionReminderNotification: CalendarDaysIcon,
  VbaSolutionNotification: CodeBracketIcon,
  AiConsultationNotification: ChatBubbleLeftRightIcon
}

const icon = computed(() => {
  return iconMap[props.notification.type] || ExclamationTriangleIcon
})

// 아이콘 클래스
const iconClass = computed(() => {
  const classes = {
    ReferralRewardNotification: 'bg-green-100 text-green-600',
    CreditTransactionNotification: 'bg-blue-100 text-blue-600',
    SystemAnnouncementNotification: 'bg-purple-100 text-purple-600',
    SubscriptionReminderNotification: 'bg-orange-100 text-orange-600',
    VbaSolutionNotification: 'bg-indigo-100 text-indigo-600',
    AiConsultationNotification: 'bg-pink-100 text-pink-600'
  }
  
  return classes[props.notification.type] || 'bg-gray-100 text-gray-600'
})

// 우선순위 클래스
const priorityClass = computed(() => {
  const classes = {
    urgent: 'bg-red-100 text-red-700',
    high: 'bg-orange-100 text-orange-700',
    low: 'bg-gray-100 text-gray-700'
  }
  
  return classes[props.notification.priority] || ''
})

// 우선순위 텍스트
const priorityText = computed(() => {
  const texts = {
    urgent: '긴급',
    high: '중요',
    low: '낮음'
  }
  
  return texts[props.notification.priority] || ''
})

// 시간 포맷
const formatTime = (timestamp) => {
  const date = new Date(timestamp)
  const now = new Date()
  const diff = now - date
  
  // 1분 미만
  if (diff < 60000) {
    return '방금 전'
  }
  
  // 1시간 미만
  if (diff < 3600000) {
    const minutes = Math.floor(diff / 60000)
    return `${minutes}분 전`
  }
  
  // 24시간 미만
  if (diff < 86400000) {
    const hours = Math.floor(diff / 3600000)
    return `${hours}시간 전`
  }
  
  // 7일 미만
  if (diff < 604800000) {
    const days = Math.floor(diff / 86400000)
    return `${days}일 전`
  }
  
  // 그 이상
  return date.toLocaleDateString('ko-KR')
}

// 클릭 핸들러
const handleClick = () => {
  if (!props.notification.read) {
    markAsRead()
  }
}

// 읽음 표시
const markAsRead = () => {
  emit('read', props.notification.id)
}

// 액션으로 이동
const navigateToAction = () => {
  if (props.notification.action_url) {
    router.push(props.notification.action_url)
  }
}

// 알림 삭제
const deleteNotification = () => {
  if (confirm('이 알림을 삭제하시겠습니까?')) {
    emit('delete', props.notification.id)
  }
}
</script>