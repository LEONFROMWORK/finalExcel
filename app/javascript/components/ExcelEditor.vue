<template>
  <div class="excel-editor">
    <!-- Formula Bar -->
    <div class="formula-bar">
      <div class="cell-reference">{{ selectedCell }}</div>
      <div class="formula-input-wrapper">
        <InputText 
          v-model="currentFormula"
          @input="validateFormula"
          @keydown.enter="applyFormula"
          placeholder="Enter formula or value"
          class="formula-input"
          :class="{ 'p-invalid': formulaError }"
        />
        <div v-if="formulaSuggestions.length" class="formula-suggestions">
          <div 
            v-for="suggestion in formulaSuggestions" 
            :key="suggestion.name"
            @click="insertSuggestion(suggestion)"
            class="suggestion-item"
          >
            <strong>{{ suggestion.name }}</strong>
            <span class="syntax">{{ suggestion.syntax }}</span>
            <span class="description">{{ suggestion.description }}</span>
          </div>
        </div>
      </div>
      <Button 
        icon="pi pi-check" 
        @click="applyFormula"
        :disabled="formulaError"
        severity="success"
        size="small"
      />
    </div>

    <!-- Error Display -->
    <Message v-if="formulaError" severity="error" :closable="false">
      <div class="flex items-center justify-between">
        <span>{{ formulaError }}</span>
        <Button 
          v-if="formulaSuggestion"
          label="자동 수정"
          icon="pi pi-wrench"
          @click="autoFixFormula"
          severity="warning"
          size="small"
        />
      </div>
    </Message>

    <!-- Quick Analysis -->
    <div v-if="analysisResult" class="quick-analysis">
      <Card>
        <template #header>
          <div class="flex items-center justify-between">
            <span class="font-semibold">빠른 분석</span>
            <Tag :severity="analysisResult.issues.length > 0 ? 'warning' : 'success'">
              {{ analysisResult.issues.length }} 이슈 발견
            </Tag>
          </div>
        </template>
        <template #content>
          <div class="analysis-stats">
            <div class="stat">
              <i class="pi pi-table"></i>
              <span>{{ analysisResult.stats.totalCells }} 셀</span>
            </div>
            <div class="stat">
              <i class="pi pi-calculator"></i>
              <span>{{ analysisResult.stats.formulaCells }} 수식</span>
            </div>
            <div class="stat">
              <i class="pi pi-exclamation-triangle"></i>
              <span>{{ analysisResult.stats.errorCells }} 오류</span>
            </div>
          </div>

          <div v-if="analysisResult.issues.length > 0" class="mt-3">
            <Button 
              label="모든 오류 자동 수정"
              icon="pi pi-wrench"
              @click="fixAllErrors"
              severity="warning"
              :loading="isFixing"
            />
          </div>
        </template>
      </Card>
    </div>

    <!-- Real-time Calculation Display -->
    <div v-if="calculationResult" class="calculation-result">
      <span class="label">계산 결과:</span>
      <span class="value" :class="{ error: !calculationResult.success }">
        {{ calculationResult.value || calculationResult.error }}
      </span>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, watch } from 'vue'
import InputText from 'primevue/inputtext'
import Button from 'primevue/button'
import Card from 'primevue/card'
import Tag from 'primevue/tag'
import Message from 'primevue/message'
import excelClient from '../services/excelClient'
import { useToast } from 'primevue/usetoast'

const props = defineProps({
  file: Object,
  selectedCell: {
    type: String,
    default: 'A1'
  }
})

const emit = defineEmits(['update', 'fixed'])

const toast = useToast()

// State
const currentFormula = ref('')
const formulaError = ref(null)
const formulaSuggestion = ref(null)
const formulaSuggestions = ref([])
const analysisResult = ref(null)
const calculationResult = ref(null)
const isFixing = ref(false)

// Watch for file changes
watch(() => props.file, async (newFile) => {
  if (newFile) {
    await loadFile(newFile)
  }
})

// Load file and analyze
const loadFile = async (file) => {
  try {
    const result = await excelClient.loadExcelFile(file)
    analysisResult.value = result.analysis
    
    if (result.analysis.issues.length > 0) {
      toast.add({
        severity: 'warn',
        summary: '이슈 발견',
        detail: `${result.analysis.issues.length}개의 문제가 발견되었습니다.`,
        life: 5000
      })
    }
  } catch (error) {
    toast.add({
      severity: 'error',
      summary: '파일 로드 실패',
      detail: error.message,
      life: 5000
    })
  }
}

// Real-time formula validation
const validateFormula = () => {
  if (!currentFormula.value.startsWith('=')) {
    formulaError.value = null
    formulaSuggestion.value = null
    return
  }
  
  const result = excelClient.validateFormula(currentFormula.value)
  
  if (result.valid) {
    formulaError.value = null
    formulaSuggestion.value = null
    
    // Calculate result
    calculationResult.value = excelClient.calculateCell(
      'Sheet1',
      props.selectedCell,
      currentFormula.value
    )
  } else {
    formulaError.value = result.error
    formulaSuggestion.value = result.suggestion
  }
  
  // Get function suggestions
  const partial = currentFormula.value.match(/=([A-Z]+)/i)
  if (partial) {
    formulaSuggestions.value = excelClient.getFormulaSuggestions(partial[1])
  } else {
    formulaSuggestions.value = []
  }
}

// Apply formula
const applyFormula = () => {
  if (formulaError.value) return
  
  emit('update', {
    cell: props.selectedCell,
    value: currentFormula.value,
    calculated: calculationResult.value?.value
  })
  
  toast.add({
    severity: 'success',
    summary: '수식 적용됨',
    detail: `${props.selectedCell}: ${currentFormula.value}`,
    life: 3000
  })
}

// Auto fix formula
const autoFixFormula = () => {
  const fixed = excelClient.fixFormula(currentFormula.value)
  currentFormula.value = fixed
  validateFormula()
  
  toast.add({
    severity: 'info',
    summary: '수식 자동 수정됨',
    detail: fixed,
    life: 3000
  })
}

// Fix all errors
const fixAllErrors = async () => {
  if (!analysisResult.value?.issues) return
  
  isFixing.value = true
  
  try {
    const fixes = analysisResult.value.issues.map(issue => ({
      ...issue,
      suggestion: issue.suggestion || excelClient.fixFormula(issue.formula)
    }))
    
    const results = await excelClient.applyFixes(fixes)
    
    const fixed = results.filter(r => r.status === 'fixed').length
    const failed = results.filter(r => r.status === 'error').length
    
    toast.add({
      severity: fixed > 0 ? 'success' : 'warn',
      summary: '자동 수정 완료',
      detail: `${fixed}개 수정됨, ${failed}개 실패`,
      life: 5000
    })
    
    emit('fixed', results)
    
    // Re-analyze
    analysisResult.value = excelClient.analyzeWorkbook()
  } catch (error) {
    toast.add({
      severity: 'error',
      summary: '자동 수정 실패',
      detail: error.message,
      life: 5000
    })
  } finally {
    isFixing.value = false
  }
}

// Insert function suggestion
const insertSuggestion = (suggestion) => {
  const current = currentFormula.value
  const match = current.match(/=([A-Z]*)/i)
  
  if (match) {
    currentFormula.value = current.replace(match[0], `=${suggestion.name}(`)
    formulaSuggestions.value = []
  }
}

// Cleanup
onUnmounted(() => {
  excelClient.destroy()
})
</script>

<style scoped>
.excel-editor {
  padding: 1rem;
}

.formula-bar {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem;
  background: #f8f9fa;
  border: 1px solid #dee2e6;
  border-radius: 0.375rem;
  margin-bottom: 1rem;
}

.cell-reference {
  min-width: 60px;
  padding: 0.5rem;
  background: white;
  border: 1px solid #dee2e6;
  border-radius: 0.25rem;
  font-weight: 600;
  text-align: center;
}

.formula-input-wrapper {
  flex: 1;
  position: relative;
}

.formula-input {
  width: 100%;
  font-family: 'Courier New', monospace;
}

.formula-suggestions {
  position: absolute;
  top: 100%;
  left: 0;
  right: 0;
  background: white;
  border: 1px solid #dee2e6;
  border-radius: 0.375rem;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
  max-height: 300px;
  overflow-y: auto;
  z-index: 1000;
  margin-top: 0.25rem;
}

.suggestion-item {
  padding: 0.5rem;
  cursor: pointer;
  border-bottom: 1px solid #f0f0f0;
}

.suggestion-item:hover {
  background: #f8f9fa;
}

.suggestion-item strong {
  color: #2563eb;
  margin-right: 0.5rem;
}

.suggestion-item .syntax {
  color: #6b7280;
  font-size: 0.875rem;
  display: block;
}

.suggestion-item .description {
  color: #9ca3af;
  font-size: 0.75rem;
  display: block;
}

.quick-analysis {
  margin-top: 1rem;
}

.analysis-stats {
  display: flex;
  gap: 1.5rem;
}

.analysis-stats .stat {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.analysis-stats .stat i {
  color: #6b7280;
}

.calculation-result {
  margin-top: 0.5rem;
  padding: 0.5rem;
  background: #f0fdf4;
  border: 1px solid #86efac;
  border-radius: 0.375rem;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.calculation-result .label {
  font-weight: 600;
  color: #166534;
}

.calculation-result .value {
  font-family: 'Courier New', monospace;
  color: #166534;
}

.calculation-result .value.error {
  color: #dc2626;
}
</style>