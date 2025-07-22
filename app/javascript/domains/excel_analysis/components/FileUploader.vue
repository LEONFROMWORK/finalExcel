<template>
  <div class="excel-uploader">
    <FileUpload
      ref="fileUploader"
      @upload="handleUpload"
      @select="handleFileSelect"
      :multiple="false"
      :accept="'.xlsx,.xls'"
      :maxFileSize="52428800"
      :customUpload="true"
      :disabled="isUploading"
      class="mb-6"
    >
      <template #header>
        <div></div>
      </template>
      <template #content="{ files, uploadedFiles, removeUploadedFileCallback, removeFileCallback }">
        <div v-if="files.length === 0" class="upload-content">
          <i class="pi pi-cloud-upload text-6xl text-gray-400 mb-4"></i>
          <h3 class="text-2xl font-semibold mb-2">Upload Excel File</h3>
          <p class="text-gray-600 mb-6 max-w-md mx-auto">
            Drag & drop your Excel file here, or click to browse. Our AI will automatically fix errors and improve your spreadsheet.
          </p>
          <p class="text-sm text-gray-500">
            Supports .xlsx and .xls files • Max size 50MB
          </p>
        </div>
        <div v-else class="file-list">
          <div v-for="file in files" :key="file.name" class="file-item">
            <Card class="mb-3">
              <template #content>
                <div class="flex items-center justify-between">
                  <div class="flex items-center gap-3">
                    <i class="pi pi-file-excel text-3xl text-green-600"></i>
                    <div>
                      <div class="font-semibold">{{ file.name }}</div>
                      <div class="text-sm text-gray-500">{{ formatFileSize(file.size) }}</div>
                    </div>
                  </div>
                  <Button 
                    icon="pi pi-times" 
                    severity="danger" 
                    text 
                    rounded 
                    @click="removeFileCallback(file)"
                  />
                </div>
                <ProgressBar 
                  v-if="isUploading" 
                  :value="uploadProgress" 
                  class="mt-3"
                  :showValue="true"
                />
              </template>
            </Card>
          </div>
        </div>
      </template>
      <template #empty>
        <div class="flex items-center justify-center h-64 border-2 border-dashed border-gray-300 rounded-lg">
          <div class="text-center">
            <i class="pi pi-cloud-upload text-6xl text-gray-400 mb-4"></i>
            <p class="text-gray-600">Drag and drop files here to upload.</p>
          </div>
        </div>
      </template>
    </FileUpload>
    
    <!-- Features -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mt-8">
      <Card v-for="feature in features" :key="feature.title">
        <template #content>
          <div class="text-center">
            <i :class="feature.icon" class="text-4xl mb-3" :style="{ color: feature.color }"></i>
            <h4 class="font-semibold mb-2">{{ feature.title }}</h4>
            <p class="text-sm text-gray-600">{{ feature.description }}</p>
          </div>
        </template>
      </Card>
    </div>
    
    <!-- Upload Dialog for Progress -->
    <Dialog 
      v-model:visible="showUploadDialog" 
      modal 
      :closable="false"
      header="Uploading File"
      :style="{ width: '450px' }"
    >
      <div class="text-center py-4">
        <i class="pi pi-spin pi-spinner text-4xl text-primary mb-4"></i>
        <p class="mb-4">Uploading {{ uploadingFileName }}...</p>
        <ProgressBar :value="uploadProgress" :showValue="true" />
      </div>
    </Dialog>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useExcelStore } from '../stores/excelStore'
import FileUpload from 'primevue/fileupload'
import Card from 'primevue/card'
import Button from 'primevue/button'
import ProgressBar from 'primevue/progressbar'
import Dialog from 'primevue/dialog'

const router = useRouter()
const excelStore = useExcelStore()

const fileUploader = ref()
const isUploading = ref(false)
const uploadProgress = ref(0)
const uploadingFileName = ref('')
const showUploadDialog = ref(false)

const features = [
  {
    icon: 'pi pi-bolt',
    color: '#f59e0b',
    title: 'Auto-Fix Errors',
    description: 'Detects and corrects formula errors, data issues'
  },
  {
    icon: 'pi pi-chart-bar',
    color: '#10b981',
    title: 'Preserve Structure',
    description: 'Maintains your original formatting and layout'
  },
  {
    icon: 'pi pi-rocket',
    color: '#3b82f6',
    title: 'Instant Results',
    description: 'Get your corrected file in seconds'
  }
]

const formatFileSize = (bytes) => {
  if (bytes === 0) return '0 Bytes'
  const k = 1024
  const sizes = ['Bytes', 'KB', 'MB', 'GB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
}

const handleFileSelect = (event) => {
  const file = event.files[0]
  if (file) {
    uploadFile(file)
  }
}

const handleUpload = (event) => {
  const file = event.files[0]
  uploadFile(file)
}

const uploadFile = async (file) => {
  isUploading.value = true
  uploadingFileName.value = file.name
  uploadProgress.value = 0
  showUploadDialog.value = true
  
  const formData = new FormData()
  formData.append('file', file)
  
  try {
    const result = await excelStore.uploadFile(formData, {
      onUploadProgress: (progressEvent) => {
        uploadProgress.value = Math.round(
          (progressEvent.loaded * 100) / progressEvent.total
        )
      }
    })
    
    if (result.success) {
      showUploadDialog.value = false
      router.push(`/excel/${result.file.id}/analysis`)
    }
  } catch (error) {
    console.error('Upload failed:', error)
    showUploadDialog.value = false
    // Clear the file from uploader
    fileUploader.value.clear()
  } finally {
    isUploading.value = false
    uploadProgress.value = 0
  }
}
</script>

<style scoped>
.excel-uploader {
  max-width: 800px;
  margin: 0 auto;
}

.upload-content {
  text-align: center;
  padding: 3rem;
}

.file-list {
  padding: 1rem;
}

:deep(.p-fileupload) {
  border: 2px dashed #e5e7eb;
  border-radius: 0.5rem;
  background: #f9fafb;
}

:deep(.p-fileupload:hover) {
  border-color: #f97316;
  background: #fff7ed;
}

:deep(.p-fileupload-content) {
  padding: 2rem;
}

:deep(.p-progressbar) {
  height: 0.5rem;
}
</style>