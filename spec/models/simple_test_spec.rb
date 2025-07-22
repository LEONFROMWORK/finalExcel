# spec/models/simple_test_spec.rb
require 'rails_helper'

RSpec.describe "Simple Test" do
  it "should pass basic assertion" do
    expect(1 + 1).to eq(2)
  end

  it "should verify Rails is loaded" do
    expect(Rails.env).to eq('test')
  end
end
