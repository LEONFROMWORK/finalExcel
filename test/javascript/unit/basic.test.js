// test/javascript/unit/basic.test.js
import { describe, it, expect } from 'vitest'

describe('Basic JavaScript Tests', () => {
  it('should perform basic math', () => {
    expect(2 + 2).toBe(4)
  })
  
  it('should handle arrays', () => {
    const arr = [1, 2, 3, 4, 5]
    expect(arr.length).toBe(5)
    expect(arr.reduce((a, b) => a + b, 0)).toBe(15)
  })
  
  it('should work with objects', () => {
    const obj = { name: 'Test', value: 42 }
    expect(obj.name).toBe('Test')
    expect(obj.value).toBe(42)
  })
  
  it('should handle async operations', async () => {
    const promise = new Promise(resolve => {
      setTimeout(() => resolve('done'), 10)
    })
    
    const result = await promise
    expect(result).toBe('done')
  })
})

describe('String Utilities', () => {
  it('should capitalize strings', () => {
    const capitalize = (str) => str.charAt(0).toUpperCase() + str.slice(1)
    expect(capitalize('hello')).toBe('Hello')
  })
  
  it('should trim whitespace', () => {
    const str = '  hello world  '
    expect(str.trim()).toBe('hello world')
  })
})