Rails.application.routes.draw do
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # API routes
  namespace :api do
    namespace :v1 do
      # Authentication routes
      post "auth/login", to: "auth#login"
      post "auth/register", to: "auth#register"
      get "auth/me", to: "auth#me"

      # Protected routes
      resources :brands
      resources :categories
      resources :phones do
        collection do
          get :search
        end
      end
      resources :orders do
        member do
          patch :update_status
        end
        resources :order_items, except: [ :new, :edit ]
      end
      resources :order_items, only: [ :show, :update, :destroy ]

      # Statistics routes
      get "statistics/dashboard", to: "statistics#dashboard"
      get "statistics/inventory", to: "statistics#inventory"
      get "statistics/sales", to: "statistics#sales"
    end
  end

  # Defines the root path route ("/")
  root "rails/health#show"
end
