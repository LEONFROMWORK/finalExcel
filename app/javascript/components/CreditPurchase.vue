<template>
  <div class="credit-purchase">
    <div class="mb-4">
      <p class="text-gray-600 mb-4">크레딧을 충전하여 더 많은 작업을 수행하세요.</p>
      
      <div class="grid grid-cols-1 gap-3">
        <Card 
          v-for="plan in creditPlans" 
          :key="plan.id"
          class="cursor-pointer hover:border-orange-500 transition-all"
          :class="{ 'border-orange-500 bg-orange-50': selectedPlan?.id === plan.id }"
          @click="selectedPlan = plan"
        >
          <template #content>
            <div class="flex items-center justify-between">
              <div>
                <h4 class="font-semibold text-lg">{{ plan.credits.toLocaleString() }} 크레딧</h4>
                <p class="text-sm text-gray-500">{{ plan.description }}</p>
              </div>
              <div class="text-right">
                <div class="text-2xl font-bold text-orange-500">₩{{ plan.price.toLocaleString() }}</div>
                <div v-if="plan.bonus" class="text-sm text-green-600">
                  +{{ plan.bonus }}% 보너스
                </div>
              </div>
            </div>
          </template>
        </Card>
      </div>
    </div>

    <Divider />

    <div class="space-y-4">
      <div class="flex items-center justify-between">
        <span class="font-semibold">선택한 플랜:</span>
        <span v-if="selectedPlan" class="text-lg">
          {{ selectedPlan.credits.toLocaleString() }} 크레딧
        </span>
        <span v-else class="text-gray-500">플랜을 선택해주세요</span>
      </div>

      <div class="flex items-center justify-between">
        <span class="font-semibold">결제 금액:</span>
        <span v-if="selectedPlan" class="text-2xl font-bold text-orange-500">
          ₩{{ selectedPlan.price.toLocaleString() }}
        </span>
        <span v-else class="text-gray-500">-</span>
      </div>

      <Button 
        label="결제하기" 
        icon="pi pi-credit-card"
        class="w-full"
        :disabled="!selectedPlan"
        @click="processPurchase"
      />
    </div>

    <div class="mt-4 p-3 bg-blue-50 rounded-lg">
      <div class="flex items-start gap-2">
        <i class="pi pi-info-circle text-blue-500"></i>
        <div class="text-sm">
          <p class="font-semibold mb-1">크레딧 사용 안내</p>
          <ul class="space-y-1 text-gray-600">
            <li>• 파일 분석: 10 크레딧</li>
            <li>• AI 메시지: 5 크레딧/메시지</li>
            <li>• 파일 수정: 20 크레딧</li>
            <li>• 새 파일 생성: 15 크레딧</li>
          </ul>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import Card from 'primevue/card'
import Button from 'primevue/button'
import Divider from 'primevue/divider'
import { useToast } from 'primevue/usetoast'

const emit = defineEmits(['purchased'])
const toast = useToast()

const selectedPlan = ref(null)

const creditPlans = [
  {
    id: 1,
    credits: 100,
    price: 10000,
    description: '가벼운 사용자를 위한 기본 플랜'
  },
  {
    id: 2,
    credits: 500,
    price: 45000,
    description: '일반 사용자를 위한 표준 플랜',
    bonus: 10
  },
  {
    id: 3,
    credits: 1000,
    price: 80000,
    description: '전문가를 위한 프로 플랜',
    bonus: 20
  },
  {
    id: 4,
    credits: 5000,
    price: 350000,
    description: '기업을 위한 비즈니스 플랜',
    bonus: 30
  }
]

const processPurchase = () => {
  if (!selectedPlan.value) return
  
  // Simulate payment processing
  toast.add({ 
    severity: 'info', 
    summary: '결제 처리 중', 
    detail: '결제를 처리하고 있습니다...',
    life: 2000
  })
  
  setTimeout(() => {
    const totalCredits = selectedPlan.value.credits * (1 + (selectedPlan.value.bonus || 0) / 100)
    emit('purchased', Math.floor(totalCredits))
    
    toast.add({ 
      severity: 'success', 
      summary: '결제 완료', 
      detail: `${Math.floor(totalCredits).toLocaleString()} 크레딧이 충전되었습니다!`
    })
  }, 2000)
}
</script>

<style scoped>
:deep(.p-card:hover) {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
}
</style>