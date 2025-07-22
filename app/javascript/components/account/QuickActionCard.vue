<template>
  <div 
    @click="handleClick"
    class="quick-action-card bg-white rounded-2xl shadow-sm hover:shadow-xl p-6 cursor-pointer transition-all duration-300 group"
    :class="cardClasses"
  >
    <!-- Icon Container -->
    <div class="mb-4">
      <div :class="iconContainerClasses" class="w-14 h-14 rounded-xl flex items-center justify-center transition-all duration-300 group-hover:scale-110">
        <component :is="icon" class="w-7 h-7" :class="iconClasses" />
      </div>
    </div>
    
    <!-- Content -->
    <h4 class="text-lg font-semibold text-gray-900 mb-2 group-hover:text-gray-800">
      {{ title }}
    </h4>
    <p class="text-sm text-gray-600 leading-relaxed">
      {{ description }}
    </p>
    
    <!-- Arrow Indicator -->
    <div class="mt-4 flex items-center text-sm font-medium transition-all duration-300 opacity-0 group-hover:opacity-100 transform translate-x-0 group-hover:translate-x-2" :class="arrowClasses">
      <span>시작하기</span>
      <svg class="ml-2 w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
      </svg>
    </div>
    
    <!-- Decorative Element -->
    <div class="absolute top-0 right-0 -mt-4 -mr-4 w-24 h-24 opacity-5 transform rotate-12 transition-transform duration-500 group-hover:rotate-45">
      <component :is="icon" class="w-full h-full" :class="`text-${color}-600`" />
    </div>
  </div>
</template>

<script>
import { computed } from 'vue'

export default {
  name: 'QuickActionCard',
  
  props: {
    icon: {
      type: String,
      required: true
    },
    title: {
      type: String,
      required: true
    },
    description: {
      type: String,
      required: true
    },
    color: {
      type: String,
      default: 'blue',
      validator: (value) => ['blue', 'green', 'purple', 'orange', 'red', 'indigo'].includes(value)
    }
  },
  
  emits: ['click'],
  
  setup(props, { emit }) {
    const colorMap = {
      blue: {
        container: 'bg-blue-100 group-hover:bg-blue-200',
        icon: 'text-blue-600',
        arrow: 'text-blue-600',
        card: 'hover:border-blue-200 border-transparent'
      },
      green: {
        container: 'bg-green-100 group-hover:bg-green-200',
        icon: 'text-green-600',
        arrow: 'text-green-600',
        card: 'hover:border-green-200 border-transparent'
      },
      purple: {
        container: 'bg-purple-100 group-hover:bg-purple-200',
        icon: 'text-purple-600',
        arrow: 'text-purple-600',
        card: 'hover:border-purple-200 border-transparent'
      },
      orange: {
        container: 'bg-orange-100 group-hover:bg-orange-200',
        icon: 'text-orange-600',
        arrow: 'text-orange-600',
        card: 'hover:border-orange-200 border-transparent'
      },
      red: {
        container: 'bg-red-100 group-hover:bg-red-200',
        icon: 'text-red-600',
        arrow: 'text-red-600',
        card: 'hover:border-red-200 border-transparent'
      },
      indigo: {
        container: 'bg-indigo-100 group-hover:bg-indigo-200',
        icon: 'text-indigo-600',
        arrow: 'text-indigo-600',
        card: 'hover:border-indigo-200 border-transparent'
      }
    }
    
    const iconContainerClasses = computed(() => colorMap[props.color].container)
    const iconClasses = computed(() => colorMap[props.color].icon)
    const arrowClasses = computed(() => colorMap[props.color].arrow)
    const cardClasses = computed(() => `border-2 ${colorMap[props.color].card} relative overflow-hidden`)
    
    const handleClick = () => {
      emit('click')
    }
    
    return {
      iconContainerClasses,
      iconClasses,
      arrowClasses,
      cardClasses,
      handleClick
    }
  }
}
</script>

<style scoped>
.quick-action-card {
  transform: translateY(0);
}

.quick-action-card:hover {
  transform: translateY(-4px);
}

.quick-action-card:active {
  transform: translateY(-2px);
}
</style>