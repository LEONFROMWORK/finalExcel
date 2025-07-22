<template>
  <div class="chat-interface h-full flex flex-col bg-gray-50">
    <!-- Chat Header -->
    <Card class="chat-header rounded-none border-x-0 border-t-0">
      <template #content>
        <div class="flex items-center justify-between px-2 py-1">
          <div class="flex items-center gap-3">
            <Button
              @click="$emit('toggle-sidebar')"
              icon="pi pi-bars"
              severity="secondary"
              text
              rounded
              class="lg:hidden"
            />
            <h2 class="text-xl font-semibold text-gray-800">
              {{ currentSession?.title || 'Excel AI 상담' }}
            </h2>
          </div>
          
          <div class="flex items-center gap-2">
            <Button
              @click="toggleMenu"
              icon="pi pi-download"
              severity="secondary"
              text
              rounded
              v-tooltip.bottom="'내보내기'"
              aria-haspopup="true"
              :aria-expanded="showExportMenu"
            />
            <Menu ref="exportMenu" :model="exportMenuItems" :popup="true" />
            
            <Button
              @click="deleteCurrentSession"
              icon="pi pi-trash"
              severity="danger"
              text
              rounded
              v-tooltip.bottom="'대화 삭제'"
            />
          </div>
        </div>
      </template>
    </Card>

    <!-- Messages Container -->
    <ScrollPanel ref="messagesContainer" class="flex-1 px-6 py-4">
      <!-- Loading state -->
      <div v-if="loading && messages.length === 0" class="flex justify-center items-center h-full">
        <div class="text-center">
          <ProgressSpinner
            style="width: 50px; height: 50px"
            strokeWidth="4"
            animationDuration=".5s"
          />
          <p class="mt-4 text-gray-600">대화를 불러오는 중...</p>
        </div>
      </div>

      <!-- Messages -->
      <div v-else class="space-y-4">
        <div v-for="message in sortedMessages" :key="message.id" class="message-item">
          <ChatMessage
            :message="message"
            :is-user="message.role === 'user'"
          />
        </div>
        
        <!-- Typing indicator -->
        <div v-if="isWaitingForResponse" class="flex items-center gap-2 text-gray-500">
          <div class="typing-indicator">
            <span></span>
            <span></span>
            <span></span>
          </div>
          <span class="text-sm">AI가 응답을 작성중입니다...</span>
        </div>
      </div>
    </ScrollPanel>

    <!-- Input Area -->
    <Card class="chat-input rounded-none border-x-0 border-b-0">
      <template #content>
        <div class="max-w-4xl mx-auto px-2 py-2">
          <!-- Image preview -->
          <div v-if="selectedImage" class="mb-4 relative inline-block">
            <Image 
              :src="imagePreview" 
              alt="Selected image"
              class="max-h-32"
              preview
            />
            <Button
              @click="removeImage"
              icon="pi pi-times"
              severity="danger"
              rounded
              class="absolute -top-2 -right-2"
              size="small"
            />
          </div>

          <!-- Input form -->
          <form @submit.prevent="handleSendMessage" class="flex items-end gap-2">
            <div class="flex-1">
              <Textarea
                v-model="messageInput"
                @keydown.enter.prevent="handleEnterKey"
                :disabled="sendingMessage"
                placeholder="Excel 관련 질문을 입력하세요... (Shift+Enter로 줄바꿈)"
                :rows="messageRows"
                :maxlength="2000"
                autoResize
                class="w-full"
              />
            </div>
            
            <div class="flex items-center gap-2">
              <!-- Image upload button -->
              <FileUpload
                mode="basic"
                accept="image/*"
                :maxFileSize="10485760"
                @select="handleImageUpload"
                :disabled="sendingMessage"
                :auto="false"
                chooseIcon="pi pi-image"
                class="p-button-secondary p-button-text p-button-rounded"
              />
              
              <!-- Send button -->
              <Button
                type="submit"
                :label="sendingMessage ? '전송중...' : '전송'"
                :icon="sendingMessage ? 'pi pi-spin pi-spinner' : 'pi pi-send'"
                :disabled="!canSendMessage"
                :loading="sendingMessage"
              />
            </div>
          </form>
          
          <div class="mt-2 text-xs text-gray-500">
            {{ messageInput.length }}/2000 | Shift+Enter로 줄바꿈
          </div>
        </div>
      </template>
    </Card>
  </div>
</template>

<script setup>
import { ref, computed, watch, nextTick, onMounted, onUnmounted } from 'vue'
import { useChatStore } from '../stores/chatStore'
import ChatMessage from './ChatMessage.vue'
import Card from 'primevue/card'
import Button from 'primevue/button'
import Menu from 'primevue/menu'
import ScrollPanel from 'primevue/scrollpanel'
import ProgressSpinner from 'primevue/progressspinner'
import Textarea from 'primevue/textarea'
import FileUpload from 'primevue/fileupload'
import Image from 'primevue/image'
import Tooltip from 'primevue/tooltip'

const props = defineProps({
  sessionId: {
    type: [String, Number],
    required: true
  }
})

const emit = defineEmits(['toggle-sidebar', 'session-deleted'])

const chatStore = useChatStore()
const messagesContainer = ref(null)
const messageInput = ref('')
const selectedImage = ref(null)
const imagePreview = ref(null)
const showExportMenu = ref(false)
const isWaitingForResponse = ref(false)
const exportMenu = ref()

// Export menu items
const exportMenuItems = ref([
  {
    label: 'JSON 형식으로 내보내기',
    icon: 'pi pi-file-export',
    command: () => exportChat('json')
  },
  {
    label: 'Markdown으로 내보내기',
    icon: 'pi pi-file',
    command: () => exportChat('markdown')
  }
])

// Computed
const { currentSession, sortedMessages, loading, sendingMessage } = chatStore

const canSendMessage = computed(() => {
  return (messageInput.value.trim() || selectedImage.value) && !sendingMessage.value
})

const messageRows = computed(() => {
  const lines = messageInput.value.split('\n').length
  return Math.min(Math.max(lines, 2), 6)
})

// Methods
const handleSendMessage = async () => {
  if (!canSendMessage.value) return
  
  try {
    isWaitingForResponse.value = true
    await chatStore.sendMessage(messageInput.value.trim(), selectedImage.value)
    
    // Clear input
    messageInput.value = ''
    selectedImage.value = null
    imagePreview.value = null
    
    // Scroll to bottom
    await nextTick()
    scrollToBottom()
  } catch (error) {
    console.error('Failed to send message:', error)
    isWaitingForResponse.value = false
  }
}

const handleEnterKey = (event) => {
  if (!event.shiftKey) {
    event.preventDefault()
    handleSendMessage()
  }
}

const handleImageUpload = (event) => {
  const file = event.files[0]
  if (!file) return
  
  selectedImage.value = file
  
  // Create preview
  const reader = new FileReader()
  reader.onload = (e) => {
    imagePreview.value = e.target.result
  }
  reader.readAsDataURL(file)
}

const toggleMenu = (event) => {
  exportMenu.value.toggle(event)
}

const removeImage = () => {
  selectedImage.value = null
  imagePreview.value = null
}

const scrollToBottom = () => {
  if (messagesContainer.value && messagesContainer.value.$el) {
    const scrollElement = messagesContainer.value.$el.querySelector('.p-scrollpanel-content')
    if (scrollElement) {
      scrollElement.scrollTop = scrollElement.scrollHeight
    }
  }
}

const exportChat = async (format) => {
  showExportMenu.value = false
  
  try {
    await chatStore.exportSession(currentSession.value.id, format)
    
    if (format === 'json') {
      alert('대화 내용이 JSON 형식으로 내보내졌습니다.')
    }
  } catch (error) {
    console.error('Export failed:', error)
    alert('내보내기에 실패했습니다.')
  }
}

const deleteCurrentSession = async () => {
  if (!confirm('이 대화를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.')) {
    return
  }
  
  try {
    await chatStore.deleteSession(currentSession.value.id)
    emit('session-deleted')
  } catch (error) {
    console.error('Failed to delete session:', error)
    alert('대화 삭제에 실패했습니다.')
  }
}

// Watch for new messages to stop waiting indicator
watch(sortedMessages, (newMessages, oldMessages) => {
  if (newMessages.length > oldMessages?.length) {
    const lastMessage = newMessages[newMessages.length - 1]
    if (lastMessage.role === 'assistant') {
      isWaitingForResponse.value = false
    }
    
    nextTick(() => {
      scrollToBottom()
    })
  }
})

// Load session data
watch(() => props.sessionId, async (newId) => {
  if (newId) {
    await chatStore.fetchSession(newId)
    await nextTick()
    scrollToBottom()
  }
}, { immediate: true })

// Cleanup
onUnmounted(() => {
  chatStore.clearCurrentSession()
})
</script>

<style scoped>
.typing-indicator {
  display: flex;
  align-items: center;
  gap: 2px;
}

.typing-indicator span {
  height: 8px;
  width: 8px;
  background-color: #9CA3AF;
  border-radius: 50%;
  animation: typing 1.4s infinite;
}

.typing-indicator span:nth-child(1) {
  animation-delay: 0s;
}

.typing-indicator span:nth-child(2) {
  animation-delay: 0.2s;
}

.typing-indicator span:nth-child(3) {
  animation-delay: 0.4s;
}

@keyframes typing {
  0%, 60%, 100% {
    transform: translateY(0);
    opacity: 0.7;
  }
  30% {
    transform: translateY(-10px);
    opacity: 1;
  }
}
</style>