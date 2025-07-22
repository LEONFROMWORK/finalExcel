import { defineStore } from 'pinia'
import axios from 'axios'

export const useUserStore = defineStore('user', {
  state: () => ({
    user: null,
    credits: 100, // Default credits
    isLoading: false,
    error: null
  }),

  getters: {
    isAuthenticated: (state) => !!state.user,
    currentCredits: (state) => state.user?.credits || state.credits,
    hasCredits: (state) => (state.user?.credits || state.credits) > 0
  },

  actions: {
    async fetchUser() {
      this.isLoading = true
      this.error = null

      try {
        const response = await axios.get('/api/v1/users/current')
        this.user = response.data
        this.credits = response.data.credits || 100
      } catch (error) {
        this.error = error.response?.data?.error || 'Failed to fetch user'
        console.error('Failed to fetch user:', error)
      } finally {
        this.isLoading = false
      }
    },

    async updateCredits(amount) {
      try {
        const response = await axios.patch('/api/v1/users/credits', {
          amount: amount
        })
        
        if (this.user) {
          this.user.credits = response.data.credits
        }
        this.credits = response.data.credits
        
        return { success: true, credits: response.data.credits }
      } catch (error) {
        this.error = error.response?.data?.error || 'Failed to update credits'
        return { success: false, error: this.error }
      }
    },

    async purchaseCredits(plan) {
      try {
        const response = await axios.post('/api/v1/users/purchase-credits', {
          plan: plan
        })
        
        if (this.user) {
          this.user.credits = response.data.credits
        }
        this.credits = response.data.credits
        
        return { success: true, credits: response.data.credits }
      } catch (error) {
        this.error = error.response?.data?.error || 'Failed to purchase credits'
        return { success: false, error: this.error }
      }
    },

    useCredits(amount) {
      // Optimistic update
      if (this.user) {
        this.user.credits = Math.max(0, (this.user.credits || 0) - amount)
      }
      this.credits = Math.max(0, this.credits - amount)
      
      // Sync with backend
      this.updateCredits(-amount)
    },

    addCredits(amount) {
      // Optimistic update
      if (this.user) {
        this.user.credits = (this.user.credits || 0) + amount
      }
      this.credits = this.credits + amount
      
      // Sync with backend
      this.updateCredits(amount)
    },

    setUser(userData) {
      this.user = userData
      this.credits = userData?.credits || 100
    },

    clearUser() {
      this.user = null
      this.credits = 100
      this.error = null
    }
  }
})