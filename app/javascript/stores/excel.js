import { defineStore } from 'pinia'
import axios from 'axios'

export const useExcelStore = defineStore('excel', {
  state: () => ({
    currentFile: null,
    analysisResult: null,
    modificationResult: null,
    isAnalyzing: false,
    isModifying: false,
    error: null,
    uploadProgress: 0
  }),

  getters: {
    hasFile: (state) => !!state.currentFile,
    hasAnalysis: (state) => !!state.analysisResult,
    totalIssues: (state) => {
      if (!state.analysisResult) return 0
      return state.analysisResult.file_analysis?.summary?.total_errors || 0
    }
  },

  actions: {
    async uploadAndAnalyze(file, userQuery = null, signal = null) {
      this.isAnalyzing = true
      this.error = null
      this.uploadProgress = 0

      try {
        const formData = new FormData()
        formData.append('file', file)
        if (userQuery) {
          formData.append('user_query', userQuery)
        }

        // Upload to Rails backend first
        const uploadResponse = await axios.post('/api/v1/excel_analysis/files', formData, {
          headers: {
            'Content-Type': 'multipart/form-data'
          },
          signal: signal,
          onUploadProgress: (progressEvent) => {
            this.uploadProgress = Math.round((progressEvent.loaded * 100) / progressEvent.total)
          }
        })

        this.currentFile = {
          id: uploadResponse.data.id,
          filename: uploadResponse.data.filename,
          url: uploadResponse.data.file_url,
          size: uploadResponse.data.file_size
        }

        // Analyze with Python service
        const analysisResponse = await axios.post('/api/v1/excel_analysis/analyze', {
          file_id: this.currentFile.id,
          file_url: this.currentFile.url,
          user_query: userQuery
        }, { signal: signal })

        this.analysisResult = analysisResponse.data

        return { success: true, data: this.analysisResult }
      } catch (error) {
        this.error = error.response?.data?.error || 'Failed to analyze file'
        return { success: false, error: this.error }
      } finally {
        this.isAnalyzing = false
      }
    },

    async applyModifications(modifications, signal = null) {
      if (!this.currentFile) {
        this.error = 'No file loaded'
        return { success: false, error: this.error }
      }

      this.isModifying = true
      this.error = null

      try {
        const response = await axios.post('/api/v1/excel_analysis/modify', {
          file_id: this.currentFile.id,
          file_url: this.currentFile.url,
          modifications: modifications
        }, { signal: signal })

        this.modificationResult = response.data

        return { success: true, data: this.modificationResult }
      } catch (error) {
        this.error = error.response?.data?.error || 'Failed to modify file'
        return { success: false, error: this.error }
      } finally {
        this.isModifying = false
      }
    },

    async downloadModifiedFile() {
      if (!this.modificationResult?.file_url) {
        this.error = 'No modified file available'
        return { success: false, error: this.error }
      }

      try {
        // Construct the download URL
        const fileUrl = this.modificationResult.file_url
        const filename = fileUrl.split('/').pop()
        const downloadUrl = `/api/v1/uploads/excel/${filename}`
        
        const response = await axios.get(downloadUrl, {
          responseType: 'blob'
        })

        const url = window.URL.createObjectURL(new Blob([response.data]))
        const link = document.createElement('a')
        link.href = url
        link.setAttribute('download', `modified_${this.currentFile.filename}`)
        document.body.appendChild(link)
        link.click()
        link.remove()
        window.URL.revokeObjectURL(url)

        return { success: true }
      } catch (error) {
        this.error = 'Failed to download file'
        return { success: false, error: this.error }
      }
    },

    async createFromTemplate(templateId, customizations = {}, signal = null) {
      this.isModifying = true
      this.error = null

      try {
        const response = await axios.post('/api/v1/excel_analysis/create-from-template', {
          template_id: templateId,
          customizations: customizations
        }, { signal: signal })

        this.currentFile = {
          id: response.data.file_id,
          filename: `template_${templateId}.xlsx`,
          url: response.data.file_url
        }

        return { success: true, data: response.data }
      } catch (error) {
        this.error = error.response?.data?.error || 'Failed to create from template'
        return { success: false, error: this.error }
      } finally {
        this.isModifying = false
      }
    },

    async createFromAI(description, requirements = [], signal = null) {
      this.isModifying = true
      this.error = null

      try {
        const response = await axios.post('/api/v1/excel_analysis/create-from-ai', {
          description: description,
          requirements: requirements
        }, { signal: signal })

        this.currentFile = {
          id: response.data.file_id,
          filename: 'ai_generated.xlsx',
          url: response.data.file_url
        }

        return { success: true, data: response.data }
      } catch (error) {
        this.error = error.response?.data?.error || 'Failed to create from AI'
        return { success: false, error: this.error }
      } finally {
        this.isModifying = false
      }
    },
    
    async generateAnalysisCode(request) {
      try {
        const payload = {
          user_request: request
        }
        
        // Include current file context if available
        if (this.currentFile && this.analysisResult) {
          payload.excel_context = {
            filename: this.currentFile.filename,
            sheets: this.analysisResult.file_analysis?.sheets || [],
            errors: this.analysisResult.file_analysis?.errors || [],
            summary: this.analysisResult.file_analysis?.summary || {}
          }
        }
        
        const response = await axios.post('/api/v1/excel_analysis/generate-code', payload)
        
        return { 
          success: true, 
          data: {
            code: response.data.code,
            explanation: response.data.explanation,
            dependencies: response.data.dependencies || []
          }
        }
      } catch (error) {
        return { 
          success: false, 
          error: error.response?.data?.error || 'Failed to generate code' 
        }
      }
    },

    async analyzeVBA() {
      if (!this.currentFile) {
        this.error = 'No file loaded'
        return { success: false, error: this.error }
      }

      this.isAnalyzing = true
      this.error = null

      try {
        const response = await axios.post('/api/v1/excel_analysis/analyze-vba', {
          file_id: this.currentFile.id
        })

        return { success: true, data: response.data }
      } catch (error) {
        this.error = error.response?.data?.error || 'Failed to analyze VBA'
        return { success: false, error: this.error }
      } finally {
        this.isAnalyzing = false
      }
    },

    async analyzeImage(imageFile, analysisType = 'auto') {
      this.isAnalyzing = true
      this.error = null

      try {
        const formData = new FormData()
        formData.append('image', imageFile)
        formData.append('analysis_type', analysisType)

        const response = await axios.post('/api/v1/excel_analysis/analyze-image', formData, {
          headers: {
            'Content-Type': 'multipart/form-data'
          }
        })

        return { success: true, data: response.data }
      } catch (error) {
        this.error = error.response?.data?.error || 'Failed to analyze image'
        return { success: false, error: this.error }
      } finally {
        this.isAnalyzing = false
      }
    },

    async imagesToExcel(imageFiles, mergeStrategy = 'separate_sheets') {
      this.isModifying = true
      this.error = null

      try {
        const formData = new FormData()
        imageFiles.forEach((file, index) => {
          formData.append(`images[${index}]`, file)
        })
        formData.append('merge_strategy', mergeStrategy)

        const response = await axios.post('/api/v1/excel_analysis/images-to-excel', formData, {
          headers: {
            'Content-Type': 'multipart/form-data'
          }
        })

        this.currentFile = {
          id: response.data.file_id,
          filename: 'images_converted.xlsx'
        }

        return { success: true, data: response.data }
      } catch (error) {
        this.error = error.response?.data?.error || 'Failed to convert images to Excel'
        return { success: false, error: this.error }
      } finally {
        this.isModifying = false
      }
    },

    clearFile() {
      this.currentFile = null
      this.analysisResult = null
      this.modificationResult = null
      this.error = null
      this.uploadProgress = 0
    }
  }
})