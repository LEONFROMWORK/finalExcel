<template>
  <div class="password-strength">
    <div class="flex gap-1 mb-2">
      <div 
        v-for="i in 4" 
        :key="i"
        class="flex-1 h-1 rounded-full transition-all duration-300"
        :class="getBarClass(i)"
      ></div>
    </div>
    <p class="text-xs" :class="strength.color">
      {{ strength.label }}
    </p>
  </div>
</template>

<script>
import { computed } from 'vue'

export default {
  name: 'PasswordStrength',
  
  props: {
    password: {
      type: String,
      default: ''
    }
  },
  
  setup(props) {
    const strength = computed(() => {
      if (!props.password) {
        return { level: 0, label: '비밀번호를 입력하세요', color: 'text-gray-400' }
      }
      
      let score = 0
      
      // Length check
      if (props.password.length >= 8) score++
      if (props.password.length >= 12) score++
      
      // Character variety checks
      if (/[a-z]/.test(props.password)) score++
      if (/[A-Z]/.test(props.password)) score++
      if (/[0-9]/.test(props.password)) score++
      if (/[^a-zA-Z0-9]/.test(props.password)) score++
      
      // Common patterns to avoid
      if (!/(.)\1{2,}/.test(props.password)) score++ // No repeated characters
      if (!/^(12345|password|qwerty)/i.test(props.password)) score++ // No common passwords
      
      // Calculate strength level (0-4)
      let level = 0
      if (score >= 2) level = 1
      if (score >= 4) level = 2
      if (score >= 6) level = 3
      if (score >= 8) level = 4
      
      const strengthMap = {
        0: { label: '매우 약함', color: 'text-gray-400' },
        1: { label: '약함', color: 'text-red-600' },
        2: { label: '보통', color: 'text-yellow-600' },
        3: { label: '강함', color: 'text-blue-600' },
        4: { label: '매우 강함', color: 'text-green-600' }
      }
      
      return { level, ...strengthMap[level] }
    })
    
    const getBarClass = (index) => {
      const level = strength.value.level
      
      if (index <= level) {
        switch (level) {
          case 1: return 'bg-red-500'
          case 2: return 'bg-yellow-500'
          case 3: return 'bg-blue-500'
          case 4: return 'bg-green-500'
          default: return 'bg-gray-200'
        }
      }
      
      return 'bg-gray-200'
    }
    
    return {
      strength,
      getBarClass
    }
  }
}
</script>