import axios from 'axios'

const API_BASE = '/api/v1/knowledge_base'

class KnowledgeService {
  async getQAPairs(params = {}) {
    return axios.get(`${API_BASE}/qa_pairs`, { params })
  }

  async getQAPair(id) {
    return axios.get(`${API_BASE}/qa_pairs/${id}`)
  }

  async searchQAPairs(params) {
    return axios.post(`${API_BASE}/qa_pairs/search`, params)
  }

  async getStatistics() {
    return axios.get(`${API_BASE}/statistics`)
  }

  async importQAPairs(data, source) {
    return axios.post(`${API_BASE}/import`, {
      data,
      source
    })
  }
}

export default new KnowledgeService()