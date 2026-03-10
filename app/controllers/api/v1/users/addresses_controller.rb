# frozen_string_literal: true

module Api
  module V1
    module Users
      # User addresses API: CRUD, get default address, set default. Requires authentication.
      class AddressesController < Api::V1::BaseController
        before_action :authenticate_user!
        before_action :set_address, only: %i[show update destroy set_default]

        # GET /api/v1/users/addresses — List addresses (optional filters: address_type, is_default).
        def index
          filters = {
            address_type: params[:address_type],
            is_default: params[:is_default]
          }

          result = ::Users::AddressDataService.get_user_addresses(user: current_user, **filters)

          if result[:success]
            render_success({ addresses: result[:addresses], total_count: result[:total_count] },
                           'Addresses retrieved successfully')
          else
            render_error(result[:error], :unprocessable_content)
          end
        end

        # GET /api/v1/users/addresses/:id — Show one address.
        def show
          render_success({ address: address_serializer(@address) }, 'Address retrieved successfully')
        end

        # POST /api/v1/users/addresses — Create address (params under address: full_name, address_line1, ...).
        def create
          # params.expect returns the inner address hash directly
          result = ::Users::AddressCreationService.create_address(user: current_user,
                                                                  **address_params.to_h.symbolize_keys)

          if result[:success]
            render_success({ address: result[:address] }, 'Address created successfully', :created)
          else
            render_error(result[:error], :unprocessable_content, result[:details])
          end
        end

        # PUT/PATCH /api/v1/users/addresses/:id — Update address (only current_user's addresses).
        def update
          return render_error('You can only update your own addresses', :forbidden) unless @address.user == current_user

          result = ::Users::AddressCreationService.update_address(address: @address,
                                                                   **address_params.to_h.symbolize_keys)

          if result[:success]
            render_success({ address: result[:address] }, 'Address updated successfully')
          else
            render_error(result[:error], :unprocessable_content, result[:details])
          end
        end

        # DELETE /api/v1/users/addresses/:id — Delete address (only current_user's addresses).
        def destroy
          return render_error('You can only delete your own addresses', :forbidden) unless @address.user == current_user

          result = ::Users::AddressCreationService.delete_address(@address)

          if result[:success]
            render_success(nil, 'Address deleted successfully')
          else
            render_error(result[:error], :unprocessable_content)
          end
        end

        # POST /api/v1/users/addresses/:id/set_default — Set this address as default for its address_type.
        def set_default
          unless @address.user == current_user
            return render_error('You can only set your own addresses as default',
                                :forbidden)
          end

          result = ::Users::AddressDataService.update_default_address(@address)

          if result[:success]
            render_success({ address: address_serializer(@address.reload) }, 'Default address updated successfully')
          else
            render_error(result[:error], :unprocessable_content)
          end
        end

        # GET /api/v1/users/addresses/default — Get default address (query: address_type, default shipping).
        def default
          address_type = params[:address_type] || 'shipping'
          result = ::Users::AddressDataService.get_default_address(current_user, address_type)

          if result[:success]
            render_success({ address: result[:address] }, 'Default address retrieved successfully')
          else
            render_error(result[:error], :not_found)
          end
        end

        private

        # Set @address from params[:id]; render 404 if not found.
        def set_address
          @address = UserAddress.find_by(id: params[:id])
          render_error('Address not found', :not_found) unless @address
        end

        def address_params
          params.expect(address: %i[full_name address_line1 address_line2 city state postal_code country phone
                                    address_type is_default])
        end

        # Serialize a UserAddress to hash for JSON response.
        def address_serializer(address)
          {
            id: address.id,
            full_name: address.full_name,
            address_line1: address.address_line1,
            address_line2: address.address_line2,
            city: address.city,
            state: address.state,
            postal_code: address.postal_code,
            country: address.country,
            phone: address.phone,
            address_type: address.address_type,
            is_default: address.is_default,
            created_at: address.created_at,
            updated_at: address.updated_at
          }
        end
      end
    end
  end
end
