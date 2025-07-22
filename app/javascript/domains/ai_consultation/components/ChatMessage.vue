<template>
  <div :class="['message flex', isUser ? 'justify-end' : 'justify-start', 'mb-4']">
    <Card :class="[
      'message-card max-w-[70%]',
      isUser ? 'bg-blue-500 text-white' : 'bg-white'
    ]">
      <template #content>
        <div class="p-2">
          <div class="flex justify-between items-center mb-1">
            <div class="flex items-center gap-2">
              <Avatar 
                :icon="isUser ? 'pi pi-user' : 'pi pi-robot'"
                :class="isUser ? 'p-avatar-primary' : 'p-avatar-secondary'"
                size="small"
                shape="circle"
              />
              <span class="text-sm font-medium">
                {{ isUser ? '나' : 'AI 어시스턴트' }}
              </span>
            </div>
            <span class="text-xs opacity-75">
              {{ formatTime(message.created_at) }}
            </span>
          </div>
          
          <div class="message-body mt-2">
            <!-- Image if present -->
            <div v-if="message.has_image && message.image_url" class="message-image mb-3">
              <Image
                :src="message.image_url"
                alt="Uploaded image"
                class="max-w-full cursor-pointer"
                preview
              />
            </div>
            
            <!-- Message text -->
            <div 
              v-if="message.content"
              class="message-text"
              :class="{ 
                'whitespace-pre-wrap': !isFormatted,
                'prose prose-sm max-w-none': !isUser && isFormatted,
                'text-white': isUser
              }"
              v-html="formattedContent"
            ></div>
            
            <!-- Metadata -->
            <div v-if="showMetadata && message.metadata" class="mt-2 flex gap-4 text-xs opacity-75">
              <span v-if="message.metadata.tokens_used">
                <i class="pi pi-hashtag mr-1"></i>
                {{ message.metadata.tokens_used }} 토큰
              </span>
              <span v-if="message.metadata.processing_time">
                <i class="pi pi-clock mr-1"></i>
                {{ formatProcessingTime(message.metadata.processing_time) }}
              </span>
            </div>
          </div>
        </div>
      </template>
    </Card>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import { marked } from 'marked'
import DOMPurify from 'dompurify'
import Card from 'primevue/card'
import Avatar from 'primevue/avatar'
import Image from 'primevue/image'

const props = defineProps({
  message: {
    type: Object,
    required: true
  },
  isUser: {
    type: Boolean,
    default: false
  },
  showMetadata: {
    type: Boolean,
    default: false
  }
})

const showImageModal = ref(false)

// Configure marked
marked.setOptions({
  breaks: true,
  gfm: true,
  headerIds: false,
  mangle: false
})

// Computed
const isFormatted = computed(() => {
  return !props.isUser && props.message.content.includes('```')
})

const formattedContent = computed(() => {
  if (props.isUser) {
    // User messages are displayed as plain text
    return escapeHtml(props.message.content)
  }
  
  try {
    // Parse markdown for assistant messages
    const rawHtml = marked(props.message.content)
    // Sanitize the HTML
    return DOMPurify.sanitize(rawHtml, {
      ALLOWED_TAGS: ['p', 'br', 'strong', 'em', 'code', 'pre', 'ul', 'ol', 'li', 'blockquote', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'a'],
      ALLOWED_ATTR: ['href', 'target', 'rel']
    })
  } catch (error) {
    console.error('Error formatting message:', error)
    return escapeHtml(props.message.content)
  }
})

// Methods
const formatTime = (timestamp) => {
  const date = new Date(timestamp)
  const now = new Date()
  
  // If today, show time only
  if (date.toDateString() === now.toDateString()) {
    return date.toLocaleTimeString('ko-KR', { 
      hour: '2-digit', 
      minute: '2-digit' 
    })
  }
  
  // Otherwise show date and time
  return date.toLocaleString('ko-KR', {
    month: 'numeric',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  })
}

const formatProcessingTime = (seconds) => {
  if (seconds < 1) {
    return `${Math.round(seconds * 1000)}ms`
  }
  return `${seconds.toFixed(1)}초`
}

const escapeHtml = (text) => {
  const map = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#039;'
  }
  return text.replace(/[&<>"']/g, m => map[m])
}
</script>

<style scoped>
.message-card :deep(.p-card-body) {
  padding: 0;
}

.message-card :deep(.p-card-content) {
  padding: 0;
}

.message-body {
  word-wrap: break-word;
}

.message-text {
  line-height: 1.6;
}

/* Markdown styles for assistant messages */
.prose :deep(p) {
  margin-bottom: 0.75rem;
}

.prose :deep(p:last-child) {
  margin-bottom: 0;
}

.prose :deep(code) {
  background-color: rgba(0, 0, 0, 0.05);
  padding: 0.125rem 0.375rem;
  border-radius: 0.25rem;
  font-size: 0.875em;
  font-family: monospace;
}

.prose :deep(pre) {
  background-color: #1F2937;
  color: #F9FAFB;
  padding: 1rem;
  border-radius: 0.5rem;
  overflow-x: auto;
  margin: 0.75rem 0;
}

.prose :deep(pre code) {
  background-color: transparent;
  padding: 0;
  color: inherit;
}

.prose :deep(ul),
.prose :deep(ol) {
  margin-left: 1.5rem;
  margin-bottom: 0.75rem;
}

.prose :deep(li) {
  margin-bottom: 0.375rem;
}

.prose :deep(blockquote) {
  border-left: 4px solid #E5E7EB;
  padding-left: 1rem;
  margin: 0.75rem 0;
  color: #6B7280;
  font-style: italic;
}

.prose :deep(h1),
.prose :deep(h2),
.prose :deep(h3),
.prose :deep(h4),
.prose :deep(h5),
.prose :deep(h6) {
  font-weight: 600;
  margin-top: 1rem;
  margin-bottom: 0.5rem;
}

.prose :deep(a) {
  color: #3B82F6;
  text-decoration: underline;
}

.prose :deep(a:hover) {
  color: #2563EB;
}

/* User message specific styles */
.bg-blue-500 .message-text :deep(code) {
  background-color: rgba(255, 255, 255, 0.2);
  color: white;
}

/* Mobile responsive */
@media (max-width: 640px) {
  .message-card {
    max-width: 85% !important;
  }
}
</style>