import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import knowledgeService from '../services/knowledgeService'

export const useKnowledgeStore = defineStore('knowledge', () => {
  // State
  const qaPairs = ref([])
  const searchResults = ref([])
  const currentQAPair = ref(null)
  const loading = ref(false)
  const error = ref(null)
  const statistics = ref({
    total: 0,
    approved: 0,
    bySource: {},
    averageQuality: 0
  })

  // Getters
  const recentQAPairs = computed(() => 
    qaPairs.value.slice(0, 10)
  )
  
  const popularQAPairs = computed(() => 
    [...qaPairs.value].sort((a, b) => b.usage_count - a.usage_count).slice(0, 10)
  )

  // Actions
  const fetchQAPairs = async (params = {}) => {
    loading.value = true
    error.value = null
    
    try {
      const response = await knowledgeService.getQAPairs(params)
      qaPairs.value = response.data.qa_pairs
      return response.data
    } catch (err) {
      error.value = err.response?.data?.errors || ['Failed to fetch Q&A pairs']
      throw err
    } finally {
      loading.value = false
    }
  }

  const fetchQAPair = async (id) => {
    loading.value = true
    error.value = null
    
    try {
      const response = await knowledgeService.getQAPair(id)
      currentQAPair.value = response.data
      return response.data
    } catch (err) {
      error.value = err.response?.data?.errors || ['Failed to fetch Q&A pair']
      throw err
    } finally {
      loading.value = false
    }
  }

  const searchQAPairs = async (searchParams) => {
    loading.value = true
    error.value = null
    
    try {
      const response = await knowledgeService.searchQAPairs(searchParams)
      searchResults.value = response.data.results
      return response.data.results
    } catch (err) {
      error.value = err.response?.data?.errors || ['Search failed']
      throw err
    } finally {
      loading.value = false
    }
  }

  const clearSearch = () => {
    searchResults.value = []
  }

  const fetchStatistics = async () => {
    try {
      const response = await knowledgeService.getStatistics()
      statistics.value = response.data
      return response.data
    } catch (err) {
      console.error('Failed to fetch statistics:', err)
    }
  }

  return {
    // State
    qaPairs,
    searchResults,
    currentQAPair,
    loading,
    error,
    statistics,
    
    // Getters
    recentQAPairs,
    popularQAPairs,
    
    // Actions
    fetchQAPairs,
    fetchQAPair,
    searchQAPairs,
    clearSearch,
    fetchStatistics
  }
})