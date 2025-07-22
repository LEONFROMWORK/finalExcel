<template>
  <div class="profile-settings space-y-6">
    <!-- Profile Information -->
    <div class="bg-white rounded-2xl shadow-sm overflow-hidden">
      <div class="p-6 border-b border-gray-200">
        <h3 class="text-lg font-semibold text-gray-900">프로필 정보</h3>
        <p class="text-sm text-gray-500 mt-1">다른 사용자에게 표시되는 정보입니다</p>
      </div>
      
      <div class="p-6 space-y-6">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">이름</label>
            <input
              v-model="form.name"
              type="text"
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
              placeholder="홍길동"
            >
          </div>
          
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">이메일</label>
            <input
              v-model="form.email"
              type="email"
              class="w-full px-4 py-2 border border-gray-300 rounded-lg bg-gray-50 cursor-not-allowed"
              disabled
            >
            <p class="text-xs text-gray-500 mt-1">이메일은 변경할 수 없습니다</p>
          </div>
          
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">전화번호</label>
            <input
              v-model="form.phone"
              type="tel"
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
              placeholder="010-1234-5678"
            >
          </div>
          
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">회사/조직</label>
            <input
              v-model="form.company"
              type="text"
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
              placeholder="회사명"
            >
          </div>
        </div>
        
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">자기소개</label>
          <textarea
            v-model="form.bio"
            rows="4"
            class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all resize-none"
            placeholder="간단한 자기소개를 작성해주세요"
          ></textarea>
          <p class="text-xs text-gray-500 mt-1">{{ form.bio?.length || 0 }}/200</p>
        </div>
        
        <div class="flex justify-end">
          <button
            @click="saveProfile"
            :disabled="!hasChanges || saving"
            class="px-6 py-2 bg-blue-600 text-white rounded-lg font-medium disabled:opacity-50 disabled:cursor-not-allowed hover:bg-blue-700 transition-colors"
          >
            <span v-if="saving" class="flex items-center gap-2">
              <svg class="animate-spin h-4 w-4" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              저장 중...
            </span>
            <span v-else>변경사항 저장</span>
          </button>
        </div>
      </div>
    </div>

    <!-- Password Change -->
    <div class="bg-white rounded-2xl shadow-sm overflow-hidden">
      <div class="p-6 border-b border-gray-200">
        <h3 class="text-lg font-semibold text-gray-900">비밀번호 변경</h3>
        <p class="text-sm text-gray-500 mt-1">정기적으로 비밀번호를 변경하여 계정을 안전하게 보호하세요</p>
      </div>
      
      <div class="p-6 space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">현재 비밀번호</label>
          <input
            v-model="passwordForm.currentPassword"
            type="password"
            class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
          >
        </div>
        
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">새 비밀번호</label>
          <input
            v-model="passwordForm.newPassword"
            type="password"
            class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
          >
          <div class="mt-2">
            <PasswordStrength :password="passwordForm.newPassword" />
          </div>
        </div>
        
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">새 비밀번호 확인</label>
          <input
            v-model="passwordForm.confirmPassword"
            type="password"
            class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
          >
          <p v-if="passwordForm.confirmPassword && passwordForm.newPassword !== passwordForm.confirmPassword" 
             class="text-xs text-red-600 mt-1">
            비밀번호가 일치하지 않습니다
          </p>
        </div>
        
        <div class="flex justify-end">
          <button
            @click="changePassword"
            :disabled="!canChangePassword || changingPassword"
            class="px-6 py-2 bg-blue-600 text-white rounded-lg font-medium disabled:opacity-50 disabled:cursor-not-allowed hover:bg-blue-700 transition-colors"
          >
            {{ changingPassword ? '변경 중...' : '비밀번호 변경' }}
          </button>
        </div>
      </div>
    </div>

    <!-- Preferences -->
    <div class="bg-white rounded-2xl shadow-sm overflow-hidden">
      <div class="p-6 border-b border-gray-200">
        <h3 class="text-lg font-semibold text-gray-900">환경 설정</h3>
        <p class="text-sm text-gray-500 mt-1">언어, 시간대 및 기타 설정을 관리합니다</p>
      </div>
      
      <div class="p-6 space-y-6">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">언어</label>
            <select
              v-model="form.language"
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
            >
              <option value="ko">한국어</option>
              <option value="en">English</option>
              <option value="ja">日本語</option>
              <option value="zh">中文</option>
            </select>
          </div>
          
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">시간대</label>
            <select
              v-model="form.timezone"
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
            >
              <option value="Asia/Seoul">서울 (GMT+9)</option>
              <option value="Asia/Tokyo">도쿄 (GMT+9)</option>
              <option value="America/New_York">뉴욕 (GMT-5)</option>
              <option value="Europe/London">런던 (GMT+0)</option>
            </select>
          </div>
        </div>
        
        <!-- Notification Settings -->
        <div>
          <h4 class="text-sm font-medium text-gray-900 mb-4">알림 설정</h4>
          <div class="space-y-3">
            <label class="flex items-center">
              <input
                v-model="form.notifications.email"
                type="checkbox"
                class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
              >
              <span class="ml-3 text-sm text-gray-700">이메일 알림 받기</span>
            </label>
            
            <label class="flex items-center">
              <input
                v-model="form.notifications.sms"
                type="checkbox"
                class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
              >
              <span class="ml-3 text-sm text-gray-700">SMS 알림 받기</span>
            </label>
            
            <label class="flex items-center">
              <input
                v-model="form.notifications.marketing"
                type="checkbox"
                class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
              >
              <span class="ml-3 text-sm text-gray-700">프로모션 및 업데이트 소식 받기</span>
            </label>
          </div>
        </div>
        
        <div class="flex justify-end">
          <button
            @click="savePreferences"
            :disabled="!hasPreferenceChanges || saving"
            class="px-6 py-2 bg-blue-600 text-white rounded-lg font-medium disabled:opacity-50 disabled:cursor-not-allowed hover:bg-blue-700 transition-colors"
          >
            환경설정 저장
          </button>
        </div>
      </div>
    </div>

    <!-- Danger Zone -->
    <div class="bg-red-50 border border-red-200 rounded-2xl overflow-hidden">
      <div class="p-6">
        <h3 class="text-lg font-semibold text-red-900 mb-2">위험 구역</h3>
        <p class="text-sm text-red-700 mb-6">이 작업들은 되돌릴 수 없습니다. 신중하게 진행해주세요.</p>
        
        <div class="space-y-4">
          <button
            @click="showDeleteModal = true"
            class="px-4 py-2 bg-red-600 text-white rounded-lg font-medium hover:bg-red-700 transition-colors"
          >
            계정 삭제
          </button>
        </div>
      </div>
    </div>

    <!-- Delete Account Modal -->
    <transition name="modal">
      <div v-if="showDeleteModal" class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div class="absolute inset-0 bg-black/50" @click="showDeleteModal = false"></div>
        
        <div class="relative bg-white rounded-2xl max-w-md w-full p-6">
          <h3 class="text-xl font-bold text-gray-900 mb-4">계정 삭제</h3>
          
          <p class="text-gray-600 mb-6">
            계정을 삭제하면 모든 데이터가 영구적으로 삭제되며 복구할 수 없습니다. 
            정말로 계정을 삭제하시겠습니까?
          </p>
          
          <div class="mb-6">
            <label class="block text-sm font-medium text-gray-700 mb-2">
              계속하려면 비밀번호를 입력하세요
            </label>
            <input
              v-model="deletePassword"
              type="password"
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-transparent"
              placeholder="비밀번호"
            >
          </div>
          
          <div class="flex gap-3 justify-end">
            <button
              @click="showDeleteModal = false"
              class="px-4 py-2 text-gray-700 hover:bg-gray-100 rounded-lg transition-colors"
            >
              취소
            </button>
            <button
              @click="confirmDelete"
              :disabled="!deletePassword || deleting"
              class="px-4 py-2 bg-red-600 text-white rounded-lg font-medium disabled:opacity-50 disabled:cursor-not-allowed hover:bg-red-700 transition-colors"
            >
              {{ deleting ? '삭제 중...' : '계정 삭제' }}
            </button>
          </div>
        </div>
      </div>
    </transition>
  </div>
</template>

<script>
import { ref, computed, watch } from 'vue'
import { useToast } from '@/composables/useToast'
import PasswordStrength from './PasswordStrength.vue'

export default {
  name: 'ProfileSettings',
  
  components: {
    PasswordStrength
  },
  
  props: {
    user: {
      type: Object,
      required: true
    }
  },
  
  emits: ['update', 'password-change', 'delete-account'],
  
  setup(props, { emit }) {
    const { showToast } = useToast()
    
    // Form data
    const form = ref({
      name: props.user.name || '',
      email: props.user.email || '',
      phone: props.user.phone || '',
      company: props.user.company || '',
      bio: props.user.bio || '',
      language: props.user.language || 'ko',
      timezone: props.user.timezone || 'Asia/Seoul',
      notifications: {
        email: props.user.notification_email !== false,
        sms: props.user.notification_sms !== false,
        marketing: props.user.marketing_agreed || false
      }
    })
    
    const originalForm = JSON.stringify(form.value)
    
    // Password form
    const passwordForm = ref({
      currentPassword: '',
      newPassword: '',
      confirmPassword: ''
    })
    
    // State
    const saving = ref(false)
    const changingPassword = ref(false)
    const deleting = ref(false)
    const showDeleteModal = ref(false)
    const deletePassword = ref('')
    
    // Computed
    const hasChanges = computed(() => {
      return JSON.stringify(form.value) !== originalForm
    })
    
    const hasPreferenceChanges = computed(() => {
      // Check if preferences have changed
      return true // Simplified for now
    })
    
    const canChangePassword = computed(() => {
      return passwordForm.value.currentPassword &&
             passwordForm.value.newPassword &&
             passwordForm.value.newPassword === passwordForm.value.confirmPassword &&
             passwordForm.value.newPassword.length >= 8
    })
    
    // Methods
    const saveProfile = async () => {
      saving.value = true
      
      try {
        await emit('update', {
          name: form.value.name,
          phone: form.value.phone,
          company: form.value.company,
          bio: form.value.bio
        })
        
        showToast('프로필이 업데이트되었습니다', 'success')
      } catch (error) {
        showToast('프로필 업데이트 실패', 'error')
      } finally {
        saving.value = false
      }
    }
    
    const savePreferences = async () => {
      saving.value = true
      
      try {
        await emit('update', {
          language: form.value.language,
          timezone: form.value.timezone,
          notification_email: form.value.notifications.email,
          notification_sms: form.value.notifications.sms,
          marketing_agreed: form.value.notifications.marketing
        })
        
        showToast('환경설정이 저장되었습니다', 'success')
      } catch (error) {
        showToast('환경설정 저장 실패', 'error')
      } finally {
        saving.value = false
      }
    }
    
    const changePassword = async () => {
      if (!canChangePassword.value) return
      
      changingPassword.value = true
      
      try {
        await emit('password-change', {
          current_password: passwordForm.value.currentPassword,
          new_password: passwordForm.value.newPassword
        })
        
        // Reset form
        passwordForm.value = {
          currentPassword: '',
          newPassword: '',
          confirmPassword: ''
        }
        
        showToast('비밀번호가 변경되었습니다', 'success')
      } catch (error) {
        showToast('비밀번호 변경 실패', 'error')
      } finally {
        changingPassword.value = false
      }
    }
    
    const confirmDelete = async () => {
      if (!deletePassword.value) return
      
      deleting.value = true
      
      try {
        await emit('delete-account', deletePassword.value)
        showToast('계정이 삭제되었습니다', 'success')
      } catch (error) {
        showToast('계정 삭제 실패', 'error')
      } finally {
        deleting.value = false
        showDeleteModal.value = false
      }
    }
    
    // Watch for user prop changes
    watch(() => props.user, (newUser) => {
      form.value = {
        name: newUser.name || '',
        email: newUser.email || '',
        phone: newUser.phone || '',
        company: newUser.company || '',
        bio: newUser.bio || '',
        language: newUser.language || 'ko',
        timezone: newUser.timezone || 'Asia/Seoul',
        notifications: {
          email: newUser.notification_email !== false,
          sms: newUser.notification_sms !== false,
          marketing: newUser.marketing_agreed || false
        }
      }
    }, { deep: true })
    
    return {
      form,
      passwordForm,
      saving,
      changingPassword,
      deleting,
      showDeleteModal,
      deletePassword,
      hasChanges,
      hasPreferenceChanges,
      canChangePassword,
      saveProfile,
      savePreferences,
      changePassword,
      confirmDelete
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