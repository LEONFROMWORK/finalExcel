<template>
  <div class="main-layout min-h-screen bg-gray-50">
    <!-- Navigation -->
    <nav class="bg-white shadow-lg">
      <div class="container mx-auto px-4">
        <!-- Desktop Navigation -->
        <Menubar :model="menuItems" class="border-none hidden md:flex">
          <template #start>
            <router-link to="/" class="flex items-center space-x-3 mr-8">
              <div class="w-10 h-10 bg-blue-600 rounded-lg flex items-center justify-center">
                <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 17v-2m3 2v-4m3 4v-6m2 10H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
                </svg>
              </div>
              <span class="text-xl font-bold text-gray-900">Excel AI Platform</span>
            </router-link>
          </template>
          <template #end>
            <div class="flex items-center space-x-4">
              <!-- 알림 센터 -->
              <NotificationCenter v-if="isAuthenticated" />
              
              <div v-if="isAuthenticated" class="flex items-center space-x-2">
                <Avatar 
                  :label="userInitial" 
                  class="cursor-pointer"
                  style="background-color: #2563eb; color: white"
                  shape="circle"
                  @click="toggle"
                  aria-haspopup="true"
                  aria-controls="overlay_menu"
                />
                <span class="hidden md:block text-gray-700">{{ userName }}</span>
                <TieredMenu ref="menu" id="overlay_menu" :model="userMenuItems" popup />
              </div>
              
              <div v-else class="flex items-center space-x-3">
                <Button 
                  label="로그인" 
                  class="p-button-text p-button-plain"
                  @click="navigateTo('/login')"
                />
                <Button 
                  label="회원가입" 
                  class="p-button-primary"
                  @click="navigateTo('/register')"
                />
              </div>
            </div>
          </template>
        </Menubar>

        <!-- Mobile Navigation -->
        <div class="md:hidden flex justify-between items-center h-16">
          <router-link to="/" class="flex items-center space-x-3">
            <div class="w-10 h-10 bg-blue-600 rounded-lg flex items-center justify-center">
              <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 17v-2m3 2v-4m3 4v-6m2 10H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
              </svg>
            </div>
            <span class="text-xl font-bold text-gray-900">Excel AI Platform</span>
          </router-link>
          
          <div class="flex items-center space-x-2">
            <Avatar 
              v-if="isAuthenticated"
              :label="userInitial" 
              class="cursor-pointer"
              style="background-color: #2563eb; color: white"
              shape="circle"
              size="small"
              @click="toggle"
              aria-haspopup="true"
              aria-controls="overlay_menu_mobile"
            />
            <TieredMenu ref="menuMobile" id="overlay_menu_mobile" :model="userMenuItems" popup />
            
            <Button
              icon="pi pi-bars"
              class="p-button-text p-button-plain"
              @click="showMobileMenu = !showMobileMenu"
            />
          </div>
        </div>
      </div>
    </nav>

    <!-- Mobile Menu Sidebar -->
    <Sidebar v-model:visible="showMobileMenu" position="right">
      <template #header>
        <h3 class="text-lg font-semibold">메뉴</h3>
      </template>
      <div class="space-y-2">
        <Button
          v-for="item in mobileMenuItems"
          :key="item.label"
          :label="item.label"
          class="p-button-text p-button-plain w-full justify-start"
          :class="{ 'bg-blue-50 text-blue-600': isActiveRoute(item) }"
          @click="handleMobileMenuClick(item)"
        />
      </div>
    </Sidebar>

    <!-- Main Content -->
    <main>
      <router-view />
    </main>

    <!-- Footer -->
    <footer class="bg-gray-800 text-white py-8 mt-auto">
      <div class="container mx-auto px-4">
        <div class="grid grid-cols-1 md:grid-cols-4 gap-8">
          <div>
            <h3 class="text-lg font-semibold mb-4">Excel AI Platform</h3>
            <p class="text-gray-400">
              Excel 작업을 더 쉽고 효율적으로 만들어드립니다.
            </p>
          </div>
          
          <div>
            <h4 class="font-semibold mb-4">주요 기능</h4>
            <ul class="space-y-2 text-gray-400">
              <li><router-link to="/excel-analysis" class="hover:text-white">Excel 분석</router-link></li>
              <li><router-link to="/consultation" class="hover:text-white">AI 상담</router-link></li>
              <li><router-link to="/knowledge-base" class="hover:text-white">지식 베이스</router-link></li>
            </ul>
          </div>
          
          <div>
            <h4 class="font-semibold mb-4">도움말</h4>
            <ul class="space-y-2 text-gray-400">
              <li><a href="#" class="hover:text-white">사용 가이드</a></li>
              <li><a href="#" class="hover:text-white">FAQ</a></li>
              <li><a href="#" class="hover:text-white">문의하기</a></li>
            </ul>
          </div>
          
          <div>
            <h4 class="font-semibold mb-4">법적 고지</h4>
            <ul class="space-y-2 text-gray-400">
              <li><a href="#" class="hover:text-white">이용약관</a></li>
              <li><a href="#" class="hover:text-white">개인정보처리방침</a></li>
            </ul>
          </div>
        </div>
        
        <div class="border-t border-gray-700 mt-8 pt-8 text-center text-gray-400">
          <p>&copy; 2024 Excel AI Platform. All rights reserved.</p>
        </div>
      </div>
    </footer>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '../domains/authentication/stores/authStore'
import Menubar from 'primevue/menubar'
import Avatar from 'primevue/avatar'
import TieredMenu from 'primevue/tieredmenu'
import Button from 'primevue/button'
import Sidebar from 'primevue/sidebar'
import NotificationCenter from './NotificationCenter.vue'

const router = useRouter()
const route = useRoute()
const authStore = useAuthStore()

// Refs
const menu = ref()
const menuMobile = ref()
const showMobileMenu = ref(false)

// Computed
const isAuthenticated = computed(() => authStore.isAuthenticated)
const isAdmin = computed(() => authStore.user?.role === 'admin')
const userName = computed(() => authStore.user?.name || '사용자')
const userInitial = computed(() => {
  const name = authStore.user?.name || '?'
  return name.charAt(0).toUpperCase()
})

// Menu items for desktop navigation
const menuItems = computed(() => {
  const items = []
  
  if (isAuthenticated.value) {
    items.push({
      label: '대시보드',
      icon: 'pi pi-home',
      command: () => navigateTo('/dashboard')
    })
    items.push({
      label: 'Excel 작업공간',
      icon: 'pi pi-desktop',
      command: () => navigateTo('/excel-workspace')
    })
    items.push({
      label: 'Excel 분석',
      icon: 'pi pi-file-excel',
      command: () => navigateTo('/excel-analysis')
    })
    items.push({
      label: 'AI 상담',
      icon: 'pi pi-comments',
      command: () => navigateTo('/consultation')
    })
  }
  
  items.push({
    label: '지식 베이스',
    icon: 'pi pi-book',
    command: () => navigateTo('/knowledge-base')
  })
  
  if (isAdmin.value) {
    items.push({
      label: '관리자',
      icon: 'pi pi-cog',
      command: () => navigateTo('/admin/pipeline')
    })
  }
  
  return items
})

// User menu items
const userMenuItems = computed(() => [
  {
    label: '프로필',
    icon: 'pi pi-user',
    command: () => navigateTo('/profile')
  },
  {
    label: '설정',
    icon: 'pi pi-cog',
    command: () => navigateTo('/settings')
  },
  {
    separator: true
  },
  {
    label: '로그아웃',
    icon: 'pi pi-sign-out',
    command: handleLogout
  }
])

// Mobile menu items
const mobileMenuItems = computed(() => {
  const items = []
  
  if (isAuthenticated.value) {
    items.push({ label: '대시보드', route: '/dashboard', icon: 'pi pi-home' })
    items.push({ label: 'Excel 작업공간', route: '/excel-workspace', icon: 'pi pi-desktop' })
    items.push({ label: 'Excel 분석', route: '/excel-analysis', icon: 'pi pi-file-excel' })
    items.push({ label: 'AI 상담', route: '/consultation', icon: 'pi pi-comments' })
  }
  
  items.push({ label: '지식 베이스', route: '/knowledge-base', icon: 'pi pi-book' })
  
  if (isAdmin.value) {
    items.push({ label: '관리자', route: '/admin/pipeline', icon: 'pi pi-cog' })
  }
  
  if (!isAuthenticated.value) {
    items.push({ label: '로그인', route: '/login', icon: 'pi pi-sign-in' })
    items.push({ label: '회원가입', route: '/register', icon: 'pi pi-user-plus' })
  }
  
  return items
})

// Methods
const handleLogout = async () => {
  await authStore.logout()
  router.push('/')
}

const navigateTo = (path) => {
  router.push(path)
}

const toggle = (event) => {
  if (menu.value) {
    menu.value.toggle(event)
  }
  if (menuMobile.value) {
    menuMobile.value.toggle(event)
  }
}

const handleMobileMenuClick = (item) => {
  showMobileMenu.value = false
  navigateTo(item.route)
}

const isActiveRoute = (item) => {
  return route.path === item.route || route.path.startsWith(item.route + '/')
}
</script>

<style scoped>
.main-layout {
  display: flex;
  flex-direction: column;
  min-height: 100vh;
}

main {
  flex: 1;
}

/* PrimeVue Menubar customization */
:deep(.p-menubar) {
  background: transparent;
  padding: 0;
  height: 4rem;
}

:deep(.p-menubar .p-menuitem-link) {
  padding: 0.75rem 1rem;
}

:deep(.p-menubar .p-menuitem.p-highlight > .p-menuitem-content > .p-menuitem-link) {
  background: transparent;
  color: #2563eb;
}

:deep(.p-button-text:not(:disabled):hover) {
  background: rgba(0, 0, 0, 0.04);
}

:deep(.p-avatar) {
  width: 2rem;
  height: 2rem;
}

:deep(.p-sidebar-header) {
  padding: 1rem;
}

:deep(.p-sidebar-content) {
  padding: 1rem;
}
</style>