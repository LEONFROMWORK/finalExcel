import axios from 'axios'

export class ChunkedUploadService {
  constructor(options = {}) {
    this.chunkSize = options.chunkSize || 5 * 1024 * 1024 // 5MB default
    this.maxRetries = options.maxRetries || 3
    this.onProgress = options.onProgress || (() => {})
    this.onChunkComplete = options.onChunkComplete || (() => {})
    this.onComplete = options.onComplete || (() => {})
    this.onError = options.onError || (() => {})
    
    this.uploadId = null
    this.totalChunks = 0
    this.uploadedChunks = new Set()
    this.abortController = new AbortController()
    this.isPaused = false
    this.isCancelled = false
  }
  
  async upload(file) {
    try {
      // Initialize upload
      const initResponse = await this.initializeUpload(file)
      this.uploadId = initResponse.upload_id
      this.totalChunks = initResponse.total_chunks
      
      // Upload chunks
      await this.uploadChunks(file)
      
      // Wait for server to assemble file
      const finalStatus = await this.waitForCompletion()
      
      this.onComplete(finalStatus)
      return finalStatus
    } catch (error) {
      this.onError(error)
      throw error
    }
  }
  
  async initializeUpload(file) {
    const response = await axios.post('/api/v1/chunked_upload/init', {
      filename: file.name,
      file_size: file.size,
      chunk_size: this.chunkSize
    })
    
    return response.data
  }
  
  async uploadChunks(file) {
    const chunks = this.createChunks(file)
    const uploadPromises = []
    
    // Upload chunks with concurrency limit
    const concurrencyLimit = 3
    let currentIndex = 0
    
    while (currentIndex < chunks.length && !this.isCancelled) {
      if (this.isPaused) {
        await this.waitForResume()
      }
      
      const activeUploads = []
      
      // Start concurrent uploads
      for (let i = 0; i < concurrencyLimit && currentIndex < chunks.length; i++) {
        const chunk = chunks[currentIndex]
        
        if (!this.uploadedChunks.has(chunk.index)) {
          activeUploads.push(this.uploadChunk(chunk, file))
        }
        
        currentIndex++
      }
      
      // Wait for current batch to complete
      await Promise.all(activeUploads)
    }
  }
  
  createChunks(file) {
    const chunks = []
    const totalChunks = Math.ceil(file.size / this.chunkSize)
    
    for (let i = 0; i < totalChunks; i++) {
      const start = i * this.chunkSize
      const end = Math.min(start + this.chunkSize, file.size)
      
      chunks.push({
        index: i,
        start,
        end,
        blob: file.slice(start, end)
      })
    }
    
    return chunks
  }
  
  async uploadChunk(chunk, file, retryCount = 0) {
    try {
      const formData = new FormData()
      formData.append('upload_id', this.uploadId)
      formData.append('chunk_number', chunk.index)
      formData.append('chunk', chunk.blob)
      
      const response = await axios.post('/api/v1/chunked_upload/chunk', formData, {
        headers: {
          'Content-Type': 'multipart/form-data'
        },
        signal: this.abortController.signal,
        onUploadProgress: (progressEvent) => {
          const chunkProgress = progressEvent.loaded / progressEvent.total
          this.updateProgress(chunk.index, chunkProgress)
        }
      })
      
      this.uploadedChunks.add(chunk.index)
      this.onChunkComplete(chunk.index, this.totalChunks)
      
      return response.data
    } catch (error) {
      if (error.name === 'AbortError' || this.isCancelled) {
        throw new Error('Upload cancelled')
      }
      
      if (retryCount < this.maxRetries) {
        console.log(`Retrying chunk ${chunk.index} (attempt ${retryCount + 1})`)
        await this.delay(1000 * (retryCount + 1)) // Exponential backoff
        return this.uploadChunk(chunk, file, retryCount + 1)
      }
      
      throw error
    }
  }
  
  updateProgress(chunkIndex, chunkProgress) {
    const baseProgress = (this.uploadedChunks.size / this.totalChunks) * 100
    const currentChunkContribution = (chunkProgress / this.totalChunks) * 100
    const totalProgress = Math.min(baseProgress + currentChunkContribution, 100)
    
    this.onProgress(totalProgress)
  }
  
  async waitForCompletion() {
    let attempts = 0
    const maxAttempts = 60 // 5 minutes timeout
    
    while (attempts < maxAttempts) {
      const status = await this.checkStatus()
      
      if (status.status === 'completed') {
        return status
      } else if (status.status === 'failed') {
        throw new Error(status.error || 'Upload failed')
      }
      
      await this.delay(5000) // Check every 5 seconds
      attempts++
    }
    
    throw new Error('Upload timeout')
  }
  
  async checkStatus() {
    const response = await axios.get(`/api/v1/chunked_upload/status/${this.uploadId}`)
    return response.data
  }
  
  pause() {
    this.isPaused = true
  }
  
  resume() {
    this.isPaused = false
  }
  
  async cancel() {
    this.isCancelled = true
    this.abortController.abort()
    
    if (this.uploadId) {
      try {
        await axios.delete(`/api/v1/chunked_upload/cancel/${this.uploadId}`)
      } catch (error) {
        console.error('Failed to cancel upload on server:', error)
      }
    }
  }
  
  async waitForResume() {
    while (this.isPaused && !this.isCancelled) {
      await this.delay(100)
    }
  }
  
  delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms))
  }
}

// Helper function for resumable uploads
export class ResumableUploadService extends ChunkedUploadService {
  constructor(options = {}) {
    super(options)
    this.storageKey = options.storageKey || 'chunked_upload_progress'
  }
  
  async upload(file) {
    // Check for existing upload
    const savedProgress = this.loadProgress(file.name)
    
    if (savedProgress && savedProgress.uploadId) {
      const resumeConfirmed = await this.confirmResume(savedProgress)
      
      if (resumeConfirmed) {
        this.uploadId = savedProgress.uploadId
        this.totalChunks = savedProgress.totalChunks
        this.uploadedChunks = new Set(savedProgress.uploadedChunks)
        
        // Continue from where we left off
        await this.uploadChunks(file)
        const finalStatus = await this.waitForCompletion()
        
        this.clearProgress(file.name)
        this.onComplete(finalStatus)
        return finalStatus
      }
    }
    
    // Start fresh upload
    return super.upload(file)
  }
  
  async uploadChunk(chunk, file, retryCount = 0) {
    const result = await super.uploadChunk(chunk, file, retryCount)
    
    // Save progress after each successful chunk
    this.saveProgress(file.name)
    
    return result
  }
  
  saveProgress(filename) {
    const progress = {
      uploadId: this.uploadId,
      filename: filename,
      totalChunks: this.totalChunks,
      uploadedChunks: Array.from(this.uploadedChunks),
      timestamp: Date.now()
    }
    
    localStorage.setItem(`${this.storageKey}_${filename}`, JSON.stringify(progress))
  }
  
  loadProgress(filename) {
    const saved = localStorage.getItem(`${this.storageKey}_${filename}`)
    if (!saved) return null
    
    try {
      const progress = JSON.parse(saved)
      
      // Check if progress is not too old (24 hours)
      const age = Date.now() - progress.timestamp
      if (age > 24 * 60 * 60 * 1000) {
        this.clearProgress(filename)
        return null
      }
      
      return progress
    } catch (error) {
      return null
    }
  }
  
  clearProgress(filename) {
    localStorage.removeItem(`${this.storageKey}_${filename}`)
  }
  
  async confirmResume(savedProgress) {
    // This should be replaced with a proper UI confirmation
    if (this.onResumeConfirm) {
      return this.onResumeConfirm(savedProgress)
    }
    
    return confirm(`Resume previous upload of ${savedProgress.filename}? (${savedProgress.uploadedChunks.length}/${savedProgress.totalChunks} chunks completed)`)
  }
}