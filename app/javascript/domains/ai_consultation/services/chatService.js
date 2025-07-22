import axios from 'axios'

const API_BASE = '/api/v1/ai_consultation'

class ChatService {
  // Session management
  async getSessions(params = {}) {
    return axios.get(`${API_BASE}/chat_sessions`, { params })
  }

  async getSession(id) {
    return axios.get(`${API_BASE}/chat_sessions/${id}`)
  }

  async createSession(title = null) {
    return axios.post(`${API_BASE}/chat_sessions`, { title })
  }

  async updateSession(id, data) {
    return axios.patch(`${API_BASE}/chat_sessions/${id}`, data)
  }

  async deleteSession(id) {
    return axios.delete(`${API_BASE}/chat_sessions/${id}`)
  }

  // Message management
  async sendMessage(sessionId, content, image = null) {
    const formData = new FormData()
    if (content) formData.append('content', content)
    if (image) formData.append('image', image)
    
    return axios.post(`${API_BASE}/chat_sessions/${sessionId}/messages`, formData, {
      headers: {
        'Content-Type': 'multipart/form-data'
      }
    })
  }

  async getMessages(sessionId, params = {}) {
    return axios.get(`${API_BASE}/chat_sessions/${sessionId}/messages`, { params })
  }

  // Export and search
  async exportSession(sessionId, format = 'json') {
    return axios.get(`${API_BASE}/chat_sessions/${sessionId}/export`, {
      params: { format },
      responseType: format === 'markdown' ? 'blob' : 'json'
    })
  }

  async searchMessages(query, params = {}) {
    return axios.get(`${API_BASE}/chat_sessions/search`, {
      params: { query, ...params }
    })
  }

  async getStatistics() {
    return axios.get(`${API_BASE}/chat_sessions/statistics`)
  }
}

export default new ChatService()