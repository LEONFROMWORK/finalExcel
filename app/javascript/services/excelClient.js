import { HyperFormula } from 'hyperformula'
import ExcelJS from 'exceljs'
import * as XLSX from 'xlsx'

class ExcelClientService {
  constructor() {
    // Initialize HyperFormula
    this.hf = HyperFormula.buildEmpty({
      licenseKey: 'gpl-v3',
      useArrayArithmetic: true,
      useStats: true
    })
    
    this.sheetId = null
    this.workbook = null
  }

  // Real-time formula validation
  validateFormula(formula) {
    try {
      // Test parse the formula
      const ast = this.hf.parse(formula, this.sheetId || 0)
      
      // Check for errors
      if (ast.type === 'ERROR') {
        return {
          valid: false,
          error: ast.error,
          suggestion: this.getSuggestionForError(ast.error)
        }
      }
      
      return {
        valid: true,
        ast: ast,
        dependencies: this.hf.getDependencies(formula)
      }
    } catch (error) {
      return {
        valid: false,
        error: error.message,
        suggestion: 'Check formula syntax'
      }
    }
  }

  // Fix common formula errors
  fixFormula(formula) {
    // Remove common errors
    let fixed = formula
    
    // Fix #REF! errors
    fixed = fixed.replace(/#REF!/g, 'A1')
    
    // Fix #DIV/0! by wrapping in IFERROR
    if (formula.includes('/')) {
      fixed = `=IFERROR(${formula.substring(1)}, 0)`
    }
    
    // Fix missing closing parentheses
    const openCount = (fixed.match(/\(/g) || []).length
    const closeCount = (fixed.match(/\)/g) || []).length
    if (openCount > closeCount) {
      fixed += ')'.repeat(openCount - closeCount)
    }
    
    return fixed
  }

  // Load Excel file in browser
  async loadExcelFile(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader()
      
      reader.onload = async (e) => {
        try {
          const data = new Uint8Array(e.target.result)
          
          // Parse with SheetJS for compatibility
          const workbook = XLSX.read(data, { type: 'array' })
          
          // Convert to HyperFormula
          this.sheetId = this.hf.addSheet('Sheet1')
          
          const worksheet = workbook.Sheets[workbook.SheetNames[0]]
          const range = XLSX.utils.decode_range(worksheet['!ref'])
          
          // Load data into HyperFormula
          for (let row = range.s.r; row <= range.e.r; row++) {
            for (let col = range.s.c; col <= range.e.c; col++) {
              const cellAddress = XLSX.utils.encode_cell({ r: row, c: col })
              const cell = worksheet[cellAddress]
              
              if (cell) {
                if (cell.f) {
                  // Formula
                  this.hf.setCellContents({ sheet: this.sheetId, row, col }, `=${cell.f}`)
                } else {
                  // Value
                  this.hf.setCellContents({ sheet: this.sheetId, row, col }, cell.v)
                }
              }
            }
          }
          
          // Also load with ExcelJS for advanced features
          this.workbook = new ExcelJS.Workbook()
          await this.workbook.xlsx.load(data)
          
          resolve({
            success: true,
            sheetNames: workbook.SheetNames,
            analysis: this.analyzeWorkbook()
          })
        } catch (error) {
          reject(error)
        }
      }
      
      reader.onerror = reject
      reader.readAsArrayBuffer(file)
    })
  }

  // Analyze workbook for issues
  analyzeWorkbook() {
    const issues = []
    const stats = {
      totalCells: 0,
      formulaCells: 0,
      errorCells: 0,
      sheets: 0
    }
    
    if (!this.workbook) return { issues, stats }
    
    this.workbook.eachSheet((worksheet) => {
      stats.sheets++
      
      worksheet.eachRow((row, rowNumber) => {
        row.eachCell((cell, colNumber) => {
          stats.totalCells++
          
          if (cell.formula) {
            stats.formulaCells++
            
            // Check for errors
            if (cell.result && cell.result.error) {
              stats.errorCells++
              issues.push({
                type: 'formula_error',
                location: `${worksheet.name}!${cell.address}`,
                formula: cell.formula,
                error: cell.result.error,
                suggestion: this.fixFormula(`=${cell.formula}`)
              })
            }
          }
          
          // Check for other issues
          if (cell.value === null || cell.value === '') {
            // Empty cells in data ranges
            if (this.isInDataRange(worksheet, rowNumber, colNumber)) {
              issues.push({
                type: 'empty_cell',
                location: `${worksheet.name}!${cell.address}`,
                suggestion: 'Fill with default value or formula'
              })
            }
          }
        })
      })
    })
    
    return { issues, stats }
  }

  // Check if cell is in a data range
  isInDataRange(worksheet, row, col) {
    // Simple heuristic: if surrounding cells have data
    let surroundingData = 0
    
    for (let r = row - 1; r <= row + 1; r++) {
      for (let c = col - 1; c <= col + 1; c++) {
        if (r > 0 && c > 0 && (r !== row || c !== col)) {
          const cell = worksheet.getCell(r, c)
          if (cell.value) surroundingData++
        }
      }
    }
    
    return surroundingData >= 3
  }

  // Apply bulk fixes
  async applyFixes(fixes) {
    if (!this.workbook) throw new Error('No workbook loaded')
    
    const results = []
    
    for (const fix of fixes) {
      try {
        const [sheetName, cellAddress] = fix.location.split('!')
        const worksheet = this.workbook.getWorksheet(sheetName)
        const cell = worksheet.getCell(cellAddress)
        
        switch (fix.type) {
          case 'formula_error':
            cell.value = { formula: fix.suggestion.substring(1) }
            results.push({ ...fix, status: 'fixed' })
            break
            
          case 'empty_cell':
            cell.value = 0 // Default value
            results.push({ ...fix, status: 'fixed' })
            break
            
          default:
            results.push({ ...fix, status: 'skipped' })
        }
      } catch (error) {
        results.push({ ...fix, status: 'error', error: error.message })
      }
    }
    
    return results
  }

  // Generate Excel file in browser
  async generateExcel() {
    if (!this.workbook) {
      this.workbook = new ExcelJS.Workbook()
    }
    
    const buffer = await this.workbook.xlsx.writeBuffer()
    return new Blob([buffer], { 
      type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' 
    })
  }

  // Real-time calculation
  calculateCell(sheetName, cellAddress, formula) {
    try {
      const result = this.hf.calculateFormula(formula, this.sheetId || 0)
      return {
        success: true,
        value: result,
        formula: formula
      }
    } catch (error) {
      return {
        success: false,
        error: error.message,
        suggestion: this.fixFormula(formula)
      }
    }
  }

  // Get formula suggestions
  getFormulaSuggestions(partial) {
    const functions = this.hf.getRegisteredFunctionNames()
    
    return functions
      .filter(fn => fn.toLowerCase().startsWith(partial.toLowerCase()))
      .slice(0, 10)
      .map(fn => ({
        name: fn,
        syntax: this.getFunctionSyntax(fn),
        description: this.getFunctionDescription(fn)
      }))
  }

  // Helper methods
  getSuggestionForError(error) {
    const suggestions = {
      '#REF!': 'Check cell references - some may be deleted or invalid',
      '#DIV/0!': 'Wrap formula in IFERROR to handle division by zero',
      '#NAME?': 'Check function name spelling or missing quotes for text',
      '#VALUE!': 'Check data types - text used where number expected',
      '#NULL!': 'Check range references - missing colon between cells',
      '#NUM!': 'Check numeric calculations - result may be too large',
      '#N/A': 'Lookup value not found - check VLOOKUP/MATCH ranges'
    }
    
    return suggestions[error] || 'Check formula syntax and references'
  }

  getFunctionSyntax(functionName) {
    // Simplified syntax hints
    const syntax = {
      'SUM': 'SUM(number1, [number2], ...)',
      'AVERAGE': 'AVERAGE(number1, [number2], ...)',
      'IF': 'IF(logical_test, value_if_true, [value_if_false])',
      'VLOOKUP': 'VLOOKUP(lookup_value, table_array, col_index_num, [range_lookup])',
      'COUNT': 'COUNT(value1, [value2], ...)',
      'CONCATENATE': 'CONCATENATE(text1, [text2], ...)'
    }
    
    return syntax[functionName] || `${functionName}(...)`
  }

  getFunctionDescription(functionName) {
    const descriptions = {
      'SUM': 'Adds all numbers in a range',
      'AVERAGE': 'Returns the average of numbers',
      'IF': 'Returns one value if true, another if false',
      'VLOOKUP': 'Looks up values in a table',
      'COUNT': 'Counts cells containing numbers',
      'CONCATENATE': 'Joins text strings together'
    }
    
    return descriptions[functionName] || 'Excel function'
  }

  // Cleanup
  destroy() {
    if (this.hf) {
      this.hf.destroy()
    }
    this.workbook = null
    this.sheetId = null
  }
}

export default new ExcelClientService()