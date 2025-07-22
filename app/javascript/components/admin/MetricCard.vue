<template>
  <div 
    class="metric-card bg-white rounded-xl shadow-sm p-6 transition-all duration-200 hover:shadow-md cursor-pointer"
    :class="`border-l-4 border-${color}-500`"
  >
    <div class="flex items-center justify-between">
      <div class="flex-1">
        <p class="text-sm font-medium text-gray-600">{{ title }}</p>
        <div class="mt-2 flex items-baseline">
          <p class="text-3xl font-bold text-gray-900">
            <template v-if="loading">
              <div class="h-8 w-24 bg-gray-200 rounded animate-pulse"></div>
            </template>
            <template v-else>
              {{ formattedValue }}
            </template>
          </p>
          <p 
            v-if="change && !loading" 
            class="ml-2 text-sm font-medium"
            :class="changeClass"
          >
            {{ change }}
          </p>
        </div>
      </div>
      
      <div 
        class="ml-4 p-3 rounded-lg"
        :class="`bg-${color}-50`"
      >
        <svg 
          class="w-6 h-6"
          :class="`text-${color}-600`"
          fill="none" 
          stroke="currentColor" 
          viewBox="0 0 24 24"
        >
          <!-- 아이콘별 path 렌더링 -->
          <path 
            v-if="icon === 'UsersIcon'"
            stroke-linecap="round" 
            stroke-linejoin="round" 
            stroke-width="2" 
            d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"
          />
          <path 
            v-else-if="icon === 'StatusOnlineIcon'"
            stroke-linecap="round" 
            stroke-linejoin="round" 
            stroke-width="2" 
            d="M5.636 18.364a9 9 0 010-12.728m12.728 0a9 9 0 010 12.728m-9.9-2.829a5 5 0 010-7.07m7.072 0a5 5 0 010 7.07M13 12a1 1 0 11-2 0 1 1 0 012 0z"
          />
          <path 
            v-else-if="icon === 'DocumentTextIcon'"
            stroke-linecap="round" 
            stroke-linejoin="round" 
            stroke-width="2" 
            d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
          />
          <path 
            v-else-if="icon === 'DatabaseIcon'"
            stroke-linecap="round" 
            stroke-linejoin="round" 
            stroke-width="2" 
            d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4m0 5c0 2.21-3.582 4-8 4s-8-1.79-8-4"
          />
        </svg>
      </div>
    </div>
    
    <!-- 추가 정보 (선택적) -->
    <div v-if="additionalInfo && !loading" class="mt-4 pt-4 border-t border-gray-100">
      <div class="flex items-center justify-between text-sm">
        <span class="text-gray-600">{{ additionalInfo.label }}</span>
        <span class="font-medium text-gray-900">{{ additionalInfo.value }}</span>
      </div>
    </div>
  </div>
</template>

<script>
import { computed } from 'vue'

export default {
  name: 'MetricCard',
  
  props: {
    title: {
      type: String,
      required: true
    },
    value: {
      type: [Number, String],
      required: true
    },
    change: {
      type: String,
      default: null
    },
    icon: {
      type: String,
      required: true
    },
    color: {
      type: String,
      default: 'blue',
      validator: (value) => ['blue', 'green', 'purple', 'indigo', 'red', 'yellow'].includes(value)
    },
    loading: {
      type: Boolean,
      default: false
    },
    format: {
      type: String,
      default: 'number',
      validator: (value) => ['number', 'currency', 'percent'].includes(value)
    },
    additionalInfo: {
      type: Object,
      default: null
    }
  },
  
  setup(props) {
    // 값 포맷팅
    const formattedValue = computed(() => {
      if (typeof props.value === 'string') return props.value
      
      switch (props.format) {
        case 'currency':
          return new Intl.NumberFormat('ko-KR', {
            style: 'currency',
            currency: 'KRW'
          }).format(props.value)
          
        case 'percent':
          return `${props.value}%`
          
        default:
          return props.value.toLocaleString('ko-KR')
      }
    })
    
    // 변화량 색상 클래스
    const changeClass = computed(() => {
      if (!props.change) return ''
      
      if (props.change.includes('+') || props.change.includes('증가')) {
        return 'text-green-600'
      } else if (props.change.includes('-') || props.change.includes('감소')) {
        return 'text-red-600'
      }
      
      return 'text-gray-600'
    })
    
    return {
      formattedValue,
      changeClass
    }
  }
}
</script>

<style scoped>
.metric-card {
  position: relative;
  overflow: hidden;
}

.metric-card::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 4px;
  background: linear-gradient(90deg, var(--tw-gradient-from) 0%, var(--tw-gradient-to) 100%);
  opacity: 0;
  transition: opacity 0.3s ease;
}

.metric-card:hover::before {
  opacity: 1;
}

/* 색상별 그라디언트 설정 */
.border-blue-500::before {
  --tw-gradient-from: #3B82F6;
  --tw-gradient-to: #60A5FA;
}

.border-green-500::before {
  --tw-gradient-from: #10B981;
  --tw-gradient-to: #34D399;
}

.border-purple-500::before {
  --tw-gradient-from: #8B5CF6;
  --tw-gradient-to: #A78BFA;
}

.border-indigo-500::before {
  --tw-gradient-from: #6366F1;
  --tw-gradient-to: #818CF8;
}
</style>