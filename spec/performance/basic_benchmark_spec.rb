# spec/performance/basic_benchmark_spec.rb
require 'spec_helper'
require 'benchmark'

RSpec.describe "Basic Performance" do
  it "performs array operations efficiently" do
    time = Benchmark.realtime do
      1000.times do
        arr = (1..100).to_a
        arr.sum
        arr.map { |n| n * 2 }
        arr.select(&:even?)
      end
    end

    expect(time).to be < 0.1 # Should complete in less than 100ms
  end

  it "handles string operations efficiently" do
    time = Benchmark.realtime do
      1000.times do
        str = "Hello " * 100
        str.upcase
        str.split.join("-")
        str.gsub(/[aeiou]/, '*')
      end
    end

    expect(time).to be < 0.2 # Should complete in less than 200ms
  end

  it "manages hash operations efficiently" do
    time = Benchmark.realtime do
      1000.times do
        hash = (1..100).each_with_object({}) { |i, h| h[i] = i * 2 }
        hash.values.sum
        hash.select { |k, v| v > 50 }
        hash.transform_values { |v| v * 3 }
      end
    end

    expect(time).to be < 0.15 # Should complete in less than 150ms
  end
end
