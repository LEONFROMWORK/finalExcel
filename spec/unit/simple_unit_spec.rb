# spec/unit/simple_unit_spec.rb
require 'spec_helper'

RSpec.describe "Unit Test without Rails" do
  it "performs basic math" do
    expect(2 + 2).to eq(4)
  end

  it "works with arrays" do
    arr = [ 1, 2, 3 ]
    expect(arr.sum).to eq(6)
  end

  it "handles strings" do
    str = "Hello, World!"
    expect(str.downcase).to eq("hello, world!")
  end
end
