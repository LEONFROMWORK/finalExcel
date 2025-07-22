<template>
  <div class="chat-sidebar h-full bg-gray-900 text-white flex flex-col">
    <!-- Header -->
    <div class="p-4 border-b border-gray-700">
      <Button
        @click="createNewChat"
        label="새 대화 시작"
        icon="pi pi-plus"
        class="w-full"
        severity="primary"
      />
    </div>

    <!-- Search -->
    <div class="p-4 border-b border-gray-700">
      <InputGroup>
        <InputGroupAddon>
          <i class="pi pi-search"></i>
        </InputGroupAddon>
        <InputText
          v-model="searchQuery"
          @input="debouncedSearch"
          placeholder="대화 검색..."
          class="bg-gray-800 border-gray-700 text-white"
        />
      </InputGroup>
    </div>

    <!-- Sessions List -->
    <ScrollPanel class="flex-1">
      <div v-if="loading && sessions.length === 0" class="p-4 text-center text-gray-400">
        <ProgressSpinner 
          style="width: 40px; height: 40px" 
          strokeWidth="4"
          animationDuration=".5s"
        />
        <p class="mt-2 text-sm">대화 목록을 불러오는 중...</p>
      </div>

      <div v-else-if="sessions.length === 0" class="p-4 text-center text-gray-400">
        <i class="pi pi-comments text-5xl mb-3 opacity-50"></i>
        <p class="text-sm">아직 대화가 없습니다</p>
        <p class="text-xs mt-1">새 대화를 시작해보세요!</p>
      </div>

      <div v-else class="p-2">
        <Card
          v-for="session in sessions"
          :key="session.id"
          @click="selectSession(session.id)"
          :class="[
            'session-item mb-2 cursor-pointer transition-all',
            currentSessionId === session.id 
              ? 'bg-gray-700 border-l-4 border-blue-500' 
              : 'hover:bg-gray-800 border-l-4 border-transparent'
          ]"
        >
          <template #content>
            <div class="flex items-start justify-between p-2">
              <div class="flex-1 min-w-0">
                <h3 class="font-medium text-sm truncate">
                  {{ session.title }}
                </h3>
                <p class="text-xs text-gray-400 mt-1 flex items-center gap-2">
                  <i class="pi pi-comments text-xs"></i>
                  {{ formatSessionInfo(session) }}
                </p>
              </div>
              
              <div class="flex items-center gap-1 ml-2">
                <Button
                  @click.stop="editSessionTitle(session)"
                  icon="pi pi-pencil"
                  severity="secondary"
                  text
                  rounded
                  size="small"
                  v-tooltip.bottom="'제목 수정'"
                />
                
                <Button
                  @click.stop="deleteSession(session.id)"
                  icon="pi pi-trash"
                  severity="danger"
                  text
                  rounded
                  size="small"
                  v-tooltip.bottom="'삭제'"
                />
              </div>
            </div>
          </template>
        </Card>
      </div>
    </ScrollPanel>

    <!-- Statistics -->
    <Card class="rounded-none border-x-0 border-b-0 bg-gray-800">
      <template #content>
        <div class="p-2 text-xs text-gray-400">
          <div class="flex justify-between items-center mb-2">
            <span class="flex items-center gap-2">
              <i class="pi pi-folder"></i>
              총 대화
            </span>
            <Tag :value="`${statistics.total_sessions || 0}개`" severity="secondary" />
          </div>
          <div class="flex justify-between items-center">
            <span class="flex items-center gap-2">
              <i class="pi pi-comment"></i>
              총 메시지
            </span>
            <Tag :value="`${statistics.total_messages || 0}개`" severity="secondary" />
          </div>
        </div>
      </template>
    </Card>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import { useChatStore } from '../stores/chatStore'
import { debounce } from 'lodash-es'
import Button from 'primevue/button'
import Card from 'primevue/card'
import InputText from 'primevue/inputtext'
import InputGroup from 'primevue/inputgroup'
import InputGroupAddon from 'primevue/inputgroupaddon'
import ScrollPanel from 'primevue/scrollpanel'
import ProgressSpinner from 'primevue/progressspinner'
import Tag from 'primevue/tag'
import Tooltip from 'primevue/tooltip'

const props = defineProps({
  currentSessionId: {
    type: [String, Number],
    default: null
  }
})

const emit = defineEmits(['session-selected', 'new-session'])

const chatStore = useChatStore()
const searchQuery = ref('')

// Computed
const { sessions, loading, statistics } = chatStore

// Methods
const createNewChat = async () => {
  try {
    const { session } = await chatStore.createSession()
    emit('new-session', session.id)
  } catch (error) {
    console.error('Failed to create new chat:', error)
  }
}

const selectSession = (sessionId) => {
  emit('session-selected', sessionId)
}

const editSessionTitle = async (session) => {
  const newTitle = prompt('새 제목을 입력하세요:', session.title)
  
  if (newTitle && newTitle !== session.title) {
    try {
      await chatStore.updateSession(session.id, { title: newTitle })
    } catch (error) {
      console.error('Failed to update session title:', error)
      alert('제목 수정에 실패했습니다.')
    }
  }
}

const deleteSession = async (sessionId) => {
  if (!confirm('이 대화를 삭제하시겠습니까?')) {
    return
  }
  
  try {
    await chatStore.deleteSession(sessionId)
    
    if (props.currentSessionId === sessionId) {
      // Select another session or create new one
      if (sessions.value.length > 0) {
        const nextSession = sessions.value.find(s => s.id !== sessionId)
        if (nextSession) {
          emit('session-selected', nextSession.id)
        } else {
          createNewChat()
        }
      }
    }
  } catch (error) {
    console.error('Failed to delete session:', error)
    alert('대화 삭제에 실패했습니다.')
  }
}

const formatSessionInfo = (session) => {
  const date = new Date(session.last_activity)
  const messages = session.message_count || 0
  
  // Format relative time
  const now = new Date()
  const diff = now - date
  const hours = Math.floor(diff / (1000 * 60 * 60))
  const days = Math.floor(hours / 24)
  
  let timeStr
  if (days > 0) {
    timeStr = `${days}일 전`
  } else if (hours > 0) {
    timeStr = `${hours}시간 전`
  } else {
    const minutes = Math.floor(diff / (1000 * 60))
    timeStr = minutes > 0 ? `${minutes}분 전` : '방금 전'
  }
  
  return `${messages}개 메시지 · ${timeStr}`
}

// Search functionality
const performSearch = async () => {
  if (searchQuery.value.trim()) {
    await chatStore.searchMessages(searchQuery.value)
  } else {
    chatStore.clearSearch()
  }
}

const debouncedSearch = debounce(performSearch, 300)

// Load initial data
onMounted(async () => {
  await chatStore.fetchSessions()
  await chatStore.fetchStatistics()
})

// Refresh sessions periodically
const refreshInterval = setInterval(() => {
  chatStore.fetchSessions()
}, 60000) // Every minute

// Cleanup
onBeforeUnmount(() => {
  clearInterval(refreshInterval)
})
</script>

<style scoped>
.session-item :deep(.p-card-body) {
  padding: 0;
}

.session-item :deep(.p-card-content) {
  padding: 0;
}

.session-item {
  background-color: rgba(31, 41, 55, 0.5);
  border: 1px solid rgba(75, 85, 99, 0.3);
}

.session-item:hover {
  background-color: rgba(31, 41, 55, 0.8);
  border-color: rgba(75, 85, 99, 0.5);
}

.session-item.bg-gray-700 {
  background-color: rgba(55, 65, 81, 0.9);
  border-left-color: #3B82F6;
}

/* Custom styles for dark theme inputs */
:deep(.p-inputtext) {
  background-color: rgba(31, 41, 55, 0.5);
  border-color: rgba(75, 85, 99, 0.5);
  color: white;
}

:deep(.p-inputtext:hover) {
  border-color: rgba(107, 114, 128, 0.7);
}

:deep(.p-inputtext:focus) {
  border-color: #3B82F6;
  box-shadow: 0 0 0 1px #3B82F6;
}

:deep(.p-inputgroup-addon) {
  background-color: rgba(31, 41, 55, 0.5);
  border-color: rgba(75, 85, 99, 0.5);
  color: #9CA3AF;
}
</style>