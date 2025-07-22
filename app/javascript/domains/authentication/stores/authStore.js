import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import authService from '../services/authService'

export const useAuthStore = defineStore('auth', () => {
  // State
  const user = ref(null)
  const token = ref(null)
  const loading = ref(false)
  const error = ref(null)

  // Getters
  const isAuthenticated = computed(() => !!token.value)
  const isAdmin = computed(() => user.value?.role === 'admin')
  const displayName = computed(() => user.value?.name || user.value?.email?.split('@')[0])

  // Actions
  const login = async (credentials) => {
    loading.value = true
    error.value = null
    
    try {
      const response = await authService.login(credentials)
      
      if (response.data.token) {
        token.value = response.data.token
        user.value = response.data.user
        
        // Store in localStorage
        localStorage.setItem('authToken', token.value)
        localStorage.setItem('user', JSON.stringify(user.value))
        
        return { success: true }
      }
    } catch (err) {
      error.value = err.response?.data?.errors || ['Login failed']
      throw err
    } finally {
      loading.value = false
    }
  }

  const register = async (userData) => {
    loading.value = true
    error.value = null
    
    try {
      const response = await authService.register(userData)
      
      if (response.data.token) {
        token.value = response.data.token
        user.value = response.data.user
        
        localStorage.setItem('authToken', token.value)
        localStorage.setItem('user', JSON.stringify(user.value))
        
        return { success: true }
      }
    } catch (err) {
      error.value = err.response?.data?.errors || ['Registration failed']
      throw err
    } finally {
      loading.value = false
    }
  }

  const logout = async () => {
    try {
      await authService.logout()
    } catch (err) {
      console.error('Logout error:', err)
    } finally {
      token.value = null
      user.value = null
      localStorage.removeItem('authToken')
      localStorage.removeItem('user')
    }
  }

  const checkAuth = () => {
    const savedToken = localStorage.getItem('authToken')
    const savedUser = localStorage.getItem('user')
    
    if (savedToken && savedUser) {
      token.value = savedToken
      user.value = JSON.parse(savedUser)
    }
  }

  return {
    // State
    user,
    token,
    loading,
    error,
    
    // Getters
    isAuthenticated,
    isAdmin,
    displayName,
    
    // Actions
    login,
    register,
    logout,
    checkAuth
  }
})