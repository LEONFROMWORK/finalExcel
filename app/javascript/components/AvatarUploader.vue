<template>
  <div class="avatar-uploader">
    <div class="relative inline-block">
      <!-- Avatar Display -->
      <div class="avatar-container">
        <img 
          :src="avatarUrl" 
          :alt="user.name || 'Avatar'"
          class="avatar-image"
          @error="handleImageError"
        >
        <div v-if="uploading" class="avatar-overlay">
          <div class="spinner"></div>
        </div>
      </div>
      
      <!-- Upload Button -->
      <button 
        type="button"
        class="upload-button"
        @click="triggerFileInput"
        :disabled="uploading"
      >
        <CameraIcon class="w-5 h-5" />
      </button>
      
      <!-- Delete Button (if avatar exists) -->
      <button 
        v-if="hasCustomAvatar"
        type="button"
        class="delete-button"
        @click="deleteAvatar"
        :disabled="uploading"
      >
        <XMarkIcon class="w-4 h-4" />
      </button>
      
      <!-- Hidden File Input -->
      <input 
        ref="fileInput"
        type="file"
        accept="image/jpeg,image/jpg,image/png,image/gif,image/webp"
        class="hidden"
        @change="handleFileSelect"
      >
    </div>
    
    <!-- Error Message -->
    <div v-if="error" class="mt-2">
      <p class="text-sm text-red-600">{{ error }}</p>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import { CameraIcon, XMarkIcon } from '@heroicons/vue/24/outline'
import { useUserStore } from '@/stores/user'
import { useToast } from '@/composables/useToast'
import api from '@/services/api'

const props = defineProps({
  user: {
    type: Object,
    required: true
  },
  size: {
    type: String,
    default: 'large' // small, medium, large
  }
})

const emit = defineEmits(['updated'])

const userStore = useUserStore()
const { showToast } = useToast()

// State
const fileInput = ref(null)
const uploading = ref(false)
const error = ref('')
const avatarUrl = ref(props.user.avatar || getDefaultAvatar())

// Computed
const hasCustomAvatar = computed(() => {
  return props.user.avatar && !props.user.avatar.includes('ui-avatars.com')
})

const sizeClasses = computed(() => {
  const sizes = {
    small: 'w-16 h-16',
    medium: 'w-24 h-24',
    large: 'w-36 h-36'
  }
  return sizes[props.size] || sizes.large
})

// Methods
function getDefaultAvatar() {
  const name = props.user.name || props.user.email || 'User'
  return `https://ui-avatars.com/api/?name=${encodeURIComponent(name)}&background=3B82F6&color=fff&size=300`
}

function triggerFileInput() {
  fileInput.value?.click()
}

async function handleFileSelect(event) {
  const file = event.target.files?.[0]
  if (!file) return
  
  error.value = ''
  
  // Client-side validation
  const maxSize = 5 * 1024 * 1024 // 5MB
  if (file.size > maxSize) {
    error.value = '파일 크기는 5MB 이하여야 합니다'
    return
  }
  
  const allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp']
  if (!allowedTypes.includes(file.type)) {
    error.value = '지원하지 않는 파일 형식입니다'
    return
  }
  
  // Preview
  const reader = new FileReader()
  reader.onload = (e) => {
    avatarUrl.value = e.target.result
  }
  reader.readAsDataURL(file)
  
  // Upload
  await uploadAvatar(file)
}

async function uploadAvatar(file) {
  uploading.value = true
  error.value = ''
  
  try {
    const formData = new FormData()
    formData.append('avatar', file)
    
    const response = await api.post('/my-account/upload-avatar', formData, {
      headers: {
        'Content-Type': 'multipart/form-data'
      }
    })
    
    if (response.data.success) {
      showToast('아바타가 업로드되었습니다', 'success')
      avatarUrl.value = response.data.avatar_url
      
      // Update user store
      await userStore.fetchCurrentUser()
      
      emit('updated', response.data.avatar_url)
    } else {
      throw new Error(response.data.error || '업로드 실패')
    }
  } catch (err) {
    error.value = err.response?.data?.error || '업로드 중 오류가 발생했습니다'
    avatarUrl.value = props.user.avatar || getDefaultAvatar()
  } finally {
    uploading.value = false
    // Reset file input
    if (fileInput.value) {
      fileInput.value.value = ''
    }
  }
}

async function deleteAvatar() {
  if (!confirm('아바타를 삭제하시겠습니까?')) return
  
  uploading.value = true
  error.value = ''
  
  try {
    const response = await api.delete('/my-account/delete-avatar')
    
    if (response.data.success) {
      showToast('아바타가 삭제되었습니다', 'success')
      avatarUrl.value = response.data.default_avatar || getDefaultAvatar()
      
      // Update user store
      await userStore.fetchCurrentUser()
      
      emit('updated', null)
    }
  } catch (err) {
    error.value = '삭제 중 오류가 발생했습니다'
  } finally {
    uploading.value = false
  }
}

function handleImageError() {
  avatarUrl.value = getDefaultAvatar()
}
</script>

<style scoped>
.avatar-container {
  @apply relative overflow-hidden rounded-full shadow-lg;
}

.avatar-image {
  @apply w-full h-full object-cover;
}

.avatar-container.large {
  @apply w-36 h-36;
}

.avatar-container.medium {
  @apply w-24 h-24;
}

.avatar-container.small {
  @apply w-16 h-16;
}

.avatar-overlay {
  @apply absolute inset-0 bg-black bg-opacity-50 flex items-center justify-center;
}

.upload-button {
  @apply absolute bottom-2 right-2 bg-white text-gray-700 p-2.5 rounded-full shadow-lg hover:shadow-xl transform hover:scale-110 transition-all;
}

.upload-button:disabled {
  @apply opacity-50 cursor-not-allowed hover:scale-100;
}

.delete-button {
  @apply absolute top-0 right-0 bg-red-500 text-white p-1.5 rounded-full shadow-lg hover:bg-red-600 transform hover:scale-110 transition-all;
}

.spinner {
  @apply inline-block w-8 h-8 border-4 border-white border-t-transparent rounded-full animate-spin;
}

/* Size variations */
.avatar-uploader[data-size="small"] .avatar-container {
  @apply w-16 h-16;
}

.avatar-uploader[data-size="small"] .upload-button {
  @apply p-1.5 bottom-0 right-0;
}

.avatar-uploader[data-size="small"] .upload-button svg {
  @apply w-3 h-3;
}

.avatar-uploader[data-size="medium"] .avatar-container {
  @apply w-24 h-24;
}

.avatar-uploader[data-size="medium"] .upload-button {
  @apply p-2 bottom-1 right-1;
}

.avatar-uploader[data-size="medium"] .upload-button svg {
  @apply w-4 h-4;
}
</style>