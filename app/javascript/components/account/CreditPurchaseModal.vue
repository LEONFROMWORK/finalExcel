<template>
  <transition name="modal">
    <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div class="absolute inset-0 bg-black/50" @click="$emit('close')"></div>
      
      <div class="relative bg-white rounded-2xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
        <!-- Header -->
        <div class="sticky top-0 bg-white border-b border-gray-200 px-6 py-4 rounded-t-2xl">
          <div class="flex items-center justify-between">
            <h2 class="text-2xl font-bold text-gray-900">크레딧 충전</h2>
            <button
              @click="$emit('close')"
              class="p-2 hover:bg-gray-100 rounded-lg transition-colors"
            >
              <svg class="w-5 h-5 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
              </svg>
            </button>
          </div>
        </div>
        
        <div class="p-6">
          <!-- Credit Packages -->
          <div class="mb-8">
            <h3 class="text-lg font-semibold text-gray-900 mb-4">크레딧 패키지 선택</h3>
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div
                v-for="package in creditPackages"
                :key="package.id"
                @click="selectedPackage = package"
                class="border-2 rounded-xl p-6 cursor-pointer transition-all"
                :class="selectedPackage?.id === package.id 
                  ? 'border-blue-500 bg-blue-50' 
                  : 'border-gray-200 hover:border-gray-300'"
              >
                <div v-if="package.popular" class="mb-2">
                  <span class="px-3 py-1 bg-orange-500 text-white text-xs font-medium rounded-full">
                    인기
                  </span>
                </div>
                
                <h4 class="text-xl font-bold text-gray-900 mb-1">
                  {{ package.credits.toLocaleString() }} 크레딧
                </h4>
                
                <div class="flex items-baseline gap-1 mb-3">
                  <span class="text-2xl font-bold">₩{{ package.price.toLocaleString() }}</span>
                  <span v-if="package.originalPrice" class="text-sm text-gray-500 line-through">
                    ₩{{ package.originalPrice.toLocaleString() }}
                  </span>
                </div>
                
                <div v-if="package.discount" class="text-sm text-green-600 font-medium mb-2">
                  {{ package.discount }}% 할인
                </div>
                
                <p class="text-sm text-gray-600">
                  크레딧당 ₩{{ Math.round(package.price / package.credits) }}
                </p>
                
                <div v-if="package.bonus" class="mt-3 text-xs text-blue-600 font-medium">
                  + {{ package.bonus }} 보너스 크레딧
                </div>
              </div>
            </div>
            
            <!-- Custom Amount -->
            <div class="mt-4">
              <button
                @click="showCustomAmount = !showCustomAmount"
                class="text-sm text-blue-600 hover:text-blue-700 font-medium"
              >
                다른 금액 입력 →
              </button>
              
              <div v-if="showCustomAmount" class="mt-3 flex gap-3">
                <input
                  v-model.number="customCredits"
                  type="number"
                  min="10"
                  step="10"
                  placeholder="크레딧 수량"
                  class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                >
                <button
                  @click="selectCustomAmount"
                  :disabled="!customCredits || customCredits < 10"
                  class="px-6 py-2 bg-blue-600 text-white rounded-lg font-medium disabled:opacity-50 disabled:cursor-not-allowed hover:bg-blue-700 transition-colors"
                >
                  선택
                </button>
              </div>
            </div>
          </div>

          <!-- Payment Method -->
          <div class="mb-8">
            <h3 class="text-lg font-semibold text-gray-900 mb-4">결제 수단</h3>
            <div class="space-y-3">
              <label
                v-for="method in paymentMethods"
                :key="method.id"
                class="flex items-center p-4 border-2 rounded-lg cursor-pointer transition-all"
                :class="selectedPaymentMethod?.id === method.id 
                  ? 'border-blue-500 bg-blue-50' 
                  : 'border-gray-200 hover:border-gray-300'"
              >
                <input
                  type="radio"
                  name="payment"
                  :value="method.id"
                  v-model="selectedPaymentMethod"
                  class="sr-only"
                >
                <div class="flex items-center gap-4 flex-1">
                  <img 
                    :src="method.icon" 
                    :alt="method.name"
                    class="h-8 object-contain"
                  >
                  <div>
                    <p class="font-medium text-gray-900">{{ method.name }}</p>
                    <p class="text-sm text-gray-500">{{ method.description }}</p>
                  </div>
                </div>
                <div v-if="selectedPaymentMethod?.id === method.id" class="text-blue-600">
                  <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                  </svg>
                </div>
              </label>
            </div>
          </div>

          <!-- Order Summary -->
          <div class="bg-gray-50 rounded-xl p-6 mb-8">
            <h3 class="font-semibold text-gray-900 mb-4">주문 요약</h3>
            
            <div v-if="selectedPackage" class="space-y-3">
              <div class="flex justify-between text-gray-700">
                <span>크레딧 {{ selectedPackage.credits.toLocaleString() }}개</span>
                <span>₩{{ selectedPackage.price.toLocaleString() }}</span>
              </div>
              
              <div v-if="selectedPackage.bonus" class="flex justify-between text-green-600">
                <span>보너스 크레딧</span>
                <span>+{{ selectedPackage.bonus }}</span>
              </div>
              
              <div v-if="appliedCoupon" class="flex justify-between text-blue-600">
                <span>쿠폰 할인 ({{ appliedCoupon.code }})</span>
                <span>-₩{{ couponDiscount.toLocaleString() }}</span>
              </div>
              
              <div class="pt-3 border-t border-gray-200">
                <div class="flex justify-between font-semibold text-lg">
                  <span>총 결제 금액</span>
                  <span>₩{{ finalAmount.toLocaleString() }}</span>
                </div>
                <p class="text-sm text-gray-500 mt-1">
                  총 {{ totalCredits.toLocaleString() }} 크레딧을 받으실 수 있습니다
                </p>
              </div>
            </div>
            
            <div v-else class="text-center text-gray-500 py-4">
              크레딧 패키지를 선택해주세요
            </div>
          </div>

          <!-- Coupon -->
          <div class="mb-8">
            <button
              @click="showCouponInput = !showCouponInput"
              class="text-sm text-blue-600 hover:text-blue-700 font-medium"
            >
              쿠폰 코드가 있으신가요? →
            </button>
            
            <div v-if="showCouponInput" class="mt-3 flex gap-3">
              <input
                v-model="couponCode"
                type="text"
                placeholder="쿠폰 코드 입력"
                class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              >
              <button
                @click="applyCoupon"
                :disabled="!couponCode"
                class="px-6 py-2 bg-gray-100 text-gray-700 rounded-lg font-medium disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-200 transition-colors"
              >
                적용
              </button>
            </div>
            
            <div v-if="appliedCoupon" class="mt-3 flex items-center gap-2 text-sm text-green-600">
              <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
              </svg>
              <span>쿠폰이 적용되었습니다</span>
              <button
                @click="removeCoupon"
                class="text-gray-500 hover:text-gray-700 ml-2"
              >
                제거
              </button>
            </div>
          </div>

          <!-- Terms -->
          <div class="mb-8">
            <label class="flex items-start">
              <input
                v-model="agreedToTerms"
                type="checkbox"
                class="mt-1 w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
              >
              <div class="ml-3 text-sm">
                <span class="text-gray-700">
                  <a href="/terms" class="text-blue-600 hover:text-blue-700">이용약관</a> 및 
                  <a href="/refund-policy" class="text-blue-600 hover:text-blue-700">환불정책</a>에 동의합니다
                </span>
              </div>
            </label>
          </div>

          <!-- Action Buttons -->
          <div class="flex gap-3">
            <button
              @click="$emit('close')"
              class="flex-1 px-6 py-3 text-gray-700 bg-gray-100 rounded-lg font-medium hover:bg-gray-200 transition-colors"
            >
              취소
            </button>
            <button
              @click="processPurchase"
              :disabled="!canPurchase"
              class="flex-1 px-6 py-3 bg-blue-600 text-white rounded-lg font-medium disabled:opacity-50 disabled:cursor-not-allowed hover:bg-blue-700 transition-colors"
            >
              {{ finalAmount.toLocaleString() }}원 결제하기
            </button>
          </div>
        </div>
      </div>
    </div>
  </transition>
</template>

<script>
import { ref, computed } from 'vue'
import { useToast } from '@/composables/useToast'

export default {
  name: 'CreditPurchaseModal',
  
  emits: ['close', 'purchase'],
  
  setup(props, { emit }) {
    const { showToast } = useToast()
    
    // Credit packages
    const creditPackages = ref([
      {
        id: 'starter',
        credits: 100,
        price: 9900,
        originalPrice: null,
        discount: 0,
        bonus: 0,
        popular: false
      },
      {
        id: 'popular',
        credits: 500,
        price: 39900,
        originalPrice: 49500,
        discount: 20,
        bonus: 50,
        popular: true
      },
      {
        id: 'pro',
        credits: 1000,
        price: 69900,
        originalPrice: 99000,
        discount: 30,
        bonus: 150,
        popular: false
      }
    ])
    
    // Payment methods
    const paymentMethods = ref([
      {
        id: 'card',
        name: '신용/체크카드',
        description: 'Visa, Mastercard, Amex 등',
        icon: '/images/payment/card.png'
      },
      {
        id: 'kakao',
        name: '카카오페이',
        description: '카카오페이로 간편 결제',
        icon: '/images/payment/kakao.png'
      },
      {
        id: 'naver',
        name: '네이버페이',
        description: '네이버페이로 간편 결제',
        icon: '/images/payment/naver.png'
      },
      {
        id: 'toss',
        name: '토스',
        description: '토스로 간편 결제',
        icon: '/images/payment/toss.png'
      }
    ])
    
    // State
    const selectedPackage = ref(null)
    const selectedPaymentMethod = ref(null)
    const showCustomAmount = ref(false)
    const customCredits = ref('')
    const showCouponInput = ref(false)
    const couponCode = ref('')
    const appliedCoupon = ref(null)
    const agreedToTerms = ref(false)
    
    // Computed
    const totalCredits = computed(() => {
      if (!selectedPackage.value) return 0
      return selectedPackage.value.credits + (selectedPackage.value.bonus || 0)
    })
    
    const couponDiscount = computed(() => {
      if (!appliedCoupon.value || !selectedPackage.value) return 0
      return Math.floor(selectedPackage.value.price * (appliedCoupon.value.discount / 100))
    })
    
    const finalAmount = computed(() => {
      if (!selectedPackage.value) return 0
      return selectedPackage.value.price - couponDiscount.value
    })
    
    const canPurchase = computed(() => {
      return selectedPackage.value && selectedPaymentMethod.value && agreedToTerms.value
    })
    
    // Methods
    const selectCustomAmount = () => {
      if (customCredits.value >= 10) {
        selectedPackage.value = {
          id: 'custom',
          credits: customCredits.value,
          price: customCredits.value * 100, // 100원 per credit
          bonus: 0
        }
        showCustomAmount.value = false
      }
    }
    
    const applyCoupon = () => {
      // Mock coupon validation
      if (couponCode.value === 'WELCOME10') {
        appliedCoupon.value = {
          code: couponCode.value,
          discount: 10
        }
        showToast('쿠폰이 적용되었습니다', 'success')
      } else {
        showToast('유효하지 않은 쿠폰 코드입니다', 'error')
      }
    }
    
    const removeCoupon = () => {
      appliedCoupon.value = null
      couponCode.value = ''
    }
    
    const processPurchase = () => {
      if (!canPurchase.value) return
      
      const purchaseData = {
        packageId: selectedPackage.value.id,
        credits: totalCredits.value,
        amount: finalAmount.value,
        paymentMethod: selectedPaymentMethod.value.id,
        coupon: appliedCoupon.value?.code
      }
      
      emit('purchase', purchaseData)
    }
    
    return {
      creditPackages,
      paymentMethods,
      selectedPackage,
      selectedPaymentMethod,
      showCustomAmount,
      customCredits,
      showCouponInput,
      couponCode,
      appliedCoupon,
      agreedToTerms,
      totalCredits,
      couponDiscount,
      finalAmount,
      canPurchase,
      selectCustomAmount,
      applyCoupon,
      removeCoupon,
      processPurchase
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
  transform: scale(0.95) translateY(20px);
}

.line-through {
  text-decoration: line-through;
}
</style>