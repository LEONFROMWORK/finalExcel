# spec/support/simplecov.rb
require 'simplecov'
require 'simplecov-html'

SimpleCov.start 'rails' do
  add_filter '/spec/'
  add_filter '/config/'
  add_filter '/vendor/'
  add_filter '/bin/'

  add_group 'Models', 'app/models'
  add_group 'Controllers', 'app/controllers'
  add_group 'Services', 'app/services'
  add_group 'Repositories', 'app/repositories'
  add_group 'Jobs', 'app/jobs'
  add_group 'Domains', 'app/domains'
  add_group 'Shared', 'app/shared'

  minimum_coverage 80
  minimum_coverage_by_file 75
end
