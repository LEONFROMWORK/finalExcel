<template>
  <div class="my-account min-h-screen bg-gray-50">
    <!-- Enhanced Header with Glass Morphism -->
    <div class="relative overflow-hidden bg-gradient-to-br from-blue-600 via-indigo-600 to-purple-700">
      <!-- Animated Background Pattern -->
      <div class="absolute inset-0 opacity-10">
        <div class="absolute -left-4 -top-4 w-72 h-72 bg-white rounded-full mix-blend-multiply filter blur-xl animate-blob"></div>
        <div class="absolute -right-4 top-20 w-72 h-72 bg-yellow-300 rounded-full mix-blend-multiply filter blur-xl animate-blob animation-delay-2000"></div>
        <div class="absolute left-20 -bottom-4 w-72 h-72 bg-pink-300 rounded-full mix-blend-multiply filter blur-xl animate-blob animation-delay-4000"></div>
      </div>
      
      <div class="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div class="flex flex-col lg:flex-row items-center lg:items-start gap-8">
          <!-- Enhanced Profile Section -->
          <div class="text-center lg:text-left">
            <AvatarUploader 
              :user="user"
              size="large"
              @updated="handleAvatarUpdate"
            />
          </div>
          
          <!-- User Info with Enhanced Stats -->
          <div class="flex-1 text-center lg:text-left text-white">
            <h1 class="text-4xl font-bold mb-2">{{ user.name || user.email.split('@')[0] }}</h1>
            <p class="text-blue-100 mb-6">{{ user.email }}</p>
            
            <!-- Quick Stats Grid -->
            <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
              <div class="bg-white/20 backdrop-blur-md rounded-xl p-4 text-center">
                <p class="text-3xl font-bold">{{ userStats.totalConsultations }}</p>
                <p class="text-sm text-blue-100 mt-1">AI 상담</p>
              </div>
              <div class="bg-white/20 backdrop-blur-md rounded-xl p-4 text-center">
                <p class="text-3xl font-bold">{{ userStats.totalFiles }}</p>
                <p class="text-sm text-blue-100 mt-1">엑셀 파일</p>
              </div>
              <div class="bg-white/20 backdrop-blur-md rounded-xl p-4 text-center">
                <p class="text-3xl font-bold">{{ userStats.vbaSolutions }}</p>
                <p class="text-sm text-blue-100 mt-1">VBA 해결</p>
              </div>
              <div class="bg-white/20 backdrop-blur-md rounded-xl p-4 text-center">
                <p class="text-3xl font-bold">{{ formatDaysActive() }}</p>
                <p class="text-sm text-blue-100 mt-1">활동일</p>
              </div>
            </div>
            
            <!-- Credit & Subscription Info -->
            <div class="flex flex-wrap items-center gap-4">
              <div class="bg-white/30 backdrop-blur-md rounded-2xl px-6 py-3 flex items-center gap-3">
                <svg class="w-6 h-6 text-yellow-300" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M8.433 7.418c.155-.103.346-.196.567-.267v1.698a2.305 2.305 0 01-.567-.267C8.07 8.34 8 8.114 8 8c0-.114.07-.34.433-.582zM11 12.849v-1.698c.22.071.412.164.567.267.364.243.433.468.433.582 0 .114-.07.34-.433.582a2.305 2.305 0 01-.567.267z" />
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-13a1 1 0 10-2 0v.092a4.535 4.535 0 00-1.676.662C6.602 6.234 6 7.009 6 8c0 .99.602 1.765 1.324 2.246.48.32 1.054.545 1.676.662v1.941c-.391-.127-.68-.317-.843-.504a1 1 0 10-1.51 1.31c.562.649 1.413 1.076 2.353 1.253V15a1 1 0 102 0v-.092a4.535 4.535 0 001.676-.662C13.398 13.766 14 12.991 14 12c0-.99-.602-1.765-1.324-2.246A4.535 4.535 0 0011 9.092V7.151c.391.127.68.317.843.504a1 1 0 101.511-1.31c-.563-.649-1.413-1.076-2.354-1.253V5a1 1 0 10-2 0z" clip-rule="evenodd" />
                </svg>
                <div>
                  <p class="text-2xl font-bold">{{ user.credits.toLocaleString() }}</p>
                  <p class="text-xs opacity-90">크레딧</p>
                </div>
              </div>
              
              <div class="bg-gradient-to-r from-yellow-400 to-orange-500 text-gray-900 rounded-2xl px-6 py-3">
                <p class="font-bold text-lg">{{ subscriptionInfo.plan }}</p>
                <p class="text-xs opacity-80">{{ subscriptionInfo.status }}</p>
              </div>
              
              <button 
                @click="showCreditPurchase = true"
                class="bg-white text-blue-600 px-6 py-3 rounded-2xl font-medium hover:shadow-lg transform hover:scale-105 transition-all"
              >
                크레딧 충전
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Enhanced Navigation with Icons -->
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 -mt-8 relative z-10">
      <div class="bg-white rounded-2xl shadow-xl overflow-hidden">
        <nav class="flex overflow-x-auto scrollbar-hide">
          <button
            v-for="tab in tabs"
            :key="tab.id"
            @click="activeTab = tab.id"
            :class="[
              'flex-shrink-0 px-6 py-4 text-sm font-medium transition-all duration-200 relative group',
              activeTab === tab.id
                ? 'text-blue-600 bg-blue-50'
                : 'text-gray-600 hover:text-gray-900 hover:bg-gray-50'
            ]"
          >
            <div class="flex items-center gap-3">
              <component :is="tab.icon" class="w-5 h-5" />
              <span>{{ tab.label }}</span>
              <span 
                v-if="tab.badge"
                class="ml-2 px-2 py-0.5 text-xs font-semibold rounded-full"
                :class="tab.badgeClass || 'bg-gray-200 text-gray-700'"
              >
                {{ tab.badge }}
              </span>
            </div>
            
            <!-- Active Indicator -->
            <div 
              v-if="activeTab === tab.id"
              class="absolute bottom-0 left-0 right-0 h-0.5 bg-blue-600 transform scale-x-100 transition-transform"
            ></div>
          </button>
        </nav>
      </div>
    </div>

    <!-- Main Content Area -->
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <transition name="fade-slide" mode="out-in">
        <!-- Overview Tab (New) -->
        <div v-if="activeTab === 'overview'" class="space-y-6">
          <!-- Quick Actions -->
          <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
            <QuickActionCard
              icon="DocumentTextIcon"
              title="새 Excel 분석"
              description="Excel 파일을 업로드하고 AI 분석을 시작하세요"
              @click="$router.push('/excel/upload')"
              color="blue"
            />
            <QuickActionCard
              icon="ChatIcon"
              title="AI 상담 시작"
              description="Excel 관련 질문을 AI와 상담하세요"
              @click="$router.push('/ai-chat')"
              color="green"
            />
            <QuickActionCard
              icon="CodeIcon"
              title="VBA 오류 해결"
              description="VBA 코드 오류를 빠르게 해결하세요"
              @click="$router.push('/vba-helper')"
              color="purple"
            />
          </div>
          
          <!-- Recent Activity Chart -->
          <div class="bg-white rounded-2xl shadow-sm p-6">
            <h3 class="text-lg font-semibold text-gray-900 mb-4">최근 활동</h3>
            <ActivityChart :data="activityChartData" />
          </div>
        </div>

        <!-- Profile Tab (Enhanced) -->
        <div v-if="activeTab === 'profile'" class="space-y-6">
          <ProfileSettings 
            :user="user" 
            @update="updateUserSettings"
            @password-change="updatePassword"
            @delete-account="deleteAccount"
          />
        </div>

        <!-- AI Consultations Tab -->
        <div v-if="activeTab === 'consultations'" class="space-y-6">
          <AIConsultationHistory 
            :consultations="aiConsultations"
            @view="viewConsultation"
            @continue="continueConsultation"
          />
        </div>

        <!-- Excel Files Tab -->
        <div v-if="activeTab === 'files'" class="space-y-6">
          <ExcelFileManager
            :files="excelFiles"
            @download="downloadFile"
            @analyze="analyzeFile"
            @delete="deleteFile"
          />
        </div>

        <!-- VBA Solutions Tab -->
        <div v-if="activeTab === 'vba'" class="space-y-6">
          <VBASolutionHistory
            :solutions="vbaSolutions"
            @view="viewSolution"
            @rate="rateSolution"
          />
        </div>

        <!-- Referral Tab (Enhanced) -->
        <div v-if="activeTab === 'referral'" class="space-y-6">
          <EnhancedReferralProgram
            :stats="referralStats"
            :code="referralCode"
            :url="referralUrl"
            :qrCode="qrCodeUrl"
            :referrals="recentReferrals"
            @copy-code="copyReferralCode"
            @copy-url="copyReferralUrl"
            @share="shareReferral"
          />
        </div>

        <!-- Subscription Tab -->
        <div v-if="activeTab === 'subscription'" class="space-y-6">
          <SubscriptionManager
            :subscription="subscriptionInfo"
            :plans="availablePlans"
            @upgrade="upgradePlan"
            @cancel="cancelSubscription"
          />
        </div>

        <!-- Security Tab -->
        <div v-if="activeTab === 'security'" class="space-y-6">
          <SecuritySettings
            :user="user"
            :sessions="activeSessions"
            :connectedServices="connectedServices"
            @enable-2fa="enable2FA"
            @revoke-session="revokeSession"
            @disconnect-service="disconnectService"
          />
        </div>

        <!-- Notifications Tab -->
        <div v-if="activeTab === 'notifications'" class="space-y-6">
          <NotificationsTab />
        </div>
        
        <!-- Data & Privacy Tab -->
        <div v-if="activeTab === 'privacy'" class="space-y-6">
          <DataPrivacySettings
            :preferences="privacyPreferences"
            @update="updatePrivacySettings"
            @download-data="downloadPersonalData"
            @delete-data="requestDataDeletion"
          />
        </div>
      </transition>
    </div>

    <!-- Modals -->
    <CreditPurchaseModal 
      v-if="showCreditPurchase"
      @close="showCreditPurchase = false"
      @purchase="handleCreditPurchase"
    />
  </div>
</template>

<script>
import { ref, computed, onMounted, watch } from 'vue'
import { useUserStore } from '@/stores/user'
import { useToast } from '@/composables/useToast'
import api from '@/services/api'

// Import all components
import QuickActionCard from './account/QuickActionCard.vue'
import ActivityChart from './account/ActivityChart.vue'
import ProfileSettings from './account/ProfileSettings.vue'
import AIConsultationHistory from './account/AIConsultationHistory.vue'
import ExcelFileManager from './account/ExcelFileManager.vue'
import VBASolutionHistory from './account/VBASolutionHistory.vue'
import EnhancedReferralProgram from './account/EnhancedReferralProgram.vue'
import SubscriptionManager from './account/SubscriptionManager.vue'
import SecuritySettings from './account/SecuritySettings.vue'
import DataPrivacySettings from './account/DataPrivacySettings.vue'
import NotificationsTab from './account/NotificationsTab.vue'
import CreditPurchaseModal from './account/CreditPurchaseModal.vue'
import AvatarUploader from './AvatarUploader.vue'

export default {
  name: 'MyAccount',
  
  components: {
    QuickActionCard,
    ActivityChart,
    ProfileSettings,
    AIConsultationHistory,
    ExcelFileManager,
    VBASolutionHistory,
    EnhancedReferralProgram,
    SubscriptionManager,
    SecuritySettings,
    DataPrivacySettings,
    CreditPurchaseModal
  },
  
  setup() {
    const userStore = useUserStore()
    const { showToast } = useToast()
    
    // State
    const activeTab = ref('overview')
    const showCreditPurchase = ref(false)
    const loading = ref(false)
    
    // Data
    const userStats = ref({
      totalConsultations: 0,
      totalFiles: 0,
      vbaSolutions: 0
    })
    
    const subscriptionInfo = ref({
      plan: 'Free',
      status: '활성',
      nextBillingDate: null
    })
    
    const unreadNotificationCount = ref(0)
    
    const activityChartData = ref([])
    const aiConsultations = ref([])
    const excelFiles = ref([])
    const vbaSolutions = ref([])
    const referralStats = ref({})
    const recentReferrals = ref([])
    const activeSessions = ref([])
    const connectedServices = ref([])
    const privacyPreferences = ref({})
    const availablePlans = ref([])
    
    // Computed
    const user = computed(() => userStore.currentUser)
    const referralCode = computed(() => referralStats.value.code || '')
    const referralUrl = computed(() => referralStats.value.referral_url || '')
    const qrCodeUrl = computed(() => referralStats.value.qr_code_url || '')
    const defaultAvatar = computed(() => 
      `https://ui-avatars.com/api/?name=${encodeURIComponent(user.value?.name || user.value?.email || 'User')}&background=3B82F6&color=fff&size=200`
    )
    
    // Enhanced tabs
    const tabs = [
      {
        id: 'overview',
        label: '개요',
        icon: 'HomeIcon'
      },
      {
        id: 'profile',
        label: '프로필',
        icon: 'UserIcon'
      },
      {
        id: 'consultations',
        label: 'AI 상담',
        icon: 'ChatIcon',
        badge: computed(() => aiConsultations.value.filter(c => c.unread).length || null)
      },
      {
        id: 'files',
        label: 'Excel 파일',
        icon: 'DocumentIcon'
      },
      {
        id: 'vba',
        label: 'VBA 솔루션',
        icon: 'CodeIcon'
      },
      {
        id: 'referral',
        label: '추천 프로그램',
        icon: 'GiftIcon',
        badge: computed(() => referralStats.value.pending_count || null),
        badgeClass: 'bg-green-100 text-green-800'
      },
      {
        id: 'subscription',
        label: '구독',
        icon: 'CreditCardIcon'
      },
      {
        id: 'notifications',
        label: '알림',
        icon: 'BellIcon',
        badge: computed(() => unreadNotificationCount.value || null),
        badgeClass: 'bg-red-100 text-red-800'
      },
      {
        id: 'security',
        label: '보안',
        icon: 'ShieldCheckIcon'
      },
      {
        id: 'privacy',
        label: '개인정보',
        icon: 'LockClosedIcon'
      }
    ]
    
    // Methods
    const loadUserStats = async () => {
      // Load various stats based on active tab
      try {
        loading.value = true
        
        switch (activeTab.value) {
          case 'overview':
            await Promise.all([
              loadActivityData(),
              loadQuickStats()
            ])
            break
          case 'consultations':
            await loadAIConsultations()
            break
          case 'files':
            await loadExcelFiles()
            break
          case 'vba':
            await loadVBASolutions()
            break
          case 'referral':
            await loadReferralStats()
            break
          case 'subscription':
            await loadSubscriptionInfo()
            break
          case 'security':
            await loadSecurityInfo()
            break
          case 'notifications':
            // Notifications tab has its own loading mechanism
            break
          case 'privacy':
            await loadPrivacySettings()
            break
        }
      } catch (error) {
        showToast('데이터 로드 중 오류가 발생했습니다', 'error')
      } finally {
        loading.value = false
      }
    }
    
    const loadActivityData = async () => {
      const response = await api.get('/my-account/activities', {
        params: { per_page: 30 }
      })
      
      // Process for chart
      const activityByDay = {}
      response.data.activities.forEach(activity => {
        const day = new Date(activity.created_at).toLocaleDateString()
        activityByDay[day] = (activityByDay[day] || 0) + 1
      })
      
      activityChartData.value = Object.entries(activityByDay).map(([date, count]) => ({
        date,
        count
      }))
    }
    
    const loadQuickStats = async () => {
      // This would ideally be a dedicated endpoint
      const [consultations, files, vba] = await Promise.all([
        api.get('/my-account/ai-consultations', { params: { per_page: 1 } }),
        api.get('/my-account/excel-files', { params: { per_page: 1 } }),
        api.get('/my-account/vba-solutions', { params: { per_page: 1 } })
      ])
      
      userStats.value = {
        totalConsultations: consultations.data.meta.total_count,
        totalFiles: files.data.meta.total_count,
        vbaSolutions: vba.data.meta.total_count
      }
    }
    
    const loadAIConsultations = async () => {
      const response = await api.get('/my-account/ai-consultations')
      aiConsultations.value = response.data.consultations
    }
    
    const loadExcelFiles = async () => {
      const response = await api.get('/my-account/excel-files')
      excelFiles.value = response.data.files
    }
    
    const loadVBASolutions = async () => {
      const response = await api.get('/my-account/vba-solutions')
      vbaSolutions.value = response.data.solutions
    }
    
    const loadReferralStats = async () => {
      const response = await api.get('/my-account/referral-stats')
      referralStats.value = response.data.stats
      recentReferrals.value = response.data.recent_referrals
    }
    
    const loadSubscriptionInfo = async () => {
      const response = await api.get('/my-account/subscription')
      subscriptionInfo.value = response.data.subscription
      availablePlans.value = response.data.available_plans || []
    }
    
    const loadSecurityInfo = async () => {
      const response = await api.get('/my-account/connected-services')
      connectedServices.value = response.data.services
      // Load active sessions if endpoint exists
    }
    
    const loadPrivacySettings = async () => {
      // Load privacy preferences
      privacyPreferences.value = {
        dataCollection: true,
        analytics: true,
        marketing: false
      }
    }
    
    const formatDaysActive = () => {
      if (!user.value?.created_at) return 0
      const days = Math.floor((Date.now() - new Date(user.value.created_at)) / (1000 * 60 * 60 * 24))
      return days
    }
    
    const copyReferralCode = async () => {
      try {
        await navigator.clipboard.writeText(referralCode.value)
        showToast('추천 코드가 복사되었습니다', 'success')
      } catch {
        showToast('복사 실패', 'error')
      }
    }
    
    const copyReferralUrl = async () => {
      try {
        await navigator.clipboard.writeText(referralUrl.value)
        showToast('추천 링크가 복사되었습니다', 'success')
      } catch {
        showToast('복사 실패', 'error')
      }
    }
    
    const shareReferral = () => {
      if (navigator.share) {
        navigator.share({
          title: 'Excel Unified 추천',
          text: `Excel Unified에 가입하고 ${referralStats.value.credits_per_signup} 크레딧을 받으세요!`,
          url: referralUrl.value
        })
      } else {
        copyReferralUrl()
      }
    }
    
    const handleAvatarUpdate = (newAvatarUrl) => {
      // Avatar has been updated
      if (user.value) {
        user.value.avatar = newAvatarUrl
      }
    }
    
    // 읽지 않은 알림 수 로드
    const loadUnreadNotificationCount = async () => {
      try {
        const { data } = await api.get('/notifications/unread_count')
        unreadNotificationCount.value = data.unread_count
      } catch (error) {
        console.error('Failed to load notification count:', error)
      }
    }
    
    const handleCreditPurchase = async (purchaseData) => {
      try {
        await api.post('/my-account/purchase-credits', purchaseData)
        showToast('크레딧 구매가 완료되었습니다', 'success')
        userStore.fetchCurrentUser()
        showCreditPurchase.value = false
      } catch (error) {
        showToast('구매 처리 중 오류가 발생했습니다', 'error')
      }
    }
    
    const updateUserSettings = async (settings) => {
      try {
        await api.patch('/my-account/settings', settings)
        showToast('설정이 저장되었습니다', 'success')
        userStore.fetchCurrentUser()
      } catch (error) {
        showToast('설정 저장 실패', 'error')
      }
    }
    
    const updatePassword = async (passwordData) => {
      try {
        await api.post('/my-account/update-password', passwordData)
        showToast('비밀번호가 변경되었습니다', 'success')
      } catch (error) {
        showToast(error.response?.data?.error || '비밀번호 변경 실패', 'error')
      }
    }
    
    const deleteAccount = async (password) => {
      if (!confirm('정말로 계정을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.')) {
        return
      }
      
      try {
        await api.delete('/my-account/delete-account', { data: { password } })
        showToast('계정이 삭제되었습니다', 'success')
        userStore.logout()
      } catch (error) {
        showToast(error.response?.data?.error || '계정 삭제 실패', 'error')
      }
    }
    
    const downloadPersonalData = async () => {
      try {
        const response = await api.post('/my-account/download-data', {}, {
          responseType: 'blob'
        })
        
        const url = window.URL.createObjectURL(new Blob([response.data]))
        const link = document.createElement('a')
        link.href = url
        link.setAttribute('download', `personal_data_${Date.now()}.json`)
        document.body.appendChild(link)
        link.click()
        link.remove()
        
        showToast('개인정보가 다운로드되었습니다', 'success')
      } catch (error) {
        showToast('다운로드 실패', 'error')
      }
    }
    
    // Watch tab changes
    watch(activeTab, () => {
      loadUserStats()
    })
    
    onMounted(() => {
      loadUserStats()
      loadUnreadNotificationCount()
    })
    
    return {
      // State
      activeTab,
      showCreditPurchase,
      loading,
      user,
      defaultAvatar,
      tabs,
      
      // Data
      userStats,
      subscriptionInfo,
      activityChartData,
      aiConsultations,
      excelFiles,
      vbaSolutions,
      referralStats,
      referralCode,
      referralUrl,
      qrCodeUrl,
      recentReferrals,
      activeSessions,
      connectedServices,
      privacyPreferences,
      availablePlans,
      
      // Methods
      formatDaysActive,
      copyReferralCode,
      copyReferralUrl,
      shareReferral,
      handleAvatarUpdate,
      handleCreditPurchase,
      updateUserSettings,
      updatePassword,
      deleteAccount,
      downloadPersonalData
    }
  }
}
</script>

<style scoped>
/* Smooth animations */
.my-account {
  animation: fadeIn 0.4s ease-out;
}

@keyframes fadeIn {
  from {
    opacity: 0;
  }
  to {
    opacity: 1;
  }
}

/* Fade slide transition */
.fade-slide-enter-active,
.fade-slide-leave-active {
  transition: all 0.3s ease-out;
}

.fade-slide-enter-from {
  opacity: 0;
  transform: translateY(20px);
}

.fade-slide-leave-to {
  opacity: 0;
  transform: translateY(-20px);
}

/* Blob animation */
@keyframes blob {
  0% {
    transform: translate(0px, 0px) scale(1);
  }
  33% {
    transform: translate(30px, -50px) scale(1.1);
  }
  66% {
    transform: translate(-20px, 20px) scale(0.9);
  }
  100% {
    transform: translate(0px, 0px) scale(1);
  }
}

.animate-blob {
  animation: blob 7s infinite;
}

.animation-delay-2000 {
  animation-delay: 2s;
}

.animation-delay-4000 {
  animation-delay: 4s;
}

/* Hide scrollbar but keep functionality */
.scrollbar-hide {
  -ms-overflow-style: none;
  scrollbar-width: none;
}

.scrollbar-hide::-webkit-scrollbar {
  display: none;
}

/* Glass morphism effects */
.glass {
  background: rgba(255, 255, 255, 0.25);
  backdrop-filter: blur(10px);
  border: 1px solid rgba(255, 255, 255, 0.18);
}

/* Hover effects */
.hover-lift {
  transition: all 0.3s ease;
}

.hover-lift:hover {
  transform: translateY(-4px);
  box-shadow: 0 12px 24px -10px rgba(0, 0, 0, 0.25);
}
</style>