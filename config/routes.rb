Rails.application.routes.draw do
  # API routes
  namespace :api do
    namespace :v1 do
      # Health check
      get 'health', to: 'health#index'

      # Authentication routes
      post 'auth/login', to: 'auth#login'
      post 'auth/register', to: 'auth#register'
      post 'auth/logout', to: 'auth#logout'
      get 'auth/me', to: 'auth#me'
      post 'auth/refresh_token', to: 'auth#refresh_token'
      get 'auth/verify_email', to: 'auth#verify_email'
      post 'auth/resend_verification', to: 'auth#resend_verification'
      post 'auth/revoke_all_tokens', to: 'auth#revoke_all_tokens'

      # Password reset
      post 'auth/password/reset', to: 'auth#password_reset'
      post 'auth/password/reset/confirm', to: 'auth#password_reset_confirm'
      post 'auth/password/change', to: 'auth#password_change'

      # Products
      resources :products do
        collection do
          get :search
        end
        member do
          post :upload_image
          delete :remove_image
        end
        # Product features
        resources :reviews, only: %i[index create show update destroy], controller: 'product_reviews'
        member do
          post :add_to_wishlist
          delete :remove_from_wishlist
        end
      end

      # Product Reviews (standalone)
      resources :product_reviews, only: %i[index show update destroy] do
        member do
          post :helpful
          delete :helpful
        end
      end

      # Product Wishlist
      resources :wishlists, only: %i[index show create destroy], controller: 'product_wishlists' do
        collection do
          get :my_wishlist
        end
      end

      # Product Comparison
      resources :product_comparisons, only: %i[index show create update destroy] do
        collection do
          get :my_comparisons
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

      # Orders
      resources :orders do
        member do
          post :confirm
          post :cancel
          post :ship
          post :deliver
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

      # User Profile & Addresses
      namespace :users do
        get 'profile', to: 'profile#show'
        put 'profile', to: 'profile#update'
        patch 'profile', to: 'profile#update'
        post 'profile/avatar', to: 'profile#upload_avatar'
        delete 'profile/avatar', to: 'profile#remove_avatar'

        # User Addresses
        resources :addresses, only: %i[index show create update destroy] do
          member do
            post :set_default
          end
          collection do
            get :default
          end
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
  get '/api-docs/swagger.json', to: 'api_docs#swagger_json'
  get '/swagger/v1/swagger.yaml', to: 'api_docs#swagger_yaml'
  get '/swagger/v1/swagger.json', to: 'api_docs#swagger_json'

  # Public Order Tracking (no authentication required)
  get 'track/:tracking_number', to: 'api/v1/orders#track', as: :track_order

  # Health checks (OkComputer)
  mount OkComputer::Engine, at: '/health'

  # Root route - health check
  root 'api/v1/health#index'
end
