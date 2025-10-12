Rails.application.routes.draw do
  # API routes
  namespace :api do
    namespace :v1 do
      # Health check
      get 'health', to: 'health#index'

      # Authentication routes (simplified)
      post 'auth/login', to: 'auth#login'
      post 'auth/register', to: 'auth#register'
      post 'auth/logout', to: 'auth#logout'
      get 'auth/me', to: 'auth#me'

      # Main resources (simplified)
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
        resources :cart_items
      end

      # Orders (simplified)
      resources :orders do
        member do
          post :confirm
          post :cancel
          post :apply_discount
          delete :remove_discount
        end
        resources :order_items
      end
      resources :order_items, only: %i[show update destroy]

      # Discount & Promotion routes
      resources :discounts do
        member do
          get :stats
          post :generate_codes
        end
        collection do
          post :validate
        end
      end

      resources :promotions do
        member do
          get :stats
          post :apply
        end
        collection do
          get :applicable
        end
      end

      # Basic notifications
      resources :notifications, only: %i[index show update destroy] do
        member do
          post :mark_read
        end
        collection do
          post :mark_all_read
        end
      end

      # Basic stock alerts
      resources :stock_alerts, only: %i[index show update destroy]

      # Payment Methods
      resources :payment_methods do
        member do
          get :stats
          post :validate_config
        end
        collection do
          post :calculate_fees
        end
      end

      # Payments
      resources :payments do
        member do
          post :refund
        end
      end

      # Statistics
      namespace :statistics do
        get :dashboard
        get :inventory
        get :sales
      end
    end
  end

  # API Documentation
  get '/api-docs', to: 'api_docs#index'
  get '/swagger/v1/swagger.yaml', to: 'api_docs#swagger_yaml'
  get '/swagger/v1/swagger.json', to: 'api_docs#swagger_json'

  # Root route - health check
  root 'api/v1/health#index'
end
