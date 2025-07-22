<template>
  <div class="data-collection-manager">
    <h2 class="text-2xl font-bold mb-6">데이터 수집 관리</h2>

    <!-- Platform Selection -->
    <div class="bg-white rounded-lg shadow-sm p-6 mb-6">
      <h3 class="text-lg font-semibold mb-4">수집 플랫폼 선택</h3>
      
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div v-for="(platform, key) in platforms" :key="key" 
             class="platform-card border rounded-lg p-4 cursor-pointer"
             :class="{ 'border-blue-500 bg-blue-50': selectedPlatforms.includes(key) }"
             @click="togglePlatform(key)">
          <h4 class="font-medium">{{ platform.name }}</h4>
          <p class="text-sm text-gray-600">
            {{ platform.requires_api ? 'API' : 'Web Scraping' }}
          </p>
          <p class="text-xs text-gray-500">
            Rate limit: {{ platform.rate_limit }}/{{ platform.requires_api ? 'day' : 'min' }}
          </p>
        </div>
      </div>

      <div class="mt-6 flex items-center gap-4">
        <div>
          <label class="block text-sm font-medium mb-1">수집 개수</label>
          <input v-model.number="collectionLimit" type="number" min="1" max="100"
                 class="px-3 py-2 border rounded-md">
        </div>
        
        <div>
          <label class="flex items-center gap-2">
            <input v-model="enableImageAnalysis" type="checkbox" class="rounded">
            <span class="text-sm">이미지 분석 활성화</span>
          </label>
        </div>

        <button @click="createCollectionTasks" 
                :disabled="selectedPlatforms.length === 0"
                class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50">
          수집 작업 생성
        </button>
      </div>
    </div>

    <!-- Collection Stats -->
    <div class="bg-white rounded-lg shadow-sm p-6 mb-6">
      <h3 class="text-lg font-semibold mb-4">수집 통계</h3>
      
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
        <div class="stat-card bg-gray-50 rounded p-4">
          <p class="text-sm text-gray-600">총 Q&A 수</p>
          <p class="text-2xl font-bold">{{ stats.total_qa_pairs }}</p>
        </div>
        
        <div v-for="(count, source) in stats.by_source" :key="source"
             class="stat-card bg-gray-50 rounded p-4">
          <p class="text-sm text-gray-600">{{ source }}</p>
          <p class="text-2xl font-bold">{{ count }}</p>
        </div>
      </div>

      <!-- Platform-specific stats -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <div v-for="(platformStats, platform) in stats.platform_stats" :key="platform"
             class="border rounded-lg p-4">
          <h4 class="font-medium mb-2">{{ platform }}</h4>
          <div class="space-y-1 text-sm">
            <p>총: {{ platformStats.total }}</p>
            <p>승인됨: {{ platformStats.approved }}</p>
            <p>이미지 포함: {{ platformStats.with_images }}</p>
          </div>
        </div>
      </div>
    </div>

    <!-- Collection Tasks -->
    <div class="bg-white rounded-lg shadow-sm p-6 mb-6">
      <h3 class="text-lg font-semibold mb-4">수집 작업 목록</h3>
      
      <div class="overflow-x-auto">
        <table class="min-w-full">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">작업명</th>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">플랫폼</th>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">상태</th>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">마지막 실행</th>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">실행 횟수</th>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">액션</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <tr v-for="task in tasks" :key="task.id">
              <td class="px-4 py-3 text-sm">{{ task.name }}</td>
              <td class="px-4 py-3 text-sm">{{ task.platform }}</td>
              <td class="px-4 py-3 text-sm">
                <span class="px-2 py-1 text-xs rounded-full"
                      :class="task.enabled ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'">
                  {{ task.enabled ? '활성' : '비활성' }}
                </span>
              </td>
              <td class="px-4 py-3 text-sm">
                {{ task.last_run ? formatDate(task.last_run) : '-' }}
              </td>
              <td class="px-4 py-3 text-sm">
                {{ task.run_count }} (성공: {{ task.success_count }})
              </td>
              <td class="px-4 py-3 text-sm">
                <button @click="runCollection(task.id)"
                        class="text-blue-600 hover:text-blue-800 mr-2">
                  실행
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Recent Collections -->
    <div class="bg-white rounded-lg shadow-sm p-6 mb-6">
      <h3 class="text-lg font-semibold mb-4">최근 수집 기록</h3>
      
      <div class="overflow-x-auto">
        <table class="min-w-full">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">작업</th>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">플랫폼</th>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">상태</th>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">수집 항목</th>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">시작 시간</th>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">소요 시간</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <tr v-for="run in stats.recent_collections" :key="run.id">
              <td class="px-4 py-3 text-sm">{{ run.task_name }}</td>
              <td class="px-4 py-3 text-sm">{{ run.platform }}</td>
              <td class="px-4 py-3 text-sm">
                <span class="px-2 py-1 text-xs rounded-full"
                      :class="getStatusClass(run.status)">
                  {{ run.status }}
                </span>
              </td>
              <td class="px-4 py-3 text-sm">{{ run.items_collected }}</td>
              <td class="px-4 py-3 text-sm">{{ formatDate(run.started_at) }}</td>
              <td class="px-4 py-3 text-sm">{{ run.duration ? `${run.duration}초` : '-' }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Export Actions -->
    <div class="bg-white rounded-lg shadow-sm p-6">
      <h3 class="text-lg font-semibold mb-4">데이터 내보내기</h3>
      
      <div class="flex flex-wrap gap-4">
        <div>
          <select v-model="exportPlatform" class="px-3 py-2 border rounded-md">
            <option value="">전체 플랫폼</option>
            <option v-for="(platform, key) in platforms" :key="key" :value="key">
              {{ platform.name }}
            </option>
          </select>
        </div>

        <button @click="downloadData('json')"
                class="px-4 py-2 bg-gray-600 text-white rounded-md hover:bg-gray-700">
          JSON 다운로드
        </button>
        
        <button @click="downloadData('csv')"
                class="px-4 py-2 bg-gray-600 text-white rounded-md hover:bg-gray-700">
          CSV 다운로드
        </button>
        
        <button @click="sendToRAG"
                class="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700">
          RAG 시스템으로 전송
        </button>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  name: 'DataCollectionManager',
  
  data() {
    return {
      platforms: {},
      tasks: [],
      stats: {
        total_qa_pairs: 0,
        by_source: {},
        recent_collections: [],
        platform_stats: {}
      },
      selectedPlatforms: [],
      collectionLimit: 10,
      enableImageAnalysis: false,
      exportPlatform: ''
    }
  },
  
  mounted() {
    this.loadData()
    this.loadStats()
  },
  
  methods: {
    async loadData() {
      try {
        const response = await this.$axios.get('/api/v1/admin/data_collection/')
        this.platforms = response.data.platforms
        this.tasks = response.data.tasks
      } catch (error) {
        console.error('Failed to load data:', error)
      }
    },
    
    async loadStats() {
      try {
        const response = await this.$axios.get('/api/v1/admin/data_collection/stats')
        this.stats = response.data
      } catch (error) {
        console.error('Failed to load stats:', error)
      }
    },
    
    togglePlatform(platform) {
      const index = this.selectedPlatforms.indexOf(platform)
      if (index > -1) {
        this.selectedPlatforms.splice(index, 1)
      } else {
        this.selectedPlatforms.push(platform)
      }
    },
    
    async createCollectionTasks() {
      try {
        const response = await this.$axios.post('/api/v1/admin/data_collection/create_task', {
          platforms: this.selectedPlatforms,
          limit: this.collectionLimit,
          enable_image_analysis: this.enableImageAnalysis,
          frequency: 'manual'
        })
        
        this.$toast.success(response.data.message)
        this.selectedPlatforms = []
        await this.loadData()
      } catch (error) {
        this.$toast.error('수집 작업 생성 실패')
      }
    },
    
    async runCollection(taskId) {
      try {
        const response = await this.$axios.post(`/api/v1/admin/data_collection/run/${taskId}`)
        this.$toast.success(response.data.message)
        
        // Reload stats after a delay
        setTimeout(() => {
          this.loadStats()
        }, 2000)
      } catch (error) {
        this.$toast.error('수집 실행 실패')
      }
    },
    
    async downloadData(format) {
      try {
        const params = { format }
        if (this.exportPlatform) {
          params.platform = this.exportPlatform
        }
        
        const response = await this.$axios.get('/api/v1/admin/data_collection/download', {
          params,
          responseType: 'blob'
        })
        
        // Create download link
        const url = window.URL.createObjectURL(new Blob([response.data]))
        const link = document.createElement('a')
        link.href = url
        link.setAttribute('download', `qa_export_${Date.now()}.${format}`)
        document.body.appendChild(link)
        link.click()
        link.remove()
      } catch (error) {
        this.$toast.error('다운로드 실패')
      }
    },
    
    async sendToRAG() {
      try {
        const data = {}
        if (this.exportPlatform) {
          data.platform = this.exportPlatform
        }
        
        const response = await this.$axios.post('/api/v1/admin/data_collection/send_to_rag', data)
        this.$toast.success(response.data.message)
      } catch (error) {
        this.$toast.error('RAG 전송 실패')
      }
    },
    
    formatDate(dateString) {
      if (!dateString) return '-'
      const date = new Date(dateString)
      return new Intl.DateTimeFormat('ko-KR', {
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit'
      }).format(date)
    },
    
    getStatusClass(status) {
      const classes = {
        'completed': 'bg-green-100 text-green-800',
        'failed': 'bg-red-100 text-red-800',
        'running': 'bg-blue-100 text-blue-800',
        'pending': 'bg-yellow-100 text-yellow-800'
      }
      return classes[status] || 'bg-gray-100 text-gray-800'
    }
  }
}
</script>

<style scoped>
.platform-card {
  transition: all 0.2s ease;
}

.platform-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
}

.stat-card {
  text-align: center;
}
</style>