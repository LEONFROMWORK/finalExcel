<template>
  <div class="task-list">
    <!-- Header -->
    <div class="flex justify-between items-center mb-6">
      <h2 class="text-2xl font-bold text-gray-900">데이터 수집 작업</h2>
      
      <Button
        @click="showCreateModal = true"
        icon="pi pi-plus"
        label="새 작업 추가"
        class="p-button-primary"
      />
    </div>

    <!-- Filters -->
    <Card class="mb-6">
      <template #content>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">상태</label>
            <Dropdown
              v-model="filters.status"
              :options="statusOptions"
              optionLabel="label"
              optionValue="value"
              placeholder="전체"
              @change="fetchTasks"
              class="w-full"
            />
          </div>
          
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">작업 유형</label>
            <Dropdown
              v-model="filters.task_type"
              :options="taskTypeOptions"
              optionLabel="label"
              optionValue="value"
              placeholder="전체"
              @change="fetchTasks"
              class="w-full"
            />
          </div>
          
          <div class="flex items-end">
            <Button
              @click="resetFilters"
              label="필터 초기화"
              class="p-button-text"
              icon="pi pi-refresh"
            />
          </div>
        </div>
      </template>
    </Card>

    <!-- Loading State -->
    <div v-if="loading && tasks.length === 0" class="text-center py-12">
      <ProgressSpinner />
      <p class="mt-4 text-gray-600">작업 목록을 불러오는 중...</p>
    </div>

    <!-- Empty State -->
    <Card v-else-if="tasks.length === 0" class="text-center">
      <template #content>
        <div class="py-12">
          <i class="pi pi-inbox text-6xl text-gray-300 mb-4"></i>
          <h3 class="text-lg font-medium text-gray-900 mb-2">작업이 없습니다</h3>
          <p class="text-gray-500">첫 번째 데이터 수집 작업을 만들어보세요!</p>
        </div>
      </template>
    </Card>

    <!-- Task DataTable -->
    <DataTable
      v-else
      :value="tasks"
      :loading="loading"
      dataKey="id"
      :paginator="true"
      :rows="10"
      paginatorTemplate="FirstPageLink PrevPageLink PageLinks NextPageLink LastPageLink CurrentPageReport RowsPerPageDropdown"
      :rowsPerPageOptions="[10, 25, 50]"
      currentPageReportTemplate="{first} - {last} / {totalRecords}개"
      responsiveLayout="scroll"
      :globalFilterFields="['name', 'task_type', 'status']"
      class="p-datatable-gridlines"
    >
      <template #header>
        <div class="flex justify-between items-center">
          <span class="text-lg font-semibold">작업 목록</span>
          <span class="p-input-icon-left">
            <i class="pi pi-search" />
            <InputText v-model="globalFilter" placeholder="검색..." @input="onGlobalFilter" />
          </span>
        </div>
      </template>

      <Column field="name" header="작업명" :sortable="true" style="min-width: 200px">
        <template #body="slotProps">
          <div class="font-semibold">{{ slotProps.data.name }}</div>
        </template>
      </Column>

      <Column field="status" header="상태" :sortable="true" style="min-width: 120px">
        <template #body="slotProps">
          <Tag :value="getStatusText(slotProps.data.status)" :severity="getStatusSeverity(slotProps.data.status)" />
        </template>
      </Column>

      <Column field="task_type" header="유형" :sortable="true" style="min-width: 150px">
        <template #body="slotProps">
          <Tag :value="getTaskTypeText(slotProps.data.task_type)" severity="secondary" />
        </template>
      </Column>

      <Column field="schedule" header="스케줄" :sortable="true" style="min-width: 120px">
        <template #body="slotProps">
          {{ getScheduleText(slotProps.data.schedule) }}
        </template>
      </Column>

      <Column field="next_run_at" header="다음 실행" :sortable="true" style="min-width: 180px">
        <template #body="slotProps">
          <div v-if="slotProps.data.next_run_at" class="text-sm">
            {{ formatDateTime(slotProps.data.next_run_at) }}
          </div>
          <span v-else class="text-gray-400">-</span>
        </template>
      </Column>

      <Column field="last_run" header="마지막 실행" style="min-width: 200px">
        <template #body="slotProps">
          <div v-if="slotProps.data.last_run" class="text-sm">
            <div>{{ formatRelativeTime(slotProps.data.last_run.started_at) }}</div>
            <Tag 
              :value="slotProps.data.last_run.status" 
              :severity="slotProps.data.last_run.status === 'completed' ? 'success' : 'danger'"
              class="mt-1"
            />
          </div>
          <span v-else class="text-gray-400">-</span>
        </template>
      </Column>

      <Column field="success_rate" header="성공률" :sortable="true" style="min-width: 100px">
        <template #body="slotProps">
          <div class="flex items-center">
            <i class="pi pi-check-circle text-green-500 mr-1"></i>
            <span>{{ slotProps.data.success_rate }}%</span>
          </div>
        </template>
      </Column>

      <Column header="작업" style="min-width: 180px" :exportable="false">
        <template #body="slotProps">
          <div class="flex items-center gap-2">
            <Button
              v-if="slotProps.data.status === 'active'"
              @click="handleStop(slotProps.data.id)"
              icon="pi pi-pause"
              class="p-button-rounded p-button-warning p-button-text"
              v-tooltip="'일시정지'"
            />
            
            <Button
              v-else-if="slotProps.data.status === 'paused'"
              @click="handleStart(slotProps.data.id)"
              icon="pi pi-play"
              class="p-button-rounded p-button-success p-button-text"
              v-tooltip="'재개'"
            />
            
            <Button
              @click="handleRunNow(slotProps.data.id)"
              icon="pi pi-bolt"
              class="p-button-rounded p-button-info p-button-text"
              :disabled="slotProps.data.status === 'disabled'"
              v-tooltip="'지금 실행'"
            />
            
            <router-link
              :to="{ name: 'pipeline-task-detail', params: { id: slotProps.data.id } }"
              v-tooltip="'상세 보기'"
            >
              <Button
                icon="pi pi-eye"
                class="p-button-rounded p-button-text"
              />
            </router-link>
          </div>
        </template>
      </Column>
    </DataTable>

    <!-- Create Task Modal -->
    <CreateTaskModal
      v-if="showCreateModal"
      @close="showCreateModal = false"
      @created="handleTaskCreated"
    />
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { usePipelineStore } from '../stores/pipelineStore'
import CreateTaskModal from './CreateTaskModal.vue'

// PrimeVue imports
import Button from 'primevue/button'
import Card from 'primevue/card'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import Dropdown from 'primevue/dropdown'
import InputText from 'primevue/inputtext'
import Tag from 'primevue/tag'
import ProgressSpinner from 'primevue/progressspinner'

const pipelineStore = usePipelineStore()

const showCreateModal = ref(false)
const globalFilter = ref('')
const filters = ref({
  status: '',
  task_type: ''
})

// Dropdown options
const statusOptions = ref([
  { label: '전체', value: '' },
  { label: '활성', value: 'active' },
  { label: '일시정지', value: 'paused' },
  { label: '비활성', value: 'disabled' }
])

const taskTypeOptions = ref([
  { label: '전체', value: '' },
  { label: '웹 스크래핑', value: 'web_scraping' },
  { label: 'API 수집', value: 'api_fetch' },
  { label: '파일 가져오기', value: 'file_import' },
  { label: '데이터베이스 동기화', value: 'database_sync' }
])

// Computed from store
const { tasks, loading } = pipelineStore

// Methods
const fetchTasks = async () => {
  await pipelineStore.fetchTasks(filters.value)
}

const resetFilters = () => {
  filters.value = {
    status: '',
    task_type: ''
  }
  globalFilter.value = ''
  fetchTasks()
}

const onGlobalFilter = () => {
  // DataTable handles global filtering internally
}

const handleStart = async (taskId) => {
  try {
    await pipelineStore.startTask(taskId)
  } catch (error) {
    console.error('Failed to start task:', error)
  }
}

const handleStop = async (taskId) => {
  try {
    await pipelineStore.stopTask(taskId)
  } catch (error) {
    console.error('Failed to stop task:', error)
  }
}

const handleRunNow = async (taskId) => {
  if (!confirm('지금 이 작업을 실행하시겠습니까?')) return
  
  try {
    await pipelineStore.startTask(taskId)
    alert('작업 실행이 시작되었습니다.')
  } catch (error) {
    console.error('Failed to run task:', error)
    alert('작업 실행에 실패했습니다.')
  }
}

const handleTaskCreated = () => {
  showCreateModal.value = false
  fetchTasks()
}

// Utility functions
const getStatusSeverity = (status) => {
  const severities = {
    active: 'success',
    paused: 'warning',
    disabled: 'secondary'
  }
  return severities[status] || 'secondary'
}

const getStatusText = (status) => {
  const texts = {
    active: '활성',
    paused: '일시정지',
    disabled: '비활성'
  }
  return texts[status] || status
}

const getTaskTypeText = (type) => {
  const texts = {
    web_scraping: '웹 스크래핑',
    api_fetch: 'API 수집',
    file_import: '파일 가져오기',
    database_sync: 'DB 동기화'
  }
  return texts[type] || type
}

const getScheduleText = (schedule) => {
  const texts = {
    manual: '수동',
    hourly: '매시간',
    daily: '매일',
    weekly: '매주',
    monthly: '매월'
  }
  return texts[schedule] || schedule
}

const formatDateTime = (dateString) => {
  if (!dateString) return ''
  const date = new Date(dateString)
  return date.toLocaleString('ko-KR')
}

const formatRelativeTime = (dateString) => {
  if (!dateString) return ''
  const date = new Date(dateString)
  const now = new Date()
  const diff = now - date
  
  const minutes = Math.floor(diff / 60000)
  const hours = Math.floor(minutes / 60)
  const days = Math.floor(hours / 24)
  
  if (days > 0) return `${days}일 전`
  if (hours > 0) return `${hours}시간 전`
  if (minutes > 0) return `${minutes}분 전`
  return '방금 전'
}

// Load initial data
onMounted(() => {
  fetchTasks()
})
</script>