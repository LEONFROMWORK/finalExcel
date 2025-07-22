import axios from 'axios'

const API_BASE = '/api/v1/auth'

class AuthService {
  constructor() {
    this.setupInterceptors()
  }

  setupInterceptors() {
    // Request interceptor to add auth token
    axios.interceptors.request.use(
      config => {
        const token = localStorage.getItem('authToken')
        if (token) {
          config.headers.Authorization = `Bearer ${token}`
        }
        return config
      },
      error => Promise.reject(error)
    )

    // Response interceptor for 401 errors
    axios.interceptors.response.use(
      response => response,
      error => {
        if (error.response?.status === 401) {
          localStorage.removeItem('authToken')
          localStorage.removeItem('user')
          window.location.href = '/login'
        }
        return Promise.reject(error)
      }
    )
  }

  async login(credentials) {
    return axios.post(`${API_BASE}/sign_in`, {
      user: credentials
    })
  }

  async register(userData) {
    return axios.post(`${API_BASE}/sign_up`, {
      user: userData
    })
  }

  async logout() {
    return axios.delete(`${API_BASE}/sign_out`)
  }

  async getCurrentUser() {
    return axios.get(`${API_BASE}/current`)
  }
}

export default new AuthService()