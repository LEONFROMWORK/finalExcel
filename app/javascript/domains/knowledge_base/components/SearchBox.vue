<template>
  <div class="knowledge-search">
    <div class="search-container">
      <div class="search-header">
        <h2 class="text-3xl font-bold text-gray-900 mb-2">Excel 지식 검색</h2>
        <p class="text-lg text-gray-600">Excel 관련 질문과 답변을 검색하세요</p>
      </div>
      
      <Card class="mb-6">
        <template #content>
          <div class="p-4">
            <div class="relative">
              <AutoComplete
                v-model="searchQuery"
                :suggestions="suggestions"
                @complete="searchSuggestions"
                @item-select="search"
                placeholder="예: VLOOKUP 사용법, 피벗 테이블 만들기..."
                class="w-full"
                inputClass="w-full"
                :delay="300"
              >
                <template #option="slotProps">
                  <div class="flex items-center">
                    <i class="pi pi-search mr-2"></i>
                    <span>{{ slotProps.option }}</span>
                  </div>
                </template>
              </AutoComplete>
              <Button
                v-if="searchQuery"
                icon="pi pi-times"
                @click="clearSearch"
                class="absolute right-2 top-1/2 -translate-y-1/2"
                text
                rounded
                severity="secondary"
              />
            </div>
            
            <div class="mt-4">
              <Checkbox 
                v-model="useSemanticSearch" 
                inputId="semantic-search"
                :binary="true"
              />
              <label for="semantic-search" class="ml-2 cursor-pointer">
                의미 기반 검색 사용
              </label>
            </div>
          </div>
        </template>
      </Card>
      
      <!-- Loading State -->
      <div v-if="isSearching" class="text-center py-12">
        <ProgressSpinner />
        <p class="mt-4 text-gray-600">검색 중...</p>
      </div>
      
      <!-- Results -->
      <div v-else-if="searchResults.length > 0" class="search-results">
        <div class="mb-4">
          <h3 class="text-xl font-semibold">검색 결과 ({{ searchResults.length }}개)</h3>
        </div>
        
        <DataView :value="searchResults" :layout="'list'">
          <template #list="slotProps">
            <div class="col-12">
              <Card 
                v-for="(result, index) in slotProps.items" 
                :key="result.id"
                class="mb-3 cursor-pointer hover:shadow-lg transition-shadow"
                @click="selectResult(result)"
              >
                <template #content>
                  <div class="p-4">
                    <h4 class="text-lg font-semibold mb-2">{{ result.question }}</h4>
                    <p class="text-gray-600 mb-4">{{ truncateText(result.answer, 200) }}</p>
                    
                    <div class="flex flex-wrap gap-4 text-sm text-gray-500">
                      <Tag severity="info" class="px-3">
                        <i class="pi pi-info-circle mr-1"></i>
                        {{ result.source }}
                      </Tag>
                      <Tag severity="success" class="px-3">
                        <i class="pi pi-check-circle mr-1"></i>
                        신뢰도: {{ (result.quality_score * 100).toFixed(0) }}%
                      </Tag>
                      <Tag class="px-3">
                        <i class="pi pi-eye mr-1"></i>
                        조회: {{ result.usage_count }}회
                      </Tag>
                    </div>
                  </div>
                </template>
              </Card>
            </div>
          </template>
        </DataView>
      </div>
      
      <!-- No Results -->
      <div v-else-if="searchQuery && !isSearching && hasSearched" class="text-center py-12">
        <Message severity="info" :closable="false">
          <i class="pi pi-search text-4xl block mb-4"></i>
          <p class="text-lg mb-2">검색 결과가 없습니다</p>
          <p class="text-sm">다른 검색어를 시도해보세요</p>
        </Message>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import { debounce } from 'lodash-es'
import { useKnowledgeStore } from '../stores/knowledgeStore'
import Card from 'primevue/card'
import AutoComplete from 'primevue/autocomplete'
import Button from 'primevue/button'
import Checkbox from 'primevue/checkbox'
import ProgressSpinner from 'primevue/progressspinner'
import DataView from 'primevue/dataview'
import Tag from 'primevue/tag'
import Message from 'primevue/message'

const emit = defineEmits(['select'])

const knowledgeStore = useKnowledgeStore()

const searchQuery = ref('')
const isSearching = ref(false)
const hasSearched = ref(false)
const searchResults = ref([])
const useSemanticSearch = ref(true)
const suggestions = ref([])

const search = async () => {
  if (!searchQuery.value.trim()) return
  
  isSearching.value = true
  hasSearched.value = true
  
  try {
    const results = await knowledgeStore.searchQAPairs({
      query: searchQuery.value,
      semantic: useSemanticSearch.value,
      limit: 10
    })
    
    searchResults.value = results
  } catch (error) {
    console.error('Search failed:', error)
    searchResults.value = []
  } finally {
    isSearching.value = false
  }
}

const debouncedSearch = debounce(search, 300)

const searchSuggestions = async (event) => {
  if (!event.query.trim()) {
    suggestions.value = []
    return
  }
  
  // Simple suggestions based on common Excel topics
  const commonTopics = [
    'VLOOKUP 사용법',
    'HLOOKUP 함수',
    '피벗 테이블 만들기',
    'INDEX MATCH 함수',
    '조건부 서식',
    '매크로 작성',
    'SUMIF 함수',
    'COUNTIF 함수',
    '차트 만들기',
    '데이터 유효성 검사'
  ]
  
  suggestions.value = commonTopics.filter(topic => 
    topic.toLowerCase().includes(event.query.toLowerCase())
  )
}

const clearSearch = () => {
  searchQuery.value = ''
  searchResults.value = []
  hasSearched.value = false
  suggestions.value = []
}

const selectResult = (result) => {
  emit('select', result)
}

const truncateText = (text, maxLength) => {
  if (text.length <= maxLength) return text
  return text.substring(0, maxLength) + '...'
}
</script>

<style scoped>
.knowledge-search {
  max-width: 1000px;
  margin: 0 auto;
  padding: 2rem;
}

.search-header {
  text-align: center;
  margin-bottom: 2rem;
}

:deep(.p-autocomplete) {
  width: 100%;
}

:deep(.p-autocomplete-input) {
  width: 100%;
  padding-right: 3rem;
}

:deep(.p-card) {
  transition: all 0.3s ease;
}

:deep(.p-card:hover) {
  transform: translateY(-2px);
}

:deep(.p-tag) {
  font-weight: normal;
}
</style>