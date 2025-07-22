<template>
  <div class="large-file-upload">
    <Card>
      <template #header>
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-2">
            <i class="pi pi-cloud-upload text-xl"></i>
            <span class="font-semibold">대용량 파일 업로드</span>
          </div>
          <Tag v-if="file" severity="info">
            {{ formatFileSize(file.size) }}
          </Tag>
        </div>
      </template>
      
      <template #content>
        <!-- File Selection -->
        <div v-if="!file && !isUploading" class="upload-area">
          <div 
            class="drop-zone"
            :class="{ 'drag-over': isDragOver }"
            @drop="handleDrop"
            @dragover.prevent="isDragOver = true"
            @dragleave="isDragOver = false"
          >
            <i class="pi pi-cloud-upload text-5xl text-gray-400 mb-4"></i>
            <p class="text-lg mb-2">파일을 드래그하여 업로드</p>
            <p class="text-sm text-gray-500 mb-4">또는</p>
            <Button 
              label="파일 선택" 
              icon="pi pi-folder-open"
              @click="selectFile"
            />
            <input 
              ref="fileInput"
              type="file"
              accept=".xlsx,.xls"
              @change="handleFileSelect"
              style="display: none"
            />
            <p class="text-xs text-gray-500 mt-4">
              최대 500MB까지 업로드 가능합니다
            </p>
          </div>
        </div>
        
        <!-- Upload Progress -->
        <div v-else-if="isUploading" class="upload-progress">
          <div class="file-info mb-4">
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-2">
                <i class="pi pi-file-excel text-2xl text-green-600"></i>
                <div>
                  <p class="font-semibold">{{ file.name }}</p>
                  <p class="text-sm text-gray-500">
                    {{ formatFileSize(uploadedBytes) }} / {{ formatFileSize(file.size) }}
                  </p>
                </div>
              </div>
              <div class="flex gap-2">
                <Button 
                  v-if="!isPaused"
                  icon="pi pi-pause"
                  severity="secondary"
                  rounded
                  text
                  @click="pauseUpload"
                  v-tooltip="'일시정지'"
                />
                <Button 
                  v-else
                  icon="pi pi-play"
                  severity="success"
                  rounded
                  text
                  @click="resumeUpload"
                  v-tooltip="'재개'"
                />
                <Button 
                  icon="pi pi-times"
                  severity="danger"
                  rounded
                  text
                  @click="cancelUpload"
                  v-tooltip="'취소'"
                />
              </div>
            </div>
          </div>
          
          <ProgressBar 
            :value="uploadProgress" 
            :showValue="true"
            class="mb-2"
          />
          
          <div class="upload-stats grid grid-cols-3 gap-4 text-sm">
            <div>
              <span class="text-gray-500">진행률:</span>
              <span class="font-semibold ml-1">{{ uploadProgress.toFixed(1) }}%</span>
            </div>
            <div>
              <span class="text-gray-500">속도:</span>
              <span class="font-semibold ml-1">{{ uploadSpeed }}</span>
            </div>
            <div>
              <span class="text-gray-500">남은 시간:</span>
              <span class="font-semibold ml-1">{{ remainingTime }}</span>
            </div>
          </div>
          
          <div v-if="uploadedChunks.length > 0" class="chunk-info mt-4">
            <p class="text-sm text-gray-500">
              청크 진행상황: {{ uploadedChunks.length }} / {{ totalChunks }}
            </p>
            <div class="chunk-grid">
              <span 
                v-for="i in totalChunks" 
                :key="i"
                class="chunk-indicator"
                :class="{
                  'uploaded': uploadedChunks.includes(i - 1),
                  'uploading': currentChunk === i - 1
                }"
              ></span>
            </div>
          </div>
        </div>
        
        <!-- Upload Complete -->
        <div v-else-if="uploadComplete" class="upload-complete text-center py-8">
          <i class="pi pi-check-circle text-5xl text-green-600 mb-4"></i>
          <h3 class="text-xl font-semibold mb-2">업로드 완료!</h3>
          <p class="text-gray-600 mb-4">{{ file.name }}</p>
          <div class="flex gap-2 justify-center">
            <Button 
              label="파일 분석하기" 
              icon="pi pi-search"
              @click="analyzeFile"
              severity="success"
            />
            <Button 
              label="새 파일 업로드" 
              icon="pi pi-plus"
              @click="reset"
              outlined
            />
          </div>
        </div>
        
        <!-- Error State -->
        <div v-else-if="error" class="upload-error text-center py-8">
          <i class="pi pi-exclamation-circle text-5xl text-red-600 mb-4"></i>
          <h3 class="text-xl font-semibold mb-2">업로드 실패</h3>
          <p class="text-gray-600 mb-4">{{ error }}</p>
          <Button 
            label="다시 시도" 
            icon="pi pi-refresh"
            @click="retryUpload"
            severity="danger"
          />
        </div>
      </template>
    </Card>
  </div>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { useToast } from 'primevue/usetoast'
import Card from 'primevue/card'
import Button from 'primevue/button'
import ProgressBar from 'primevue/progressbar'
import Tag from 'primevue/tag'
import { ChunkedUploadService, ResumableUploadService } from '../services/chunkedUpload'

const props = defineProps({
  enableResume: {
    type: Boolean,
    default: true
  },
  chunkSize: {
    type: Number,
    default: 5 * 1024 * 1024 // 5MB
  }
})

const emit = defineEmits(['upload-complete', 'upload-error'])

const toast = useToast()

// Refs
const fileInput = ref(null)
const file = ref(null)
const isDragOver = ref(false)
const isUploading = ref(false)
const isPaused = ref(false)
const uploadComplete = ref(false)
const error = ref(null)
const uploadProgress = ref(0)
const uploadedBytes = ref(0)
const uploadedChunks = ref([])
const totalChunks = ref(0)
const currentChunk = ref(-1)
const uploadStartTime = ref(null)
const lastProgressTime = ref(null)
const lastProgressBytes = ref(0)
const uploadService = ref(null)
const uploadResult = ref(null)

// Computed
const uploadSpeed = computed(() => {
  if (!uploadStartTime.value || !lastProgressTime.value) return '0 KB/s'
  
  const timeDiff = (lastProgressTime.value - uploadStartTime.value) / 1000 // seconds
  const bytesDiff = uploadedBytes.value - lastProgressBytes.value
  
  if (timeDiff === 0) return '0 KB/s'
  
  const bytesPerSecond = bytesDiff / timeDiff
  return formatSpeed(bytesPerSecond)
})

const remainingTime = computed(() => {
  if (!file.value || uploadProgress.value === 0) return '계산 중...'
  
  const remainingBytes = file.value.size - uploadedBytes.value
  const currentSpeed = getAverageSpeed()
  
  if (currentSpeed === 0) return '계산 중...'
  
  const remainingSeconds = remainingBytes / currentSpeed
  return formatTime(remainingSeconds)
})

// Methods
const selectFile = () => {
  fileInput.value.click()
}

const handleFileSelect = (event) => {
  const selectedFile = event.target.files[0]
  if (selectedFile) {
    processFile(selectedFile)
  }
}

const handleDrop = (event) => {
  event.preventDefault()
  isDragOver.value = false
  
  const droppedFile = event.dataTransfer.files[0]
  if (droppedFile) {
    processFile(droppedFile)
  }
}

const processFile = async (selectedFile) => {
  // Validate file
  if (!selectedFile.name.match(/\.(xlsx|xls)$/i)) {
    toast.add({
      severity: 'error',
      summary: '잘못된 파일 형식',
      detail: 'Excel 파일(.xlsx, .xls)만 업로드 가능합니다',
      life: 5000
    })
    return
  }
  
  if (selectedFile.size > 500 * 1024 * 1024) {
    toast.add({
      severity: 'error',
      summary: '파일 크기 초과',
      detail: '500MB 이하의 파일만 업로드 가능합니다',
      life: 5000
    })
    return
  }
  
  file.value = selectedFile
  
  // Check for resumable upload
  if (props.enableResume && selectedFile.size > 50 * 1024 * 1024) {
    const savedProgress = localStorage.getItem(`chunked_upload_progress_${selectedFile.name}`)
    if (savedProgress) {
      const resume = await confirmResume()
      if (resume) {
        startUpload(true)
        return
      }
    }
  }
  
  startUpload(false)
}

const confirmResume = () => {
  return new Promise((resolve) => {
    // In a real app, use a proper confirmation dialog
    const confirmed = confirm('이전 업로드를 이어서 진행하시겠습니까?')
    resolve(confirmed)
  })
}

const startUpload = async (resume = false) => {
  isUploading.value = true
  uploadComplete.value = false
  error.value = null
  uploadStartTime.value = Date.now()
  lastProgressTime.value = Date.now()
  
  // Create upload service
  const ServiceClass = props.enableResume ? ResumableUploadService : ChunkedUploadService
  
  uploadService.value = new ServiceClass({
    chunkSize: props.chunkSize,
    onProgress: (progress) => {
      uploadProgress.value = progress
      lastProgressTime.value = Date.now()
    },
    onChunkComplete: (chunkIndex, total) => {
      uploadedChunks.value.push(chunkIndex)
      totalChunks.value = total
      currentChunk.value = -1
    },
    onComplete: (result) => {
      handleUploadComplete(result)
    },
    onError: (error) => {
      handleUploadError(error)
    }
  })
  
  try {
    uploadResult.value = await uploadService.value.upload(file.value)
  } catch (err) {
    // Error already handled by onError callback
  }
}

const handleUploadComplete = (result) => {
  isUploading.value = false
  uploadComplete.value = true
  uploadProgress.value = 100
  
  toast.add({
    severity: 'success',
    summary: '업로드 완료',
    detail: '파일이 성공적으로 업로드되었습니다',
    life: 3000
  })
  
  emit('upload-complete', result)
}

const handleUploadError = (err) => {
  isUploading.value = false
  error.value = err.message || '업로드 중 오류가 발생했습니다'
  
  toast.add({
    severity: 'error',
    summary: '업로드 실패',
    detail: error.value,
    life: 5000
  })
  
  emit('upload-error', err)
}

const pauseUpload = () => {
  if (uploadService.value) {
    uploadService.value.pause()
    isPaused.value = true
  }
}

const resumeUpload = () => {
  if (uploadService.value) {
    uploadService.value.resume()
    isPaused.value = false
  }
}

const cancelUpload = async () => {
  if (uploadService.value) {
    await uploadService.value.cancel()
  }
  
  reset()
  
  toast.add({
    severity: 'info',
    summary: '업로드 취소됨',
    detail: '파일 업로드가 취소되었습니다',
    life: 3000
  })
}

const retryUpload = () => {
  error.value = null
  startUpload(false)
}

const analyzeFile = () => {
  if (uploadResult.value && uploadResult.value.file_id) {
    // Navigate to analysis page or trigger analysis
    window.location.href = `/excel/analysis/${uploadResult.value.file_id}`
  }
}

const reset = () => {
  file.value = null
  isUploading.value = false
  isPaused.value = false
  uploadComplete.value = false
  error.value = null
  uploadProgress.value = 0
  uploadedBytes.value = 0
  uploadedChunks.value = []
  totalChunks.value = 0
  currentChunk.value = -1
  uploadService.value = null
  uploadResult.value = null
  
  if (fileInput.value) {
    fileInput.value.value = ''
  }
}

// Helper functions
const formatFileSize = (bytes) => {
  if (bytes === 0) return '0 Bytes'
  
  const k = 1024
  const sizes = ['Bytes', 'KB', 'MB', 'GB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
}

const formatSpeed = (bytesPerSecond) => {
  if (bytesPerSecond < 1024) {
    return `${bytesPerSecond.toFixed(0)} B/s`
  } else if (bytesPerSecond < 1024 * 1024) {
    return `${(bytesPerSecond / 1024).toFixed(1)} KB/s`
  } else {
    return `${(bytesPerSecond / (1024 * 1024)).toFixed(1)} MB/s`
  }
}

const formatTime = (seconds) => {
  if (seconds < 60) {
    return `${Math.ceil(seconds)}초`
  } else if (seconds < 3600) {
    return `${Math.ceil(seconds / 60)}분`
  } else {
    const hours = Math.floor(seconds / 3600)
    const minutes = Math.ceil((seconds % 3600) / 60)
    return `${hours}시간 ${minutes}분`
  }
}

const getAverageSpeed = () => {
  if (!uploadStartTime.value) return 0
  
  const elapsedTime = (Date.now() - uploadStartTime.value) / 1000
  if (elapsedTime === 0) return 0
  
  return uploadedBytes.value / elapsedTime
}

// Watch for progress updates
watch(uploadProgress, (newProgress) => {
  uploadedBytes.value = (file.value?.size || 0) * (newProgress / 100)
})
</script>

<style scoped>
.drop-zone {
  border: 2px dashed #e5e7eb;
  border-radius: 0.5rem;
  padding: 3rem;
  text-align: center;
  transition: all 0.3s;
  cursor: pointer;
}

.drop-zone:hover,
.drop-zone.drag-over {
  border-color: #f97316;
  background-color: #fff7ed;
}

.chunk-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(10px, 1fr));
  gap: 2px;
  margin-top: 0.5rem;
}

.chunk-indicator {
  height: 10px;
  background-color: #e5e7eb;
  border-radius: 2px;
  transition: background-color 0.3s;
}

.chunk-indicator.uploaded {
  background-color: #10b981;
}

.chunk-indicator.uploading {
  background-color: #f59e0b;
  animation: pulse 1s infinite;
}

@keyframes pulse {
  0%, 100% {
    opacity: 1;
  }
  50% {
    opacity: 0.5;
  }
}

.upload-stats > div {
  padding: 0.5rem;
  background-color: #f9fafb;
  border-radius: 0.375rem;
}
</style>