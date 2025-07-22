<template>
  <div class="not-found-page min-h-screen bg-gray-50 flex items-center justify-center px-4">
    <div class="text-center">
      <div class="text-9xl font-bold text-gray-300 mb-4">404</div>
      <h1 class="text-3xl font-bold text-gray-900 mb-4">페이지를 찾을 수 없습니다</h1>
      <p class="text-lg text-gray-600 mb-8">
        요청하신 페이지가 존재하지 않거나 이동되었을 수 있습니다.
      </p>
      <div class="flex flex-col sm:flex-row gap-4 justify-center">
        <Button
          label="홈으로 돌아가기"
          icon="pi pi-home"
          @click="router.push('/')"
        />
        <Button
          label="이전 페이지로"
          icon="pi pi-arrow-left"
          severity="secondary"
          @click="goBack"
        />
      </div>
    </div>
  </div>
</template>

<script setup>
import { useRouter } from 'vue-router'
import Button from 'primevue/button'

const router = useRouter()

const goBack = () => {
  router.back()
}
</script>