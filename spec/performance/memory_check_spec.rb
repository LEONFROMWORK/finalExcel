# spec/performance/memory_check_spec.rb
require 'spec_helper'

RSpec.describe "Memory Usage" do
  def memory_usage_mb
    `ps -o rss= -p #{Process.pid}`.to_i / 1024.0
  end

  it "maintains reasonable memory usage" do
    initial_memory = memory_usage_mb

    # Perform some operations
    1000.times do
      arr = (1..1000).to_a
      hash = arr.each_with_object({}) { |i, h| h[i] = i.to_s * 10 }
    end

    # Force garbage collection
    GC.start

    final_memory = memory_usage_mb
    memory_increase = final_memory - initial_memory

    # Memory increase should be less than 50MB
    expect(memory_increase).to be < 50
  end

  it "releases memory after operations" do
    GC.start
    baseline = memory_usage_mb

    # Create large objects
    big_array = Array.new(100_000) { |i| "String #{i}" * 10 }
    after_creation = memory_usage_mb

    # Clear and garbage collect
    big_array = nil
    GC.start
    sleep 0.1
    GC.start

    after_gc = memory_usage_mb

    # Memory should return close to baseline (within 20MB)
    expect(after_gc - baseline).to be < 20
  end
end
