<template>
  <Dialog 
    v-model:visible="visible"
    modal 
    header="새 데이터 수집 작업 만들기"
    :style="{ width: '50rem' }"
    :breakpoints="{ '960px': '75vw', '640px': '90vw' }"
    @hide="$emit('close')"
  >
        
    <form @submit.prevent="handleSubmit">
      <!-- Basic Info -->
      <div class="space-y-4">
        <div class="field">
          <label for="name" class="block text-sm font-medium text-gray-700 mb-2">작업 이름 *</label>
          <InputText
            id="name"
            v-model="form.name"
            required
            class="w-full"
            placeholder="예: Excel 지식 베이스 수집"
          />
        </div>
        
        <div class="field">
          <label for="description" class="block text-sm font-medium text-gray-700 mb-2">설명</label>
          <Textarea
            id="description"
            v-model="form.description"
            rows="3"
            class="w-full"
            placeholder="작업에 대한 설명을 입력하세요"
          />
        </div>
        
        <div class="grid grid-cols-2 gap-4">
          <div class="field">
            <label for="task_type" class="block text-sm font-medium text-gray-700 mb-2">작업 유형 *</label>
            <Dropdown
              id="task_type"
              v-model="form.task_type"
              :options="taskTypeOptions"
              optionLabel="label"
              optionValue="value"
              placeholder="선택하세요"
              required
              class="w-full"
            />
          </div>
          
          <div class="field">
            <label for="schedule" class="block text-sm font-medium text-gray-700 mb-2">실행 스케줄 *</label>
            <Dropdown
              id="schedule"
              v-model="form.schedule"
              :options="scheduleOptions"
              optionLabel="label"
              optionValue="value"
              placeholder="선택하세요"
              required
              class="w-full"
            />
          </div>
        </div>
      </div>
          
      <!-- Source Configuration -->
      <Divider />
      <div class="mt-4">
        <h4 class="text-sm font-medium text-gray-900 mb-3">소스 설정</h4>
        
        <!-- Web Scraping Config -->
        <div v-if="form.task_type === 'web_scraping'" class="space-y-4">
          <div class="field">
            <label class="block text-sm font-medium text-gray-700 mb-2">URL *</label>
            <InputText
              v-model="form.source_config.url"
              type="url"
              required
              class="w-full"
              placeholder="https://example.com/data"
            />
          </div>
          
          <div class="field">
            <label class="block text-sm font-medium text-gray-700 mb-2">파서 타입</label>
            <Dropdown
              v-model="form.source_config.parser"
              :options="parserOptions"
              optionLabel="label"
              optionValue="value"
              class="w-full"
            />
          </div>
        </div>
            
        <!-- API Fetch Config -->
        <div v-else-if="form.task_type === 'api_fetch'" class="space-y-4">
          <div class="field">
            <label class="block text-sm font-medium text-gray-700 mb-2">API 엔드포인트 *</label>
            <InputText
              v-model="form.source_config.endpoint"
              type="url"
              required
              class="w-full"
              placeholder="https://api.example.com/data"
            />
          </div>
          
          <div class="field">
            <label class="block text-sm font-medium text-gray-700 mb-2">인증 헤더 (선택사항)</label>
            <InputText
              v-model="form.source_config.auth_header"
              type="text"
              class="w-full"
              placeholder="Bearer YOUR_API_KEY"
            />
          </div>
        </div>
            
        <!-- File Import Config -->
        <div v-else-if="form.task_type === 'file_import'" class="space-y-4">
          <div class="field">
            <label class="block text-sm font-medium text-gray-700 mb-2">파일 경로 *</label>
            <InputText
              v-model="form.source_config.file_path"
              type="text"
              required
              class="w-full"
              placeholder="/path/to/data.csv"
            />
          </div>
          
          <div class="field">
            <label class="block text-sm font-medium text-gray-700 mb-2">파일 형식</label>
            <Dropdown
              v-model="form.source_config.format"
              :options="fileFormatOptions"
              optionLabel="label"
              optionValue="value"
              class="w-full"
            />
          </div>
        </div>
            
        <!-- Database Sync Config -->
        <div v-else-if="form.task_type === 'database_sync'" class="space-y-4">
          <div class="field">
            <label class="block text-sm font-medium text-gray-700 mb-2">데이터베이스 이름 *</label>
            <InputText
              v-model="form.source_config.database.name"
              type="text"
              required
              class="w-full"
              placeholder="external_db"
            />
          </div>
          
          <div class="field">
            <label class="block text-sm font-medium text-gray-700 mb-2">테이블/컬렉션</label>
            <InputText
              v-model="form.source_config.database.table"
              type="text"
              class="w-full"
              placeholder="knowledge_items"
            />
          </div>
        </div>
      </div>
          
      <!-- Output Configuration -->
      <Divider />
      <div class="mt-4">
        <h4 class="text-sm font-medium text-gray-900 mb-3">출력 설정</h4>
        
        <div class="field">
          <label class="block text-sm font-medium text-gray-700 mb-2">저장 위치</label>
          <Dropdown
            v-model="form.source_config.output.type"
            :options="outputTypeOptions"
            optionLabel="label"
            optionValue="value"
            class="w-full"
          />
        </div>
      </div>
    </form>
    
    <!-- Actions -->
    <template #footer>
      <div class="flex justify-end gap-3">
        <Button
          @click="$emit('close')"
          label="취소"
          class="p-button-text"
        />
        
        <Button
          @click="handleSubmit"
          :loading="creating"
          label="작업 만들기"
          icon="pi pi-check"
          class="p-button-primary"
        />
      </div>
    </template>
  </Dialog>
</template>

<script setup>
import { ref, watch } from 'vue'
import { usePipelineStore } from '../stores/pipelineStore'

// PrimeVue imports
import Dialog from 'primevue/dialog'
import Button from 'primevue/button'
import InputText from 'primevue/inputtext'
import Textarea from 'primevue/textarea'
import Dropdown from 'primevue/dropdown'
import Divider from 'primevue/divider'

const emit = defineEmits(['close', 'created'])

const pipelineStore = usePipelineStore()
const visible = ref(true)
const creating = ref(false)

const form = ref({
  name: '',
  description: '',
  task_type: '',
  schedule: '',
  source_config: {
    url: '',
    endpoint: '',
    file_path: '',
    parser: 'default',
    format: 'csv',
    auth_header: '',
    database: {
      name: '',
      table: ''
    },
    output: {
      type: 'knowledge_base'
    }
  }
})

// Dropdown options
const taskTypeOptions = ref([
  { label: '웹 스크래핑', value: 'web_scraping' },
  { label: 'API 수집', value: 'api_fetch' },
  { label: '파일 가져오기', value: 'file_import' },
  { label: '데이터베이스 동기화', value: 'database_sync' }
])

const scheduleOptions = ref([
  { label: '수동 실행', value: 'manual' },
  { label: '매시간', value: 'hourly' },
  { label: '매일', value: 'daily' },
  { label: '매주', value: 'weekly' },
  { label: '매월', value: 'monthly' }
])

const parserOptions = ref([
  { label: '기본 파서', value: 'default' },
  { label: '커스텀 파서', value: 'custom' }
])

const fileFormatOptions = ref([
  { label: 'CSV', value: 'csv' },
  { label: 'JSON', value: 'json' },
  { label: 'XML', value: 'xml' },
  { label: 'Excel', value: 'excel' }
])

const outputTypeOptions = ref([
  { label: '지식 베이스', value: 'knowledge_base' },
  { label: '파일로 저장', value: 'file' },
  { label: '기본 저장소', value: 'default' }
])

// Reset source config when task type changes
watch(() => form.value.task_type, () => {
  form.value.source_config = {
    url: '',
    endpoint: '',
    file_path: '',
    parser: 'default',
    format: 'csv',
    auth_header: '',
    database: {
      name: '',
      table: ''
    },
    output: {
      type: 'knowledge_base'
    }
  }
})

const handleSubmit = async () => {
  creating.value = true
  
  try {
    await pipelineStore.createTask(form.value)
    emit('created')
  } catch (error) {
    console.error('Failed to create task:', error)
    alert('작업 생성에 실패했습니다.')
  } finally {
    creating.value = false
  }
}
</script>