<template>
  <div class="excel-workspace">
    <!-- Header with Credit Display -->
    <div class="workspace-header">
      <div class="flex items-center justify-between">
        <h1 class="text-2xl font-bold">Excel 통합 작업 공간</h1>
        <div class="credit-display">
          <Card class="p-2">
            <template #content>
              <div class="flex items-center gap-3">
                <i class="pi pi-wallet text-2xl text-orange-500"></i>
                <div>
                  <div class="text-sm text-gray-500">현재 크레딧</div>
                  <div class="text-xl font-bold">{{ userCredits.toLocaleString() }}</div>
                </div>
                <Button 
                  icon="pi pi-plus" 
                  label="충전" 
                  size="small" 
                  outlined 
                  @click="showCreditDialog = true" 
                />
              </div>
            </template>
          </Card>
        </div>
      </div>
    </div>

    <!-- Main Content Area -->
    <Splitter :style="{ height: 'calc(100vh - 200px)' }" class="mb-5">
      <!-- Left Panel - Work Area (70%) -->
      <SplitterPanel :size="70" :minSize="50">
        <div class="work-area p-4">
          <!-- File Upload Section -->
          <Card class="mb-4">
            <template #header>
              <div class="flex items-center gap-2">
                <i class="pi pi-file-excel text-xl"></i>
                <span class="font-semibold">파일 업로드</span>
              </div>
            </template>
            <template #content>
              <!-- Regular upload for small files -->
              <FileUpload
                v-if="!showLargeFileUpload"
                ref="fileUploader"
                name="files[]"
                :multiple="false"
                :accept="'.xlsx,.xls'"
                @select="handleFileSelect"
                :maxFileSize="52428800"
                :showUploadButton="false"
                :showCancelButton="false"
              >
                <template #header>
                  <div class="flex items-center justify-between w-full">
                    <span class="text-sm text-gray-500">Excel 파일을 업로드하세요</span>
                    <Button 
                      label="대용량 파일" 
                      icon="pi pi-upload"
                      text
                      size="small"
                      @click="showLargeFileUpload = true"
                    />
                  </div>
                </template>
                <template #empty>
                  <div class="flex flex-col items-center justify-center py-12">
                    <i class="pi pi-cloud-upload text-5xl text-gray-400 mb-4"></i>
                    <p class="text-lg mb-2">파일을 드래그하여 업로드</p>
                    <p class="text-sm text-gray-500">또는 클릭하여 파일 선택</p>
                    <p class="text-xs text-gray-400 mt-2">50MB 이하 파일용</p>
                  </div>
                </template>
              </FileUpload>
              
              <!-- Large file upload component -->
              <LargeFileUpload 
                v-else
                @upload-complete="handleLargeFileUploadComplete"
                @upload-error="handleLargeFileUploadError"
              >
                <template #header>
                  <Button 
                    icon="pi pi-arrow-left"
                    label="일반 업로드로 돌아가기"
                    text
                    size="small"
                    @click="showLargeFileUpload = false"
                  />
                </template>
              </LargeFileUpload>

              <!-- File Analysis Results -->
              <div v-if="currentFile" class="mt-4">
                <Divider />
                <TabView>
                  <TabPanel header="분석 요약">
                    <div class="analysis-results">
                      <div v-if="analysisResult">
                        <div class="grid grid-cols-2 gap-4">
                          <div class="stat-item">
                            <i class="pi pi-table text-blue-500"></i>
                            <span>시트 수: {{ analysisResult.file_analysis?.summary?.total_sheets || 0 }}</span>
                          </div>
                          <div 
                            class="stat-item" 
                            :class="{ 'cursor-pointer hover:bg-orange-50': totalIssues > 0 }"
                            @click="totalIssues > 0 && (showErrorSolver = true)"
                          >
                            <i class="pi pi-exclamation-triangle text-orange-500"></i>
                            <span>오류 감지: </span>
                            <Badge 
                              :value="totalIssues" 
                              :severity="totalIssues > 0 ? 'danger' : 'success'"
                            />
                          </div>
                          <div class="stat-item">
                            <i class="pi pi-chart-line text-green-500"></i>
                            <span>수식 수: {{ analysisResult.file_analysis?.summary?.total_formulas || 0 }}</span>
                          </div>
                          <div class="stat-item">
                            <i class="pi pi-code text-purple-500"></i>
                            <span>VBA: {{ analysisResult.file_analysis?.summary?.has_vba ? '있음' : '없음' }}</span>
                          </div>
                        </div>
                      </div>
                      <div v-else-if="isProcessing" class="text-center py-4">
                        <ProgressSpinner style="width: 50px; height: 50px" />
                        <p class="mt-2">파일 분석 중...</p>
                      </div>
                    </div>
                  </TabPanel>
                  <TabPanel header="오류 해결" :disabled="totalIssues === 0">
                    <ErrorSolver 
                      v-if="currentFile && analysisResult"
                      :excelFile="currentFile"
                      :errors="analysisResult.file_analysis?.errors || []"
                      @errors-resolved="handleErrorsResolved"
                    />
                  </TabPanel>
                </TabView>
              </div>
            </template>
          </Card>

          <!-- Quick Actions -->
          <Card v-if="currentFile && analysisResult" class="mb-4">
            <template #header>
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-2">
                  <i class="pi pi-bolt text-xl"></i>
                  <span class="font-semibold">빠른 작업</span>
                </div>
                <Tag severity="warning">
                  예상 크레딧: {{ estimatedCredits }}
                </Tag>
              </div>
            </template>
            <template #content>
              <div class="grid grid-cols-2 gap-4 mb-4">
                <Button 
                  v-for="action in quickActions" 
                  :key="action.value"
                  :label="action.label"
                  :icon="`pi ${action.icon}`"
                  :outlined="!selectedActions.includes(action.value)"
                  @click="toggleAction(action.value)"
                  class="justify-start"
                />
              </div>
              
              <div class="flex gap-2">
                <Button 
                  label="선택 작업 실행" 
                  icon="pi pi-play"
                  @click="executeSelectedActions"
                  :disabled="selectedActions.length === 0 || isProcessing"
                  severity="success"
                />
                <Button 
                  label="자동 수정" 
                  icon="pi pi-magic"
                  @click="executeAutoFix"
                  :disabled="isProcessing"
                  severity="warning"
                />
                <Button 
                  v-if="modificationResult"
                  label="다운로드" 
                  icon="pi pi-download"
                  @click="downloadResult"
                  severity="info"
                />
              </div>
            </template>
          </Card>

          <!-- New File Options -->
          <Card v-if="!currentFile" class="mb-4">
            <template #header>
              <div class="flex items-center gap-2">
                <i class="pi pi-plus text-xl"></i>
                <span class="font-semibold">새 파일 생성</span>
              </div>
            </template>
            <template #content>
              <div class="grid grid-cols-2 gap-4">
                <Button 
                  label="템플릿에서 시작" 
                  icon="pi pi-clone"
                  class="p-button-lg"
                  @click="showTemplateDialog = true"
                />
                <Button 
                  label="AI와 함께 생성" 
                  icon="pi pi-sparkles"
                  class="p-button-lg"
                  severity="info"
                  @click="focusAIInput"
                />
              </div>
            </template>
          </Card>
        </div>
      </SplitterPanel>

      <!-- Right Panel - AI Consultation (30%) -->
      <SplitterPanel :size="30" :minSize="20">
        <div class="ai-consultation-area h-full flex flex-col">
          <Card class="flex-1 flex flex-col">
            <template #header>
              <div class="flex items-center gap-2">
                <i class="pi pi-comments text-xl"></i>
                <span class="font-semibold">AI 상담</span>
                <Tag v-if="currentFile" severity="info" class="ml-auto">
                  {{ currentFile.filename }}
                </Tag>
              </div>
            </template>
            <template #content>
              <div class="flex flex-col h-full">
                <!-- Chat History -->
                <ScrollPanel ref="scrollPanel" class="flex-1 mb-4" style="height: calc(100vh - 400px)">
                  <div v-if="chatMessages.length === 0" class="text-center py-8 text-gray-500">
                    <i class="pi pi-comments text-4xl mb-4 block"></i>
                    <p>AI와 대화를 시작하세요.</p>
                    <p class="text-sm mt-2">파일 분석, 수정 제안, 새 파일 생성 등 모든 작업을 도와드립니다.</p>
                  </div>
                  
                  <div v-else class="space-y-4 pr-4">
                    <div 
                      v-for="message in chatMessages" 
                      :key="message.id"
                      :class="[
                        'message',
                        message.role === 'user' ? 'user-message' : 'ai-message'
                      ]"
                    >
                      <div class="flex items-start gap-3">
                        <Avatar 
                          :icon="message.role === 'user' ? 'pi pi-user' : 'pi pi-sparkles'"
                          :style="{ 
                            backgroundColor: message.role === 'user' ? '#f97316' : '#3b82f6',
                            color: 'white'
                          }"
                          shape="circle"
                        />
                        <div class="flex-1">
                          <div 
                            class="message-content"
                            v-html="formatMessageContent(message.content)"
                          ></div>
                          <div class="text-xs text-gray-500 mt-1">
                            {{ formatTime(message.timestamp) }}
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                </ScrollPanel>

                <!-- Input Area -->
                <div class="input-area border-t pt-4">
                  <div class="flex gap-2">
                    <Textarea
                      ref="aiInput"
                      v-model="userMessage"
                      :autoResize="true"
                      rows="3"
                      placeholder="질문을 입력하세요... (예: 이 오류를 어떻게 수정하나요?)"
                      class="flex-1"
                      @keydown.enter.prevent="sendMessage"
                    />
                    <Button 
                      icon="pi pi-send" 
                      @click="sendMessage"
                      :disabled="!userMessage.trim() || isProcessing"
                      :loading="isProcessing"
                    />
                  </div>
                  
                  <div class="text-xs text-gray-500 mt-2">
                    <i class="pi pi-info-circle"></i>
                    메시지당 5 크레딧이 사용됩니다.
                  </div>
                </div>
              </div>
            </template>
          </Card>
        </div>
      </SplitterPanel>
    </Splitter>

    <!-- Template Dialog -->
    <Dialog 
      v-model:visible="showTemplateDialog" 
      header="템플릿 선택" 
      :style="{ width: '50vw' }"
      :modal="true"
    >
      <div class="grid grid-cols-3 gap-4">
        <div 
          v-for="template in templates" 
          :key="template.id"
          class="template-card cursor-pointer p-4 border rounded-lg hover:border-orange-500 transition-colors"
          @click="selectTemplate(template)"
        >
          <i :class="template.icon" class="text-3xl mb-2"></i>
          <h4 class="font-semibold">{{ template.name }}</h4>
          <p class="text-sm text-gray-600">{{ template.description }}</p>
        </div>
      </div>
    </Dialog>

    <!-- Credit Purchase Dialog -->
    <Dialog 
      v-model:visible="showCreditDialog" 
      header="크레딧 충전" 
      :style="{ width: '30vw' }"
      :modal="true"
    >
      <CreditPurchase @purchased="handleCreditPurchase" />
    </Dialog>

    <!-- Error Solver Modal -->
    <Dialog 
      v-model:visible="showErrorSolver" 
      header="Excel 오류 해결사" 
      :style="{ width: '90vw' }"
      :modal="true"
      :maximizable="true"
      position="center"
    >
      <ErrorSolver 
        v-if="currentFile && analysisResult"
        :excelFile="currentFile"
        :errors="analysisResult.file_analysis?.errors || []"
        @errors-resolved="handleErrorsResolved"
      />
    </Dialog>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, nextTick, watch } from 'vue'
import { useToast } from 'primevue/usetoast'
import { useMemoryCleanup } from '../composables/useMemoryCleanup'
import Splitter from 'primevue/splitter'
import SplitterPanel from 'primevue/splitterpanel'
import Card from 'primevue/card'
import FileUpload from 'primevue/fileupload'
import Button from 'primevue/button'
import Textarea from 'primevue/textarea'
import ProgressSpinner from 'primevue/progressspinner'
import Dialog from 'primevue/dialog'
import Tag from 'primevue/tag'
import ScrollPanel from 'primevue/scrollpanel'
import Avatar from 'primevue/avatar'
import Divider from 'primevue/divider'
import TabView from 'primevue/tabview'
import TabPanel from 'primevue/tabpanel'
import Badge from 'primevue/badge'
import CreditPurchase from '../components/CreditPurchase.vue'
import LargeFileUpload from '../components/LargeFileUpload.vue'
import ErrorSolver from '../domains/ai_consultation/components/ErrorSolver.vue'
import VbaQuickHelper from '../components/VbaQuickHelper.vue'
import { useExcelStore } from '../stores/excel'
import { useUserStore } from '../stores/user'

// Memory cleanup
const { 
  setCleanupInterval, 
  addCleanupFunction,
  createCleanupAbortController 
} = useMemoryCleanup()

// Stores
const excelStore = useExcelStore()
const userStore = useUserStore()
const toast = useToast()

// Refs
const scrollPanel = ref(null)
const aiInput = ref(null)
const fileUploader = ref(null)

// State
const chatMessages = ref([])
const userMessage = ref('')
const showCreditDialog = ref(false)
const showTemplateDialog = ref(false)
const selectedActions = ref([])
const showLargeFileUpload = ref(false)
const showErrorSolver = ref(false)
const showVbaHelper = ref(false)
const vbaHelperMinimized = ref(false)

// Abort controller for API requests
let currentRequestController = null

// Computed properties
const currentFile = computed(() => excelStore.currentFile)
const analysisResult = computed(() => excelStore.analysisResult)
const modificationResult = computed(() => excelStore.modificationResult)
const isProcessing = computed(() => excelStore.isAnalyzing || excelStore.isModifying)
const userCredits = computed(() => userStore.credits || 100)
const totalIssues = computed(() => excelStore.totalIssues)

// Quick actions
const quickActions = [
  { label: '수식 오류 수정', value: 'formula_fix', icon: 'pi-wrench' },
  { label: '데이터 정리', value: 'data_cleanup', icon: 'pi-filter' },
  { label: '유효성 검사 추가', value: 'add_validation', icon: 'pi-shield' },
  { label: '차트 생성', value: 'add_chart', icon: 'pi-chart-line' },
  { label: '서식 개선', value: 'format_cells', icon: 'pi-palette' }
]

// Templates
const templates = [
  { id: 'monthly_report', name: '월간 보고서', icon: 'pi pi-calendar', description: '월별 데이터 집계 템플릿' },
  { id: 'inventory', name: '재고 관리', icon: 'pi pi-box', description: '재고 추적 및 관리 템플릿' },
  { id: 'financial_analysis', name: '재무 분석', icon: 'pi pi-chart-line', description: '수입/지출 분석 템플릿' },
  { id: 'project_management', name: '프로젝트 관리', icon: 'pi pi-briefcase', description: '프로젝트 진행 상황 추적' },
  { id: 'sales_dashboard', name: '판매 대시보드', icon: 'pi pi-shopping-cart', description: '판매 실적 분석 템플릿' },
  { id: 'hr_management', name: '인사 관리', icon: 'pi pi-users', description: '직원 정보 관리 템플릿' }
]

// Computed estimated credits
const estimatedCredits = computed(() => {
  let credits = 0
  if (currentFile.value) {
    credits += 10 // Base analysis
  }
  credits += selectedActions.value.length * 5
  return credits
})

// Watch for chat messages to auto-scroll
watch(chatMessages, async () => {
  await nextTick()
  if (scrollPanel.value) {
    const content = scrollPanel.value.$el.querySelector('.p-scrollpanel-content')
    if (content) {
      content.scrollTop = content.scrollHeight
    }
  }
}, { deep: true })

// Methods
const handleFileSelect = async (event) => {
  const file = event.files[0]
  if (!file) return
  
  // Cancel any pending request
  if (currentRequestController) {
    currentRequestController.abort()
  }
  
  currentRequestController = createCleanupAbortController()
  
  try {
    const result = await excelStore.uploadAndAnalyze(file, null, currentRequestController.signal)
    
    if (!result.success) {
      toast.add({ 
        severity: 'error', 
        summary: '업로드 실패', 
        detail: result.error,
        life: 5000
      })
    } else {
      toast.add({ 
        severity: 'success', 
        summary: '분석 완료', 
        detail: '파일 분석이 완료되었습니다.',
        life: 3000
      })
      
      // Add AI message about analysis
      chatMessages.value.push({
        id: Date.now(),
        role: 'assistant',
        content: `파일 분석이 완료되었습니다. ${totalIssues.value}개의 이슈를 발견했습니다. 어떤 작업을 도와드릴까요?`,
        timestamp: new Date()
      })
    }
  } catch (error) {
    if (error.name !== 'AbortError') {
      toast.add({ 
        severity: 'error', 
        summary: '오류 발생', 
        detail: '파일 처리 중 오류가 발생했습니다.',
        life: 5000
      })
    }
  } finally {
    currentRequestController = null
  }
}

const toggleAction = (actionValue) => {
  const index = selectedActions.value.indexOf(actionValue)
  if (index > -1) {
    selectedActions.value.splice(index, 1)
  } else {
    selectedActions.value.push(actionValue)
  }
}

const executeSelectedActions = async () => {
  if (selectedActions.value.length === 0) return
  
  const modifications = selectedActions.value.map(action => {
    switch (action) {
      case 'formula_fix':
        return { type: 'formula_fix' }
      case 'data_cleanup':
        return { type: 'data_cleanup', cleanup_type: 'all' }
      case 'add_validation':
        return { 
          type: 'add_validation', 
          range: 'A:A', 
          validation_type: 'list', 
          values: ['Valid', 'Invalid'] 
        }
      case 'add_chart':
        return { 
          type: 'add_chart', 
          chart_type: 'bar', 
          data_range: 'A1:C10',
          position: 'E5'
        }
      case 'format_cells':
        return { 
          type: 'format_cells', 
          range: 'A1:Z1',
          font: { bold: true, size: 12 },
          fill: { color: 'F0F0F0' }
        }
      default:
        return null
    }
  }).filter(Boolean)
  
  currentRequestController = createCleanupAbortController()
  
  try {
    const result = await excelStore.applyModifications(modifications, currentRequestController.signal)
    
    if (result.success) {
      toast.add({ 
        severity: 'success', 
        summary: '수정 완료', 
        detail: '선택한 작업이 완료되었습니다.',
        life: 3000
      })
      selectedActions.value = []
      
      // Deduct credits
      userStore.useCredits(estimatedCredits.value)
    } else {
      toast.add({ 
        severity: 'error', 
        summary: '수정 실패', 
        detail: result.error,
        life: 5000
      })
    }
  } catch (error) {
    if (error.name !== 'AbortError') {
      toast.add({ 
        severity: 'error', 
        summary: '오류 발생', 
        detail: '작업 처리 중 오류가 발생했습니다.',
        life: 5000
      })
    }
  } finally {
    currentRequestController = null
  }
}

const executeAutoFix = async () => {
  const modifications = [
    { type: 'formula_fix' },
    { type: 'data_cleanup', cleanup_type: 'all' }
  ]
  
  currentRequestController = createCleanupAbortController()
  
  try {
    const result = await excelStore.applyModifications(modifications, currentRequestController.signal)
    
    if (result.success) {
      toast.add({ 
        severity: 'success', 
        summary: '자동 수정 완료', 
        detail: '파일의 오류가 자동으로 수정되었습니다.',
        life: 3000
      })
      
      // Deduct credits
      userStore.useCredits(20)
    } else {
      toast.add({ 
        severity: 'error', 
        summary: '수정 실패', 
        detail: result.error,
        life: 5000
      })
    }
  } catch (error) {
    if (error.name !== 'AbortError') {
      toast.add({ 
        severity: 'error', 
        summary: '오류 발생', 
        detail: '자동 수정 중 오류가 발생했습니다.',
        life: 5000
      })
    }
  } finally {
    currentRequestController = null
  }
}

const downloadResult = async () => {
  const result = await excelStore.downloadModifiedFile()
  
  if (result.success) {
    toast.add({ 
      severity: 'success', 
      summary: '다운로드 완료', 
      detail: '파일이 다운로드되었습니다.',
      life: 3000
    })
  } else {
    toast.add({ 
      severity: 'error', 
      summary: '다운로드 실패', 
      detail: result.error,
      life: 5000
    })
  }
}

const selectTemplate = async (template) => {
  showTemplateDialog.value = false
  
  currentRequestController = createCleanupAbortController()
  
  try {
    const result = await excelStore.createFromTemplate(template.id, {}, currentRequestController.signal)
    
    if (result.success) {
      toast.add({ 
        severity: 'success', 
        summary: '템플릿 생성됨', 
        detail: `${template.name} 템플릿이 생성되었습니다.`,
        life: 3000
      })
      
      // Add to chat
      chatMessages.value.push({
        id: Date.now(),
        role: 'assistant',
        content: `${template.name} 템플릿을 생성했습니다. 추가로 수정하고 싶은 부분이 있으신가요?`,
        timestamp: new Date()
      })
    } else {
      toast.add({ 
        severity: 'error', 
        summary: '템플릿 생성 실패', 
        detail: result.error,
        life: 5000
      })
    }
  } catch (error) {
    if (error.name !== 'AbortError') {
      toast.add({ 
        severity: 'error', 
        summary: '오류 발생', 
        detail: '템플릿 생성 중 오류가 발생했습니다.',
        life: 5000
      })
    }
  } finally {
    currentRequestController = null
  }
}

const sendMessage = async () => {
  if (!userMessage.value.trim()) return
  
  // Add user message
  chatMessages.value.push({
    id: Date.now(),
    role: 'user',
    content: userMessage.value,
    timestamp: new Date()
  })
  
  const message = userMessage.value
  userMessage.value = ''
  
  currentRequestController = createCleanupAbortController()
  
  try {
    // Check if it's a request to create from AI
    if (message.toLowerCase().includes('만들') || message.toLowerCase().includes('생성')) {
      const result = await excelStore.createFromAI(message, [], currentRequestController.signal)
      
      if (result.success) {
        chatMessages.value.push({
          id: Date.now(),
          role: 'assistant',
          content: '요청하신 내용을 바탕으로 Excel 파일을 생성했습니다. 다운로드하시거나 추가 수정이 필요하시면 말씀해주세요.',
          timestamp: new Date()
        })
      } else {
        chatMessages.value.push({
          id: Date.now(),
          role: 'assistant',
          content: '파일 생성 중 오류가 발생했습니다. 다시 시도해주세요.',
          timestamp: new Date()
        })
      }
    } else {
      // Regular chat response
      chatMessages.value.push({
        id: Date.now(),
        role: 'assistant',
        content: '네, 도와드리겠습니다. 구체적으로 어떤 작업을 원하시는지 알려주세요.',
        timestamp: new Date()
      })
    }
    
    // Deduct credits
    userStore.useCredits(5)
  } catch (error) {
    if (error.name !== 'AbortError') {
      chatMessages.value.push({
        id: Date.now(),
        role: 'assistant',
        content: '죄송합니다. 요청 처리 중 오류가 발생했습니다.',
        timestamp: new Date()
      })
    }
  } finally {
    currentRequestController = null
  }
}

const formatTime = (date) => {
  return new Intl.DateTimeFormat('ko-KR', {
    hour: '2-digit',
    minute: '2-digit'
  }).format(date)
}

const handleCreditPurchase = (amount) => {
  userStore.addCredits(amount)
  showCreditDialog.value = false
  toast.add({ 
    severity: 'success', 
    summary: '충전 완료', 
    detail: `${amount} 크레딧이 충전되었습니다.`,
    life: 3000
  })
}

const handleLargeFileUploadComplete = async (result) => {
  showLargeFileUpload.value = false
  
  // Load the file info
  excelStore.currentFile = {
    id: result.file_id,
    filename: result.filename,
    url: result.file_url,
    size: result.file_size
  }
  
  toast.add({ 
    severity: 'success', 
    summary: '대용량 파일 업로드 완료', 
    detail: '파일 분석을 시작합니다.',
    life: 3000
  })
  
  // Add AI message
  chatMessages.value.push({
    id: Date.now(),
    role: 'assistant',
    content: `대용량 파일 업로드가 완료되었습니다. 파일 크기로 인해 분석에 시간이 걸릴 수 있습니다. 어떤 작업을 도와드릴까요?`,
    timestamp: new Date()
  })
}

const handleLargeFileUploadError = (error) => {
  toast.add({ 
    severity: 'error', 
    summary: '업로드 실패', 
    detail: error.message || '대용량 파일 업로드 중 오류가 발생했습니다.',
    life: 5000
  })
}

const focusAIInput = async () => {
  await nextTick()
  if (aiInput.value) {
    aiInput.value.$el.querySelector('textarea').focus()
  }
}

const handleErrorsResolved = async () => {
  // Refresh analysis after errors are resolved
  toast.add({ 
    severity: 'info', 
    summary: '새로고침 중', 
    detail: '오류 해결 후 분석 결과를 업데이트합니다.',
    life: 2000
  })
  
  // Re-analyze the file
  if (currentFile.value) {
    const result = await excelStore.analyzeFile(currentFile.value.id)
    if (result.success) {
      toast.add({ 
        severity: 'success', 
        summary: '업데이트 완료', 
        detail: '분석 결과가 업데이트되었습니다.',
        life: 3000
      })
      
      // Close modal if no more errors
      if (totalIssues.value === 0) {
        showErrorSolver.value = false
      }
    }
  }
}

// Cleanup
addCleanupFunction(() => {
  // Clear any large data
  chatMessages.value = []
  selectedActions.value = []
  
  // Clear file uploader
  if (fileUploader.value) {
    fileUploader.value.clear()
  }
  
  // Cancel any pending requests
  if (currentRequestController) {
    currentRequestController.abort()
  }
  
  // Clear store
  excelStore.clearFile()
})

// Auto-save chat history periodically
setCleanupInterval(() => {
  if (chatMessages.value.length > 100) {
    // Keep only last 50 messages to prevent memory buildup
    chatMessages.value = chatMessages.value.slice(-50)
  }
}, 60000) // Every minute

onMounted(() => {
  // Initialize user credits
  userStore.fetchCredits()
})
</script>

<style scoped>
.excel-workspace {
  height: 100vh;
  background-color: #f8f9fa;
}

.workspace-header {
  padding: 1rem 2rem;
  background: white;
  border-bottom: 1px solid #e9ecef;
}

.work-area {
  height: 100%;
  overflow-y: auto;
}

.ai-consultation-area {
  height: 100%;
  padding: 1rem;
  background-color: #f8f9fa;
}

.stat-item {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem;
  background: #f8f9fa;
  border-radius: 0.375rem;
}

.stat-item i {
  font-size: 1.25rem;
}

.template-card:hover {
  background-color: #fff7ed;
}

.message {
  display: flex;
}

.user-message {
  justify-content: flex-end;
}

.user-message .message-content {
  background-color: #f97316;
  color: white;
  padding: 0.75rem 1rem;
  border-radius: 1rem 1rem 0 1rem;
  max-width: 80%;
}

.ai-message .message-content {
  background-color: #e5e7eb;
  color: #374151;
  padding: 0.75rem 1rem;
  border-radius: 1rem 1rem 1rem 0;
  max-width: 80%;
}

:deep(.p-fileupload-content) {
  border: 2px dashed #e5e7eb;
  background-color: #f9fafb;
}

:deep(.p-fileupload-content:hover) {
  border-color: #f97316;
  background-color: #fff7ed;
}

:deep(.p-splitter-gutter) {
  background-color: #e5e7eb;
}

:deep(.p-button-lg) {
  padding: 1rem 1.5rem;
  font-size: 1.125rem;
}

:deep(.p-card) {
  box-shadow: 0 1px 3px 0 rgb(0 0 0 / 0.1);
}
</style>