# frozen_string_literal: true

module Shared
  module Interfaces
    # Interface for repository pattern
    module RepositoryInterface
      def find(id)
        raise NotImplementedError
      end

      def find_by(attributes)
        raise NotImplementedError
      end

      def all
        raise NotImplementedError
      end

      def create(attributes)
        raise NotImplementedError
      end

      def update(id, attributes)
        raise NotImplementedError
      end

      def delete(id)
        raise NotImplementedError
      end

      def exists?(id)
        raise NotImplementedError
      end

      def count
        raise NotImplementedError
      end
    end
  end
end
