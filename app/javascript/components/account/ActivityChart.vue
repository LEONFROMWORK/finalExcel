<template>
  <div class="activity-chart">
    <!-- Chart Header -->
    <div class="flex justify-between items-center mb-6">
      <div>
        <p class="text-sm text-gray-500">지난 30일 활동</p>
        <p class="text-2xl font-bold text-gray-900">{{ totalActivities }} 활동</p>
      </div>
      <div class="flex gap-2">
        <button
          v-for="view in viewOptions"
          :key="view.value"
          @click="currentView = view.value"
          :class="[
            'px-3 py-1.5 text-sm font-medium rounded-lg transition-colors',
            currentView === view.value
              ? 'bg-blue-100 text-blue-700'
              : 'text-gray-600 hover:bg-gray-100'
          ]"
        >
          {{ view.label }}
        </button>
      </div>
    </div>
    
    <!-- Chart Container -->
    <div class="relative">
      <!-- Bar Chart -->
      <div v-if="currentView === 'bar'" class="h-64">
        <div class="flex items-end justify-between h-full gap-2">
          <div
            v-for="(day, index) in chartData"
            :key="index"
            class="flex-1 flex flex-col items-center justify-end group"
          >
            <!-- Tooltip -->
            <div class="relative">
              <div 
                v-if="hoveredIndex === index"
                class="absolute bottom-full mb-2 left-1/2 transform -translate-x-1/2 bg-gray-900 text-white text-xs rounded-lg px-3 py-2 whitespace-nowrap z-10"
              >
                <div class="font-semibold">{{ formatDateFull(day.date) }}</div>
                <div>{{ day.count }} 활동</div>
                <div class="absolute top-full left-1/2 transform -translate-x-1/2 -mt-1">
                  <div class="w-0 h-0 border-l-4 border-r-4 border-t-4 border-transparent border-t-gray-900"></div>
                </div>
              </div>
            </div>
            
            <!-- Bar -->
            <div
              @mouseenter="hoveredIndex = index"
              @mouseleave="hoveredIndex = null"
              class="w-full bg-gradient-to-t from-blue-500 to-blue-400 rounded-t-md transition-all duration-300 cursor-pointer hover:from-blue-600 hover:to-blue-500"
              :style="{ height: `${getBarHeight(day.count)}%` }"
            ></div>
            
            <!-- Label -->
            <div class="mt-2 text-xs text-gray-500 transform -rotate-45 origin-top-left translate-x-3">
              {{ formatDateShort(day.date) }}
            </div>
          </div>
        </div>
        
        <!-- Y-axis labels -->
        <div class="absolute left-0 top-0 h-full flex flex-col justify-between text-xs text-gray-500 -ml-8">
          <span>{{ maxCount }}</span>
          <span>{{ Math.floor(maxCount / 2) }}</span>
          <span>0</span>
        </div>
      </div>
      
      <!-- Line Chart -->
      <div v-else-if="currentView === 'line'" class="h-64 relative">
        <svg class="w-full h-full">
          <!-- Grid lines -->
          <g class="grid-lines">
            <line
              v-for="i in 5"
              :key="`grid-${i}`"
              :x1="0"
              :y1="(i - 1) * 64"
              :x2="chartWidth"
              :y2="(i - 1) * 64"
              stroke="#e5e7eb"
              stroke-width="1"
            />
          </g>
          
          <!-- Line path -->
          <path
            :d="linePath"
            fill="none"
            stroke="url(#gradient)"
            stroke-width="3"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
          
          <!-- Area under line -->
          <path
            :d="areaPath"
            fill="url(#areaGradient)"
            opacity="0.1"
          />
          
          <!-- Data points -->
          <g>
            <circle
              v-for="(point, index) in linePoints"
              :key="`point-${index}`"
              :cx="point.x"
              :cy="point.y"
              r="4"
              fill="#3b82f6"
              stroke="white"
              stroke-width="2"
              class="cursor-pointer"
              @mouseenter="hoveredIndex = index"
              @mouseleave="hoveredIndex = null"
            />
          </g>
          
          <!-- Gradient definitions -->
          <defs>
            <linearGradient id="gradient" x1="0%" y1="0%" x2="100%" y2="0%">
              <stop offset="0%" stop-color="#3b82f6" />
              <stop offset="100%" stop-color="#8b5cf6" />
            </linearGradient>
            <linearGradient id="areaGradient" x1="0%" y1="0%" x2="0%" y2="100%">
              <stop offset="0%" stop-color="#3b82f6" />
              <stop offset="100%" stop-color="#3b82f6" stop-opacity="0" />
            </linearGradient>
          </defs>
        </svg>
        
        <!-- Hover tooltip -->
        <div
          v-if="hoveredIndex !== null && linePoints[hoveredIndex]"
          class="absolute bg-gray-900 text-white text-xs rounded-lg px-3 py-2 pointer-events-none z-10"
          :style="{
            left: `${linePoints[hoveredIndex].x}px`,
            top: `${linePoints[hoveredIndex].y - 50}px`,
            transform: 'translateX(-50%)'
          }"
        >
          <div class="font-semibold">{{ formatDateFull(chartData[hoveredIndex].date) }}</div>
          <div>{{ chartData[hoveredIndex].count }} 활동</div>
        </div>
      </div>
      
      <!-- Heatmap -->
      <div v-else-if="currentView === 'heatmap'" class="grid grid-cols-7 gap-1">
        <div
          v-for="(week, weekIndex) in heatmapData"
          :key="`week-${weekIndex}`"
          class="space-y-1"
        >
          <div
            v-for="(day, dayIndex) in week"
            :key="`day-${dayIndex}`"
            class="w-8 h-8 rounded cursor-pointer transition-all duration-200 hover:ring-2 hover:ring-blue-400 hover:ring-offset-1"
            :class="getHeatmapColor(day.count)"
            :title="`${formatDateFull(day.date)}: ${day.count} 활동`"
          ></div>
        </div>
      </div>
    </div>
    
    <!-- Legend for heatmap -->
    <div v-if="currentView === 'heatmap'" class="flex items-center justify-center gap-2 mt-6">
      <span class="text-xs text-gray-500">적음</span>
      <div class="flex gap-1">
        <div class="w-4 h-4 rounded bg-gray-100"></div>
        <div class="w-4 h-4 rounded bg-blue-200"></div>
        <div class="w-4 h-4 rounded bg-blue-400"></div>
        <div class="w-4 h-4 rounded bg-blue-600"></div>
        <div class="w-4 h-4 rounded bg-blue-800"></div>
      </div>
      <span class="text-xs text-gray-500">많음</span>
    </div>
  </div>
</template>

<script>
import { ref, computed, onMounted } from 'vue'

export default {
  name: 'ActivityChart',
  
  props: {
    data: {
      type: Array,
      default: () => []
    }
  },
  
  setup(props) {
    const currentView = ref('bar')
    const hoveredIndex = ref(null)
    const chartWidth = ref(600)
    const chartHeight = ref(256)
    
    const viewOptions = [
      { value: 'bar', label: '막대' },
      { value: 'line', label: '선' },
      { value: 'heatmap', label: '히트맵' }
    ]
    
    // Process data for 30 days
    const chartData = computed(() => {
      const days = []
      const today = new Date()
      
      for (let i = 29; i >= 0; i--) {
        const date = new Date(today)
        date.setDate(date.getDate() - i)
        const dateStr = date.toLocaleDateString()
        
        const existingData = props.data.find(d => d.date === dateStr)
        days.push({
          date: dateStr,
          count: existingData?.count || 0
        })
      }
      
      return days
    })
    
    const totalActivities = computed(() => {
      return chartData.value.reduce((sum, day) => sum + day.count, 0)
    })
    
    const maxCount = computed(() => {
      return Math.max(...chartData.value.map(d => d.count), 10)
    })
    
    const getBarHeight = (count) => {
      return (count / maxCount.value) * 100
    }
    
    // Line chart calculations
    const linePoints = computed(() => {
      const points = []
      const xStep = chartWidth.value / (chartData.value.length - 1)
      
      chartData.value.forEach((day, index) => {
        points.push({
          x: index * xStep,
          y: chartHeight.value - (day.count / maxCount.value) * chartHeight.value
        })
      })
      
      return points
    })
    
    const linePath = computed(() => {
      if (linePoints.value.length === 0) return ''
      
      const points = linePoints.value
      let path = `M ${points[0].x} ${points[0].y}`
      
      // Create smooth curve
      for (let i = 1; i < points.length; i++) {
        const xMid = (points[i - 1].x + points[i].x) / 2
        const yMid = (points[i - 1].y + points[i].y) / 2
        const cp1x = (xMid + points[i - 1].x) / 2
        const cp2x = (xMid + points[i].x) / 2
        
        path += ` Q ${cp1x} ${points[i - 1].y} ${xMid} ${yMid}`
        path += ` Q ${cp2x} ${points[i].y} ${points[i].x} ${points[i].y}`
      }
      
      return path
    })
    
    const areaPath = computed(() => {
      if (linePoints.value.length === 0) return ''
      
      let path = linePath.value
      path += ` L ${linePoints.value[linePoints.value.length - 1].x} ${chartHeight.value}`
      path += ` L ${linePoints.value[0].x} ${chartHeight.value}`
      path += ' Z'
      
      return path
    })
    
    // Heatmap data
    const heatmapData = computed(() => {
      const weeks = []
      let week = []
      
      chartData.value.forEach((day, index) => {
        week.push(day)
        
        if ((index + 1) % 7 === 0 || index === chartData.value.length - 1) {
          weeks.push(week)
          week = []
        }
      })
      
      return weeks
    })
    
    const getHeatmapColor = (count) => {
      if (count === 0) return 'bg-gray-100'
      if (count <= 2) return 'bg-blue-200'
      if (count <= 5) return 'bg-blue-400'
      if (count <= 10) return 'bg-blue-600'
      return 'bg-blue-800'
    }
    
    const formatDateShort = (dateStr) => {
      const date = new Date(dateStr)
      return `${date.getMonth() + 1}/${date.getDate()}`
    }
    
    const formatDateFull = (dateStr) => {
      const date = new Date(dateStr)
      const options = { month: 'short', day: 'numeric', year: 'numeric' }
      return date.toLocaleDateString('ko-KR', options)
    }
    
    onMounted(() => {
      // Calculate actual chart dimensions
      const container = document.querySelector('.activity-chart')
      if (container) {
        chartWidth.value = container.offsetWidth - 100
      }
    })
    
    return {
      currentView,
      hoveredIndex,
      viewOptions,
      chartData,
      totalActivities,
      maxCount,
      chartWidth,
      linePoints,
      linePath,
      areaPath,
      heatmapData,
      getBarHeight,
      getHeatmapColor,
      formatDateShort,
      formatDateFull
    }
  }
}
</script>

<style scoped>
.activity-chart {
  min-height: 350px;
}
</style>