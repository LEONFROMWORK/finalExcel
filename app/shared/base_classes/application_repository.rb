# frozen_string_literal: true

module Shared
  module BaseClasses
    # Base repository class with common functionality
    class ApplicationRepository
      include Shared::Interfaces::RepositoryInterface

      def initialize(model_class)
        @model_class = model_class
      end

      def find(id)
        @model_class.find_by(id: id)
      end

      def find_by(attributes)
        @model_class.find_by(attributes)
      end

      def all
        @model_class.all
      end

      def create(attributes)
        @model_class.create(attributes)
      end

      def update(id, attributes)
        record = find(id)
        return nil unless record

        record.update(attributes)
        record
      end

      def delete(id)
        record = find(id)
        return false unless record

        record.destroy
      end

      def exists?(id)
        @model_class.exists?(id: id)
      end

      def count
        @model_class.count
      end

      protected

      attr_reader :model_class
    end
  end
end
