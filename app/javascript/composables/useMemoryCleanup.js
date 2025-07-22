import { onUnmounted, onBeforeUnmount } from 'vue'

export function useMemoryCleanup() {
  const cleanupFunctions = []
  const intervals = new Set()
  const timeouts = new Set()
  const eventListeners = []
  const abortControllers = new Set()

  // Track intervals
  const setCleanupInterval = (callback, delay) => {
    const id = setInterval(callback, delay)
    intervals.add(id)
    return id
  }

  // Track timeouts
  const setCleanupTimeout = (callback, delay) => {
    const id = setTimeout(callback, delay)
    timeouts.add(id)
    return id
  }

  // Track event listeners
  const addCleanupEventListener = (target, event, handler, options) => {
    target.addEventListener(event, handler, options)
    eventListeners.push({ target, event, handler, options })
  }

  // Track abort controllers for fetch requests
  const createCleanupAbortController = () => {
    const controller = new AbortController()
    abortControllers.add(controller)
    return controller
  }

  // Add custom cleanup function
  const addCleanupFunction = (fn) => {
    cleanupFunctions.push(fn)
  }

  // Cleanup function
  const cleanup = () => {
    // Clear all intervals
    intervals.forEach(id => clearInterval(id))
    intervals.clear()

    // Clear all timeouts
    timeouts.forEach(id => clearTimeout(id))
    timeouts.clear()

    // Remove all event listeners
    eventListeners.forEach(({ target, event, handler, options }) => {
      target.removeEventListener(event, handler, options)
    })
    eventListeners.length = 0

    // Abort all pending requests
    abortControllers.forEach(controller => {
      if (!controller.signal.aborted) {
        controller.abort()
      }
    })
    abortControllers.clear()

    // Run custom cleanup functions
    cleanupFunctions.forEach(fn => {
      try {
        fn()
      } catch (error) {
        console.error('Error in cleanup function:', error)
      }
    })
    cleanupFunctions.length = 0
  }

  // Auto cleanup on unmount
  onBeforeUnmount(cleanup)
  onUnmounted(cleanup)

  return {
    setCleanupInterval,
    setCleanupTimeout,
    addCleanupEventListener,
    createCleanupAbortController,
    addCleanupFunction,
    cleanup
  }
}