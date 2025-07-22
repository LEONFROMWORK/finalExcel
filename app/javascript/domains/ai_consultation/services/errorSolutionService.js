import axios from 'axios'

const API_BASE = '/api/v1/ai_consultation/error_solutions'

class ErrorSolutionService {
  // 정적 분석 실행
  async getStaticAnalysis(excelFileId) {
    return axios.get(`${API_BASE}/static_analysis`, {
      params: { excel_file_id: excelFileId }
    })
  }
  
  // 오류 해결책 분석 (Tier 방식)
  async analyzeSolution(excelFileId, errorContext) {
    return axios.post(`${API_BASE}/analyze`, {
      excel_file_id: excelFileId,
      ...errorContext
    })
  }
  
  // 빠른 수정
  async quickFix(excelFileId, errorType, location) {
    return axios.post(`${API_BASE}/quick_fix`, {
      excel_file_id: excelFileId,
      error_type: errorType,
      location: location
    })
  }
  
  // 고급 실행 (Enterprise)
  async executeAdvanced(excelFileId, options = {}) {
    return axios.post(`${API_BASE}/execute_advanced`, {
      excel_file_id: excelFileId,
      ...options
    })
  }
  
  // 오류 패턴 검색
  async searchErrorPatterns(query) {
    return axios.get(`${API_BASE}/search_patterns`, {
      params: { q: query }
    })
  }
  
  // 오류 통계
  async getErrorStatistics(excelFileId) {
    return axios.get(`${API_BASE}/statistics`, {
      params: { excel_file_id: excelFileId }
    })
  }
}

export default new ErrorSolutionService()