import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import chatService from '../services/chatService'

export const useChatStore = defineStore('chat', () => {
  // State
  const sessions = ref([])
  const currentSession = ref(null)
  const messages = ref([])
  const loading = ref(false)
  const sendingMessage = ref(false)
  const error = ref(null)
  const statistics = ref({
    total_sessions: 0,
    total_messages: 0,
    popular_topics: []
  })
  const searchResults = ref([])

  // Getters
  const hasActiveSessions = computed(() => 
    sessions.value.some(s => s.status === 'active')
  )

  const sortedMessages = computed(() => 
    [...messages.value].sort((a, b) => new Date(a.created_at) - new Date(b.created_at))
  )

  const lastMessage = computed(() => 
    messages.value.length > 0 ? messages.value[messages.value.length - 1] : null
  )

  // Actions
  const fetchSessions = async (params = {}) => {
    loading.value = true
    error.value = null
    
    try {
      const response = await chatService.getSessions(params)
      sessions.value = response.data.sessions
      return response.data
    } catch (err) {
      error.value = err.response?.data?.errors || ['Failed to fetch sessions']
      throw err
    } finally {
      loading.value = false
    }
  }

  const fetchSession = async (id) => {
    loading.value = true
    error.value = null
    
    try {
      const response = await chatService.getSession(id)
      currentSession.value = response.data.session
      messages.value = response.data.messages
      return response.data
    } catch (err) {
      error.value = err.response?.data?.errors || ['Failed to fetch session']
      throw err
    } finally {
      loading.value = false
    }
  }

  const createSession = async (title = null) => {
    loading.value = true
    error.value = null
    
    try {
      const response = await chatService.createSession(title)
      const newSession = response.data.session
      sessions.value.unshift(newSession)
      currentSession.value = newSession
      messages.value = response.data.messages
      return response.data
    } catch (err) {
      error.value = err.response?.data?.errors || ['Failed to create session']
      throw err
    } finally {
      loading.value = false
    }
  }

  const sendMessage = async (content, image = null) => {
    if (!currentSession.value) {
      throw new Error('No active session')
    }

    sendingMessage.value = true
    error.value = null
    
    try {
      const response = await chatService.sendMessage(
        currentSession.value.id,
        content,
        image
      )
      
      // Add the user message to the messages array
      messages.value.push(response.data.message)
      
      // Update session info
      currentSession.value = response.data.session
      
      // The AI response will be added via websocket or polling
      return response.data
    } catch (err) {
      error.value = err.response?.data?.errors || ['Failed to send message']
      throw err
    } finally {
      sendingMessage.value = false
    }
  }

  const addMessage = (message) => {
    // Used to add messages received via websocket
    messages.value.push(message)
  }

  const updateSession = async (id, data) => {
    try {
      const response = await chatService.updateSession(id, data)
      const updatedSession = response.data.session
      
      // Update in sessions list
      const index = sessions.value.findIndex(s => s.id === id)
      if (index !== -1) {
        sessions.value[index] = updatedSession
      }
      
      // Update current session if it's the same
      if (currentSession.value?.id === id) {
        currentSession.value = updatedSession
      }
      
      return response.data
    } catch (err) {
      error.value = err.response?.data?.errors || ['Failed to update session']
      throw err
    }
  }

  const deleteSession = async (id) => {
    try {
      await chatService.deleteSession(id)
      
      // Remove from sessions list
      sessions.value = sessions.value.filter(s => s.id !== id)
      
      // Clear current session if it was deleted
      if (currentSession.value?.id === id) {
        currentSession.value = null
        messages.value = []
      }
    } catch (err) {
      error.value = err.response?.data?.errors || ['Failed to delete session']
      throw err
    }
  }

  const searchMessages = async (query, params = {}) => {
    loading.value = true
    error.value = null
    
    try {
      const response = await chatService.searchMessages(query, params)
      searchResults.value = response.data.results
      return response.data
    } catch (err) {
      error.value = err.response?.data?.errors || ['Search failed']
      throw err
    } finally {
      loading.value = false
    }
  }

  const clearSearch = () => {
    searchResults.value = []
  }

  const fetchStatistics = async () => {
    try {
      const response = await chatService.getStatistics()
      statistics.value = response.data
      return response.data
    } catch (err) {
      console.error('Failed to fetch statistics:', err)
    }
  }

  const exportSession = async (id, format = 'json') => {
    try {
      const response = await chatService.exportSession(id, format)
      
      if (format === 'markdown') {
        // Download the markdown file
        const url = window.URL.createObjectURL(new Blob([response.data]))
        const link = document.createElement('a')
        link.href = url
        link.setAttribute('download', `chat_session_${id}.md`)
        document.body.appendChild(link)
        link.click()
        link.remove()
        window.URL.revokeObjectURL(url)
      }
      
      return response.data
    } catch (err) {
      error.value = err.response?.data?.errors || ['Export failed']
      throw err
    }
  }

  const clearCurrentSession = () => {
    currentSession.value = null
    messages.value = []
  }

  return {
    // State
    sessions,
    currentSession,
    messages,
    loading,
    sendingMessage,
    error,
    statistics,
    searchResults,
    
    // Getters
    hasActiveSessions,
    sortedMessages,
    lastMessage,
    
    // Actions
    fetchSessions,
    fetchSession,
    createSession,
    sendMessage,
    addMessage,
    updateSession,
    deleteSession,
    searchMessages,
    clearSearch,
    fetchStatistics,
    exportSession,
    clearCurrentSession
  }
})