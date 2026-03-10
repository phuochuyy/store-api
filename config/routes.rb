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

      # Shipping
      get 'shipping/methods', to: 'shipping#methods'
      get 'shipping/calculate', to: 'shipping#calculate'
      get 'shipping/zones', to: 'shipping#zones'

      # Tax
      get 'tax/calculate', to: 'tax#calculate'
      get 'tax/rates', to: 'tax#rates'

      # Products namespace
      namespace :products do
        # Main products resource
        resources :products, controller: 'products', path: '' do
          collection do
            get :search
          end
          member do
            post :upload_image
            delete :remove_image
            post :add_to_wishlist
            delete :remove_from_wishlist
          end
          resources :reviews, only: %i[index create], controller: 'reviews'
          resources :variants, only: %i[index show create update destroy], controller: 'variants'
        end

        # Product Reviews (standalone)
        resources :reviews, only: %i[index show update destroy], controller: 'reviews' do
          member do
            post :helpful
            delete :helpful
          end
        end

        # Product Wishlist
        resources :wishlists, only: %i[index show create destroy], controller: 'wishlists' do
          collection do
            get :my_wishlist
          end
        end

        # Product Comparison
        resources :comparisons, only: %i[index show create update destroy], controller: 'comparisons' do
          collection do
            get :my_comparisons
          end
        end
      end

      resources :brands
      resources :categories

      # Shopping Cart namespace
      namespace :carts do
        resources :carts, controller: 'carts' do
          member do
            delete :clear
          end
          collection do
            post :merge
          end
          resources :items, only: %i[index show create update destroy], controller: 'items'
        end
        resources :items, only: %i[index show create update destroy], controller: 'items'
      end

      # Orders namespace
      namespace :orders do
        resources :orders, controller: 'orders' do
          member do
            post :confirm
            post :cancel
            post :ship
            post :deliver
            post :apply_discount
            delete :remove_discount
          end
          resources :items, only: %i[index show create update destroy], controller: 'items'
        end
        resources :items, only: %i[show update destroy], controller: 'items'
      end

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

      # Returns
      resources :returns, only: %i[index show create] do
        member do
          patch :cancel
          patch :approve
          patch :reject
          patch :complete
        end
      end

      # Address validation
      post 'addresses/validate', to: 'addresses#validate'
      get 'addresses/autocomplete', to: 'addresses#autocomplete'

      # Payments namespace
      namespace :payments do
        resources :payments, controller: 'payments' do
          member do
            post :refund
          end
        end

        resources :methods, controller: 'methods' do
          member do
            get :stats
            post :validate_config
          end
          collection do
            post :calculate_fees
          end
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
  get 'track/:tracking_number', to: 'api/v1/orders/orders#track', as: :track_order

  # Health checks (OkComputer)
  mount OkComputer::Engine, at: '/health'

  # Root route - health check
  root 'api/v1/health#index'
end
