<template>
  <div class="signup-form">
    <form @submit.prevent="handleSubmit" class="space-y-6">
      <!-- Email -->
      <div>
        <label for="email" class="block text-sm font-medium text-gray-700 mb-2">
          이메일
        </label>
        <input
          id="email"
          v-model="form.email"
          type="email"
          required
          class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
          placeholder="your@email.com"
        >
        <p v-if="errors.email" class="mt-1 text-sm text-red-600">{{ errors.email }}</p>
      </div>

      <!-- Password -->
      <div>
        <label for="password" class="block text-sm font-medium text-gray-700 mb-2">
          비밀번호
        </label>
        <div class="relative">
          <input
            id="password"
            v-model="form.password"
            :type="showPassword ? 'text' : 'password'"
            required
            class="w-full px-4 py-3 pr-12 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
            placeholder="8자 이상"
          >
          <button
            type="button"
            @click="showPassword = !showPassword"
            class="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-500 hover:text-gray-700"
          >
            <svg v-if="!showPassword" class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path>
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path>
            </svg>
            <svg v-else class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21"></path>
            </svg>
          </button>
        </div>
        <p v-if="errors.password" class="mt-1 text-sm text-red-600">{{ errors.password }}</p>
      </div>

      <!-- Password Confirmation -->
      <div>
        <label for="password_confirmation" class="block text-sm font-medium text-gray-700 mb-2">
          비밀번호 확인
        </label>
        <input
          id="password_confirmation"
          v-model="form.password_confirmation"
          type="password"
          required
          class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
          placeholder="비밀번호 재입력"
        >
        <p v-if="errors.password_confirmation" class="mt-1 text-sm text-red-600">{{ errors.password_confirmation }}</p>
      </div>

      <!-- Referral Code Section -->
      <div class="bg-gradient-to-r from-blue-50 to-indigo-50 rounded-lg p-4">
        <div class="flex items-center justify-between mb-3">
          <label class="block text-sm font-medium text-gray-700">
            추천인 코드 (선택사항)
          </label>
          <span v-if="referralBonus" class="text-sm font-medium text-green-600">
            +{{ referralBonus }} 크레딧 보너스!
          </span>
        </div>
        
        <div class="relative">
          <input
            v-model="form.referral_code"
            type="text"
            class="w-full px-4 py-3 pr-12 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all uppercase"
            placeholder="추천 코드 입력"
            @input="validateReferralCode"
          >
          
          <!-- Validation Icon -->
          <div class="absolute right-3 top-1/2 transform -translate-y-1/2">
            <svg v-if="referralValidated" class="w-5 h-5 text-green-500" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
            </svg>
            <svg v-else-if="referralInvalid" class="w-5 h-5 text-red-500" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
            </svg>
            <div v-else-if="checkingReferral" class="animate-spin">
              <svg class="w-5 h-5 text-gray-400" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
            </div>
          </div>
        </div>
        
        <p v-if="referralMessage" class="mt-2 text-sm" :class="referralValidated ? 'text-green-600' : 'text-red-600'">
          {{ referralMessage }}
        </p>
        
        <p class="mt-2 text-xs text-gray-600">
          친구의 추천 코드를 입력하면 가입 시 {{ defaultReferralBonus }} 크레딧을 추가로 받을 수 있습니다
        </p>
      </div>

      <!-- Terms Agreement -->
      <div class="space-y-3">
        <label class="flex items-start">
          <input
            v-model="form.agree_terms"
            type="checkbox"
            required
            class="mt-1 w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
          >
          <span class="ml-3 text-sm text-gray-700">
            <a href="/terms" target="_blank" class="text-blue-600 hover:text-blue-700">이용약관</a> 및 
            <a href="/privacy" target="_blank" class="text-blue-600 hover:text-blue-700">개인정보처리방침</a>에 동의합니다
          </span>
        </label>
        
        <label class="flex items-start">
          <input
            v-model="form.marketing_agreed"
            type="checkbox"
            class="mt-1 w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
          >
          <span class="ml-3 text-sm text-gray-700">
            프로모션 및 마케팅 정보 수신에 동의합니다 (선택)
          </span>
        </label>
      </div>

      <!-- Submit Button -->
      <button
        type="submit"
        :disabled="loading || !form.agree_terms"
        class="w-full py-3 px-4 bg-blue-600 text-white font-medium rounded-lg disabled:opacity-50 disabled:cursor-not-allowed hover:bg-blue-700 transition-colors flex items-center justify-center"
      >
        <span v-if="loading" class="flex items-center">
          <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          가입 중...
        </span>
        <span v-else>
          {{ referralValidated ? `가입하고 ${referralBonus} 크레딧 받기` : '회원가입' }}
        </span>
      </button>

      <!-- Social Login -->
      <div class="relative">
        <div class="absolute inset-0 flex items-center">
          <div class="w-full border-t border-gray-300"></div>
        </div>
        <div class="relative flex justify-center text-sm">
          <span class="px-4 bg-white text-gray-500">또는</span>
        </div>
      </div>

      <div class="grid grid-cols-2 gap-3">
        <button
          type="button"
          @click="signupWithGoogle"
          class="py-3 px-4 border border-gray-300 rounded-lg text-gray-700 font-medium hover:bg-gray-50 transition-colors flex items-center justify-center gap-2"
        >
          <img src="https://www.google.com/favicon.ico" alt="Google" class="w-5 h-5">
          Google
        </button>
        
        <button
          type="button"
          @click="signupWithGithub"
          class="py-3 px-4 border border-gray-300 rounded-lg text-gray-700 font-medium hover:bg-gray-50 transition-colors flex items-center justify-center gap-2"
        >
          <img src="https://github.com/favicon.ico" alt="GitHub" class="w-5 h-5">
          GitHub
        </button>
      </div>

      <!-- Login Link -->
      <p class="text-center text-sm text-gray-600">
        이미 계정이 있으신가요?
        <a href="/login" class="text-blue-600 hover:text-blue-700 font-medium">로그인</a>
      </p>
    </form>
  </div>
</template>

<script>
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useToast } from '@/composables/useToast'
import api from '@/services/api'

export default {
  name: 'SignupForm',
  
  setup() {
    const router = useRouter()
    const { showToast } = useToast()
    
    // Form data
    const form = ref({
      email: '',
      password: '',
      password_confirmation: '',
      referral_code: '',
      agree_terms: false,
      marketing_agreed: false
    })
    
    // State
    const loading = ref(false)
    const showPassword = ref(false)
    const errors = ref({})
    
    // Referral code validation
    const checkingReferral = ref(false)
    const referralValidated = ref(false)
    const referralInvalid = ref(false)
    const referralMessage = ref('')
    const referralBonus = ref(0)
    const defaultReferralBonus = 10
    
    // Check if referral code is in URL
    const urlParams = new URLSearchParams(window.location.search)
    const refCode = urlParams.get('ref')
    if (refCode) {
      form.value.referral_code = refCode
      validateReferralCode()
    }
    
    // Validate referral code
    const validateReferralCode = async () => {
      const code = form.value.referral_code.trim()
      
      if (!code) {
        referralValidated.value = false
        referralInvalid.value = false
        referralMessage.value = ''
        referralBonus.value = 0
        return
      }
      
      if (code.length < 4) return
      
      checkingReferral.value = true
      referralValidated.value = false
      referralInvalid.value = false
      
      try {
        const response = await api.post('/auth/validate-referral', { code })
        
        if (response.data.valid) {
          referralValidated.value = true
          referralMessage.value = `${response.data.referrer_name}님의 추천 코드가 확인되었습니다`
          referralBonus.value = response.data.signup_credits || defaultReferralBonus
        } else {
          referralInvalid.value = true
          referralMessage.value = '유효하지 않은 추천 코드입니다'
          referralBonus.value = 0
        }
      } catch (error) {
        referralInvalid.value = true
        referralMessage.value = '추천 코드 확인 중 오류가 발생했습니다'
        referralBonus.value = 0
      } finally {
        checkingReferral.value = false
      }
    }
    
    // Handle form submission
    const handleSubmit = async () => {
      loading.value = true
      errors.value = {}
      
      try {
        const response = await api.post('/auth/signup', {
          user: {
            email: form.value.email,
            password: form.value.password,
            password_confirmation: form.value.password_confirmation,
            referral_code: form.value.referral_code,
            marketing_agreed: form.value.marketing_agreed
          }
        })
        
        if (response.data.success) {
          showToast('회원가입이 완료되었습니다!', 'success')
          
          // Show referral bonus message if applicable
          if (referralValidated.value) {
            showToast(`${referralBonus.value} 크레딧이 지급되었습니다!`, 'success')
          }
          
          // Auto login or redirect to login page
          router.push('/login')
        }
      } catch (error) {
        if (error.response?.data?.errors) {
          errors.value = error.response.data.errors
        } else {
          showToast('회원가입 중 오류가 발생했습니다', 'error')
        }
      } finally {
        loading.value = false
      }
    }
    
    // Social signup
    const signupWithGoogle = () => {
      // Store referral code in session if present
      if (form.value.referral_code) {
        sessionStorage.setItem('signup_referral_code', form.value.referral_code)
      }
      window.location.href = '/auth/google_oauth2'
    }
    
    const signupWithGithub = () => {
      // Store referral code in session if present
      if (form.value.referral_code) {
        sessionStorage.setItem('signup_referral_code', form.value.referral_code)
      }
      window.location.href = '/auth/github'
    }
    
    return {
      form,
      loading,
      showPassword,
      errors,
      checkingReferral,
      referralValidated,
      referralInvalid,
      referralMessage,
      referralBonus,
      defaultReferralBonus,
      handleSubmit,
      validateReferralCode,
      signupWithGoogle,
      signupWithGithub
    }
  }
}
</script>

<style scoped>
.signup-form {
  max-width: 480px;
  margin: 0 auto;
}
</style>