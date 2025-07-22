import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import excelService from '../services/excelService'

export const useExcelStore = defineStore('excel', () => {
  // State
  const files = ref([])
  const currentFile = ref(null)
  const loading = ref(false)
  const error = ref(null)
  const statistics = ref({
    totalFiles: 0,
    completedFiles: 0,
    errorsFixed: 0,
    activeAnalysis: 0
  })

  // Getters
  const recentFiles = computed(() => 
    files.value.slice(0, 5)
  )
  
  const pendingFiles = computed(() => 
    files.value.filter(f => f.status === 'pending' || f.status === 'processing')
  )

  // Actions
  const fetchFiles = async () => {
    loading.value = true
    error.value = null
    
    try {
      const response = await excelService.getFiles()
      files.value = response.data.files
      updateStatistics()
    } catch (err) {
      error.value = err.response?.data?.errors || ['Failed to fetch files']
    } finally {
      loading.value = false
    }
  }

  const fetchFile = async (id) => {
    loading.value = true
    error.value = null
    
    try {
      const response = await excelService.getFile(id)
      currentFile.value = response.data
      return response.data
    } catch (err) {
      error.value = err.response?.data?.errors || ['Failed to fetch file']
      throw err
    } finally {
      loading.value = false
    }
  }

  const uploadFile = async (formData, config = {}) => {
    loading.value = true
    error.value = null
    
    try {
      const response = await excelService.uploadFile(formData, config)
      files.value.unshift(response.data)
      updateStatistics()
      
      return {
        success: true,
        file: response.data
      }
    } catch (err) {
      error.value = err.response?.data?.errors || ['Upload failed']
      throw err
    } finally {
      loading.value = false
    }
  }

  const getAnalysis = async (fileId) => {
    try {
      const response = await excelService.getAnalysis(fileId)
      return response.data
    } catch (err) {
      error.value = err.response?.data?.errors || ['Failed to get analysis']
      throw err
    }
  }

  const reanalyze = async (fileId) => {
    try {
      const response = await excelService.reanalyze(fileId)
      
      // Update file status in store
      const file = files.value.find(f => f.id === fileId)
      if (file) {
        file.status = 'pending'
      }
      
      return response.data
    } catch (err) {
      error.value = err.response?.data?.errors || ['Failed to start reanalysis']
      throw err
    }
  }

  const updateStatistics = () => {
    statistics.value = {
      totalFiles: files.value.length,
      completedFiles: files.value.filter(f => f.status === 'completed').length,
      errorsFixed: files.value.reduce((sum, f) => sum + (f.errors_fixed || 0), 0),
      activeAnalysis: files.value.filter(f => f.status === 'processing').length
    }
  }

  return {
    // State
    files,
    currentFile,
    loading,
    error,
    statistics,
    
    // Getters
    recentFiles,
    pendingFiles,
    
    // Actions
    fetchFiles,
    fetchFile,
    uploadFile,
    getAnalysis,
    reanalyze
  }
})