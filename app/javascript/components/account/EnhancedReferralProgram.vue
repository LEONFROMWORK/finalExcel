<template>
  <div class="referral-program space-y-6">
    <!-- Referral Stats Overview -->
    <div class="grid grid-cols-1 md:grid-cols-4 gap-6">
      <div class="bg-white rounded-2xl shadow-sm p-6 text-center hover-lift">
        <div class="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center mx-auto mb-3">
          <svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"></path>
          </svg>
        </div>
        <p class="text-3xl font-bold text-gray-900">{{ stats.total_signups || 0 }}</p>
        <p class="text-sm text-gray-600 mt-1">총 추천 수</p>
      </div>
      
      <div class="bg-white rounded-2xl shadow-sm p-6 text-center hover-lift">
        <div class="w-12 h-12 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-3">
          <svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
          </svg>
        </div>
        <p class="text-3xl font-bold text-green-600">{{ stats.total_earned || 0 }}</p>
        <p class="text-sm text-gray-600 mt-1">획득 크레딧</p>
      </div>
      
      <div class="bg-white rounded-2xl shadow-sm p-6 text-center hover-lift">
        <div class="w-12 h-12 bg-yellow-100 rounded-full flex items-center justify-center mx-auto mb-3">
          <svg class="w-6 h-6 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
          </svg>
        </div>
        <p class="text-3xl font-bold text-yellow-600">{{ stats.pending_amount || 0 }}</p>
        <p class="text-sm text-gray-600 mt-1">대기 중</p>
      </div>
      
      <div class="bg-white rounded-2xl shadow-sm p-6 text-center hover-lift">
        <div class="w-12 h-12 bg-purple-100 rounded-full flex items-center justify-center mx-auto mb-3">
          <svg class="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"></path>
          </svg>
        </div>
        <p class="text-3xl font-bold text-purple-600">{{ stats.conversion_rate || 0 }}%</p>
        <p class="text-sm text-gray-600 mt-1">전환율</p>
      </div>
    </div>

    <!-- Referral Code Section -->
    <div class="bg-gradient-to-br from-blue-600 to-indigo-700 rounded-2xl shadow-xl overflow-hidden">
      <div class="p-8">
        <h3 class="text-2xl font-bold text-white mb-6">나의 추천 코드</h3>
        
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 items-start">
          <!-- Code Display -->
          <div class="lg:col-span-2 space-y-6">
            <div class="bg-white/20 backdrop-blur-md rounded-xl p-6">
              <p class="text-white/80 text-sm mb-2">추천 코드</p>
              <div class="flex items-center gap-3">
                <code class="text-3xl font-mono font-bold text-white tracking-wider">
                  {{ code }}
                </code>
                <button 
                  @click="$emit('copy-code')"
                  class="p-2 bg-white/20 hover:bg-white/30 rounded-lg transition-colors group"
                  title="복사"
                >
                  <svg class="w-5 h-5 text-white group-hover:scale-110 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"></path>
                  </svg>
                </button>
              </div>
            </div>
            
            <div>
              <p class="text-white/80 text-sm mb-2">추천 링크</p>
              <div class="flex gap-2">
                <input 
                  :value="url"
                  readonly
                  class="flex-1 px-4 py-3 bg-white/20 backdrop-blur-md border border-white/30 rounded-lg text-white placeholder-white/60 focus:outline-none focus:ring-2 focus:ring-white/50"
                >
                <button 
                  @click="$emit('copy-url')"
                  class="px-6 py-3 bg-white text-blue-600 rounded-lg font-medium hover:bg-blue-50 transition-colors"
                >
                  복사
                </button>
              </div>
            </div>
            
            <!-- Share Options -->
            <div class="flex flex-wrap gap-3">
              <button 
                @click="shareVia('kakao')"
                class="px-4 py-2 bg-yellow-400 text-gray-900 rounded-lg font-medium hover:bg-yellow-300 transition-colors"
              >
                카카오톡 공유
              </button>
              <button 
                @click="shareVia('facebook')"
                class="px-4 py-2 bg-blue-500 text-white rounded-lg font-medium hover:bg-blue-400 transition-colors"
              >
                페이스북 공유
              </button>
              <button 
                @click="shareVia('twitter')"
                class="px-4 py-2 bg-sky-500 text-white rounded-lg font-medium hover:bg-sky-400 transition-colors"
              >
                트위터 공유
              </button>
              <button 
                @click="$emit('share')"
                class="px-4 py-2 bg-white/20 text-white border border-white/30 rounded-lg font-medium hover:bg-white/30 transition-colors"
              >
                더보기
              </button>
            </div>
          </div>
          
          <!-- QR Code -->
          <div class="text-center">
            <div class="bg-white p-4 rounded-xl inline-block">
              <img 
                :src="qrCode" 
                alt="QR Code"
                class="w-40 h-40"
              >
            </div>
            <p class="text-white/80 text-sm mt-3">QR 코드로 공유하기</p>
          </div>
        </div>
        
        <!-- Reward Info -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-8">
          <div class="bg-white/10 backdrop-blur-md rounded-xl p-4 border border-white/20">
            <div class="flex items-center gap-3">
              <div class="w-10 h-10 bg-green-500 rounded-full flex items-center justify-center">
                <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"></path>
                </svg>
              </div>
              <div>
                <p class="text-white font-bold text-lg">{{ stats.credits_per_signup || 10 }} 크레딧</p>
                <p class="text-white/70 text-sm">회원가입 시 즉시 지급</p>
              </div>
            </div>
          </div>
          
          <div class="bg-white/10 backdrop-blur-md rounded-xl p-4 border border-white/20">
            <div class="flex items-center gap-3">
              <div class="w-10 h-10 bg-orange-500 rounded-full flex items-center justify-center">
                <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z"></path>
                </svg>
              </div>
              <div>
                <p class="text-white font-bold text-lg">{{ stats.credits_per_purchase || 5 }} 크레딧</p>
                <p class="text-white/70 text-sm">첫 구매 시 추가 지급</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Recent Referrals -->
    <div class="bg-white rounded-2xl shadow-sm overflow-hidden">
      <div class="p-6 border-b border-gray-200 flex justify-between items-center">
        <h3 class="text-lg font-semibold text-gray-900">최근 추천 내역</h3>
        <span v-if="referrals.length > 0" class="text-sm text-gray-500">
          최근 30일
        </span>
      </div>
      
      <div v-if="referrals.length > 0" class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                추천인
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                유형
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                크레딧
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                상태
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                날짜
              </th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <tr v-for="referral in referrals" :key="referral.id" class="hover:bg-gray-50 transition-colors">
              <td class="px-6 py-4 whitespace-nowrap">
                <div class="flex items-center">
                  <div class="w-8 h-8 bg-gray-200 rounded-full flex items-center justify-center mr-3">
                    <span class="text-xs font-medium text-gray-600">
                      {{ referral.referred_email.charAt(0).toUpperCase() }}
                    </span>
                  </div>
                  <span class="text-sm text-gray-900">{{ referral.referred_email }}</span>
                </div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <span class="px-2.5 py-1 text-xs font-medium rounded-full"
                      :class="getReferralTypeClass(referral.reward_type)">
                  {{ getReferralTypeLabel(referral.reward_type) }}
                </span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <span class="text-sm font-semibold text-gray-900">
                  +{{ referral.credits_amount }}
                </span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <span class="px-2.5 py-1 text-xs font-medium rounded-full"
                      :class="getReferralStatusClass(referral.status)">
                  {{ getReferralStatusLabel(referral.status) }}
                </span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                {{ formatDate(referral.created_at) }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      
      <div v-else class="p-12 text-center">
        <div class="w-20 h-20 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
          <svg class="w-10 h-10 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"></path>
          </svg>
        </div>
        <h4 class="text-lg font-medium text-gray-900 mb-2">아직 추천 내역이 없습니다</h4>
        <p class="text-sm text-gray-500 mb-6">친구들과 Excel Unified를 공유하고 크레딧을 받으세요!</p>
        <button 
          @click="$emit('share')"
          class="px-6 py-3 bg-blue-600 text-white rounded-lg font-medium hover:bg-blue-700 transition-colors"
        >
          지금 공유하기
        </button>
      </div>
    </div>
  </div>
</template>

<script>
import { ref } from 'vue'
import { useToast } from '@/composables/useToast'

export default {
  name: 'EnhancedReferralProgram',
  
  props: {
    stats: {
      type: Object,
      default: () => ({})
    },
    code: {
      type: String,
      required: true
    },
    url: {
      type: String,
      required: true
    },
    qrCode: {
      type: String,
      required: true
    },
    referrals: {
      type: Array,
      default: () => []
    }
  },
  
  emits: ['copy-code', 'copy-url', 'share'],
  
  setup(props, { emit }) {
    const { showToast } = useToast()
    
    const shareVia = (platform) => {
      const text = `Excel Unified에서 ${props.stats.credits_per_signup || 10} 크레딧을 받으세요!`
      const encodedUrl = encodeURIComponent(props.url)
      const encodedText = encodeURIComponent(text)
      
      const shareUrls = {
        kakao: `https://story.kakao.com/share?url=${encodedUrl}`,
        facebook: `https://www.facebook.com/sharer/sharer.php?u=${encodedUrl}`,
        twitter: `https://twitter.com/intent/tweet?text=${encodedText}&url=${encodedUrl}`
      }
      
      if (shareUrls[platform]) {
        window.open(shareUrls[platform], '_blank', 'width=600,height=400')
      }
    }
    
    const getReferralTypeClass = (type) => {
      const classes = {
        signup: 'bg-blue-100 text-blue-700',
        purchase: 'bg-green-100 text-green-700',
        milestone: 'bg-purple-100 text-purple-700'
      }
      return classes[type] || 'bg-gray-100 text-gray-700'
    }
    
    const getReferralTypeLabel = (type) => {
      const labels = {
        signup: '회원가입',
        purchase: '구매',
        milestone: '마일스톤'
      }
      return labels[type] || type
    }
    
    const getReferralStatusClass = (status) => {
      const classes = {
        pending: 'bg-yellow-100 text-yellow-700',
        approved: 'bg-blue-100 text-blue-700',
        paid: 'bg-green-100 text-green-700',
        cancelled: 'bg-red-100 text-red-700'
      }
      return classes[status] || 'bg-gray-100 text-gray-700'
    }
    
    const getReferralStatusLabel = (status) => {
      const labels = {
        pending: '대기중',
        approved: '승인됨',
        paid: '지급완료',
        cancelled: '취소됨'
      }
      return labels[status] || status
    }
    
    const formatDate = (date) => {
      return new Date(date).toLocaleDateString('ko-KR', {
        year: 'numeric',
        month: 'short',
        day: 'numeric'
      })
    }
    
    return {
      shareVia,
      getReferralTypeClass,
      getReferralTypeLabel,
      getReferralStatusClass,
      getReferralStatusLabel,
      formatDate
    }
  }
}
</script>

<style scoped>
.hover-lift {
  transition: all 0.3s ease;
}

.hover-lift:hover {
  transform: translateY(-4px);
  box-shadow: 0 12px 24px -10px rgba(0, 0, 0, 0.15);
}
</style>