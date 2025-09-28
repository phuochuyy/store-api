Rails.application.routes.draw do
  # API routes
  namespace :api do
    namespace :v1 do
      # Health check
      get 'health', to: 'health#index'

      # Authentication routes
      post 'auth/login', to: 'auth#login'
      post 'auth/register', to: 'auth#register'
      post 'auth/refresh_token', to: 'auth#refresh_token'
      post 'auth/logout', to: 'auth#logout'
      get 'auth/me', to: 'auth#me'
      get 'auth/verify_email', to: 'auth#verify_email'
      post 'auth/resend_verification', to: 'auth#resend_verification'
      post 'auth/revoke_all_tokens', to: 'auth#revoke_all_tokens'

      # Main resources
      resources :products do
        collection do
          get :search
        end
        member do
          post :upload_image
          delete :remove_image
        end
      end

      resources :brands
      resources :categories

      # Shopping Cart routes
      resources :carts do
        member do
          delete :clear
        end
        collection do
          post :merge
        end
        resources :cart_items
      end

      resources :orders do
        resources :order_items
        resources :payments, only: %i[create]
      end
      resources :order_items, only: %i[show update destroy]

      # Payment routes
      resources :payments, only: %i[index show update destroy] do
        member do
          post :refund
        end
      end

      # Payment method routes
      resources :payment_methods do
        member do
          get :stats
          post :validate_config
        end
        collection do
          post :calculate_fees
        end
      end

      # Stock alerts routes
      resources :stock_alerts, only: %i[index show update destroy] do
        member do
          post :resolve
          post :dismiss
        end
        collection do
          post :bulk_operation
          get :statistics
          get :critical
          get :low_stock
          get :pending_notifications
          post :mark_notifications_sent
          get :summary
        end
      end

      # Payment history routes
      resources :payment_histories, only: %i[index show] do
        member do
          get :timeline
          get :audit_trail
        end
        collection do
          get :statistics
          get :search
          get :export
          get :my_recent
          get :status_changes
          get :refunds
          get :failures
        end
      end

      # Notifications routes
      resources :notifications, only: %i[index show update destroy] do
        member do
          post :mark_read
          post :mark_unread
        end
        collection do
          post :mark_all_read
          get :unread_count
          get :recent
          get :statistics
          # Admin-only notification sending endpoints
          post :send_stock_alerts
          post :send_daily_summary
          post :send_pending
        end
      end

      # Statistics routes (Admin only)
      get 'statistics/dashboard', to: 'statistics#dashboard'
      get 'statistics/inventory', to: 'statistics#inventory'
      get 'statistics/sales', to: 'statistics#sales'
    end
  end

  # API Documentation
  get '/api-docs', to: 'api_docs#index'
  get '/swagger/v1/swagger.yaml', to: 'api_docs#swagger_yaml'
  get '/swagger/v1/swagger.json', to: 'api_docs#swagger_json'

  # Root route - health check
  root 'api/v1/health#index'
end
