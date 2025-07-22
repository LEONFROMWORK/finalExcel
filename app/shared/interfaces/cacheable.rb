# frozen_string_literal: true

module Shared
  module Interfaces
    # Interface for cacheable services
    module Cacheable
      def cache_key
        raise NotImplementedError
      end

      def cache_expires_in
        1.hour
      end

      def with_cache(&block)
        Rails.cache.fetch(cache_key, expires_in: cache_expires_in, &block)
      end

      def invalidate_cache
        Rails.cache.delete(cache_key)
      end
    end
  end
end
