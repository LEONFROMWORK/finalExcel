// cypress/support/commands.js

// Authentication commands
Cypress.Commands.add('login', (email = 'test@example.com', password = 'password123') => {
  cy.request('POST', `${Cypress.env('apiUrl')}/auth/login`, {
    email,
    password
  }).then((response) => {
    window.localStorage.setItem('auth_token', response.body.token)
    window.localStorage.setItem('current_user', JSON.stringify(response.body.user))
  })
})

Cypress.Commands.add('logout', () => {
  window.localStorage.removeItem('auth_token')
  window.localStorage.removeItem('current_user')
})

// Database commands
Cypress.Commands.add('resetDatabase', () => {
  cy.task('db:reset')
})

Cypress.Commands.add('seedDatabase', () => {
  cy.task('db:seed')
})

// File upload command
Cypress.Commands.add('uploadFile', (fileName, selector) => {
  cy.get(selector).selectFile(`cypress/fixtures/${fileName}`, { force: true })
})

// Wait for API response
Cypress.Commands.add('waitForApi', (alias, timeout = 10000) => {
  cy.intercept('GET', '**/api/v1/**').as(alias)
  cy.wait(`@${alias}`, { timeout })
})

// Custom assertions
Cypress.Commands.add('shouldBeLoggedIn', () => {
  cy.window().its('localStorage.auth_token').should('exist')
  cy.get('[data-cy=user-menu]').should('be.visible')
})

Cypress.Commands.add('shouldNotBeLoggedIn', () => {
  cy.window().its('localStorage.auth_token').should('not.exist')
  cy.get('[data-cy=login-button]').should('be.visible')
})

// Excel file commands
Cypress.Commands.add('uploadExcelFile', (fileName = 'test-data.xlsx') => {
  cy.get('[data-cy=upload-button]').click()
  cy.get('input[type=file]').selectFile(`cypress/fixtures/${fileName}`, { force: true })
  cy.get('[data-cy=analyze-button]').click()
})

Cypress.Commands.add('waitForAnalysis', (timeout = 30000) => {
  cy.get('[data-cy=analysis-status]', { timeout }).should('contain', 'Completed')
})

// QA Pair commands
Cypress.Commands.add('createQAPair', (question, answer) => {
  cy.get('[data-cy=add-qa-button]').click()
  cy.get('[data-cy=question-input]').type(question)
  cy.get('[data-cy=answer-input]').type(answer)
  cy.get('[data-cy=save-qa-button]').click()
})

// Chat commands
Cypress.Commands.add('sendChatMessage', (message) => {
  cy.get('[data-cy=chat-input]').type(message)
  cy.get('[data-cy=send-message]').click()
})

Cypress.Commands.add('waitForAIResponse', (timeout = 15000) => {
  cy.get('[data-cy=ai-response]', { timeout }).should('be.visible')
  cy.get('[data-cy=typing-indicator]').should('not.exist')
})