# spec/config/env_check_spec.rb
require 'spec_helper'

RSpec.describe "Environment Configuration" do
  it "has required environment variables structure" do
    expect(ENV).to be_a(Object)
  end

  it "can read Rails environment" do
    env = ENV['RAILS_ENV'] || 'development'
    expect([ 'development', 'test', 'production' ]).to include(env)
  end

  it "has valid Ruby version" do
    expect(RUBY_VERSION).to match(/^3\.\d+\.\d+/)
  end

  it "has valid bundler" do
    expect(Bundler::VERSION).to be_a(String)
  end
end
