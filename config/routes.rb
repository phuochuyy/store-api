Rails.application.routes.draw do
  # API routes
  namespace :api do
    namespace :v1 do
      # Health check
      get "health", to: "health#index"

      # Authentication routes
      post "auth/login", to: "auth#login"
      post "auth/register", to: "auth#register"
      post "auth/refresh_token", to: "auth#refresh_token"
      post "auth/logout", to: "auth#logout"
      get "auth/me", to: "auth#me"

      # Main resources
      resources :phones do
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
      resources :orders do
        resources :order_items
      end
      resources :order_items, only: [:show, :update, :destroy]

      # Statistics routes (Admin only)
      get "statistics/dashboard", to: "statistics#dashboard"
      get "statistics/inventory", to: "statistics#inventory"
      get "statistics/sales", to: "statistics#sales"
    end
  end

  # API Documentation
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'

  # Root route - health check
  root "api/v1/health#index"
end
