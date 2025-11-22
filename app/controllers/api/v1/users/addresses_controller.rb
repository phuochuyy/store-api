# frozen_string_literal: true

module Api
  module V1
    module Users
      class AddressesController < Api::V1::BaseController
        before_action :authenticate_user!
        before_action :set_address, only: %i[show update destroy set_default]

        def index
          filters = {
            address_type: params[:address_type],
            is_default: params[:is_default]
          }

          result = Users::AddressDataService.get_user_addresses(user: current_user, **filters)

          if result[:success]
            render_success({ addresses: result[:addresses], total_count: result[:total_count] },
                           'Addresses retrieved successfully')
          else
            render_error(result[:error], :unprocessable_content)
          end
        end

        def show
          render_success({ address: address_serializer(@address) }, 'Address retrieved successfully')
        end

        def create
          result = Users::AddressCreationService.create_address(user: current_user, **address_params)

          if result[:success]
            render_success({ address: address_serializer(result[:address]) }, 'Address created successfully', :created)
          else
            render_error(result[:error], :unprocessable_content, result[:errors])
          end
        end

        def update
          return render_error('You can only update your own addresses', :forbidden) unless @address.user == current_user

          result = Users::AddressCreationService.update_address(address: @address, **address_params)

          if result[:success]
            render_success({ address: address_serializer(result[:address]) }, 'Address updated successfully')
          else
            render_error(result[:error], :unprocessable_content, result[:errors])
          end
        end

        def destroy
          return render_error('You can only delete your own addresses', :forbidden) unless @address.user == current_user

          result = Users::AddressCreationService.delete_address(@address)

          if result[:success]
            render_success(nil, 'Address deleted successfully')
          else
            render_error(result[:error], :unprocessable_content)
          end
        end

        def set_default
          unless @address.user == current_user
            return render_error('You can only set your own addresses as default',
                                :forbidden)
          end

          result = Users::AddressDataService.update_default_address(@address)

          if result[:success]
            render_success({ address: address_serializer(@address.reload) }, 'Default address updated successfully')
          else
            render_error(result[:error], :unprocessable_content)
          end
        end

        def default
          address_type = params[:address_type] || 'shipping'
          result = Users::AddressDataService.get_default_address(current_user, address_type)

          if result[:success]
            render_success({ address: result[:address] }, 'Default address retrieved successfully')
          else
            render_error(result[:error], :not_found)
          end
        end

        private

        def set_address
          @address = UserAddress.find_by(id: params[:id])
          render_error('Address not found', :not_found) unless @address
        end

        def address_params
          params.expect(address: %i[full_name address_line1 address_line2 city state postal_code country phone
                                    address_type is_default])
        end

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
