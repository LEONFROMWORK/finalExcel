import { createRouter, createWebHistory } from 'vue-router'
import HomePage from '@/pages/HomePage.vue'
import LoginPage from '@/pages/LoginPage.vue'

const routes = [
  {
    path: '/',
    name: 'home',
    component: HomePage
  },
  {
    path: '/login',
    name: 'login',
    component: LoginPage
  },
  {
    path: '/excel-workspace',
    name: 'excel-workspace',
    component: () => import('@/pages/ExcelWorkspacePage.vue')
  },
  {
    path: '/knowledge-base',
    name: 'knowledge-base',
    component: () => import('@/pages/KnowledgeBasePage.vue')
  },
  {
    path: '/ai-chat',
    name: 'ai-chat',
    component: () => import('@/pages/AiChatPage.vue')
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

export default router