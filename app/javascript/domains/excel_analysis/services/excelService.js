import axios from 'axios'

const API_BASE = '/api/v1/excel_analysis'

class ExcelService {
  async getFiles(params = {}) {
    return axios.get(`${API_BASE}/files`, { params })
  }

  async getFile(id) {
    return axios.get(`${API_BASE}/files/${id}`)
  }

  async uploadFile(formData, config = {}) {
    return axios.post(`${API_BASE}/files`, formData, {
      headers: {
        'Content-Type': 'multipart/form-data'
      },
      ...config
    })
  }

  async getAnalysis(fileId) {
    return axios.get(`${API_BASE}/files/${fileId}/analysis`)
  }

  async reanalyze(fileId) {
    return axios.post(`${API_BASE}/files/${fileId}/reanalyze`)
  }

  async downloadFile(fileId) {
    return axios.get(`${API_BASE}/files/${fileId}/download`, {
      responseType: 'blob'
    })
  }
}

export default new ExcelService()