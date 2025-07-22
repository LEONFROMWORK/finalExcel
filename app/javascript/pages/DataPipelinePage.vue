<template>
  <div class="data-pipeline-page min-h-screen bg-gray-50">
    <div class="container mx-auto px-4 py-8">
      <!-- Page Header -->
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-gray-900">데이터 파이프라인 관리</h1>
        <p class="mt-2 text-gray-600">
          Excel 지식 베이스 구축을 위한 데이터 수집 및 처리 작업을 관리합니다.
        </p>
      </div>

      <!-- Statistics Cards -->
      <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
        <Card>
          <template #content>
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-gray-600">전체 작업</p>
                <p class="text-2xl font-bold text-gray-900 mt-1">{{ globalStats.total_tasks }}</p>
              </div>
              <div class="p-3 bg-blue-100 rounded-full">
                <i class="pi pi-list text-2xl text-blue-600"></i>
              </div>
            </div>
          </template>
        </Card>

        <Card>
          <template #content>
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-gray-600">활성 작업</p>
                <p class="text-2xl font-bold text-green-600 mt-1">{{ globalStats.active_tasks }}</p>
              </div>
              <div class="p-3 bg-green-100 rounded-full">
                <i class="pi pi-check text-2xl text-green-600"></i>
              </div>
            </div>
          </template>
        </Card>

        <Card>
          <template #content>
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-gray-600">성공률</p>
                <p class="text-2xl font-bold text-blue-600 mt-1">{{ successRate }}%</p>
              </div>
              <div class="p-3 bg-blue-100 rounded-full">
                <i class="pi pi-chart-bar text-2xl text-blue-600"></i>
              </div>
            </div>
          </template>
        </Card>

        <Card>
          <template #content>
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-gray-600">수집된 항목</p>
                <p class="text-2xl font-bold text-purple-600 mt-1">
                  {{ formatNumber(globalStats.total_items_collected) }}
                </p>
              </div>
              <div class="p-3 bg-purple-100 rounded-full">
                <i class="pi pi-download text-2xl text-purple-600"></i>
              </div>
            </div>
          </template>
        </Card>
      </div>

      <!-- Tabs -->
      <TabView v-model:activeIndex="activeTabIndex">
        <TabPanel header="작업 목록">
          <TaskList />
        </TabPanel>
        
        <TabPanel header="최근 활동">
          <Card>
            <template #content>
              <h3 class="text-lg font-semibold text-gray-900 mb-4">최근 수집 활동</h3>
              
              <div v-if="recentActivity.length === 0" class="text-center py-8 text-gray-500">
                최근 활동이 없습니다.
              </div>
              
              <div v-else class="space-y-4">
                <div
                  v-for="activity in recentActivity"
                  :key="activity.run_id"
                  class="border-l-4 pl-4 py-2"
                  :class="getActivityBorderClass(activity.status)"
                >
                  <div class="flex items-start justify-between">
                    <div class="flex-1">
                      <h4 class="font-medium text-gray-900">{{ activity.task_name }}</h4>
                      <div class="mt-1 text-sm text-gray-500 space-y-1">
                        <p>
                          상태: 
                          <span :class="getActivityStatusClass(activity.status)">
                            {{ getStatusText(activity.status) }}
                          </span>
                        </p>
                        <p v-if="activity.items_collected">
                          수집된 항목: {{ activity.items_collected }}개
                        </p>
                        <p v-if="activity.duration">
                          소요 시간: {{ activity.duration }}
                        </p>
                      </div>
                    </div>
                    
                    <div class="text-sm text-gray-500 ml-4">
                      {{ formatDateTime(activity.started_at) }}
                    </div>
                  </div>
                </div>
              </div>
            </template>
          </Card>
        </TabPanel>
      </TabView>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import { usePipelineStore } from '../domains/data_pipeline/stores/pipelineStore'
import TaskList from '../domains/data_pipeline/components/TaskList.vue'
import Card from 'primevue/card'
import Button from 'primevue/button'
import TabView from 'primevue/tabview'
import TabPanel from 'primevue/tabpanel'

const pipelineStore = usePipelineStore()

const activeTabIndex = ref(0)

// Computed from store
const { globalStats, recentActivity, successRate } = pipelineStore

// Methods
const formatNumber = (num) => {
  if (!num) return '0'
  return num.toLocaleString('ko-KR')
}

const formatDateTime = (dateString) => {
  if (!dateString) return ''
  const date = new Date(dateString)
  return date.toLocaleString('ko-KR', {
    month: 'numeric',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  })
}

const getActivityBorderClass = (status) => {
  const classes = {
    completed: 'border-green-500',
    failed: 'border-red-500',
    running: 'border-blue-500',
    cancelled: 'border-gray-400'
  }
  return classes[status] || 'border-gray-300'
}

const getActivityStatusClass = (status) => {
  const classes = {
    completed: 'text-green-600',
    failed: 'text-red-600',
    running: 'text-blue-600',
    cancelled: 'text-gray-600'
  }
  return classes[status] || 'text-gray-600'
}

const getStatusText = (status) => {
  const texts = {
    completed: '완료',
    failed: '실패',
    running: '실행 중',
    cancelled: '취소됨'
  }
  return texts[status] || status
}

// Load data
onMounted(async () => {
  await Promise.all([
    pipelineStore.fetchGlobalStatistics(),
    pipelineStore.fetchRecentActivity()
  ])
})

// Refresh activity periodically
const refreshInterval = setInterval(() => {
  pipelineStore.fetchRecentActivity()
  pipelineStore.fetchGlobalStatistics()
}, 30000) // Every 30 seconds

// Cleanup
onBeforeUnmount(() => {
  clearInterval(refreshInterval)
})
</script>