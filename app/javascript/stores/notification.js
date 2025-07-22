import { defineStore } from 'pinia'
import axios from '@/config/axios'

export const useNotificationStore = defineStore('notification', {
  state: () => ({
    notifications: [],
    unreadCount: 0,
    loading: false,
    error: null,
    preferences: {
      email_notifications: true,
      push_notifications: true,
      categories: []
    }
  }),
  
  getters: {
    unreadNotifications: (state) => {
      return state.notifications.filter(n => !n.read)
    },
    
    urgentNotifications: (state) => {
      return state.notifications.filter(n => n.priority === 'urgent' && !n.read)
    },
    
    hasUnread: (state) => {
      return state.unreadCount > 0
    }
  },
  
  actions: {
    // 알림 목록 조회
    async fetchNotifications(page = 1, unreadOnly = false) {
      this.loading = true
      this.error = null
      
      try {
        const response = await axios.get('/api/v1/notifications', {
          params: { page, unread_only: unreadOnly }
        })
        
        if (page === 1) {
          this.notifications = response.data.notifications
        } else {
          this.notifications.push(...response.data.notifications)
        }
        
        this.unreadCount = response.data.meta.unread_count
        
        return response.data
      } catch (error) {
        this.error = error.response?.data?.message || '알림을 불러오는데 실패했습니다'
        throw error
      } finally {
        this.loading = false
      }
    },
    
    // 읽지 않은 알림 수 조회
    async fetchUnreadCount() {
      try {
        const response = await axios.get('/api/v1/notifications/unread_count')
        this.unreadCount = response.data.unread_count
      } catch (error) {
        console.error('Failed to fetch unread count:', error)
      }
    },
    
    // 알림 읽음 처리
    async markAsRead(notificationId) {
      try {
        await axios.patch(`/api/v1/notifications/${notificationId}/read`)
        
        const notification = this.notifications.find(n => n.id === notificationId)
        if (notification) {
          notification.read = true
          notification.read_at = new Date().toISOString()
          this.unreadCount = Math.max(0, this.unreadCount - 1)
        }
      } catch (error) {
        throw error
      }
    },
    
    // 모든 알림 읽음 처리
    async markAllAsRead() {
      try {
        await axios.post('/api/v1/notifications/mark_all_read')
        
        this.notifications.forEach(notification => {
          notification.read = true
          notification.read_at = new Date().toISOString()
        })
        
        this.unreadCount = 0
      } catch (error) {
        throw error
      }
    },
    
    // 알림 삭제
    async deleteNotification(notificationId) {
      try {
        await axios.delete(`/api/v1/notifications/${notificationId}`)
        
        const index = this.notifications.findIndex(n => n.id === notificationId)
        if (index !== -1) {
          const notification = this.notifications[index]
          if (!notification.read) {
            this.unreadCount = Math.max(0, this.unreadCount - 1)
          }
          this.notifications.splice(index, 1)
        }
      } catch (error) {
        throw error
      }
    },
    
    // 새 알림 추가 (WebSocket에서 호출)
    addNotification(notification) {
      this.notifications.unshift(notification)
      if (!notification.read) {
        this.unreadCount += 1
      }
      
      // 알림음 재생 (옵션)
      this.playNotificationSound()
    },
    
    // 읽지 않은 알림 수 설정 (WebSocket에서 호출)
    setUnreadCount(count) {
      this.unreadCount = count
    },
    
    // 알림 설정 조회
    async fetchPreferences() {
      try {
        const response = await axios.get('/api/v1/notifications/preferences')
        this.preferences = response.data
      } catch (error) {
        throw error
      }
    },
    
    // 알림 설정 업데이트
    async updatePreferences(preferences) {
      try {
        await axios.patch('/api/v1/notifications/preferences', {
          preferences
        })
        
        this.preferences = { ...this.preferences, ...preferences }
      } catch (error) {
        throw error
      }
    },
    
    // 알림음 재생
    playNotificationSound() {
      if (this.preferences.sound_enabled !== false) {
        const audio = new Audio('/sounds/notification.mp3')
        audio.volume = 0.5
        audio.play().catch(() => {
          // 자동 재생이 차단된 경우 무시
        })
      }
    },
    
    // 초기화
    reset() {
      this.notifications = []
      this.unreadCount = 0
      this.loading = false
      this.error = null
    }
  }
})