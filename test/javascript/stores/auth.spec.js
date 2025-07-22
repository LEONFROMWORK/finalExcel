// test/javascript/stores/auth.spec.js
import { setActivePinia, createPinia } from 'pinia'
import { describe, it, expect, beforeEach, vi } from 'vitest'
import { useAuthStore } from '@/stores/auth'
import axios from 'axios'

vi.mock('axios')

describe('Auth Store', () => {
  let store
  
  beforeEach(() => {
    setActivePinia(createPinia())
    store = useAuthStore()
  })
  
  describe('state', () => {
    it('has initial state', () => {
      expect(store.currentUser).toBe(null)
      expect(store.isAuthenticated).toBe(false)
      expect(store.isLoading).toBe(false)
      expect(store.error).toBe(null)
    })
  })
  
  describe('getters', () => {
    it('isAdmin returns true for admin users', () => {
      store.currentUser = { id: 1, email: 'admin@example.com', role: 'admin' }
      expect(store.isAdmin).toBe(true)
    })
    
    it('isAdmin returns false for regular users', () => {
      store.currentUser = { id: 1, email: 'user@example.com', role: 'user' }
      expect(store.isAdmin).toBe(false)
    })
    
    it('isAdmin returns false when not authenticated', () => {
      store.currentUser = null
      expect(store.isAdmin).toBe(false)
    })
  })
  
  describe('actions', () => {
    describe('login', () => {
      it('logs in user successfully', async () => {
        const mockResponse = {
          data: {
            user: { id: 1, email: 'test@example.com', role: 'user' },
            token: 'mock-jwt-token',
          },
        }
        
        axios.create().post.mockResolvedValue(mockResponse)
        
        const result = await store.login({
          email: 'test@example.com',
          password: 'password123',
        })
        
        expect(result).toBe(true)
        expect(store.currentUser).toEqual(mockResponse.data.user)
        expect(store.isAuthenticated).toBe(true)
        expect(localStorage.getItem('auth_token')).toBe('mock-jwt-token')
      })
      
      it('handles login failure', async () => {
        const mockError = {
          response: {
            data: { error: 'Invalid credentials' },
          },
        }
        
        axios.create().post.mockRejectedValue(mockError)
        
        const result = await store.login({
          email: 'test@example.com',
          password: 'wrong-password',
        })
        
        expect(result).toBe(false)
        expect(store.currentUser).toBe(null)
        expect(store.isAuthenticated).toBe(false)
        expect(store.error).toBe('Invalid credentials')
      })
    })
    
    describe('logout', () => {
      it('clears user data', async () => {
        store.currentUser = { id: 1, email: 'test@example.com' }
        store.isAuthenticated = true
        localStorage.setItem('auth_token', 'mock-token')
        
        axios.create().delete.mockResolvedValue({ data: {} })
        
        await store.logout()
        
        expect(store.currentUser).toBe(null)
        expect(store.isAuthenticated).toBe(false)
        expect(localStorage.getItem('auth_token')).toBe(null)
      })
    })
    
    describe('fetchCurrentUser', () => {
      it('fetches user data successfully', async () => {
        const mockUser = { id: 1, email: 'test@example.com', role: 'user' }
        
        axios.create().get.mockResolvedValue({ data: { user: mockUser } })
        localStorage.setItem('auth_token', 'mock-token')
        
        await store.fetchCurrentUser()
        
        expect(store.currentUser).toEqual(mockUser)
        expect(store.isAuthenticated).toBe(true)
      })
      
      it('handles fetch failure', async () => {
        axios.create().get.mockRejectedValue(new Error('Unauthorized'))
        localStorage.setItem('auth_token', 'invalid-token')
        
        await store.fetchCurrentUser()
        
        expect(store.currentUser).toBe(null)
        expect(store.isAuthenticated).toBe(false)
        expect(localStorage.getItem('auth_token')).toBe(null)
      })
    })
    
    describe('register', () => {
      it('registers user successfully', async () => {
        const mockResponse = {
          data: {
            user: { id: 1, email: 'new@example.com', role: 'user' },
            token: 'mock-jwt-token',
          },
        }
        
        axios.create().post.mockResolvedValue(mockResponse)
        
        const result = await store.register({
          email: 'new@example.com',
          password: 'password123',
          name: 'New User',
        })
        
        expect(result).toBe(true)
        expect(store.currentUser).toEqual(mockResponse.data.user)
        expect(store.isAuthenticated).toBe(true)
      })
      
      it('handles registration errors', async () => {
        const mockError = {
          response: {
            data: {
              errors: {
                email: ['has already been taken'],
              },
            },
          },
        }
        
        axios.create().post.mockRejectedValue(mockError)
        
        const result = await store.register({
          email: 'existing@example.com',
          password: 'password123',
          name: 'User',
        })
        
        expect(result).toBe(false)
        expect(store.error).toEqual({ email: ['has already been taken'] })
      })
    })
    
    describe('updateProfile', () => {
      it('updates user profile', async () => {
        store.currentUser = { id: 1, email: 'test@example.com', name: 'Test' }
        
        const updatedUser = { id: 1, email: 'test@example.com', name: 'Updated Name' }
        axios.create().patch.mockResolvedValue({ data: { user: updatedUser } })
        
        await store.updateProfile({ name: 'Updated Name' })
        
        expect(store.currentUser).toEqual(updatedUser)
      })
    })
  })
  
  describe('persistence', () => {
    it('initializes from localStorage', () => {
      const mockUser = { id: 1, email: 'test@example.com', role: 'user' }
      localStorage.setItem('auth_token', 'mock-token')
      localStorage.setItem('current_user', JSON.stringify(mockUser))
      
      setActivePinia(createPinia())
      store = useAuthStore()
      
      expect(store.checkAuthStatus()).toBe(true)
      expect(store.currentUser).toEqual(mockUser)
      expect(store.isAuthenticated).toBe(true)
    })
  })
})