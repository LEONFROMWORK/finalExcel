Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # API routes
  namespace :api do
    namespace :v1 do
      # Health check
      get "health", to: "health#index"

      # Authentication - DISABLED FOR FREE TEST PERIOD
      # devise_for :users,
      #   path: "auth",
      #   controllers: {
      #     sessions: "authentication/sessions",
      #     registrations: "authentication/registrations",
      #     omniauth_callbacks: "authentication/omniauth_callbacks"
      #   },
      #   defaults: { format: :json }

      # # Custom auth routes
      # namespace :auth do
      #   post 'signup', to: 'registrations#create'
      #   post 'validate-referral', to: 'registrations#validate_referral'
      # end

      # Excel Analysis - unified routes
      namespace :excel_analysis do
        # File management
        resources :files, only: [ :create, :show, :index ] do
          member do
            get :analysis
            post :reanalyze
          end
        end

        # Excel operations
        post "files", to: "excel#upload"
        post "analyze", to: "excel#analyze"
        post "modify", to: "excel#modify"
        post "create-from-template", to: "excel#create_from_template"
        post "create-from-ai", to: "excel#create_from_ai"
        post "analyze-vba", to: "excel#analyze_vba"
        post "analyze-image", to: "excel#analyze_image"
        post "images-to-excel", to: "excel#images_to_excel"
        post "generate-code", to: "excel#generate_code"
      end

      # Chunked upload routes
      namespace :chunked_upload do
        post "init", to: "chunked_upload#init"
        post "chunk", to: "chunked_upload#upload_chunk"
        get "status/:upload_id", to: "chunked_upload#status"
        delete "cancel/:upload_id", to: "chunked_upload#cancel"
      end

      # Streaming download routes
      get "streaming_download/:file_id", to: "streaming_download#download"
      get "streaming_download/:file_id/partial", to: "streaming_download#partial_download"

      # File serving routes
      get "uploads/excel/:file_url", to: "excel#download"
      get "tmp/uploads/:file_url", to: "excel#serve_temp_file"

      # User credits - PAYMENT FEATURES DISABLED FOR FREE TEST PERIOD
      namespace :users do
        get "current", to: "users#current"
        # patch 'credits', to: 'users#update_credits'
        # post 'purchase-credits', to: 'users#purchase_credits'
      end

      # Knowledge Base
      namespace :knowledge_base do
        resources :qa_pairs, only: [ :index, :show ] do
          collection do
            post :search
          end
        end
      end

      # AI Consultation
      namespace :ai_consultation do
        resources :chat_sessions, only: [ :create, :index, :show, :update, :destroy ] do
          resources :messages, only: [ :create ]
          member do
            get :messages
            get :export
          end
          collection do
            get :statistics
            get :search
          end
        end

        # Error Solutions
        resources :error_solutions, only: [ :index, :show ] do
          collection do
            post :solve
            get :patterns
          end
          member do
            post :apply
            post :feedback
          end
        end
      end

      # VBA Helper
      namespace :vba do
        post "solve", to: "vba_helper#solve"
        post "feedback", to: "vba_helper#feedback"
        get "common_patterns", to: "vba_helper#common_patterns"
        get "stats", to: "vba_helper#stats"
      end

      # Admin Dashboard - NO LOGIN REQUIRED FOR FREE TEST PERIOD
      namespace :admin do
        namespace :dashboard do
          get "overview", to: "dashboard#overview"
          get "user_activities", to: "dashboard#user_activities"
          get "active_users", to: "dashboard#active_users"
          get "vector_db_status", to: "dashboard#vector_db_status"
          get "user/:id", to: "dashboard#user_detail"
          post "export", to: "dashboard#export_data"
          get "realtime_stats", to: "dashboard#realtime_stats"
        end

        # Data Collection Management
        namespace :data_collection do
          get "/", to: "data_collection#index"
          post "create_task", to: "data_collection#create_task"
          post "run/:id", to: "data_collection#run_collection"
          post "run_bulk", to: "data_collection#run_bulk_collection"
          get "stats", to: "data_collection#collection_stats"
          get "download", to: "data_collection#download_data"
          post "send_to_rag", to: "data_collection#send_to_rag"
        end
      end

      # My Account - LIMITED FOR FREE TEST PERIOD (NO LOGIN REQUIRED)
      # namespace :my_account do
      #   get 'referral-stats', to: 'my_account#referral_stats'
      #   get 'activities', to: 'my_account#activities'
      #   get 'credit-history', to: 'my_account#credit_history'
      #   patch 'settings', to: 'my_account#update_settings'
      #   post 'purchase-credits', to: 'my_account#purchase_credits'
      #   post 'upload-avatar', to: 'my_account#upload_avatar'
      #   delete 'delete-avatar', to: 'my_account#delete_avatar'
      #
      #   # 추가 기능
      #   get 'ai-consultations', to: 'my_account#ai_consultations'
      #   get 'vba-solutions', to: 'my_account#vba_solutions'
      #   get 'excel-files', to: 'my_account#excel_files'
      #   get 'subscription', to: 'my_account#subscription_info'
      #   post 'update-password', to: 'my_account#update_password'
      #   delete 'delete-account', to: 'my_account#delete_account'
      #   post 'download-data', to: 'my_account#download_personal_data'
      #
      #   # 알림 설정
      #   get 'notifications', to: 'my_account#notifications'
      #   patch 'notification-preferences', to: 'my_account#update_notification_preferences'
      #
      #   # 연동 서비스
      #   get 'connected-services', to: 'my_account#connected_services'
      #   post 'connect-service', to: 'my_account#connect_service'
      #   delete 'disconnect-service/:service', to: 'my_account#disconnect_service'
      # end

      # 알림
      resources :notifications, only: [ :index, :destroy ] do
        collection do
          get "unread_count"
          post "mark_all_read"
          get "preferences"
          patch "preferences", to: "notifications#update_preferences"
        end
        member do
          patch "read", to: "notifications#mark_as_read"
        end
      end

      # Data Pipeline (Admin only)
      namespace :data_pipeline do
        resources :collection_tasks do
          member do
            post :start
            post :stop
            get :runs
            get :statistics
          end
          collection do
            get :global_statistics
            get :recent_activity
          end
        end

        resources :collection_runs, only: [ :show ] do
          member do
            post :cancel
          end
        end
      end
    end
  end

  # Vue.js app - catch all route
  root "application#index"
  get "*path", to: "application#index", constraints: ->(req) { !req.xhr? && req.format.html? }
end
