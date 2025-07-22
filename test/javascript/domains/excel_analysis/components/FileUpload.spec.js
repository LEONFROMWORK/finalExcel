// test/javascript/domains/excel_analysis/components/FileUpload.spec.js
import { mount } from '@vue/test-utils'
import { createTestingPinia } from '@pinia/testing'
import { describe, it, expect, vi, beforeEach } from 'vitest'
import FileUpload from '@/domains/excel_analysis/components/FileUpload.vue'
import { useExcelStore } from '@/domains/excel_analysis/stores/excelStore'

describe('FileUpload', () => {
  let wrapper
  
  beforeEach(() => {
    wrapper = mount(FileUpload, {
      global: {
        plugins: [createTestingPinia({
          createSpy: vi.fn,
        })],
      },
    })
  })
  
  it('renders upload area', () => {
    expect(wrapper.find('[data-testid="upload-area"]').exists()).toBe(true)
    expect(wrapper.text()).toContain('Drag and drop')
  })
  
  it('shows file input', () => {
    const input = wrapper.find('input[type="file"]')
    expect(input.exists()).toBe(true)
    expect(input.attributes('accept')).toContain('.xlsx')
    expect(input.attributes('accept')).toContain('.xls')
  })
  
  it('handles file selection', async () => {
    const file = new File(['content'], 'test.xlsx', {
      type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    })
    
    const input = wrapper.find('input[type="file"]')
    
    // Mock the files property
    Object.defineProperty(input.element, 'files', {
      value: [file],
      writable: false,
    })
    
    await input.trigger('change')
    
    expect(wrapper.emitted('file-selected')).toBeTruthy()
    expect(wrapper.emitted('file-selected')[0][0]).toBe(file)
  })
  
  it('validates file type', async () => {
    const invalidFile = new File(['content'], 'test.txt', {
      type: 'text/plain'
    })
    
    const input = wrapper.find('input[type="file"]')
    
    Object.defineProperty(input.element, 'files', {
      value: [invalidFile],
      writable: false,
    })
    
    await input.trigger('change')
    
    expect(wrapper.emitted('file-selected')).toBeFalsy()
    expect(wrapper.text()).toContain('Please select a valid Excel file')
  })
  
  it('validates file size', async () => {
    const largeFile = new File(
      [new ArrayBuffer(51 * 1024 * 1024)], // 51MB
      'large.xlsx',
      { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' }
    )
    
    const input = wrapper.find('input[type="file"]')
    
    Object.defineProperty(input.element, 'files', {
      value: [largeFile],
      writable: false,
    })
    
    await input.trigger('change')
    
    expect(wrapper.emitted('file-selected')).toBeFalsy()
    expect(wrapper.text()).toContain('File size must be less than 50MB')
  })
  
  it('handles drag and drop', async () => {
    const file = new File(['content'], 'test.xlsx', {
      type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    })
    
    const dropZone = wrapper.find('[data-testid="upload-area"]')
    
    await dropZone.trigger('dragenter')
    expect(wrapper.vm.isDragging).toBe(true)
    
    await dropZone.trigger('drop', {
      dataTransfer: {
        files: [file],
      },
    })
    
    expect(wrapper.vm.isDragging).toBe(false)
    expect(wrapper.emitted('file-selected')).toBeTruthy()
    expect(wrapper.emitted('file-selected')[0][0]).toBe(file)
  })
  
  it('uploads file to store', async () => {
    const store = useExcelStore()
    const file = new File(['content'], 'test.xlsx', {
      type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    })
    
    wrapper = mount(FileUpload, {
      props: {
        autoUpload: true,
      },
      global: {
        plugins: [createTestingPinia({
          createSpy: vi.fn,
        })],
      },
    })
    
    const input = wrapper.find('input[type="file"]')
    Object.defineProperty(input.element, 'files', {
      value: [file],
      writable: false,
    })
    
    await input.trigger('change')
    
    expect(store.uploadFile).toHaveBeenCalledWith(file)
  })
  
  it('shows loading state during upload', async () => {
    const store = useExcelStore()
    store.isUploading = true
    
    wrapper = mount(FileUpload, {
      global: {
        plugins: [createTestingPinia({
          initialState: {
            excel: {
              isUploading: true,
            },
          },
        })],
      },
    })
    
    expect(wrapper.find('[data-testid="loading-spinner"]').exists()).toBe(true)
    expect(wrapper.find('input[type="file"]').attributes('disabled')).toBeDefined()
  })
  
  it('displays upload progress', async () => {
    const store = useExcelStore()
    
    wrapper = mount(FileUpload, {
      global: {
        plugins: [createTestingPinia({
          initialState: {
            excel: {
              isUploading: true,
              uploadProgress: 65,
            },
          },
        })],
      },
    })
    
    const progressBar = wrapper.find('[data-testid="progress-bar"]')
    expect(progressBar.exists()).toBe(true)
    expect(progressBar.element.style.width).toBe('65%')
  })
})