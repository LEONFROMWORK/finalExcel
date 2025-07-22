// cypress/e2e/user_journey.cy.js

describe('Complete User Journey', () => {
  beforeEach(() => {
    cy.resetDatabase()
    cy.seedDatabase()
  })
  
  describe('New User Registration and Onboarding', () => {
    it('allows new user to register and complete onboarding', () => {
      cy.visit('/')
      
      // Navigate to registration
      cy.get('[data-cy=register-link]').click()
      cy.url().should('include', '/register')
      
      // Fill registration form
      cy.get('[data-cy=email-input]').type('newuser@example.com')
      cy.get('[data-cy=password-input]').type('password123')
      cy.get('[data-cy=password-confirmation-input]').type('password123')
      cy.get('[data-cy=name-input]').type('New User')
      cy.get('[data-cy=register-button]').click()
      
      // Should be redirected to dashboard
      cy.url().should('include', '/dashboard')
      cy.shouldBeLoggedIn()
      
      // Check welcome message
      cy.get('[data-cy=welcome-message]').should('contain', 'Welcome, New User')
      
      // Complete onboarding tour
      cy.get('[data-cy=start-tour]').click()
      cy.get('[data-cy=tour-next]').click()
      cy.get('[data-cy=tour-next]').click()
      cy.get('[data-cy=tour-finish]').click()
    })
  })
  
  describe('Excel File Analysis Workflow', () => {
    beforeEach(() => {
      cy.login()
      cy.visit('/dashboard')
    })
    
    it('uploads and analyzes an Excel file successfully', () => {
      // Navigate to Excel analysis
      cy.get('[data-cy=nav-excel-analysis]').click()
      cy.url().should('include', '/excel-analysis')
      
      // Upload file
      cy.get('[data-cy=upload-area]').should('be.visible')
      cy.uploadFile('sample-data.xlsx', 'input[type=file]')
      
      // Check file appears in list
      cy.get('[data-cy=file-list]').should('contain', 'sample-data.xlsx')
      cy.get('[data-cy=file-status]').should('contain', 'Processing')
      
      // Wait for analysis to complete
      cy.waitForAnalysis()
      
      // View analysis results
      cy.get('[data-cy=view-analysis]').first().click()
      cy.get('[data-cy=analysis-summary]').should('be.visible')
      cy.get('[data-cy=data-insights]').should('contain', 'rows')
      cy.get('[data-cy=data-insights]').should('contain', 'columns')
      
      // Generate QA pairs from analysis
      cy.get('[data-cy=generate-qa-button]').click()
      cy.get('[data-cy=qa-generation-status]').should('contain', 'Generating')
      
      // Wait for QA generation
      cy.get('[data-cy=qa-generation-status]', { timeout: 20000 })
        .should('contain', 'Generated')
      cy.get('[data-cy=qa-count]').should('contain', 'QA pairs')
    })
    
    it('handles invalid file upload', () => {
      cy.get('[data-cy=nav-excel-analysis]').click()
      
      // Try to upload non-Excel file
      cy.uploadFile('invalid.txt', 'input[type=file]')
      
      // Should show error
      cy.get('[data-cy=error-message]').should('contain', 'Please select a valid Excel file')
      cy.get('[data-cy=file-list]').should('not.contain', 'invalid.txt')
    })
  })
  
  describe('Knowledge Base Search and Management', () => {
    beforeEach(() => {
      cy.login()
      cy.visit('/knowledge-base')
    })
    
    it('searches and manages QA pairs', () => {
      // Search functionality
      cy.get('[data-cy=search-input]').type('Excel formula')
      cy.get('[data-cy=search-button]').click()
      
      // Check search results
      cy.get('[data-cy=search-results]').should('be.visible')
      cy.get('[data-cy=qa-item]').should('have.length.at.least', 1)
      
      // Create new QA pair
      cy.createQAPair(
        'How do I calculate average in Excel?',
        'Use the AVERAGE function: =AVERAGE(A1:A10)'
      )
      
      // Verify creation
      cy.get('[data-cy=success-message]').should('contain', 'QA pair created')
      cy.get('[data-cy=qa-list]').should('contain', 'How do I calculate average')
      
      // Edit QA pair
      cy.get('[data-cy=edit-qa]').first().click()
      cy.get('[data-cy=answer-input]').clear().type('Updated answer with more details')
      cy.get('[data-cy=save-qa-button]').click()
      
      // Verify update
      cy.get('[data-cy=success-message]').should('contain', 'Updated successfully')
      
      // Delete QA pair
      cy.get('[data-cy=delete-qa]').first().click()
      cy.get('[data-cy=confirm-delete]').click()
      
      // Verify deletion
      cy.get('[data-cy=success-message]').should('contain', 'Deleted successfully')
    })
    
    it('filters QA pairs by category', () => {
      // Apply category filter
      cy.get('[data-cy=category-filter]').select('technical')
      
      // Verify filtered results
      cy.get('[data-cy=qa-item]').each(($el) => {
        cy.wrap($el).find('[data-cy=qa-category]').should('contain', 'technical')
      })
      
      // Clear filter
      cy.get('[data-cy=clear-filters]').click()
      cy.get('[data-cy=qa-item]').should('have.length.at.least', 5)
    })
  })
  
  describe('AI Consultation Session', () => {
    beforeEach(() => {
      cy.login()
      cy.visit('/ai-consultation')
    })
    
    it('conducts an AI consultation session', () => {
      // Start new consultation
      cy.get('[data-cy=new-consultation]').click()
      cy.get('[data-cy=consultation-title]').type('Data Analysis Help')
      cy.get('[data-cy=start-consultation]').click()
      
      // Send first message
      cy.sendChatMessage('How can I analyze sales trends in my Excel data?')
      cy.waitForAIResponse()
      
      // Verify AI response
      cy.get('[data-cy=ai-response]').last().should('contain', 'analyze')
      
      // Continue conversation
      cy.sendChatMessage('Can you show me an example formula?')
      cy.waitForAIResponse()
      
      // Check message history
      cy.get('[data-cy=chat-message]').should('have.length.at.least', 4)
      
      // Upload context file
      cy.get('[data-cy=attach-file]').click()
      cy.uploadFile('sales-data.xlsx', '[data-cy=context-file-input]')
      cy.get('[data-cy=file-attached]').should('contain', 'sales-data.xlsx')
      
      // Ask about the uploaded file
      cy.sendChatMessage('What insights can you find in this sales data?')
      cy.waitForAIResponse()
      
      // Save consultation
      cy.get('[data-cy=save-consultation]').click()
      cy.get('[data-cy=success-message]').should('contain', 'Consultation saved')
    })
    
    it('loads previous consultation sessions', () => {
      // View consultation history
      cy.get('[data-cy=consultation-history]').click()
      
      // Should show previous consultations
      cy.get('[data-cy=consultation-item]').should('have.length.at.least', 1)
      
      // Load a previous consultation
      cy.get('[data-cy=load-consultation]').first().click()
      
      // Verify messages loaded
      cy.get('[data-cy=chat-message]').should('have.length.at.least', 2)
      
      // Continue from previous consultation
      cy.sendChatMessage('Following up on our previous discussion...')
      cy.waitForAIResponse()
    })
  })
  
  describe('Admin Data Pipeline Management', () => {
    beforeEach(() => {
      cy.login('admin@example.com', 'adminpass123')
      cy.visit('/admin/data-pipelines')
    })
    
    it('creates and manages data pipelines', () => {
      // Create new data source
      cy.get('[data-cy=add-data-source]').click()
      cy.get('[data-cy=source-name]').type('Sales API')
      cy.get('[data-cy=source-type]').select('api')
      cy.get('[data-cy=api-endpoint]').type('https://api.example.com/sales')
      cy.get('[data-cy=polling-interval]').type('3600')
      cy.get('[data-cy=save-source]').click()
      
      // Verify creation
      cy.get('[data-cy=success-message]').should('contain', 'Data source created')
      cy.get('[data-cy=source-list]').should('contain', 'Sales API')
      
      // Create workflow
      cy.get('[data-cy=add-workflow]').click()
      cy.get('[data-cy=workflow-name]').type('Sales Data Processing')
      cy.get('[data-cy=workflow-schedule]').type('0 */6 * * *')
      
      // Add workflow steps
      cy.get('[data-cy=add-step]').click()
      cy.get('[data-cy=step-type]').select('extract')
      cy.get('[data-cy=step-source]').select('Sales API')
      cy.get('[data-cy=save-step]').click()
      
      cy.get('[data-cy=add-step]').click()
      cy.get('[data-cy=step-type]').select('transform')
      cy.get('[data-cy=transform-operation]').select('aggregate')
      cy.get('[data-cy=save-step]').click()
      
      cy.get('[data-cy=add-step]').click()
      cy.get('[data-cy=step-type]').select('load')
      cy.get('[data-cy=destination]').select('knowledge_base')
      cy.get('[data-cy=save-step]').click()
      
      // Save workflow
      cy.get('[data-cy=save-workflow]').click()
      cy.get('[data-cy=success-message]').should('contain', 'Workflow created')
      
      // Test workflow
      cy.get('[data-cy=test-workflow]').first().click()
      cy.get('[data-cy=test-status]').should('contain', 'Running')
      
      // Wait for test to complete
      cy.get('[data-cy=test-status]', { timeout: 30000 }).should('contain', 'Success')
      
      // View logs
      cy.get('[data-cy=view-logs]').first().click()
      cy.get('[data-cy=log-entries]').should('be.visible')
      cy.get('[data-cy=log-entry]').should('have.length.at.least', 1)
    })
    
    it('monitors pipeline execution', () => {
      // View dashboard
      cy.get('[data-cy=pipeline-dashboard]').should('be.visible')
      
      // Check metrics
      cy.get('[data-cy=total-sources]').should('contain.number')
      cy.get('[data-cy=active-workflows]').should('contain.number')
      cy.get('[data-cy=records-processed]').should('contain.number')
      
      // View execution history
      cy.get('[data-cy=execution-history]').click()
      cy.get('[data-cy=execution-item]').should('have.length.at.least', 1)
      
      // Check execution details
      cy.get('[data-cy=view-execution]').first().click()
      cy.get('[data-cy=execution-details]').should('be.visible')
      cy.get('[data-cy=execution-timeline]').should('be.visible')
    })
  })
  
  describe('Error Handling and Recovery', () => {
    it('handles network errors gracefully', () => {
      cy.login()
      cy.visit('/dashboard')
      
      // Simulate network failure
      cy.intercept('GET', '**/api/v1/**', { forceNetworkError: true }).as('networkError')
      
      cy.get('[data-cy=nav-excel-analysis]').click()
      
      // Should show error message
      cy.get('[data-cy=error-banner]').should('contain', 'Network error')
      cy.get('[data-cy=retry-button]').should('be.visible')
      
      // Restore network and retry
      cy.intercept('GET', '**/api/v1/**').as('apiCall')
      cy.get('[data-cy=retry-button]').click()
      
      // Should recover
      cy.wait('@apiCall')
      cy.get('[data-cy=error-banner]').should('not.exist')
    })
    
    it('handles session expiration', () => {
      cy.login()
      cy.visit('/dashboard')
      
      // Simulate expired token
      cy.window().then((win) => {
        win.localStorage.setItem('auth_token', 'expired-token')
      })
      
      // Try to access protected resource
      cy.get('[data-cy=nav-excel-analysis]').click()
      
      // Should redirect to login
      cy.url().should('include', '/login')
      cy.get('[data-cy=session-expired-message]').should('be.visible')
    })
  })
  
  describe('Performance and Loading States', () => {
    it('shows appropriate loading states', () => {
      cy.login()
      cy.visit('/excel-analysis')
      
      // Intercept API calls with delay
      cy.intercept('GET', '**/api/v1/excel_analysis/files', (req) => {
        req.reply((res) => {
          res.delay(2000) // 2 second delay
          res.send({ files: [] })
        })
      }).as('slowApi')
      
      // Reload page
      cy.reload()
      
      // Should show loading state
      cy.get('[data-cy=loading-spinner]').should('be.visible')
      cy.get('[data-cy=file-list-skeleton]').should('be.visible')
      
      // Wait for load to complete
      cy.wait('@slowApi')
      
      // Loading states should disappear
      cy.get('[data-cy=loading-spinner]').should('not.exist')
      cy.get('[data-cy=file-list-skeleton]').should('not.exist')
    })
  })
})