import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '../domains/authentication/stores/authStore'

// Lazy load components
const HomePage = () => import('../pages/HomePage.vue')
const DashboardPage = () => import('../pages/DashboardPage.vue')
const LoginPage = () => import('../domains/authentication/components/LoginPage.vue')
const RegisterPage = () => import('../domains/authentication/components/RegisterPage.vue')
const ExcelAnalysisPage = () => import('../pages/ExcelAnalysisPage.vue')
const ExcelWorkspacePage = () => import('../pages/ExcelWorkspacePage.vue')
const FileUploadPage = () => import('../domains/excel_analysis/components/FileUpload.vue')
const FileDetailPage = () => import('../domains/excel_analysis/components/FileDetail.vue')
const AiConsultationPage = () => import('../pages/AiConsultationPage.vue')
const KnowledgeBasePage = () => import('../pages/KnowledgeBasePage.vue')
const DataPipelinePage = () => import('../pages/DataPipelinePage.vue')

const routes = [
  {
    path: '/',
    name: 'home',
    component: HomePage,
    meta: { requiresAuth: false }
  },
  {
    path: '/login',
    name: 'login',
    component: LoginPage,
    meta: { requiresAuth: false, guestOnly: true }
  },
  {
    path: '/register',
    name: 'register',
    component: RegisterPage,
    meta: { requiresAuth: false, guestOnly: true }
  },
  {
    path: '/dashboard',
    name: 'dashboard',
    component: DashboardPage,
    meta: { requiresAuth: true }
  },
  {
    path: '/excel-analysis',
    name: 'excel-analysis',
    component: ExcelAnalysisPage,
    meta: { requiresAuth: true }
  },
  {
    path: '/excel-workspace',
    name: 'excel-workspace',
    component: ExcelWorkspacePage,
    meta: { requiresAuth: true }
  },
  {
    path: '/excel-analysis/upload',
    name: 'excel-upload',
    component: FileUploadPage,
    meta: { requiresAuth: true }
  },
  {
    path: '/excel-analysis/:id',
    name: 'excel-file-detail',
    component: FileDetailPage,
    meta: { requiresAuth: true },
    props: true
  },
  {
    path: '/consultation',
    name: 'ai-consultation',
    component: AiConsultationPage,
    meta: { requiresAuth: true }
  },
  {
    path: '/knowledge-base',
    name: 'knowledge-base',
    component: KnowledgeBasePage,
    meta: { requiresAuth: false }
  },
  {
    path: '/admin/pipeline',
    name: 'admin-pipeline',
    component: DataPipelinePage,
    meta: { requiresAuth: true, requiresAdmin: true }
  },
  {
    path: '/admin/pipeline/tasks/:id',
    name: 'pipeline-task-detail',
    component: () => import('../domains/data_pipeline/components/TaskDetail.vue'),
    meta: { requiresAuth: true, requiresAdmin: true },
    props: true
  },
  {
    path: '/:pathMatch(.*)*',
    name: 'not-found',
    component: () => import('../pages/NotFoundPage.vue')
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes,
  scrollBehavior(to, from, savedPosition) {
    if (savedPosition) {
      return savedPosition
    } else {
      return { top: 0 }
    }
  }
})

// Navigation guards
router.beforeEach(async (to, from, next) => {
  const authStore = useAuthStore()
  
  // Check if user is authenticated
  const isAuthenticated = authStore.isAuthenticated
  const requiresAuth = to.matched.some(record => record.meta.requiresAuth)
  const guestOnly = to.matched.some(record => record.meta.guestOnly)
  const requiresAdmin = to.matched.some(record => record.meta.requiresAdmin)
  
  // Redirect to login if authentication is required
  if (requiresAuth && !isAuthenticated) {
    next({ name: 'login', query: { redirect: to.fullPath } })
    return
  }
  
  // Redirect to dashboard if already authenticated and trying to access guest-only pages
  if (guestOnly && isAuthenticated) {
    next({ name: 'dashboard' })
    return
  }
  
  // Check admin access
  if (requiresAdmin && authStore.user?.role !== 'admin') {
    next({ name: 'dashboard' })
    return
  }
  
  next()
})

export default router