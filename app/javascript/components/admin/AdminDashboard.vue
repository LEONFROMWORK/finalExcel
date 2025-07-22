<template>
  <div class="admin-dashboard min-h-screen bg-gradient-to-br from-gray-50 to-gray-100">
    <!-- 상단 헤더 -->
    <header class="bg-white shadow-sm border-b border-gray-200 sticky top-0 z-50">
      <div class="px-6 py-4">
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-4">
            <h1 class="text-2xl font-bold text-gray-900">관리자 대시보드</h1>
            <span class="text-sm text-gray-500">
              {{ currentTime }}
            </span>
          </div>
          
          <!-- 실시간 알림 표시 -->
          <div class="flex items-center space-x-4">
            <div class="flex items-center space-x-2">
              <div class="relative">
                <div class="w-3 h-3 bg-green-500 rounded-full animate-pulse"></div>
                <div class="absolute inset-0 w-3 h-3 bg-green-500 rounded-full animate-ping"></div>
              </div>
              <span class="text-sm font-medium text-gray-700">
                {{ realtimeStats.active_users }} 명 접속 중
              </span>
            </div>
            
            <button 
              @click="refreshData"
              :class="{ 'animate-spin': isRefreshing }"
              class="p-2 text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded-lg transition-colors"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
              </svg>
            </button>
          </div>
        </div>
      </div>
    </header>

    <!-- 메인 컨텐츠 -->
    <main class="p-6">
      <!-- 주요 지표 카드 -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <MetricCard
          v-for="metric in mainMetrics"
          :key="metric.id"
          :title="metric.title"
          :value="metric.value"
          :change="metric.change"
          :icon="metric.icon"
          :color="metric.color"
          :loading="loading"
        />
      </div>

      <!-- 탭 네비게이션 -->
      <div class="bg-white rounded-xl shadow-sm mb-6">
        <nav class="flex border-b border-gray-200">
          <button
            v-for="tab in tabs"
            :key="tab.id"
            @click="activeTab = tab.id"
            :class="[
              'flex-1 py-4 px-6 text-center font-medium transition-all duration-200',
              activeTab === tab.id
                ? 'text-blue-600 border-b-2 border-blue-600 bg-blue-50/30'
                : 'text-gray-500 hover:text-gray-700 hover:bg-gray-50'
            ]"
          >
            <div class="flex items-center justify-center space-x-2">
              <component :is="tab.icon" class="w-5 h-5" />
              <span>{{ tab.label }}</span>
              <span 
                v-if="tab.badge"
                class="ml-2 px-2 py-0.5 text-xs font-semibold rounded-full"
                :class="tab.badgeClass"
              >
                {{ tab.badge }}
              </span>
            </div>
          </button>
        </nav>
      </div>

      <!-- 탭 컨텐츠 -->
      <div class="transition-all duration-300">
        <!-- 실시간 활동 탭 -->
        <div v-if="activeTab === 'realtime'" class="space-y-6">
          <!-- 활동 스트림 -->
          <div class="bg-white rounded-xl shadow-sm p-6">
            <div class="flex items-center justify-between mb-4">
              <h3 class="text-lg font-semibold text-gray-900">실시간 활동 스트림</h3>
              <div class="flex items-center space-x-2">
                <span class="text-sm text-gray-500">자동 새로고침</span>
                <toggle-switch v-model="autoRefresh" />
              </div>
            </div>
            
            <ActivityStream 
              :activities="recentActivities"
              :loading="loading"
              @user-click="showUserDetail"
            />
          </div>

          <!-- 실시간 차트 -->
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <div class="bg-white rounded-xl shadow-sm p-6">
              <h3 class="text-lg font-semibold text-gray-900 mb-4">활동 분포</h3>
              <ActivityChart :data="activityChartData" />
            </div>
            
            <div class="bg-white rounded-xl shadow-sm p-6">
              <h3 class="text-lg font-semibold text-gray-900 mb-4">시스템 상태</h3>
              <SystemHealthMonitor :health="systemHealth" />
            </div>
          </div>
        </div>

        <!-- 벡터 DB 탭 -->
        <div v-if="activeTab === 'vectordb'" class="space-y-6">
          <div class="bg-white rounded-xl shadow-sm p-6">
            <div class="flex items-center justify-between mb-6">
              <div>
                <h3 class="text-lg font-semibold text-gray-900">벡터 DB 변환 현황</h3>
                <p class="text-sm text-gray-500 mt-1">
                  데이터가 실제로 벡터 DB로 변환되고 서비스에 적용되는 과정을 모니터링합니다
                </p>
              </div>
              
              <div class="flex items-center space-x-3">
                <select 
                  v-model="vectorDbFilter"
                  class="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                >
                  <option value="all">전체</option>
                  <option value="processing">진행 중</option>
                  <option value="completed">완료</option>
                  <option value="failed">실패</option>
                </select>
              </div>
            </div>
            
            <VectorDbStatusTable 
              :statuses="vectorDbStatuses"
              :loading="loading"
              @retry="retryConversion"
            />
          </div>

          <!-- 변환 통계 -->
          <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
            <div class="bg-white rounded-xl shadow-sm p-6">
              <h4 class="text-sm font-medium text-gray-600 mb-2">총 임베딩 생성</h4>
              <p class="text-3xl font-bold text-gray-900">
                {{ formatNumber(vectorStats.total_embeddings) }}
              </p>
              <p class="text-sm text-green-600 mt-2">
                +{{ formatNumber(vectorStats.today_embeddings) }} 오늘
              </p>
            </div>
            
            <div class="bg-white rounded-xl shadow-sm p-6">
              <h4 class="text-sm font-medium text-gray-600 mb-2">평균 처리 시간</h4>
              <p class="text-3xl font-bold text-gray-900">
                {{ vectorStats.avg_processing_time }}ms
              </p>
              <p class="text-sm text-gray-500 mt-2">
                아이템당
              </p>
            </div>
            
            <div class="bg-white rounded-xl shadow-sm p-6">
              <h4 class="text-sm font-medium text-gray-600 mb-2">성공률</h4>
              <p class="text-3xl font-bold text-gray-900">
                {{ vectorStats.success_rate }}%
              </p>
              <div class="mt-2 w-full bg-gray-200 rounded-full h-2">
                <div 
                  :style="`width: ${vectorStats.success_rate}%`"
                  class="bg-green-500 h-2 rounded-full transition-all duration-300"
                ></div>
              </div>
            </div>
          </div>
        </div>

        <!-- 사용자 분석 탭 -->
        <div v-if="activeTab === 'users'" class="space-y-6">
          <UserAnalytics 
            :users="userAnalytics"
            :loading="loading"
            @view-detail="showUserDetail"
            @export="exportUserData"
          />
        </div>
      </div>
    </main>

    <!-- 사용자 상세 모달 -->
    <UserDetailModal 
      v-if="selectedUser"
      :user="selectedUser"
      @close="selectedUser = null"
    />
  </div>
</template>

<script>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useAdminStore } from '@/stores/admin'
import { useToast } from '@/composables/useToast'
import MetricCard from './MetricCard.vue'
import ActivityStream from './ActivityStream.vue'
import ActivityChart from './ActivityChart.vue'
import SystemHealthMonitor from './SystemHealthMonitor.vue'
import VectorDbStatusTable from './VectorDbStatusTable.vue'
import UserAnalytics from './UserAnalytics.vue'
import UserDetailModal from './UserDetailModal.vue'
import ToggleSwitch from '@/components/common/ToggleSwitch.vue'

export default {
  name: 'AdminDashboard',
  
  components: {
    MetricCard,
    ActivityStream,
    ActivityChart,
    SystemHealthMonitor,
    VectorDbStatusTable,
    UserAnalytics,
    UserDetailModal,
    ToggleSwitch
  },
  
  setup() {
    const adminStore = useAdminStore()
    const { showToast } = useToast()
    
    // 상태
    const loading = ref(false)
    const isRefreshing = ref(false)
    const activeTab = ref('realtime')
    const autoRefresh = ref(true)
    const selectedUser = ref(null)
    const vectorDbFilter = ref('all')
    const currentTime = ref(new Date().toLocaleString('ko-KR'))
    
    // 탭 설정
    const tabs = [
      {
        id: 'realtime',
        label: '실시간 모니터링',
        icon: 'ChartBarIcon',
        badge: computed(() => adminStore.realtimeStats?.active_users || 0),
        badgeClass: 'bg-green-100 text-green-800'
      },
      {
        id: 'vectordb',
        label: '벡터 DB 상태',
        icon: 'DatabaseIcon',
        badge: computed(() => adminStore.vectorDbStats?.processing || 0),
        badgeClass: 'bg-blue-100 text-blue-800'
      },
      {
        id: 'users',
        label: '사용자 분석',
        icon: 'UsersIcon',
        badge: null
      }
    ]
    
    // 주요 지표
    const mainMetrics = computed(() => [
      {
        id: 'total_users',
        title: '전체 사용자',
        value: adminStore.overview?.quick_stats?.total_users || 0,
        change: `+${adminStore.overview?.quick_stats?.new_users_today || 0} 오늘`,
        icon: 'UsersIcon',
        color: 'blue'
      },
      {
        id: 'active_now',
        title: '현재 활동 중',
        value: adminStore.realtimeStats?.active_users || 0,
        change: '실시간',
        icon: 'StatusOnlineIcon',
        color: 'green'
      },
      {
        id: 'excel_files',
        title: 'Excel 파일',
        value: adminStore.overview?.quick_stats?.total_excel_files || 0,
        change: `+${adminStore.overview?.quick_stats?.excel_files_today || 0} 오늘`,
        icon: 'DocumentTextIcon',
        color: 'purple'
      },
      {
        id: 'vector_embeddings',
        title: '벡터 임베딩',
        value: formatNumber(adminStore.vectorDbStats?.total_embeddings || 0),
        change: `${adminStore.vectorDbStats?.success_rate || 0}% 성공률`,
        icon: 'DatabaseIcon',
        color: 'indigo'
      }
    ])
    
    // 데이터 로드
    const loadData = async () => {
      loading.value = true
      try {
        await Promise.all([
          adminStore.fetchOverview(),
          adminStore.fetchRealtimeStats(),
          adminStore.fetchVectorDbStatus()
        ])
      } catch (error) {
        showToast('데이터 로드 실패', 'error')
      } finally {
        loading.value = false
      }
    }
    
    // 데이터 새로고침
    const refreshData = async () => {
      isRefreshing.value = true
      await loadData()
      isRefreshing.value = false
      showToast('데이터가 새로고침되었습니다', 'success')
    }
    
    // 실시간 업데이트
    let refreshInterval = null
    const startAutoRefresh = () => {
      if (autoRefresh.value) {
        refreshInterval = setInterval(() => {
          if (document.visibilityState === 'visible') {
            adminStore.fetchRealtimeStats()
          }
        }, 5000) // 5초마다
      }
    }
    
    const stopAutoRefresh = () => {
      if (refreshInterval) {
        clearInterval(refreshInterval)
        refreshInterval = null
      }
    }
    
    // 시계 업데이트
    const updateTime = () => {
      currentTime.value = new Date().toLocaleString('ko-KR')
    }
    
    let timeInterval = null
    
    // 사용자 상세 보기
    const showUserDetail = async (userId) => {
      try {
        const user = await adminStore.fetchUserDetail(userId)
        selectedUser.value = user
      } catch (error) {
        showToast('사용자 정보 로드 실패', 'error')
      }
    }
    
    // 벡터 변환 재시도
    const retryConversion = async (statusId) => {
      try {
        await adminStore.retryVectorConversion(statusId)
        showToast('변환 작업이 재시작되었습니다', 'success')
      } catch (error) {
        showToast('재시도 실패', 'error')
      }
    }
    
    // 데이터 내보내기
    const exportUserData = async (format) => {
      try {
        await adminStore.exportData('user_activities', format)
        showToast('데이터 내보내기가 시작되었습니다', 'success')
      } catch (error) {
        showToast('내보내기 실패', 'error')
      }
    }
    
    // 숫자 포맷
    const formatNumber = (num) => {
      if (num >= 1000000) {
        return (num / 1000000).toFixed(1) + 'M'
      } else if (num >= 1000) {
        return (num / 1000).toFixed(1) + 'K'
      }
      return num.toLocaleString()
    }
    
    // 라이프사이클
    onMounted(() => {
      loadData()
      startAutoRefresh()
      timeInterval = setInterval(updateTime, 1000)
    })
    
    onUnmounted(() => {
      stopAutoRefresh()
      if (timeInterval) {
        clearInterval(timeInterval)
      }
    })
    
    // 자동 새로고침 토글 감시
    watch(autoRefresh, (newVal) => {
      if (newVal) {
        startAutoRefresh()
      } else {
        stopAutoRefresh()
      }
    })
    
    return {
      // 상태
      loading,
      isRefreshing,
      activeTab,
      autoRefresh,
      selectedUser,
      vectorDbFilter,
      currentTime,
      
      // 데이터
      tabs,
      mainMetrics,
      realtimeStats: computed(() => adminStore.realtimeStats),
      recentActivities: computed(() => adminStore.recentActivities),
      vectorDbStatuses: computed(() => adminStore.vectorDbStatuses),
      vectorStats: computed(() => adminStore.vectorDbStats),
      userAnalytics: computed(() => adminStore.userAnalytics),
      activityChartData: computed(() => adminStore.activityChartData),
      systemHealth: computed(() => adminStore.systemHealth),
      
      // 메서드
      refreshData,
      showUserDetail,
      retryConversion,
      exportUserData,
      formatNumber
    }
  }
}
</script>

<style scoped>
/* 부드러운 애니메이션 */
.admin-dashboard {
  animation: fadeIn 0.3s ease-in;
}

@keyframes fadeIn {
  from {
    opacity: 0;
    transform: translateY(10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

/* 탭 전환 애니메이션 */
.tab-content-enter-active,
.tab-content-leave-active {
  transition: all 0.3s ease;
}

.tab-content-enter-from {
  opacity: 0;
  transform: translateX(30px);
}

.tab-content-leave-to {
  opacity: 0;
  transform: translateX(-30px);
}

/* 호버 효과 */
.metric-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
}

/* 스크롤바 커스터마이징 */
::-webkit-scrollbar {
  width: 8px;
  height: 8px;
}

::-webkit-scrollbar-track {
  background: #f3f4f6;
}

::-webkit-scrollbar-thumb {
  background: #9ca3af;
  border-radius: 4px;
}

::-webkit-scrollbar-thumb:hover {
  background: #6b7280;
}
</style>