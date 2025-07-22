module Api
  module V1
    class HealthController < Api::V1::ApiController
      def index
        health_status = {
          status: "healthy",
          timestamp: Time.current,
          services: check_services
        }

        # Determine overall health
        overall_healthy = health_status[:services].values.all? { |s| s[:status] == "healthy" }
        health_status[:status] = overall_healthy ? "healthy" : "degraded"

        render json: health_status, status: overall_healthy ? :ok : :service_unavailable
      end

      private

      def check_services
        {
          database: check_database,
          redis: check_redis,
          python_service: check_python_service,
          pgvector: check_pgvector
        }
      end

      def check_database
        start = Time.current
        ActiveRecord::Base.connection.execute("SELECT 1")
        latency = ((Time.current - start) * 1000).round(2)

        {
          status: "healthy",
          latency_ms: latency
        }
      rescue StandardError => e
        {
          status: "unhealthy",
          error: e.message
        }
      end

      def check_redis
        return { status: "not_configured" } unless defined?(Redis)

        start = Time.current
        redis = Redis.new(url: ENV["REDIS_URL"] || "redis://localhost:6379")
        redis.ping
        latency = ((Time.current - start) * 1000).round(2)

        {
          status: "healthy",
          latency_ms: latency
        }
      rescue StandardError => e
        {
          status: "unhealthy",
          error: e.message
        }
      end

      def check_python_service
        start = Time.current
        client = PythonServiceClient.new
        healthy = client.health_check
        latency = ((Time.current - start) * 1000).round(2)

        if healthy
          {
            status: "healthy",
            latency_ms: latency,
            url: ENV["PYTHON_SERVICE_URL"] || "http://localhost:8000"
          }
        else
          {
            status: "unhealthy",
            error: "Health check failed"
          }
        end
      rescue StandardError => e
        {
          status: "unhealthy",
          error: e.message
        }
      end

      def check_pgvector
        start = Time.current
        result = ActiveRecord::Base.connection.execute("SELECT extversion FROM pg_extension WHERE extname = 'vector'")
        latency = ((Time.current - start) * 1000).round(2)

        if result.any?
          version = result.first["extversion"]
          {
            status: "healthy",
            version: version,
            latency_ms: latency
          }
        else
          {
            status: "unhealthy",
            error: "pgvector extension not installed"
          }
        end
      rescue StandardError => e
        {
          status: "unhealthy",
          error: e.message
        }
      end
    end
  end
end
