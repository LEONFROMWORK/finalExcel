<template>
  <div class="security-settings space-y-6">
    <!-- Two-Factor Authentication -->
    <div class="bg-white rounded-2xl shadow-sm overflow-hidden">
      <div class="p-6 border-b border-gray-200">
        <div class="flex items-center justify-between">
          <div>
            <h3 class="text-lg font-semibold text-gray-900">2단계 인증</h3>
            <p class="text-sm text-gray-500 mt-1">계정 보안을 강화하기 위해 2단계 인증을 사용하세요</p>
          </div>
          <div :class="user.two_factor_enabled ? 'bg-green-100' : 'bg-gray-100'" class="px-3 py-1 rounded-full">
            <span :class="user.two_factor_enabled ? 'text-green-800' : 'text-gray-600'" class="text-sm font-medium">
              {{ user.two_factor_enabled ? '활성화됨' : '비활성화됨' }}
            </span>
          </div>
        </div>
      </div>
      
      <div class="p-6">
        <div v-if="!user.two_factor_enabled" class="space-y-4">
          <p class="text-gray-600">
            2단계 인증을 활성화하면 로그인 시 비밀번호와 함께 휴대폰의 인증 앱에서 생성된 코드를 입력해야 합니다.
          </p>
          <button
            @click="startTwoFactorSetup"
            class="px-4 py-2 bg-green-600 text-white rounded-lg font-medium hover:bg-green-700 transition-colors"
          >
            2단계 인증 설정하기
          </button>
        </div>
        
        <div v-else class="space-y-4">
          <div class="flex items-center gap-3 text-green-600">
            <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M2.166 4.999A11.954 11.954 0 0010 1.944 11.954 11.954 0 0017.834 5c.11.65.166 1.32.166 2.001 0 5.225-3.34 9.67-8 11.317C5.34 16.67 2 12.225 2 7c0-.682.057-1.35.166-2.001zm11.541 3.708a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
            </svg>
            <span class="font-medium">2단계 인증이 활성화되어 있습니다</span>
          </div>
          
          <div class="flex gap-3">
            <button
              @click="showBackupCodes"
              class="px-4 py-2 text-blue-600 border border-blue-600 rounded-lg font-medium hover:bg-blue-50 transition-colors"
            >
              백업 코드 보기
            </button>
            <button
              @click="disableTwoFactor"
              class="px-4 py-2 text-red-600 border border-red-600 rounded-lg font-medium hover:bg-red-50 transition-colors"
            >
              비활성화
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Active Sessions -->
    <div class="bg-white rounded-2xl shadow-sm overflow-hidden">
      <div class="p-6 border-b border-gray-200">
        <h3 class="text-lg font-semibold text-gray-900">활성 세션</h3>
        <p class="text-sm text-gray-500 mt-1">현재 로그인된 기기와 위치를 확인하세요</p>
      </div>
      
      <div class="divide-y divide-gray-200">
        <div v-for="session in sessions" :key="session.id" class="p-6 hover:bg-gray-50">
          <div class="flex items-start justify-between">
            <div class="flex items-start gap-4">
              <div class="w-12 h-12 bg-gray-100 rounded-lg flex items-center justify-center">
                <svg v-if="session.device_type === 'desktop'" class="w-6 h-6 text-gray-600" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M3 5a2 2 0 012-2h10a2 2 0 012 2v8a2 2 0 01-2 2h-2.22l.123.489.804.804A1 1 0 0113 18H7a1 1 0 01-.707-1.707l.804-.804L7.22 15H5a2 2 0 01-2-2V5zm5.771 7H5V5h10v7H8.771z" clip-rule="evenodd" />
                </svg>
                <svg v-else class="w-6 h-6 text-gray-600" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M7 2a2 2 0 00-2 2v12a2 2 0 002 2h6a2 2 0 002-2V4a2 2 0 00-2-2H7zm3 14a1 1 0 100-2 1 1 0 000 2z" />
                </svg>
              </div>
              
              <div>
                <div class="flex items-center gap-2">
                  <h4 class="font-medium text-gray-900">
                    {{ session.browser }} on {{ session.os }}
                  </h4>
                  <span v-if="session.current" class="px-2 py-0.5 bg-green-100 text-green-700 text-xs font-medium rounded-full">
                    현재 세션
                  </span>
                </div>
                <p class="text-sm text-gray-600 mt-1">
                  {{ session.ip_address }} · {{ session.location }}
                </p>
                <p class="text-xs text-gray-500 mt-1">
                  마지막 활동: {{ formatLastActive(session.last_active_at) }}
                </p>
              </div>
            </div>
            
            <button
              v-if="!session.current"
              @click="$emit('revoke-session', session.id)"
              class="px-3 py-1.5 text-sm font-medium text-red-600 hover:bg-red-50 rounded-lg transition-colors"
            >
              종료
            </button>
          </div>
        </div>
      </div>
      
      <div class="p-6 bg-gray-50 border-t border-gray-200">
        <button
          @click="revokeAllSessions"
          class="text-sm font-medium text-red-600 hover:text-red-700"
        >
          다른 모든 세션 종료
        </button>
      </div>
    </div>

    <!-- Connected Services -->
    <div class="bg-white rounded-2xl shadow-sm overflow-hidden">
      <div class="p-6 border-b border-gray-200">
        <h3 class="text-lg font-semibold text-gray-900">연동된 서비스</h3>
        <p class="text-sm text-gray-500 mt-1">타사 서비스와의 연동을 관리하세요</p>
      </div>
      
      <div class="divide-y divide-gray-200">
        <div v-for="service in connectedServices" :key="service.service" class="p-6">
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-4">
              <div class="w-12 h-12 rounded-lg overflow-hidden">
                <img 
                  :src="getServiceIcon(service.service)" 
                  :alt="service.service"
                  class="w-full h-full object-cover"
                >
              </div>
              
              <div>
                <h4 class="font-medium text-gray-900">{{ getServiceName(service.service) }}</h4>
                <p class="text-sm text-gray-600">
                  {{ service.email }} · 연동일: {{ formatDate(service.connected_at) }}
                </p>
              </div>
            </div>
            
            <button
              @click="$emit('disconnect-service', service.service)"
              class="px-4 py-2 text-sm font-medium text-gray-700 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
            >
              연동 해제
            </button>
          </div>
        </div>
      </div>
      
      <div v-if="availableServices.length > 0" class="p-6 bg-gray-50 border-t border-gray-200">
        <p class="text-sm text-gray-600 mb-3">추가 서비스 연동</p>
        <div class="flex gap-3">
          <button
            v-for="service in availableServices"
            :key="service"
            @click="connectService(service)"
            class="px-4 py-2 text-sm font-medium bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors flex items-center gap-2"
          >
            <img 
              :src="getServiceIcon(service)" 
              :alt="service"
              class="w-5 h-5"
            >
            {{ getServiceName(service) }}
          </button>
        </div>
      </div>
    </div>

    <!-- Security Activity Log -->
    <div class="bg-white rounded-2xl shadow-sm overflow-hidden">
      <div class="p-6 border-b border-gray-200">
        <h3 class="text-lg font-semibold text-gray-900">보안 활동 로그</h3>
        <p class="text-sm text-gray-500 mt-1">최근 보안 관련 활동 내역</p>
      </div>
      
      <div class="divide-y divide-gray-200">
        <div v-for="activity in securityActivities" :key="activity.id" class="p-6 hover:bg-gray-50">
          <div class="flex items-start gap-3">
            <div :class="getActivityIconClass(activity.type)" class="w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0">
              <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                <path v-if="activity.type === 'login'" fill-rule="evenodd" d="M3 3a1 1 0 011 1v12a1 1 0 11-2 0V4a1 1 0 011-1zm7.707 3.293a1 1 0 010 1.414L9.414 9H17a1 1 0 110 2H9.414l1.293 1.293a1 1 0 01-1.414 1.414l-3-3a1 1 0 010-1.414l3-3a1 1 0 011.414 0z" clip-rule="evenodd" />
                <path v-else-if="activity.type === 'password_change'" d="M10 2a5 5 0 00-5 5v2a2 2 0 00-2 2v5a2 2 0 002 2h10a2 2 0 002-2v-5a2 2 0 00-2-2H7V7a3 3 0 015.905-.75 1 1 0 001.937-.5A5.002 5.002 0 0010 2z" />
                <path v-else fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
              </svg>
            </div>
            
            <div class="flex-1">
              <p class="text-sm font-medium text-gray-900">{{ getActivityLabel(activity.type) }}</p>
              <p class="text-sm text-gray-600 mt-1">
                {{ activity.details }}
              </p>
              <p class="text-xs text-gray-500 mt-1">
                {{ formatDate(activity.created_at) }} · {{ activity.ip_address }}
              </p>
            </div>
          </div>
        </div>
      </div>
      
      <div class="p-6 bg-gray-50 border-t border-gray-200 text-center">
        <button class="text-sm font-medium text-blue-600 hover:text-blue-700">
          전체 활동 로그 보기
        </button>
      </div>
    </div>

    <!-- Two-Factor Setup Modal -->
    <transition name="modal">
      <div v-if="showTwoFactorModal" class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div class="absolute inset-0 bg-black/50" @click="showTwoFactorModal = false"></div>
        
        <div class="relative bg-white rounded-2xl max-w-md w-full p-6">
          <h3 class="text-xl font-bold text-gray-900 mb-4">2단계 인증 설정</h3>
          
          <div class="space-y-4">
            <div class="text-center">
              <img :src="qrCodeUrl" alt="QR Code" class="mx-auto mb-4">
              <p class="text-sm text-gray-600">
                Google Authenticator 또는 유사한 앱으로 QR 코드를 스캔하세요
              </p>
            </div>
            
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">
                인증 코드 입력
              </label>
              <input
                v-model="verificationCode"
                type="text"
                class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                placeholder="6자리 코드"
              >
            </div>
          </div>
          
          <div class="flex gap-3 justify-end mt-6">
            <button
              @click="showTwoFactorModal = false"
              class="px-4 py-2 text-gray-700 hover:bg-gray-100 rounded-lg transition-colors"
            >
              취소
            </button>
            <button
              @click="confirmTwoFactor"
              :disabled="verificationCode.length !== 6"
              class="px-4 py-2 bg-blue-600 text-white rounded-lg font-medium disabled:opacity-50 disabled:cursor-not-allowed hover:bg-blue-700 transition-colors"
            >
              확인
            </button>
          </div>
        </div>
      </div>
    </transition>
  </div>
</template>

<script>
import { ref, computed } from 'vue'
import { useToast } from '@/composables/useToast'

export default {
  name: 'SecuritySettings',
  
  props: {
    user: {
      type: Object,
      required: true
    },
    sessions: {
      type: Array,
      default: () => []
    },
    connectedServices: {
      type: Array,
      default: () => []
    }
  },
  
  emits: ['enable-2fa', 'revoke-session', 'disconnect-service'],
  
  setup(props, { emit }) {
    const { showToast } = useToast()
    
    const showTwoFactorModal = ref(false)
    const verificationCode = ref('')
    const qrCodeUrl = ref('https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=otpauth://totp/ExcelUnified:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=ExcelUnified')
    
    // Mock security activities
    const securityActivities = ref([
      {
        id: 1,
        type: 'login',
        details: 'Chrome에서 로그인',
        ip_address: '123.456.789.0',
        created_at: new Date()
      },
      {
        id: 2,
        type: 'password_change',
        details: '비밀번호가 변경되었습니다',
        ip_address: '123.456.789.0',
        created_at: new Date(Date.now() - 86400000)
      }
    ])
    
    const availableServices = computed(() => {
      const connected = props.connectedServices.map(s => s.service)
      const allServices = ['google', 'github', 'microsoft']
      return allServices.filter(s => !connected.includes(s))
    })
    
    const startTwoFactorSetup = () => {
      showTwoFactorModal.value = true
    }
    
    const confirmTwoFactor = () => {
      if (verificationCode.value.length === 6) {
        emit('enable-2fa', { code: verificationCode.value })
        showToast('2단계 인증이 활성화되었습니다', 'success')
        showTwoFactorModal.value = false
      }
    }
    
    const disableTwoFactor = () => {
      if (confirm('2단계 인증을 비활성화하시겠습니까?')) {
        showToast('2단계 인증이 비활성화되었습니다', 'success')
      }
    }
    
    const showBackupCodes = () => {
      showToast('백업 코드 기능은 준비 중입니다', 'info')
    }
    
    const revokeAllSessions = () => {
      if (confirm('현재 세션을 제외한 모든 세션을 종료하시겠습니까?')) {
        showToast('모든 세션이 종료되었습니다', 'success')
      }
    }
    
    const connectService = (service) => {
      window.location.href = `/auth/${service}`
    }
    
    const getServiceIcon = (service) => {
      const icons = {
        google: 'https://www.google.com/favicon.ico',
        github: 'https://github.com/favicon.ico',
        microsoft: 'https://www.microsoft.com/favicon.ico'
      }
      return icons[service] || ''
    }
    
    const getServiceName = (service) => {
      const names = {
        google: 'Google',
        github: 'GitHub',
        microsoft: 'Microsoft'
      }
      return names[service] || service
    }
    
    const getActivityIconClass = (type) => {
      const classes = {
        login: 'bg-green-100 text-green-600',
        password_change: 'bg-blue-100 text-blue-600',
        failed_login: 'bg-red-100 text-red-600'
      }
      return classes[type] || 'bg-gray-100 text-gray-600'
    }
    
    const getActivityLabel = (type) => {
      const labels = {
        login: '로그인',
        password_change: '비밀번호 변경',
        failed_login: '로그인 실패'
      }
      return labels[type] || type
    }
    
    const formatDate = (date) => {
      return new Date(date).toLocaleDateString('ko-KR', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
      })
    }
    
    const formatLastActive = (date) => {
      const now = new Date()
      const active = new Date(date)
      const diff = Math.floor((now - active) / 1000 / 60) // minutes
      
      if (diff < 1) return '방금 전'
      if (diff < 60) return `${diff}분 전`
      if (diff < 1440) return `${Math.floor(diff / 60)}시간 전`
      return `${Math.floor(diff / 1440)}일 전`
    }
    
    return {
      showTwoFactorModal,
      verificationCode,
      qrCodeUrl,
      securityActivities,
      availableServices,
      startTwoFactorSetup,
      confirmTwoFactor,
      disableTwoFactor,
      showBackupCodes,
      revokeAllSessions,
      connectService,
      getServiceIcon,
      getServiceName,
      getActivityIconClass,
      getActivityLabel,
      formatDate,
      formatLastActive
    }
  }
}
</script>

<style scoped>
/* Modal transition */
.modal-enter-active,
.modal-leave-active {
  transition: all 0.3s ease;
}

.modal-enter-from,
.modal-leave-to {
  opacity: 0;
}

.modal-enter-from > div:last-child,
.modal-leave-to > div:last-child {
  transform: scale(0.9);
}
</style>