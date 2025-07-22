<template>
  <div class="home-page">
    <!-- Hero Section -->
    <section class="bg-gradient-to-br from-blue-600 to-blue-800 text-white">
      <div class="container mx-auto px-4 py-16 md:py-24">
        <div class="max-w-4xl mx-auto text-center">
          <h1 class="text-4xl md:text-6xl font-bold mb-6">
            Excel AI Knowledge Platform
          </h1>
          <p class="text-xl md:text-2xl mb-8 text-blue-100">
            Excel 문제 해결을 위한 AI 기반 통합 플랫폼
          </p>
          <div class="flex flex-col sm:flex-row gap-4 justify-center">
            <Button
              v-if="!isAuthenticated"
              label="시작하기"
              class="p-button-lg"
              style="background-color: white; color: #2563eb; border: none"
              @click="navigateTo('/login')"
            />
            <Button
              v-else
              label="Excel 작업공간 바로가기"
              icon="pi pi-desktop"
              class="p-button-lg"
              style="background-color: #f97316; color: white; border: none"
              @click="navigateTo('/excel-workspace')"
            />
            <Button
              label="더 알아보기"
              class="p-button-lg p-button-outlined"
              style="border-color: white; color: white"
              @click="scrollToFeatures"
            />
          </div>
        </div>
      </div>
    </section>

    <!-- Features Section -->
    <section id="features" class="py-16 bg-gray-50">
      <div class="container mx-auto px-4">
        <div class="text-center mb-12">
          <h2 class="text-3xl md:text-4xl font-bold text-gray-900 mb-4">
            주요 기능
          </h2>
          <p class="text-xl text-gray-600">
            Excel 작업을 더 쉽고 효율적으로 만들어드립니다
          </p>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
          <!-- New Excel Workspace -->
          <Card class="hover:shadow-xl transition-shadow border-2 border-orange-200">
            <template #header>
              <div class="p-6 pb-0">
                <div class="w-16 h-16 bg-orange-100 rounded-lg flex items-center justify-center">
                  <i class="pi pi-desktop text-4xl text-orange-600"></i>
                </div>
              </div>
            </template>
            <template #title>
              <span class="flex items-center gap-2">
                Excel 통합 작업공간
                <Tag severity="danger" value="NEW" />
              </span>
            </template>
            <template #content>
              <p class="text-gray-600 mb-4">
                모든 Excel 작업을 한 곳에서! 파일 분석, 수정, 생성, AI 상담까지 통합된 환경에서 작업하세요.
              </p>
              <Button
                label="작업공간 열기"
                icon="pi pi-arrow-right"
                iconPos="right"
                severity="warning"
                @click="navigateTo('/excel-workspace')"
              />
            </template>
          </Card>

          <!-- Excel Analysis -->
          <Card class="hover:shadow-xl transition-shadow">
            <template #header>
              <div class="p-6 pb-0">
                <div class="w-16 h-16 bg-green-100 rounded-lg flex items-center justify-center">
                  <i class="pi pi-file-excel text-4xl text-green-600"></i>
                </div>
              </div>
            </template>
            <template #title>
              Excel 파일 분석
            </template>
            <template #content>
              <p class="text-gray-600 mb-4">
                Excel 파일을 업로드하면 AI가 자동으로 구조를 분석하고 문제점을 파악합니다.
              </p>
              <Button
                label="파일 분석하기"
                icon="pi pi-arrow-right"
                iconPos="right"
                class="p-button-text p-button-success"
                @click="navigateTo('/excel-analysis')"
              />
            </template>
          </Card>

          <!-- AI Consultation -->
          <Card class="hover:shadow-xl transition-shadow">
            <template #header>
              <div class="p-6 pb-0">
                <div class="w-16 h-16 bg-blue-100 rounded-lg flex items-center justify-center">
                  <i class="pi pi-comments text-4xl text-blue-600"></i>
                </div>
              </div>
            </template>
            <template #title>
              AI 상담
            </template>
            <template #content>
              <p class="text-gray-600 mb-4">
                Excel 관련 질문을 AI와 대화하며 실시간으로 해결책을 찾아보세요.
              </p>
              <Button
                label="상담 시작하기"
                icon="pi pi-arrow-right"
                iconPos="right"
                class="p-button-text"
                @click="navigateTo('/consultation')"
              />
            </template>
          </Card>

          <!-- Knowledge Base -->
          <Card class="hover:shadow-xl transition-shadow">
            <template #header>
              <div class="p-6 pb-0">
                <div class="w-16 h-16 bg-purple-100 rounded-lg flex items-center justify-center">
                  <i class="pi pi-book text-4xl text-purple-600"></i>
                </div>
              </div>
            </template>
            <template #title>
              지식 베이스
            </template>
            <template #content>
              <p class="text-gray-600 mb-4">
                방대한 Excel 지식 데이터베이스에서 필요한 정보를 빠르게 검색하세요.
              </p>
              <Button
                label="지식 검색하기"
                icon="pi pi-arrow-right"
                iconPos="right"
                class="p-button-text p-button-help"
                @click="navigateTo('/knowledge-base')"
              />
            </template>
          </Card>
        </div>
      </div>
    </section>

    <!-- How It Works Section -->
    <section class="py-16 bg-white">
      <div class="container mx-auto px-4">
        <div class="text-center mb-12">
          <h2 class="text-3xl md:text-4xl font-bold text-gray-900 mb-4">
            간단한 사용 방법
          </h2>
          <p class="text-xl text-gray-600">
            3단계로 Excel 문제를 해결하세요
          </p>
        </div>

        <div class="max-w-4xl mx-auto">
          <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
            <!-- Step 1 -->
            <div class="text-center">
              <div class="w-20 h-20 bg-blue-600 text-white rounded-full flex items-center justify-center text-2xl font-bold mx-auto mb-4">
                1
              </div>
              <h3 class="text-xl font-semibold text-gray-900 mb-2">파일 업로드</h3>
              <p class="text-gray-600">
                문제가 있는 Excel 파일을 업로드하거나 질문을 입력하세요
              </p>
            </div>

            <!-- Step 2 -->
            <div class="text-center">
              <div class="w-20 h-20 bg-blue-600 text-white rounded-full flex items-center justify-center text-2xl font-bold mx-auto mb-4">
                2
              </div>
              <h3 class="text-xl font-semibold text-gray-900 mb-2">AI 분석</h3>
              <p class="text-gray-600">
                AI가 파일을 분석하고 관련 지식을 검색합니다
              </p>
            </div>

            <!-- Step 3 -->
            <div class="text-center">
              <div class="w-20 h-20 bg-blue-600 text-white rounded-full flex items-center justify-center text-2xl font-bold mx-auto mb-4">
                3
              </div>
              <h3 class="text-xl font-semibold text-gray-900 mb-2">해결책 제공</h3>
              <p class="text-gray-600">
                맞춤형 해결책과 단계별 가이드를 받아보세요
              </p>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- Statistics Section -->
    <section class="py-16 bg-gray-50">
      <div class="container mx-auto px-4">
        <div class="grid grid-cols-1 md:grid-cols-4 gap-8 text-center">
          <div>
            <div class="text-4xl font-bold text-blue-600 mb-2">10,000+</div>
            <div class="text-gray-600">지식 데이터</div>
          </div>
          <div>
            <div class="text-4xl font-bold text-green-600 mb-2">5,000+</div>
            <div class="text-gray-600">해결된 문제</div>
          </div>
          <div>
            <div class="text-4xl font-bold text-purple-600 mb-2">98%</div>
            <div class="text-gray-600">만족도</div>
          </div>
          <div>
            <div class="text-4xl font-bold text-orange-600 mb-2">24/7</div>
            <div class="text-gray-600">AI 상담 가능</div>
          </div>
        </div>
      </div>
    </section>

    <!-- CTA Section -->
    <section class="py-16 bg-blue-600 text-white">
      <div class="container mx-auto px-4 text-center">
        <h2 class="text-3xl md:text-4xl font-bold mb-4">
          지금 바로 시작하세요
        </h2>
        <p class="text-xl mb-8 text-blue-100">
          Excel 작업의 효율성을 높이고 시간을 절약하세요
        </p>
        <Button
          v-if="!isAuthenticated"
          label="무료로 시작하기"
          class="p-button-lg"
          style="background-color: white; color: #2563eb; border: none"
          @click="navigateTo('/register')"
        />
        <Button
          v-else
          label="대시보드로 이동"
          class="p-button-lg"
          style="background-color: white; color: #2563eb; border: none"
          @click="navigateTo('/dashboard')"
        />
      </div>
    </section>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '../domains/authentication/stores/authStore'
import Card from 'primevue/card'
import Button from 'primevue/button'
import Tag from 'primevue/tag'

const router = useRouter()
const authStore = useAuthStore()

const isAuthenticated = computed(() => authStore.isAuthenticated)

const navigateTo = (path) => {
  router.push(path)
}

const scrollToFeatures = () => {
  const element = document.getElementById('features')
  if (element) {
    element.scrollIntoView({ behavior: 'smooth' })
  }
}
</script>

<style scoped>
.home-page {
  min-height: 100vh;
}

/* Smooth scroll behavior */
html {
  scroll-behavior: smooth;
}

/* PrimeVue Card customization */
:deep(.p-card) {
  box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
  border-radius: 0.75rem;
}

:deep(.p-card-header) {
  background: transparent;
  border: none;
}

:deep(.p-card-body) {
  padding: 1.5rem;
}

:deep(.p-card-title) {
  font-size: 1.25rem;
  font-weight: 600;
  color: #111827;
  margin-bottom: 0.5rem;
}

/* Button customization */
:deep(.p-button-lg) {
  padding: 0.75rem 2rem;
  font-size: 1rem;
  font-weight: 600;
  border-radius: 0.5rem;
}

:deep(.p-button-text) {
  font-weight: 500;
}

:deep(.p-button-success.p-button-text:not(:disabled):hover) {
  background: rgba(34, 197, 94, 0.04);
  color: #16a34a;
}

:deep(.p-button-help.p-button-text:not(:disabled):hover) {
  background: rgba(147, 51, 234, 0.04);
  color: #7c3aed;
}
</style>