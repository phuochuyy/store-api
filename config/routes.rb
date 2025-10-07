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
        end
        resources :order_items
      end
      resources :order_items, only: %i[show update destroy]

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
    end
  end

  # API Documentation
  get '/api-docs', to: 'api_docs#index'
  get '/swagger/v1/swagger.yaml', to: 'api_docs#swagger_yaml'
  get '/swagger/v1/swagger.json', to: 'api_docs#swagger_json'

  # Root route - health check
  root 'api/v1/health#index'
end
