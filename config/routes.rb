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
      end
      resources :order_items, only: %i[show update destroy]

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
