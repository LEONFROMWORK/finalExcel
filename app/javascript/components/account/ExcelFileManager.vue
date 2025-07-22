<template>
  <div class="excel-file-manager">
    <!-- Header with actions -->
    <div class="bg-white rounded-2xl shadow-sm p-6 mb-6">
      <div class="flex flex-col lg:flex-row justify-between items-start lg:items-center gap-4">
        <div>
          <h3 class="text-xl font-bold text-gray-900">Excel 파일 관리</h3>
          <p class="text-sm text-gray-500 mt-1">
            총 {{ files.length }}개 파일 · {{ formatTotalSize() }} 사용 중
          </p>
        </div>
        
        <div class="flex flex-wrap gap-3">
          <!-- Search -->
          <div class="relative">
            <input
              v-model="searchQuery"
              type="text"
              placeholder="파일 검색..."
              class="pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            >
            <svg class="absolute left-3 top-2.5 w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
            </svg>
          </div>
          
          <!-- Sort -->
          <select
            v-model="sortBy"
            class="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          >
            <option value="date">최신순</option>
            <option value="name">이름순</option>
            <option value="size">크기순</option>
            <option value="analyzed">분석순</option>
          </select>
          
          <!-- View toggle -->
          <div class="flex bg-gray-100 rounded-lg p-1">
            <button
              @click="viewMode = 'grid'"
              :class="[
                'px-3 py-1.5 rounded-md transition-colors',
                viewMode === 'grid' ? 'bg-white shadow-sm' : 'text-gray-600 hover:text-gray-900'
              ]"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z"></path>
              </svg>
            </button>
            <button
              @click="viewMode = 'list'"
              :class="[
                'px-3 py-1.5 rounded-md transition-colors',
                viewMode === 'list' ? 'bg-white shadow-sm' : 'text-gray-600 hover:text-gray-900'
              ]"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"></path>
              </svg>
            </button>
          </div>
          
          <!-- Upload button -->
          <button
            @click="$router.push('/excel/upload')"
            class="px-4 py-2 bg-blue-600 text-white rounded-lg font-medium hover:bg-blue-700 transition-colors flex items-center gap-2"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"></path>
            </svg>
            업로드
          </button>
        </div>
      </div>
    </div>
    
    <!-- Files Grid View -->
    <div v-if="viewMode === 'grid' && sortedFiles.length > 0" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
      <div
        v-for="file in sortedFiles"
        :key="file.id"
        class="bg-white rounded-xl shadow-sm hover:shadow-md transition-all duration-300 overflow-hidden group"
      >
        <!-- File Preview -->
        <div class="relative h-40 bg-gradient-to-br from-green-50 to-green-100 flex items-center justify-center">
          <svg class="w-16 h-16 text-green-600" fill="currentColor" viewBox="0 0 24 24">
            <path d="M14,2H6A2,2 0 0,0 4,4V20A2,2 0 0,0 6,22H18A2,2 0 0,0 20,20V8L14,2M18,20H6V4H13V9H18V20M10,19L12,15H9V10H15V15L13,19H10Z" />
          </svg>
          
          <!-- Quick actions on hover -->
          <div class="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center gap-2">
            <button
              @click="$emit('download', file.id)"
              class="p-2 bg-white rounded-lg text-gray-700 hover:bg-gray-100 transition-colors"
              title="다운로드"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"></path>
              </svg>
            </button>
            <button
              @click="$emit('analyze', file.id)"
              class="p-2 bg-white rounded-lg text-gray-700 hover:bg-gray-100 transition-colors"
              title="분석"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"></path>
              </svg>
            </button>
            <button
              @click="confirmDelete(file)"
              class="p-2 bg-white rounded-lg text-red-600 hover:bg-red-50 transition-colors"
              title="삭제"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path>
              </svg>
            </button>
          </div>
          
          <!-- Analysis badge -->
          <div v-if="file.analysis_count > 0" class="absolute top-2 right-2">
            <span class="px-2 py-1 bg-blue-600 text-white text-xs rounded-full">
              {{ file.analysis_count }} 분석
            </span>
          </div>
        </div>
        
        <!-- File Info -->
        <div class="p-4">
          <h4 class="font-medium text-gray-900 truncate mb-1" :title="file.filename">
            {{ file.filename }}
          </h4>
          <div class="flex items-center justify-between text-sm text-gray-500">
            <span>{{ formatFileSize(file.size) }}</span>
            <span>{{ formatDate(file.created_at) }}</span>
          </div>
          <div v-if="file.last_analyzed" class="mt-2 text-xs text-gray-500">
            마지막 분석: {{ formatDate(file.last_analyzed) }}
          </div>
        </div>
      </div>
    </div>
    
    <!-- Files List View -->
    <div v-else-if="viewMode === 'list' && sortedFiles.length > 0" class="bg-white rounded-2xl shadow-sm overflow-hidden">
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              파일명
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              크기
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              분석
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              업로드일
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              작업
            </th>
          </tr>
        </thead>
        <tbody class="bg-white divide-y divide-gray-200">
          <tr v-for="file in sortedFiles" :key="file.id" class="hover:bg-gray-50">
            <td class="px-6 py-4 whitespace-nowrap">
              <div class="flex items-center">
                <div class="w-10 h-10 bg-green-100 rounded-lg flex items-center justify-center mr-3">
                  <svg class="w-6 h-6 text-green-600" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M14,2H6A2,2 0 0,0 4,4V20A2,2 0 0,0 6,22H18A2,2 0 0,0 20,20V8L14,2M18,20H6V4H13V9H18V20M10,19L12,15H9V10H15V15L13,19H10Z" />
                  </svg>
                </div>
                <div>
                  <div class="text-sm font-medium text-gray-900">{{ file.filename }}</div>
                  <div v-if="file.sheets" class="text-xs text-gray-500">{{ file.sheets }} 시트</div>
                </div>
              </div>
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
              {{ formatFileSize(file.size) }}
            </td>
            <td class="px-6 py-4 whitespace-nowrap">
              <span v-if="file.analysis_count > 0" class="px-2 py-1 text-xs font-medium rounded-full bg-blue-100 text-blue-800">
                {{ file.analysis_count }}회
              </span>
              <span v-else class="text-sm text-gray-500">-</span>
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
              {{ formatDate(file.created_at) }}
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
              <div class="flex gap-2">
                <button
                  @click="$emit('download', file.id)"
                  class="text-blue-600 hover:text-blue-900"
                >
                  다운로드
                </button>
                <button
                  @click="$emit('analyze', file.id)"
                  class="text-green-600 hover:text-green-900"
                >
                  분석
                </button>
                <button
                  @click="confirmDelete(file)"
                  class="text-red-600 hover:text-red-900"
                >
                  삭제
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    
    <!-- Empty State -->
    <div v-else-if="files.length === 0" class="bg-white rounded-2xl shadow-sm p-12 text-center">
      <div class="w-20 h-20 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
        <svg class="w-10 h-10 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z"></path>
        </svg>
      </div>
      <h4 class="text-lg font-medium text-gray-900 mb-2">Excel 파일이 없습니다</h4>
      <p class="text-sm text-gray-500 mb-6">첫 번째 Excel 파일을 업로드해보세요</p>
      <button
        @click="$router.push('/excel/upload')"
        class="px-6 py-3 bg-blue-600 text-white rounded-lg font-medium hover:bg-blue-700 transition-colors"
      >
        파일 업로드하기
      </button>
    </div>
    
    <!-- Delete Confirmation Modal -->
    <transition name="modal">
      <div v-if="fileToDelete" class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div class="absolute inset-0 bg-black/50" @click="fileToDelete = null"></div>
        
        <div class="relative bg-white rounded-2xl max-w-md w-full p-6">
          <h3 class="text-xl font-bold text-gray-900 mb-4">파일 삭제</h3>
          
          <p class="text-gray-600 mb-6">
            <span class="font-medium">{{ fileToDelete.filename }}</span> 파일을 삭제하시겠습니까?
            이 작업은 되돌릴 수 없습니다.
          </p>
          
          <div class="flex gap-3 justify-end">
            <button
              @click="fileToDelete = null"
              class="px-4 py-2 text-gray-700 hover:bg-gray-100 rounded-lg transition-colors"
            >
              취소
            </button>
            <button
              @click="deleteFile"
              class="px-4 py-2 bg-red-600 text-white rounded-lg font-medium hover:bg-red-700 transition-colors"
            >
              삭제
            </button>
          </div>
        </div>
      </div>
    </transition>
  </div>
</template>

<script>
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useToast } from '@/composables/useToast'

export default {
  name: 'ExcelFileManager',
  
  props: {
    files: {
      type: Array,
      default: () => []
    }
  },
  
  emits: ['download', 'analyze', 'delete'],
  
  setup(props, { emit }) {
    const router = useRouter()
    const { showToast } = useToast()
    
    const searchQuery = ref('')
    const sortBy = ref('date')
    const viewMode = ref('grid')
    const fileToDelete = ref(null)
    
    const sortedFiles = computed(() => {
      let filtered = [...props.files]
      
      // Search filter
      if (searchQuery.value) {
        const query = searchQuery.value.toLowerCase()
        filtered = filtered.filter(f => 
          f.filename.toLowerCase().includes(query)
        )
      }
      
      // Sort
      filtered.sort((a, b) => {
        switch (sortBy.value) {
          case 'name':
            return a.filename.localeCompare(b.filename)
          case 'size':
            return b.size - a.size
          case 'analyzed':
            return b.analysis_count - a.analysis_count
          case 'date':
          default:
            return new Date(b.created_at) - new Date(a.created_at)
        }
      })
      
      return filtered
    })
    
    const formatTotalSize = () => {
      const totalBytes = props.files.reduce((sum, file) => sum + file.size, 0)
      return formatFileSize(totalBytes)
    }
    
    const formatFileSize = (bytes) => {
      if (bytes === 0) return '0 Bytes'
      
      const k = 1024
      const sizes = ['Bytes', 'KB', 'MB', 'GB']
      const i = Math.floor(Math.log(bytes) / Math.log(k))
      
      return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
    }
    
    const formatDate = (date) => {
      return new Date(date).toLocaleDateString('ko-KR', {
        year: 'numeric',
        month: 'short',
        day: 'numeric'
      })
    }
    
    const confirmDelete = (file) => {
      fileToDelete.value = file
    }
    
    const deleteFile = () => {
      if (fileToDelete.value) {
        emit('delete', fileToDelete.value.id)
        showToast('파일이 삭제되었습니다', 'success')
        fileToDelete.value = null
      }
    }
    
    return {
      searchQuery,
      sortBy,
      viewMode,
      fileToDelete,
      sortedFiles,
      formatTotalSize,
      formatFileSize,
      formatDate,
      confirmDelete,
      deleteFile,
      router
    }
  }
}
</script>

<style scoped>
/* Modal transition */
.modal-enter-active,
.modal-leave-active {
  transition: all 0.3s ease;
}

.modal-enter-from,
.modal-leave-to {
  opacity: 0;
}

.modal-enter-from > div:last-child,
.modal-leave-to > div:last-child {
  transform: scale(0.9);
}
</style>