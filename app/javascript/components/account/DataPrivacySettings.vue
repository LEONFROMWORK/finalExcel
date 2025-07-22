<template>
  <div class="data-privacy-settings space-y-6">
    <!-- Privacy Controls -->
    <div class="bg-white rounded-2xl shadow-sm overflow-hidden">
      <div class="p-6 border-b border-gray-200">
        <h3 class="text-lg font-semibold text-gray-900">개인정보 설정</h3>
        <p class="text-sm text-gray-500 mt-1">데이터 수집 및 사용 방법을 관리하세요</p>
      </div>
      
      <div class="p-6 space-y-6">
        <!-- Data Collection -->
        <div>
          <h4 class="text-sm font-medium text-gray-900 mb-4">데이터 수집</h4>
          <div class="space-y-3">
            <label class="flex items-start">
              <input
                v-model="privacySettings.dataCollection"
                type="checkbox"
                class="mt-1 w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
              >
              <div class="ml-3">
                <span class="text-sm font-medium text-gray-700">서비스 개선을 위한 데이터 수집</span>
                <p class="text-xs text-gray-500 mt-1">
                  사용 패턴 및 오류 정보를 수집하여 서비스를 개선합니다
                </p>
              </div>
            </label>
            
            <label class="flex items-start">
              <input
                v-model="privacySettings.analytics"
                type="checkbox"
                class="mt-1 w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
              >
              <div class="ml-3">
                <span class="text-sm font-medium text-gray-700">분석 데이터</span>
                <p class="text-xs text-gray-500 mt-1">
                  페이지 방문 및 기능 사용 통계를 수집합니다
                </p>
              </div>
            </label>
            
            <label class="flex items-start">
              <input
                v-model="privacySettings.crashReports"
                type="checkbox"
                class="mt-1 w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
              >
              <div class="ml-3">
                <span class="text-sm font-medium text-gray-700">오류 보고서</span>
                <p class="text-xs text-gray-500 mt-1">
                  앱 충돌 시 자동으로 오류 보고서를 전송합니다
                </p>
              </div>
            </label>
          </div>
        </div>
        
        <!-- Communication Preferences -->
        <div>
          <h4 class="text-sm font-medium text-gray-900 mb-4">커뮤니케이션</h4>
          <div class="space-y-3">
            <label class="flex items-start">
              <input
                v-model="privacySettings.productUpdates"
                type="checkbox"
                class="mt-1 w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
              >
              <div class="ml-3">
                <span class="text-sm font-medium text-gray-700">제품 업데이트</span>
                <p class="text-xs text-gray-500 mt-1">
                  새로운 기능 및 업데이트 소식을 받습니다
                </p>
              </div>
            </label>
            
            <label class="flex items-start">
              <input
                v-model="privacySettings.tips"
                type="checkbox"
                class="mt-1 w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
              >
              <div class="ml-3">
                <span class="text-sm font-medium text-gray-700">사용 팁</span>
                <p class="text-xs text-gray-500 mt-1">
                  Excel Unified 활용 팁을 이메일로 받습니다
                </p>
              </div>
            </label>
            
            <label class="flex items-start">
              <input
                v-model="privacySettings.marketing"
                type="checkbox"
                class="mt-1 w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
              >
              <div class="ml-3">
                <span class="text-sm font-medium text-gray-700">프로모션 및 이벤트</span>
                <p class="text-xs text-gray-500 mt-1">
                  특별 할인 및 이벤트 정보를 받습니다
                </p>
              </div>
            </label>
          </div>
        </div>
        
        <!-- Third-party Sharing -->
        <div>
          <h4 class="text-sm font-medium text-gray-900 mb-4">제3자 공유</h4>
          <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-4">
            <div class="flex items-start gap-3">
              <svg class="w-5 h-5 text-yellow-600 flex-shrink-0 mt-0.5" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
              </svg>
              <div class="text-sm text-yellow-800">
                <p class="font-medium">개인정보는 제3자와 공유되지 않습니다</p>
                <p class="mt-1">귀하의 데이터는 법적 요구사항이 있는 경우를 제외하고 제3자와 공유되지 않습니다.</p>
              </div>
            </div>
          </div>
          
          <label class="flex items-start">
            <input
              v-model="privacySettings.anonymousUsage"
              type="checkbox"
              class="mt-1 w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
            >
            <div class="ml-3">
              <span class="text-sm font-medium text-gray-700">익명화된 사용 데이터</span>
              <p class="text-xs text-gray-500 mt-1">
                서비스 개선을 위해 익명화된 데이터를 분석에 사용할 수 있습니다
              </p>
            </div>
          </label>
        </div>
        
        <div class="flex justify-end">
          <button
            @click="savePrivacySettings"
            :disabled="!hasChanges"
            class="px-6 py-2 bg-blue-600 text-white rounded-lg font-medium disabled:opacity-50 disabled:cursor-not-allowed hover:bg-blue-700 transition-colors"
          >
            설정 저장
          </button>
        </div>
      </div>
    </div>

    <!-- Data Management -->
    <div class="bg-white rounded-2xl shadow-sm overflow-hidden">
      <div class="p-6 border-b border-gray-200">
        <h3 class="text-lg font-semibold text-gray-900">데이터 관리</h3>
        <p class="text-sm text-gray-500 mt-1">개인 데이터를 다운로드하거나 삭제할 수 있습니다</p>
      </div>
      
      <div class="p-6 space-y-6">
        <!-- Data Export -->
        <div>
          <h4 class="font-medium text-gray-900 mb-2">데이터 내보내기</h4>
          <p class="text-sm text-gray-600 mb-4">
            계정과 관련된 모든 데이터의 사본을 다운로드할 수 있습니다. 여기에는 프로필 정보, 
            활동 내역, 업로드한 파일 목록 등이 포함됩니다.
          </p>
          <button
            @click="requestDataExport"
            class="px-4 py-2 bg-gray-100 text-gray-700 rounded-lg font-medium hover:bg-gray-200 transition-colors"
          >
            데이터 다운로드 요청
          </button>
        </div>
        
        <!-- Data Deletion -->
        <div>
          <h4 class="font-medium text-gray-900 mb-2">데이터 삭제</h4>
          <p class="text-sm text-gray-600 mb-4">
            특정 데이터를 선택적으로 삭제할 수 있습니다. 일부 데이터는 법적 요구사항에 따라 
            보존될 수 있습니다.
          </p>
          
          <div class="space-y-3">
            <button
              @click="showDeleteModal = 'activity'"
              class="block w-full text-left px-4 py-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors"
            >
              <div class="flex items-center justify-between">
                <div>
                  <p class="font-medium text-gray-900">활동 내역 삭제</p>
                  <p class="text-sm text-gray-500">검색 기록, 사용 로그 등</p>
                </div>
                <svg class="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
                </svg>
              </div>
            </button>
            
            <button
              @click="showDeleteModal = 'files'"
              class="block w-full text-left px-4 py-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors"
            >
              <div class="flex items-center justify-between">
                <div>
                  <p class="font-medium text-gray-900">업로드 파일 삭제</p>
                  <p class="text-sm text-gray-500">모든 Excel 파일 및 분석 결과</p>
                </div>
                <svg class="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
                </svg>
              </div>
            </button>
            
            <button
              @click="showDeleteModal = 'conversations'"
              class="block w-full text-left px-4 py-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors"
            >
              <div class="flex items-center justify-between">
                <div>
                  <p class="font-medium text-gray-900">AI 대화 내역 삭제</p>
                  <p class="text-sm text-gray-500">모든 AI 상담 대화 기록</p>
                </div>
                <svg class="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
                </svg>
              </div>
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Data Retention -->
    <div class="bg-blue-50 rounded-2xl p-6">
      <h3 class="text-lg font-semibold text-gray-900 mb-3">데이터 보존 정책</h3>
      <div class="space-y-2 text-sm text-gray-700">
        <p>• 활동 로그: 90일 후 자동 삭제</p>
        <p>• Excel 파일: 마지막 접근 후 1년간 보관</p>
        <p>• AI 대화 내역: 6개월간 보관</p>
        <p>• 계정 삭제 시: 30일 유예 기간 후 영구 삭제</p>
      </div>
      <a href="/privacy-policy" class="inline-block mt-4 text-blue-600 hover:text-blue-700 font-medium">
        전체 개인정보 처리방침 보기 →
      </a>
    </div>

    <!-- Delete Confirmation Modal -->
    <transition name="modal">
      <div v-if="showDeleteModal" class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div class="absolute inset-0 bg-black/50" @click="showDeleteModal = null"></div>
        
        <div class="relative bg-white rounded-2xl max-w-md w-full p-6">
          <h3 class="text-xl font-bold text-gray-900 mb-4">데이터 삭제 확인</h3>
          
          <p class="text-gray-600 mb-6">
            {{ getDeleteDescription(showDeleteModal) }}
          </p>
          
          <div class="bg-red-50 border border-red-200 rounded-lg p-4 mb-6">
            <p class="text-sm text-red-800">
              <strong>경고:</strong> 이 작업은 되돌릴 수 없습니다. 삭제된 데이터는 복구할 수 없습니다.
            </p>
          </div>
          
          <div class="flex gap-3 justify-end">
            <button
              @click="showDeleteModal = null"
              class="px-4 py-2 text-gray-700 hover:bg-gray-100 rounded-lg transition-colors"
            >
              취소
            </button>
            <button
              @click="confirmDelete"
              class="px-4 py-2 bg-red-600 text-white rounded-lg font-medium hover:bg-red-700 transition-colors"
            >
              삭제 확인
            </button>
          </div>
        </div>
      </div>
    </transition>
  </div>
</template>

<script>
import { ref, computed } from 'vue'
import { useToast } from '@/composables/useToast'

export default {
  name: 'DataPrivacySettings',
  
  props: {
    preferences: {
      type: Object,
      default: () => ({})
    }
  },
  
  emits: ['update', 'download-data', 'delete-data'],
  
  setup(props, { emit }) {
    const { showToast } = useToast()
    
    const showDeleteModal = ref(null)
    
    const privacySettings = ref({
      dataCollection: props.preferences.dataCollection ?? true,
      analytics: props.preferences.analytics ?? true,
      crashReports: props.preferences.crashReports ?? true,
      productUpdates: props.preferences.productUpdates ?? true,
      tips: props.preferences.tips ?? true,
      marketing: props.preferences.marketing ?? false,
      anonymousUsage: props.preferences.anonymousUsage ?? true
    })
    
    const originalSettings = JSON.stringify(privacySettings.value)
    
    const hasChanges = computed(() => {
      return JSON.stringify(privacySettings.value) !== originalSettings
    })
    
    const savePrivacySettings = async () => {
      try {
        await emit('update', privacySettings.value)
        showToast('개인정보 설정이 저장되었습니다', 'success')
      } catch (error) {
        showToast('설정 저장에 실패했습니다', 'error')
      }
    }
    
    const requestDataExport = async () => {
      try {
        await emit('download-data')
        showToast('데이터 다운로드를 준비 중입니다. 이메일로 링크를 보내드리겠습니다.', 'info')
      } catch (error) {
        showToast('데이터 다운로드 요청에 실패했습니다', 'error')
      }
    }
    
    const getDeleteDescription = (type) => {
      const descriptions = {
        activity: '모든 활동 내역과 사용 로그가 삭제됩니다. 여기에는 검색 기록, 페이지 방문 기록, 기능 사용 통계가 포함됩니다.',
        files: '업로드한 모든 Excel 파일과 분석 결과가 삭제됩니다. 공유한 파일도 더 이상 접근할 수 없게 됩니다.',
        conversations: '모든 AI 상담 대화 내역이 삭제됩니다. 저장한 대화나 즐겨찾기도 모두 삭제됩니다.'
      }
      return descriptions[type] || ''
    }
    
    const confirmDelete = async () => {
      if (!showDeleteModal.value) return
      
      try {
        await emit('delete-data', { type: showDeleteModal.value })
        showToast('데이터가 삭제되었습니다', 'success')
        showDeleteModal.value = null
      } catch (error) {
        showToast('데이터 삭제에 실패했습니다', 'error')
      }
    }
    
    return {
      privacySettings,
      hasChanges,
      showDeleteModal,
      savePrivacySettings,
      requestDataExport,
      getDeleteDescription,
      confirmDelete
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