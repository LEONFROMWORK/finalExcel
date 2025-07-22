<template>
  <div class="error-solver">
    <!-- 오류 분석 섹션 -->
    <Card class="mb-4">
      <template #header>
        <div class="flex items-center justify-between">
          <h3 class="text-lg font-semibold">
            <i class="pi pi-exclamation-triangle mr-2"></i>
            Excel 오류 해결사
          </h3>
          <Tag :value="currentTier" :severity="tierSeverity" />
        </div>
      </template>
      
      <template #content>
        <!-- 오류 목록 -->
        <div v-if="errors.length > 0" class="mb-4">
          <h4 class="font-medium mb-2">발견된 오류 ({{ errors.length }}개)</h4>
          <div class="space-y-2">
            <div 
              v-for="error in errors" 
              :key="`${error.type}_${error.location}`"
              class="flex items-center justify-between p-3 border rounded-lg"
              :class="getErrorClass(error.severity)"
            >
              <div class="flex-1">
                <div class="flex items-center gap-2">
                  <i :class="getErrorIcon(error.type)" class="text-sm"></i>
                  <span class="font-medium">{{ error.type }}</span>
                  <span class="text-sm text-gray-600">@ {{ error.location }}</span>
                </div>
                <p class="text-sm text-gray-700 mt-1">{{ error.message }}</p>
              </div>
              <Button
                @click="selectError(error)"
                icon="pi pi-wrench"
                severity="secondary"
                size="small"
                rounded
                v-tooltip="'해결하기'"
              />
            </div>
          </div>
        </div>
        
        <!-- 오류 없음 -->
        <div v-else-if="!loading" class="text-center py-8 text-gray-500">
          <i class="pi pi-check-circle text-4xl text-green-500 mb-2"></i>
          <p>발견된 오류가 없습니다!</p>
        </div>
        
        <!-- 로딩 -->
        <div v-else class="flex justify-center py-8">
          <ProgressSpinner />
        </div>
      </template>
    </Card>
    
    <!-- 선택된 오류 해결 -->
    <Card v-if="selectedError" class="mb-4">
      <template #header>
        <div class="flex items-center justify-between">
          <h3 class="text-lg font-semibold">
            오류 해결: {{ selectedError.type }}
          </h3>
          <Button
            @click="selectedError = null"
            icon="pi pi-times"
            severity="secondary"
            text
            rounded
          />
        </div>
      </template>
      
      <template #content>
        <!-- 해결 단계 표시 -->
        <div class="space-y-4">
          <!-- Phase 1: 정적 분석 -->
          <div class="phase-section">
            <div class="flex items-center gap-2 mb-2">
              <i class="pi pi-search text-blue-500"></i>
              <span class="font-medium">1단계: 무료 정적 분석</span>
              <Tag 
                v-if="solution.type === 'static_analysis'" 
                value="해결됨" 
                severity="success" 
              />
            </div>
            
            <div v-if="solution.type === 'static_analysis'" class="ml-6">
              <div class="bg-blue-50 p-3 rounded">
                <p class="font-medium mb-2">{{ solution.solution.description }}</p>
                <ol class="list-decimal list-inside space-y-1">
                  <li v-for="(step, idx) in solution.solution.steps" :key="idx" class="text-sm">
                    {{ step }}
                  </li>
                </ol>
                
                <Button
                  v-if="solution.solution.auto_fix"
                  @click="applyAutoFix"
                  label="자동 수정 적용"
                  icon="pi pi-bolt"
                  severity="success"
                  size="small"
                  class="mt-3"
                />
              </div>
            </div>
            <div v-else class="ml-6 text-gray-500 text-sm">
              정적 분석으로 해결 불가
            </div>
          </div>
          
          <!-- Phase 2: AI 분석 -->
          <div class="phase-section" v-if="solution.type !== 'static_analysis'">
            <div class="flex items-center gap-2 mb-2">
              <i class="pi pi-sparkles text-purple-500"></i>
              <span class="font-medium">2단계: AI 분석</span>
              <Tag 
                v-if="solution.tier"
                :value="`${solution.tier} (${formatCost(solution.cost)})`"
                :severity="solution.tier === 'basic' ? 'info' : 'warning'"
              />
            </div>
            
            <div v-if="solution.type === 'ai_guidance'" class="ml-6">
              <div class="bg-purple-50 p-3 rounded">
                <div v-for="(item, idx) in solution.solution.explanations" :key="idx" class="mb-2">
                  <p class="text-sm">{{ item.content }}</p>
                </div>
                
                <div v-if="solution.solution.formulas && solution.solution.formulas.length > 0" class="mt-3">
                  <p class="font-medium text-sm mb-1">제안된 수식:</p>
                  <div v-for="formula in solution.solution.formulas" :key="formula.cell" 
                       class="bg-white p-2 rounded border font-mono text-sm">
                    {{ formula.cell }}: {{ formula.formula }}
                  </div>
                </div>
              </div>
            </div>
            <div v-else-if="analyzing" class="ml-6">
              <div class="flex items-center gap-2 text-gray-600">
                <ProgressSpinner style="width: 20px; height: 20px" />
                <span class="text-sm">AI 분석 중...</span>
              </div>
            </div>
          </div>
          
          <!-- Phase 3: Code Execution -->
          <div class="phase-section" v-if="solution.requires_escalation">
            <div class="flex items-center gap-2 mb-2">
              <i class="pi pi-code text-orange-500"></i>
              <span class="font-medium">3단계: 고급 실행 (Enterprise)</span>
              <Tag value="필요" severity="danger" />
            </div>
            
            <div class="ml-6">
              <div class="bg-orange-50 p-3 rounded">
                <p class="font-medium mb-2">{{ solution.message }}</p>
                <p class="text-sm text-gray-700 mb-3">
                  예상 비용: ${{ solution.estimated_cost }}
                </p>
                
                <div class="grid grid-cols-2 gap-2 mb-3">
                  <div v-for="(feature, key) in solution.capabilities" :key="key"
                       class="bg-white p-2 rounded border">
                    <p class="font-medium text-sm">{{ feature.description }}</p>
                    <ul class="text-xs text-gray-600 mt-1">
                      <li v-for="example in feature.examples" :key="example">
                        • {{ example }}
                      </li>
                    </ul>
                  </div>
                </div>
                
                <div class="flex gap-2">
                  <Button
                    v-if="userTier === 'enterprise'"
                    @click="executeAdvanced"
                    label="고급 분석 실행"
                    icon="pi pi-play"
                    severity="warning"
                    size="small"
                  />
                  <Button
                    v-else
                    @click="showUpgradeDialog = true"
                    label="Enterprise로 업그레이드"
                    icon="pi pi-crown"
                    severity="info"
                    size="small"
                  />
                </div>
              </div>
            </div>
          </div>
        </div>
      </template>
    </Card>
    
    <!-- 빠른 작업 -->
    <Card>
      <template #header>
        <h3 class="text-lg font-semibold">
          <i class="pi pi-bolt mr-2"></i>
          빠른 작업
        </h3>
      </template>
      
      <template #content>
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-3">
          <Button
            @click="runStaticAnalysis"
            label="정적 분석"
            icon="pi pi-search"
            severity="secondary"
            class="p-button-sm"
            :loading="loading"
          />
          <Button
            @click="fixAllSimpleErrors"
            label="간단한 오류 자동 수정"
            icon="pi pi-wrench"
            severity="success"
            class="p-button-sm"
            :disabled="simpleErrors.length === 0"
          />
          <Button
            @click="exportErrorReport"
            label="오류 보고서"
            icon="pi pi-download"
            severity="info"
            class="p-button-sm"
          />
          <Button
            @click="showHelpDialog = true"
            label="도움말"
            icon="pi pi-question-circle"
            severity="help"
            class="p-button-sm"
          />
        </div>
      </template>
    </Card>
    
    <!-- 업그레이드 다이얼로그 -->
    <Dialog 
      v-model:visible="showUpgradeDialog"
      header="Enterprise 업그레이드"
      :style="{ width: '450px' }"
      modal
    >
      <div class="space-y-4">
        <p>고급 분석 기능을 사용하려면 Enterprise 플랜이 필요합니다.</p>
        
        <div class="bg-gray-50 p-4 rounded">
          <h4 class="font-semibold mb-2">Enterprise 플랜 혜택</h4>
          <ul class="space-y-1 text-sm">
            <li>✓ Code Interpreter 실행</li>
            <li>✓ 대량 데이터 변환</li>
            <li>✓ 고급 수식 자동 생성</li>
            <li>✓ What-if 분석</li>
            <li>✓ 무제한 AI 사용</li>
          </ul>
        </div>
        
        <div class="flex justify-end gap-2">
          <Button
            @click="showUpgradeDialog = false"
            label="취소"
            severity="secondary"
          />
          <Button
            @click="navigateToUpgrade"
            label="업그레이드 하기"
            icon="pi pi-arrow-right"
          />
        </div>
      </div>
    </Dialog>
    
    <!-- 도움말 다이얼로그 -->
    <Dialog
      v-model:visible="showHelpDialog"
      header="Excel 오류 해결 도움말"
      :style="{ width: '600px' }"
      modal
    >
      <div class="space-y-4">
        <div>
          <h4 class="font-semibold mb-2">3단계 해결 프로세스</h4>
          <ol class="list-decimal list-inside space-y-2 text-sm">
            <li>
              <strong>정적 분석 (무료)</strong>: 
              코드 실행 없이 패턴 기반으로 오류를 분석하고 해결책을 제시합니다.
            </li>
            <li>
              <strong>AI 분석 (Basic/Pro)</strong>: 
              AI가 오류를 진단하고 구체적인 수식과 해결 방법을 생성합니다.
            </li>
            <li>
              <strong>Code Execution (Enterprise)</strong>: 
              실제 코드를 실행하여 데이터를 변환하고 복잡한 문제를 해결합니다.
            </li>
          </ol>
        </div>
        
        <div>
          <h4 class="font-semibold mb-2">주요 오류 타입</h4>
          <div class="grid grid-cols-2 gap-2 text-sm">
            <div>
              <strong>#REF!</strong>: 삭제된 셀 참조
            </div>
            <div>
              <strong>#VALUE!</strong>: 잘못된 데이터 타입
            </div>
            <div>
              <strong>#DIV/0!</strong>: 0으로 나누기
            </div>
            <div>
              <strong>#N/A</strong>: 값을 찾을 수 없음
            </div>
          </div>
        </div>
      </div>
    </Dialog>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import Card from 'primevue/card'
import Button from 'primevue/button'
import Tag from 'primevue/tag'
import ProgressSpinner from 'primevue/progressspinner'
import Dialog from 'primevue/dialog'
import Tooltip from 'primevue/tooltip'
import errorSolutionService from '../services/errorSolutionService'
import { useAuthStore } from '@/stores/authStore'
import { useToast } from 'primevue/usetoast'

const props = defineProps({
  excelFileId: {
    type: [String, Number],
    required: true
  }
})

const router = useRouter()
const authStore = useAuthStore()
const toast = useToast()

// State
const errors = ref([])
const selectedError = ref(null)
const solution = ref({})
const loading = ref(false)
const analyzing = ref(false)
const showUpgradeDialog = ref(false)
const showHelpDialog = ref(false)

// Computed
const currentTier = computed(() => {
  const tierMap = {
    basic: 'Basic',
    pro: 'Pro',
    enterprise: 'Enterprise'
  }
  return tierMap[authStore.user?.ai_tier] || 'Free'
})

const userTier = computed(() => authStore.user?.ai_tier || 'free')

const tierSeverity = computed(() => {
  const severityMap = {
    Free: 'secondary',
    Basic: 'info',
    Pro: 'warning',
    Enterprise: 'success'
  }
  return severityMap[currentTier.value] || 'secondary'
})

const simpleErrors = computed(() => {
  return errors.value.filter(error => 
    ['#DIV/0!', '#VALUE!', '#N/A'].includes(error.type)
  )
})

// Methods
const runStaticAnalysis = async () => {
  loading.value = true
  try {
    const response = await errorSolutionService.getStaticAnalysis(props.excelFileId)
    errors.value = response.data.errors
    
    toast.add({
      severity: 'success',
      summary: '분석 완료',
      detail: `${errors.value.length}개의 오류를 발견했습니다`,
      life: 3000
    })
  } catch (error) {
    console.error('Static analysis failed:', error)
    toast.add({
      severity: 'error',
      summary: '분석 실패',
      detail: '오류 분석에 실패했습니다',
      life: 3000
    })
  } finally {
    loading.value = false
  }
}

const selectError = async (error) => {
  selectedError.value = error
  solution.value = {}
  analyzing.value = true
  
  try {
    const response = await errorSolutionService.analyzeSolution(props.excelFileId, {
      problem_description: `Fix ${error.type} error at ${error.location}`,
      selected_errors: [error]
    })
    
    solution.value = response.data
  } catch (error) {
    console.error('Solution analysis failed:', error)
    toast.add({
      severity: 'error',
      summary: '해결책 분석 실패',
      detail: error.response?.data?.error || '분석에 실패했습니다',
      life: 3000
    })
  } finally {
    analyzing.value = false
  }
}

const applyAutoFix = async () => {
  try {
    const response = await errorSolutionService.quickFix(
      props.excelFileId,
      selectedError.value.type,
      selectedError.value.location
    )
    
    if (response.data.success) {
      toast.add({
        severity: 'success',
        summary: '자동 수정 완료',
        detail: response.data.message,
        life: 3000
      })
      
      // 오류 목록 새로고침
      await runStaticAnalysis()
      selectedError.value = null
    } else {
      toast.add({
        severity: 'warn',
        summary: '자동 수정 불가',
        detail: response.data.message,
        life: 5000
      })
    }
  } catch (error) {
    console.error('Auto fix failed:', error)
    toast.add({
      severity: 'error',
      summary: '수정 실패',
      detail: '자동 수정에 실패했습니다',
      life: 3000
    })
  }
}

const fixAllSimpleErrors = async () => {
  const fixPromises = simpleErrors.value.map(error =>
    errorSolutionService.quickFix(props.excelFileId, error.type, error.location)
  )
  
  try {
    const results = await Promise.allSettled(fixPromises)
    const successCount = results.filter(r => r.status === 'fulfilled' && r.value.data.success).length
    
    toast.add({
      severity: successCount > 0 ? 'success' : 'warn',
      summary: '일괄 수정 완료',
      detail: `${successCount}/${simpleErrors.value.length}개 오류를 수정했습니다`,
      life: 5000
    })
    
    // 새로고침
    await runStaticAnalysis()
  } catch (error) {
    console.error('Batch fix failed:', error)
  }
}

const executeAdvanced = async () => {
  try {
    const response = await errorSolutionService.executeAdvanced(props.excelFileId)
    
    toast.add({
      severity: 'info',
      summary: '고급 분석',
      detail: response.data.message,
      life: 3000
    })
  } catch (error) {
    console.error('Advanced execution failed:', error)
  }
}

const exportErrorReport = () => {
  // 오류 보고서 생성
  const report = {
    file_id: props.excelFileId,
    timestamp: new Date().toISOString(),
    errors: errors.value,
    tier: currentTier.value
  }
  
  const blob = new Blob([JSON.stringify(report, null, 2)], { type: 'application/json' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `error_report_${props.excelFileId}_${Date.now()}.json`
  a.click()
  URL.revokeObjectURL(url)
}

const navigateToUpgrade = () => {
  showUpgradeDialog.value = false
  router.push('/settings/subscription')
}

const getErrorClass = (severity) => {
  const classes = {
    error: 'border-red-300 bg-red-50',
    warning: 'border-yellow-300 bg-yellow-50',
    info: 'border-blue-300 bg-blue-50'
  }
  return classes[severity] || 'border-gray-300'
}

const getErrorIcon = (errorType) => {
  if (errorType.startsWith('#')) return 'pi pi-exclamation-circle text-red-500'
  if (errorType.includes('reference')) return 'pi pi-link text-orange-500'
  if (errorType.includes('data')) return 'pi pi-database text-blue-500'
  return 'pi pi-info-circle text-gray-500'
}

const formatCost = (cost) => {
  if (cost === 0) return '무료'
  if (cost < 0.01) return '<$0.01'
  return `$${cost.toFixed(2)}`
}

// Lifecycle
onMounted(() => {
  runStaticAnalysis()
})
</script>

<style scoped>
.phase-section {
  padding: 1rem;
  border: 1px solid #e5e7eb;
  border-radius: 0.5rem;
  background-color: #fafafa;
}

.phase-section:hover {
  background-color: #f5f5f5;
}
</style>