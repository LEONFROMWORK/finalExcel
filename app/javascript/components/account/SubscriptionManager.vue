<template>
  <div class="subscription-manager">
    <!-- Current Plan -->
    <div class="bg-gradient-to-br from-blue-600 to-indigo-700 rounded-2xl shadow-xl p-8 text-white mb-6">
      <div class="flex flex-col lg:flex-row justify-between items-start lg:items-center gap-6">
        <div>
          <h3 class="text-2xl font-bold mb-2">현재 구독 플랜</h3>
          <div class="flex items-center gap-3 mb-4">
            <span class="text-4xl font-bold">{{ subscription.plan }}</span>
            <span :class="getStatusClass(subscription.status)" class="px-3 py-1 rounded-full text-sm font-medium">
              {{ getStatusLabel(subscription.status) }}
            </span>
          </div>
          
          <div class="space-y-2 text-blue-100">
            <div class="flex items-center gap-2">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
              </svg>
              <span>남은 크레딧: {{ subscription.credits_remaining.toLocaleString() }}</span>
            </div>
            <div v-if="subscription.next_billing_date" class="flex items-center gap-2">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
              </svg>
              <span>다음 결제일: {{ formatDate(subscription.next_billing_date) }}</span>
            </div>
          </div>
        </div>
        
        <div class="flex gap-3">
          <button
            v-if="subscription.plan !== 'Enterprise'"
            @click="showUpgradeModal = true"
            class="px-6 py-3 bg-white text-blue-600 rounded-lg font-medium hover:bg-blue-50 transition-colors"
          >
            업그레이드
          </button>
          <button
            v-if="subscription.status === 'active' && subscription.plan !== 'Free'"
            @click="showCancelModal = true"
            class="px-6 py-3 bg-white/20 text-white border border-white/30 rounded-lg font-medium hover:bg-white/30 transition-colors"
          >
            구독 관리
          </button>
        </div>
      </div>
      
      <!-- Current Plan Features -->
      <div class="mt-6 pt-6 border-t border-white/20">
        <h4 class="text-sm font-medium text-blue-100 mb-3">포함된 기능:</h4>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
          <div v-for="feature in subscription.features" :key="feature" class="flex items-start gap-2">
            <svg class="w-5 h-5 text-green-400 flex-shrink-0 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
            </svg>
            <span class="text-sm">{{ feature }}</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Available Plans -->
    <div class="mb-6">
      <h3 class="text-xl font-bold text-gray-900 mb-4">사용 가능한 플랜</h3>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div
          v-for="plan in availablePlans"
          :key="plan.id"
          class="bg-white rounded-2xl shadow-sm hover:shadow-xl transition-all duration-300 overflow-hidden"
          :class="{ 'ring-2 ring-blue-500': plan.recommended }"
        >
          <!-- Plan Header -->
          <div class="p-6" :class="plan.recommended ? 'bg-gradient-to-br from-blue-50 to-indigo-50' : ''">
            <div v-if="plan.recommended" class="mb-2">
              <span class="px-3 py-1 bg-blue-600 text-white text-xs font-medium rounded-full">
                추천
              </span>
            </div>
            <h4 class="text-2xl font-bold text-gray-900 mb-2">{{ plan.name }}</h4>
            <div class="flex items-baseline gap-1 mb-4">
              <span class="text-4xl font-bold">₩{{ plan.price.toLocaleString() }}</span>
              <span class="text-gray-500">/월</span>
            </div>
            <p class="text-gray-600">{{ plan.description }}</p>
          </div>
          
          <!-- Features -->
          <div class="p-6 pt-0">
            <ul class="space-y-3 mb-6">
              <li v-for="feature in plan.features" :key="feature" class="flex items-start gap-3">
                <svg class="w-5 h-5 text-green-500 flex-shrink-0 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
                </svg>
                <span class="text-sm text-gray-700">{{ feature }}</span>
              </li>
            </ul>
            
            <button
              v-if="plan.id !== currentPlanId"
              @click="selectPlan(plan)"
              class="w-full py-3 rounded-lg font-medium transition-colors"
              :class="plan.recommended 
                ? 'bg-blue-600 text-white hover:bg-blue-700' 
                : 'bg-gray-100 text-gray-700 hover:bg-gray-200'"
            >
              {{ plan.price === 0 ? '무료로 시작' : '선택하기' }}
            </button>
            <div v-else class="w-full py-3 bg-gray-100 text-gray-500 rounded-lg text-center font-medium">
              현재 플랜
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Usage History -->
    <div class="bg-white rounded-2xl shadow-sm p-6">
      <h3 class="text-xl font-bold text-gray-900 mb-4">사용량 및 결제 내역</h3>
      
      <!-- Usage Chart -->
      <div class="mb-6">
        <div class="flex justify-between text-sm text-gray-600 mb-2">
          <span>이번 달 사용량</span>
          <span>{{ currentUsage.used.toLocaleString() }} / {{ currentUsage.limit.toLocaleString() }}</span>
        </div>
        <div class="w-full h-3 bg-gray-200 rounded-full overflow-hidden">
          <div
            class="h-full bg-gradient-to-r from-blue-500 to-blue-600 transition-all duration-500"
            :style="{ width: `${usagePercentage}%` }"
          ></div>
        </div>
        <p v-if="usagePercentage > 80" class="text-sm text-orange-600 mt-2">
          사용량이 80%를 초과했습니다. 업그레이드를 고려해보세요.
        </p>
      </div>
      
      <!-- Billing History -->
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead>
            <tr>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                날짜
              </th>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                설명
              </th>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                금액
              </th>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                상태
              </th>
              <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                영수증
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200">
            <tr v-for="invoice in billingHistory" :key="invoice.id" class="hover:bg-gray-50">
              <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-900">
                {{ formatDate(invoice.date) }}
              </td>
              <td class="px-4 py-3 whitespace-nowrap text-sm text-gray-900">
                {{ invoice.description }}
              </td>
              <td class="px-4 py-3 whitespace-nowrap text-sm font-medium text-gray-900">
                ₩{{ invoice.amount.toLocaleString() }}
              </td>
              <td class="px-4 py-3 whitespace-nowrap">
                <span :class="getInvoiceStatusClass(invoice.status)" class="px-2 py-1 text-xs font-medium rounded-full">
                  {{ getInvoiceStatusLabel(invoice.status) }}
                </span>
              </td>
              <td class="px-4 py-3 whitespace-nowrap text-sm">
                <button
                  @click="downloadInvoice(invoice.id)"
                  class="text-blue-600 hover:text-blue-900 font-medium"
                >
                  다운로드
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Upgrade Modal -->
    <transition name="modal">
      <div v-if="showUpgradeModal" class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div class="absolute inset-0 bg-black/50" @click="showUpgradeModal = false"></div>
        
        <div class="relative bg-white rounded-2xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
          <div class="p-6">
            <h3 class="text-2xl font-bold text-gray-900 mb-6">플랜 업그레이드</h3>
            
            <div v-if="selectedPlan" class="space-y-6">
              <!-- Plan Comparison -->
              <div class="bg-gray-50 rounded-xl p-6">
                <h4 class="font-medium text-gray-900 mb-4">플랜 비교</h4>
                <div class="grid grid-cols-2 gap-4">
                  <div>
                    <p class="text-sm text-gray-600 mb-1">현재 플랜</p>
                    <p class="text-lg font-semibold">{{ subscription.plan }}</p>
                    <p class="text-sm text-gray-500">₩{{ getCurrentPlanPrice().toLocaleString() }}/월</p>
                  </div>
                  <div>
                    <p class="text-sm text-gray-600 mb-1">새 플랜</p>
                    <p class="text-lg font-semibold">{{ selectedPlan.name }}</p>
                    <p class="text-sm text-gray-500">₩{{ selectedPlan.price.toLocaleString() }}/월</p>
                  </div>
                </div>
              </div>
              
              <!-- Payment Method -->
              <div>
                <h4 class="font-medium text-gray-900 mb-3">결제 방법</h4>
                <div class="space-y-2">
                  <label class="flex items-center p-4 border border-gray-300 rounded-lg cursor-pointer hover:bg-gray-50">
                    <input type="radio" name="payment" value="card" v-model="paymentMethod" class="mr-3">
                    <div class="flex-1">
                      <p class="font-medium">신용/체크카드</p>
                      <p class="text-sm text-gray-500">Visa, Mastercard, Amex</p>
                    </div>
                  </label>
                  <label class="flex items-center p-4 border border-gray-300 rounded-lg cursor-pointer hover:bg-gray-50">
                    <input type="radio" name="payment" value="transfer" v-model="paymentMethod" class="mr-3">
                    <div class="flex-1">
                      <p class="font-medium">계좌이체</p>
                      <p class="text-sm text-gray-500">실시간 계좌이체</p>
                    </div>
                  </label>
                </div>
              </div>
              
              <!-- Terms -->
              <div class="text-sm text-gray-600">
                <p>• 즉시 새 플랜으로 변경됩니다</p>
                <p>• 남은 기간에 대한 금액은 자동으로 정산됩니다</p>
                <p>• 언제든지 구독을 취소할 수 있습니다</p>
              </div>
            </div>
            
            <div class="flex gap-3 justify-end mt-6">
              <button
                @click="showUpgradeModal = false"
                class="px-4 py-2 text-gray-700 hover:bg-gray-100 rounded-lg transition-colors"
              >
                취소
              </button>
              <button
                @click="confirmUpgrade"
                :disabled="!paymentMethod"
                class="px-6 py-2 bg-blue-600 text-white rounded-lg font-medium disabled:opacity-50 disabled:cursor-not-allowed hover:bg-blue-700 transition-colors"
              >
                업그레이드 확인
              </button>
            </div>
          </div>
        </div>
      </div>
    </transition>

    <!-- Cancel Modal -->
    <transition name="modal">
      <div v-if="showCancelModal" class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div class="absolute inset-0 bg-black/50" @click="showCancelModal = false"></div>
        
        <div class="relative bg-white rounded-2xl max-w-md w-full p-6">
          <h3 class="text-xl font-bold text-gray-900 mb-4">구독 취소</h3>
          
          <p class="text-gray-600 mb-6">
            구독을 취소하시겠습니까? 현재 결제 기간이 끝날 때까지 서비스를 이용하실 수 있습니다.
          </p>
          
          <div class="mb-6">
            <label class="block text-sm font-medium text-gray-700 mb-2">
              취소 사유를 알려주세요 (선택사항)
            </label>
            <textarea
              v-model="cancelReason"
              rows="3"
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              placeholder="서비스 개선에 도움이 됩니다"
            ></textarea>
          </div>
          
          <div class="flex gap-3 justify-end">
            <button
              @click="showCancelModal = false"
              class="px-4 py-2 text-gray-700 hover:bg-gray-100 rounded-lg transition-colors"
            >
              유지하기
            </button>
            <button
              @click="confirmCancel"
              class="px-4 py-2 bg-red-600 text-white rounded-lg font-medium hover:bg-red-700 transition-colors"
            >
              구독 취소
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
  name: 'SubscriptionManager',
  
  props: {
    subscription: {
      type: Object,
      required: true
    },
    plans: {
      type: Array,
      default: () => []
    }
  },
  
  emits: ['upgrade', 'cancel'],
  
  setup(props, { emit }) {
    const { showToast } = useToast()
    
    const showUpgradeModal = ref(false)
    const showCancelModal = ref(false)
    const selectedPlan = ref(null)
    const paymentMethod = ref('')
    const cancelReason = ref('')
    
    // Mock data - in real app, this would come from API
    const availablePlans = ref([
      {
        id: 'free',
        name: 'Free',
        price: 0,
        description: '개인 사용자를 위한 무료 플랜',
        features: [
          '월 10회 AI 상담',
          '기본 Excel 분석',
          'VBA 오류 해결',
          '5GB 저장 공간'
        ],
        recommended: false
      },
      {
        id: 'pro',
        name: 'Pro',
        price: 29000,
        description: '전문가를 위한 프로 플랜',
        features: [
          '무제한 AI 상담',
          '고급 Excel 분석',
          'VBA 오류 해결 및 최적화',
          '50GB 저장 공간',
          '우선 지원',
          'API 액세스'
        ],
        recommended: true
      },
      {
        id: 'enterprise',
        name: 'Enterprise',
        price: 99000,
        description: '기업을 위한 엔터프라이즈 플랜',
        features: [
          '모든 Pro 기능',
          '전담 지원',
          '무제한 저장 공간',
          'SSO 지원',
          '맞춤형 AI 모델',
          'SLA 보장'
        ],
        recommended: false
      }
    ])
    
    const currentUsage = ref({
      used: 7,
      limit: 10
    })
    
    const billingHistory = ref([
      {
        id: 1,
        date: '2024-01-01',
        description: 'Pro 플랜 구독',
        amount: 29000,
        status: 'paid'
      },
      {
        id: 2,
        date: '2024-02-01',
        description: 'Pro 플랜 구독',
        amount: 29000,
        status: 'paid'
      }
    ])
    
    const currentPlanId = computed(() => {
      const planMap = { 'Free': 'free', 'Pro': 'pro', 'Enterprise': 'enterprise' }
      return planMap[props.subscription.plan] || 'free'
    })
    
    const usagePercentage = computed(() => {
      return Math.round((currentUsage.value.used / currentUsage.value.limit) * 100)
    })
    
    const selectPlan = (plan) => {
      selectedPlan.value = plan
      showUpgradeModal.value = true
    }
    
    const confirmUpgrade = () => {
      if (!selectedPlan.value || !paymentMethod.value) return
      
      emit('upgrade', {
        planId: selectedPlan.value.id,
        paymentMethod: paymentMethod.value
      })
      
      showToast('플랜이 업그레이드되었습니다', 'success')
      showUpgradeModal.value = false
    }
    
    const confirmCancel = () => {
      emit('cancel', { reason: cancelReason.value })
      showToast('구독이 취소되었습니다', 'success')
      showCancelModal.value = false
    }
    
    const getCurrentPlanPrice = () => {
      const plan = availablePlans.value.find(p => p.id === currentPlanId.value)
      return plan?.price || 0
    }
    
    const downloadInvoice = (invoiceId) => {
      showToast('영수증을 다운로드하는 중...', 'info')
      // In real app, this would trigger a download
    }
    
    const getStatusClass = (status) => {
      const classes = {
        active: 'bg-green-100 text-green-800',
        cancelled: 'bg-red-100 text-red-800',
        past_due: 'bg-yellow-100 text-yellow-800'
      }
      return classes[status] || 'bg-gray-100 text-gray-800'
    }
    
    const getStatusLabel = (status) => {
      const labels = {
        active: '활성',
        cancelled: '취소됨',
        past_due: '연체'
      }
      return labels[status] || status
    }
    
    const getInvoiceStatusClass = (status) => {
      const classes = {
        paid: 'bg-green-100 text-green-800',
        pending: 'bg-yellow-100 text-yellow-800',
        failed: 'bg-red-100 text-red-800'
      }
      return classes[status] || 'bg-gray-100 text-gray-800'
    }
    
    const getInvoiceStatusLabel = (status) => {
      const labels = {
        paid: '결제완료',
        pending: '대기중',
        failed: '실패'
      }
      return labels[status] || status
    }
    
    const formatDate = (date) => {
      return new Date(date).toLocaleDateString('ko-KR', {
        year: 'numeric',
        month: 'long',
        day: 'numeric'
      })
    }
    
    return {
      showUpgradeModal,
      showCancelModal,
      selectedPlan,
      paymentMethod,
      cancelReason,
      availablePlans,
      currentUsage,
      billingHistory,
      currentPlanId,
      usagePercentage,
      selectPlan,
      confirmUpgrade,
      confirmCancel,
      getCurrentPlanPrice,
      downloadInvoice,
      getStatusClass,
      getStatusLabel,
      getInvoiceStatusClass,
      getInvoiceStatusLabel,
      formatDate
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