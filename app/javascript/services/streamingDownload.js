import axios from 'axios'

export class StreamingDownloadService {
  constructor(options = {}) {
    this.onProgress = options.onProgress || (() => {})
    this.onComplete = options.onComplete || (() => {})
    this.onError = options.onError || (() => {})
    this.chunkSize = options.chunkSize || 1024 * 1024 // 1MB chunks
    
    this.abortController = null
    this.isPaused = false
    this.downloadedBytes = 0
    this.totalBytes = 0
  }
  
  async download(fileId, filename) {
    try {
      this.abortController = new AbortController()
      
      // Get file info first
      const fileInfo = await this.getFileInfo(fileId)
      this.totalBytes = fileInfo.file_size
      
      // Use streaming if file is large
      if (this.totalBytes > 50 * 1024 * 1024) { // 50MB
        await this.streamingDownload(fileId, filename)
      } else {
        await this.regularDownload(fileId, filename)
      }
      
      this.onComplete()
    } catch (error) {
      if (error.name !== 'AbortError') {
        this.onError(error)
      }
      throw error
    }
  }
  
  async getFileInfo(fileId) {
    const response = await axios.get(`/api/v1/excel_analysis/files/${fileId}`)
    return response.data
  }
  
  async regularDownload(fileId, filename) {
    const response = await axios.get(`/api/v1/streaming_download/${fileId}`, {
      responseType: 'blob',
      signal: this.abortController.signal,
      onDownloadProgress: (progressEvent) => {
        this.downloadedBytes = progressEvent.loaded
        const progress = (progressEvent.loaded / progressEvent.total) * 100
        this.onProgress(progress, progressEvent.loaded, progressEvent.total)
      }
    })
    
    // Create download link
    const url = window.URL.createObjectURL(new Blob([response.data]))
    const link = document.createElement('a')
    link.href = url
    link.setAttribute('download', filename)
    document.body.appendChild(link)
    link.click()
    link.remove()
    window.URL.revokeObjectURL(url)
  }
  
  async streamingDownload(fileId, filename) {
    const response = await fetch(`/api/v1/streaming_download/${fileId}`, {
      signal: this.abortController.signal,
      headers: {
        'Authorization': `Bearer ${this.getAuthToken()}`
      }
    })
    
    if (!response.ok) {
      throw new Error(`Download failed: ${response.statusText}`)
    }
    
    const reader = response.body.getReader()
    const chunks = []
    
    while (true) {
      if (this.isPaused) {
        await this.waitForResume()
      }
      
      const { done, value } = await reader.read()
      
      if (done) break
      
      chunks.push(value)
      this.downloadedBytes += value.length
      
      const progress = (this.downloadedBytes / this.totalBytes) * 100
      this.onProgress(progress, this.downloadedBytes, this.totalBytes)
    }
    
    // Create blob and download
    const blob = new Blob(chunks)
    const url = window.URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.setAttribute('download', filename)
    document.body.appendChild(link)
    link.click()
    link.remove()
    window.URL.revokeObjectURL(url)
  }
  
  async downloadWithResume(fileId, filename) {
    const savedProgress = this.loadProgress(fileId)
    
    if (savedProgress && savedProgress.downloadedBytes > 0) {
      const resumeConfirmed = confirm(`Resume previous download? (${this.formatBytes(savedProgress.downloadedBytes)} of ${this.formatBytes(savedProgress.totalBytes)} downloaded)`)
      
      if (resumeConfirmed) {
        await this.resumeDownload(fileId, filename, savedProgress)
        return
      }
    }
    
    // Start fresh download
    await this.download(fileId, filename)
  }
  
  async resumeDownload(fileId, filename, savedProgress) {
    try {
      this.downloadedBytes = savedProgress.downloadedBytes
      this.totalBytes = savedProgress.totalBytes
      this.abortController = new AbortController()
      
      // Load existing chunks
      const existingChunks = await this.loadChunks(fileId)
      
      // Download remaining data using range requests
      const response = await fetch(`/api/v1/streaming_download/${fileId}/partial`, {
        signal: this.abortController.signal,
        headers: {
          'Authorization': `Bearer ${this.getAuthToken()}`,
          'Range': `bytes=${this.downloadedBytes}-`
        }
      })
      
      if (!response.ok && response.status !== 206) {
        throw new Error(`Resume failed: ${response.statusText}`)
      }
      
      const reader = response.body.getReader()
      const newChunks = []
      
      while (true) {
        if (this.isPaused) {
          await this.waitForResume()
        }
        
        const { done, value } = await reader.read()
        
        if (done) break
        
        newChunks.push(value)
        this.downloadedBytes += value.length
        
        // Save progress periodically
        if (this.downloadedBytes % (10 * 1024 * 1024) === 0) { // Every 10MB
          await this.saveChunks(fileId, [...existingChunks, ...newChunks])
          this.saveProgress(fileId)
        }
        
        const progress = (this.downloadedBytes / this.totalBytes) * 100
        this.onProgress(progress, this.downloadedBytes, this.totalBytes)
      }
      
      // Combine all chunks and download
      const allChunks = [...existingChunks, ...newChunks]
      const blob = new Blob(allChunks)
      const url = window.URL.createObjectURL(blob)
      const link = document.createElement('a')
      link.href = url
      link.setAttribute('download', filename)
      document.body.appendChild(link)
      link.click()
      link.remove()
      window.URL.revokeObjectURL(url)
      
      // Clear saved data
      this.clearProgress(fileId)
      this.clearChunks(fileId)
      
      this.onComplete()
    } catch (error) {
      if (error.name !== 'AbortError') {
        this.onError(error)
      }
      throw error
    }
  }
  
  pause() {
    this.isPaused = true
  }
  
  resume() {
    this.isPaused = false
  }
  
  cancel() {
    if (this.abortController) {
      this.abortController.abort()
    }
  }
  
  async waitForResume() {
    while (this.isPaused) {
      await new Promise(resolve => setTimeout(resolve, 100))
    }
  }
  
  getAuthToken() {
    // Get auth token from your auth system
    return localStorage.getItem('auth_token') || ''
  }
  
  formatBytes(bytes) {
    if (bytes === 0) return '0 Bytes'
    
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
  }
  
  // Progress persistence methods
  saveProgress(fileId) {
    const progress = {
      fileId,
      downloadedBytes: this.downloadedBytes,
      totalBytes: this.totalBytes,
      timestamp: Date.now()
    }
    
    localStorage.setItem(`download_progress_${fileId}`, JSON.stringify(progress))
  }
  
  loadProgress(fileId) {
    const saved = localStorage.getItem(`download_progress_${fileId}`)
    if (!saved) return null
    
    try {
      const progress = JSON.parse(saved)
      
      // Check if progress is not too old (24 hours)
      const age = Date.now() - progress.timestamp
      if (age > 24 * 60 * 60 * 1000) {
        this.clearProgress(fileId)
        return null
      }
      
      return progress
    } catch (error) {
      return null
    }
  }
  
  clearProgress(fileId) {
    localStorage.removeItem(`download_progress_${fileId}`)
  }
  
  // IndexedDB methods for storing chunks
  async saveChunks(fileId, chunks) {
    // This is a simplified version - in production, use IndexedDB
    // to store large binary data
    console.log(`Saving ${chunks.length} chunks for file ${fileId}`)
  }
  
  async loadChunks(fileId) {
    // Load chunks from IndexedDB
    console.log(`Loading chunks for file ${fileId}`)
    return []
  }
  
  async clearChunks(fileId) {
    // Clear chunks from IndexedDB
    console.log(`Clearing chunks for file ${fileId}`)
  }
}