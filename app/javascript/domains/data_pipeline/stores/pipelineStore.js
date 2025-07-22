import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import pipelineService from '../services/pipelineService'

export const usePipelineStore = defineStore('pipeline', () => {
  // State
  const tasks = ref([])
  const currentTask = ref(null)
  const runs = ref([])
  const recentActivity = ref([])
  const loading = ref(false)
  const error = ref(null)
  const globalStats = ref({
    total_tasks: 0,
    active_tasks: 0,
    total_runs: 0,
    successful_runs: 0,
    failed_runs: 0,
    total_items_collected: 0,
    total_items_processed: 0,
    task_types: {},
    schedules: {}
  })

  // Getters
  const activeTasks = computed(() => 
    tasks.value.filter(task => task.status === 'active')
  )

  const pausedTasks = computed(() => 
    tasks.value.filter(task => task.status === 'paused')
  )

  const successRate = computed(() => {
    if (globalStats.value.total_runs === 0) return 0
    return ((globalStats.value.successful_runs / globalStats.value.total_runs) * 100).toFixed(2)
  })

  // Actions
  const fetchTasks = async (params = {}) => {
    loading.value = true
    error.value = null
    
    try {
      const response = await pipelineService.getTasks(params)
      tasks.value = response.data.tasks
      return response.data
    } catch (err) {
      error.value = err.response?.data?.errors || ['Failed to fetch tasks']
      throw err
    } finally {
      loading.value = false
    }
  }

  const fetchTask = async (id) => {
    loading.value = true
    error.value = null
    
    try {
      const response = await pipelineService.getTask(id)
      currentTask.value = response.data.task
      runs.value = response.data.recent_runs || []
      return response.data
    } catch (err) {
      error.value = err.response?.data?.errors || ['Failed to fetch task']
      throw err
    } finally {
      loading.value = false
    }
  }

  const createTask = async (taskData) => {
    loading.value = true
    error.value = null
    
    try {
      const response = await pipelineService.createTask(taskData)
      tasks.value.unshift(response.data.task)
      return response.data
    } catch (err) {
      error.value = err.response?.data?.errors || ['Failed to create task']
      throw err
    } finally {
      loading.value = false
    }
  }

  const updateTask = async (id, data) => {
    try {
      const response = await pipelineService.updateTask(id, data)
      const updatedTask = response.data.task
      
      // Update in tasks list
      const index = tasks.value.findIndex(t => t.id === id)
      if (index !== -1) {
        tasks.value[index] = updatedTask
      }
      
      // Update current task if it's the same
      if (currentTask.value?.id === id) {
        currentTask.value = updatedTask
      }
      
      return response.data
    } catch (err) {
      error.value = err.response?.data?.errors || ['Failed to update task']
      throw err
    }
  }

  const deleteTask = async (id) => {
    try {
      await pipelineService.deleteTask(id)
      
      // Remove from tasks list
      tasks.value = tasks.value.filter(t => t.id !== id)
      
      // Clear current task if it was deleted
      if (currentTask.value?.id === id) {
        currentTask.value = null
      }
    } catch (err) {
      error.value = err.response?.data?.errors || ['Failed to delete task']
      throw err
    }
  }

  const startTask = async (id) => {
    try {
      const response = await pipelineService.startTask(id)
      
      // Update task in list
      const index = tasks.value.findIndex(t => t.id === id)
      if (index !== -1) {
        tasks.value[index] = response.data.task
      }
      
      return response.data
    } catch (err) {
      error.value = err.response?.data?.errors || ['Failed to start task']
      throw err
    }
  }

  const stopTask = async (id) => {
    try {
      const response = await pipelineService.stopTask(id)
      
      // Update task in list
      const index = tasks.value.findIndex(t => t.id === id)
      if (index !== -1) {
        tasks.value[index] = response.data.task
      }
      
      return response.data
    } catch (err) {
      error.value = err.response?.data?.errors || ['Failed to stop task']
      throw err
    }
  }

  const fetchTaskRuns = async (taskId, params = {}) => {
    loading.value = true
    error.value = null
    
    try {
      const response = await pipelineService.getTaskRuns(taskId, params)
      runs.value = response.data.runs
      return response.data
    } catch (err) {
      error.value = err.response?.data?.errors || ['Failed to fetch runs']
      throw err
    } finally {
      loading.value = false
    }
  }

  const fetchTaskStatistics = async (taskId) => {
    try {
      const response = await pipelineService.getTaskStatistics(taskId)
      return response.data
    } catch (err) {
      error.value = err.response?.data?.errors || ['Failed to fetch statistics']
      throw err
    }
  }

  const fetchGlobalStatistics = async () => {
    try {
      const response = await pipelineService.getGlobalStatistics()
      globalStats.value = response.data
      return response.data
    } catch (err) {
      console.error('Failed to fetch global statistics:', err)
    }
  }

  const fetchRecentActivity = async (limit = 20) => {
    try {
      const response = await pipelineService.getRecentActivity({ limit })
      recentActivity.value = response.data.activity
      return response.data
    } catch (err) {
      console.error('Failed to fetch recent activity:', err)
    }
  }

  const cancelRun = async (runId) => {
    try {
      const response = await pipelineService.cancelRun(runId)
      
      // Update run in list if present
      const index = runs.value.findIndex(r => r.id === runId)
      if (index !== -1) {
        runs.value[index] = response.data.run
      }
      
      return response.data
    } catch (err) {
      error.value = err.response?.data?.errors || ['Failed to cancel run']
      throw err
    }
  }

  return {
    // State
    tasks,
    currentTask,
    runs,
    recentActivity,
    loading,
    error,
    globalStats,
    
    // Getters
    activeTasks,
    pausedTasks,
    successRate,
    
    // Actions
    fetchTasks,
    fetchTask,
    createTask,
    updateTask,
    deleteTask,
    startTask,
    stopTask,
    fetchTaskRuns,
    fetchTaskStatistics,
    fetchGlobalStatistics,
    fetchRecentActivity,
    cancelRun
  }
})