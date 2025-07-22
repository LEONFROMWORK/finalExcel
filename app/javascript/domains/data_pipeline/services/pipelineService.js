import axios from 'axios'

const API_BASE = '/api/v1/data_pipeline'

class PipelineService {
  // Collection Tasks
  async getTasks(params = {}) {
    return axios.get(`${API_BASE}/collection_tasks`, { params })
  }

  async getTask(id) {
    return axios.get(`${API_BASE}/collection_tasks/${id}`)
  }

  async createTask(data) {
    return axios.post(`${API_BASE}/collection_tasks`, data)
  }

  async updateTask(id, data) {
    return axios.patch(`${API_BASE}/collection_tasks/${id}`, data)
  }

  async deleteTask(id) {
    return axios.delete(`${API_BASE}/collection_tasks/${id}`)
  }

  async startTask(id) {
    return axios.post(`${API_BASE}/collection_tasks/${id}/start`)
  }

  async stopTask(id) {
    return axios.post(`${API_BASE}/collection_tasks/${id}/stop`)
  }

  async getTaskRuns(id, params = {}) {
    return axios.get(`${API_BASE}/collection_tasks/${id}/runs`, { params })
  }

  async getTaskStatistics(id) {
    return axios.get(`${API_BASE}/collection_tasks/${id}/statistics`)
  }

  // Collection Runs
  async getRun(id) {
    return axios.get(`${API_BASE}/collection_runs/${id}`)
  }

  async cancelRun(id) {
    return axios.post(`${API_BASE}/collection_runs/${id}/cancel`)
  }

  // Global
  async getGlobalStatistics(params = {}) {
    return axios.get(`${API_BASE}/collection_tasks/global_statistics`, { params })
  }

  async getRecentActivity(params = {}) {
    return axios.get(`${API_BASE}/collection_tasks/recent_activity`, { params })
  }
}

export default new PipelineService()