<template>
  <Message v-if="showWarning" severity="warn" :closable="false" class="demo-warning">
    <div class="flex items-center gap-3">
      <i class="pi pi-exclamation-triangle text-2xl"></i>
      <div>
        <strong>데모 모드</strong>
        <p class="text-sm mt-1">
          일부 기능(RAG 검색, 데이터 수집, 대용량 파일 처리)은 현재 시뮬레이션됩니다.
          실제 프로덕션 버전에서는 모든 기능이 정상 작동합니다.
        </p>
      </div>
    </div>
  </Message>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import Message from 'primevue/message'

const showWarning = ref(false)

onMounted(() => {
  // Check if running in demo mode
  const isDemoMode = import.meta.env.VITE_DEMO_MODE === 'true' || 
                     window.location.hostname === 'localhost'
  showWarning.value = isDemoMode
})
</script>

<style scoped>
.demo-warning {
  margin: 1rem;
  background-color: #fff3cd;
  border-color: #ffeaa7;
}
</style>