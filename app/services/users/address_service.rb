# frozen_string_literal: true

module Users
  class AddressService
    class << self
      # Create user address
      # @param user [User] User to create address for
      # @param address_params [Hash] Address parameters
      # @return [Hash] Result with success status
      def create_address(user:, **address_params)
        return { success: false, error: 'User not found' } unless user

        # Validate required fields
        required_fields = %w[full_name address_line1 city postal_code country]
        missing_fields = required_fields.select { |field| address_params[field.to_sym].blank? }

        if missing_fields.any?
          return {
            success: false,
            error: "Missing required fields: #{missing_fields.join(', ')}"
          }
        end

        # Set default address type if not provided
        address_params[:address_type] ||= 'shipping'

        # If this is set as default, remove default from other addresses of same type
        if address_params[:is_default] == true
          user.user_addresses.where(address_type: address_params[:address_type]).update_all(is_default: false)
        end

        # Create address
        address = user.user_addresses.build(address_params)

        if address.save
          {
            success: true,
            address: address_data(address),
            message: 'Address created successfully'
          }
        else
          {
            success: false,
            error: 'Failed to create address',
            details: address.errors.full_messages
          }
        end
      rescue StandardError => e
        Rails.logger.error "Address creation error: #{e.message}"
        {
          success: false,
          error: 'Failed to create address',
          details: e.message
        }
      end

      # Get user addresses
      # @param user [User] User to get addresses for
      # @param filters [Hash] Filter options
      # @return [Hash] Result with addresses
      def get_user_addresses(user:, **filters)
        return { success: false, error: 'User not found' } unless user

        addresses = user.user_addresses

        # Apply filters
        addresses = addresses.where(address_type: filters[:address_type]) if filters[:address_type]
        addresses = addresses.where(is_default: true) if filters[:default_only]
        addresses = addresses.recent if filters[:sort_by] == 'recent'

        # Pagination
        page = filters[:page] || 1
        per_page = filters[:per_page] || 20
        addresses = addresses.page(page).per(per_page)

        {
          success: true,
          addresses: addresses.map { |address| address_data(address) },
          pagination: {
            current_page: addresses.current_page,
            total_pages: addresses.total_pages,
            total_count: addresses.total_count,
            per_page: addresses.limit_value
          },
          summary: {
            total_addresses: user.user_addresses.count,
            shipping_addresses: user.user_addresses.shipping.count,
            billing_addresses: user.user_addresses.billing.count,
            default_shipping: user.default_address('shipping')&.id,
            default_billing: user.default_address('billing')&.id
          }
        }
      end

      # Update user address
      # @param address [UserAddress] Address to update
      # @param address_params [Hash] Update parameters
      # @return [Hash] Result with success status
      def update_address(address:, **address_params)
        return { success: false, error: 'Address not found' } unless address

        # If setting as default, remove default from other addresses of same type
        if address_params[:is_default] == true
          address.user.user_addresses
                 .where(address_type: address.address_type)
                 .where.not(id: address.id)
                 .update_all(is_default: false)
        end

        if address.update(address_params)
          {
            success: true,
            address: address_data(address),
            message: 'Address updated successfully'
          }
        else
          {
            success: false,
            error: 'Failed to update address',
            details: address.errors.full_messages
          }
        end
      rescue StandardError => e
        Rails.logger.error "Address update error: #{e.message}"
        {
          success: false,
          error: 'Failed to update address',
          details: e.message
        }
      end

      # Delete user address
      # @param address [UserAddress] Address to delete
      # @return [Hash] Result with success status
      def delete_address(address)
        return { success: false, error: 'Address not found' } unless address

        # Check if this is the last address of its type
        remaining_addresses = address.user.user_addresses
                                     .where(address_type: address.address_type)
                                     .where.not(id: address.id)

        if remaining_addresses.empty?
          return {
            success: false,
            error: 'Cannot delete the last address of this type'
          }
        end

        # If deleting default address, set another as default
        if address.is_default?
          new_default = remaining_addresses.first
          new_default.update!(is_default: true)
        end

        address.destroy!

        {
          success: true,
          message: 'Address deleted successfully'
        }
      rescue StandardError => e
        Rails.logger.error "Address deletion error: #{e.message}"
        {
          success: false,
          error: 'Failed to delete address',
          details: e.message
        }
      end

      # Set address as default
      # @param address [UserAddress] Address to set as default
      # @return [Hash] Result with success status
      def set_default_address(address)
        return { success: false, error: 'Address not found' } unless address

        address.set_as_default!

        {
          success: true,
          address: address_data(address),
          message: 'Address set as default successfully'
        }
      rescue StandardError => e
        Rails.logger.error "Set default address error: #{e.message}"
        {
          success: false,
          error: 'Failed to set default address',
          details: e.message
        }
      end

      # Get default address
      # @param user [User] User to get default address for
      # @param address_type [String] Type of address (shipping/billing)
      # @return [Hash] Result with default address
      def get_default_address(user:, address_type: 'shipping')
        return { success: false, error: 'User not found' } unless user

        default_address = user.default_address(address_type)

        if default_address
          {
            success: true,
            address: address_data(default_address),
            message: 'Default address retrieved successfully'
          }
        else
          {
            success: false,
            error: "No default #{address_type} address found"
          }
        end
      end

      # Validate address
      # @param address_params [Hash] Address parameters to validate
      # @return [Hash] Validation result
      def validate_address(**address_params)
        # Create a temporary address object for validation
        temp_address = UserAddress.new(address_params)

        if temp_address.valid?
          {
            success: true,
            valid: true,
            message: 'Address is valid'
          }
        else
          {
            success: false,
            valid: false,
            error: 'Address validation failed',
            details: temp_address.errors.full_messages
          }
        end
      end

      # Get address statistics
      # @param user [User] User to get statistics for
      # @return [Hash] Address statistics
      def get_address_statistics(user)
        return { success: false, error: 'User not found' } unless user

        addresses = user.user_addresses

        {
          success: true,
          statistics: {
            total_addresses: addresses.count,
            shipping_addresses: addresses.shipping.count,
            billing_addresses: addresses.billing.count,
            default_addresses: addresses.default.count,
            countries: addresses.group(:country).count,
            cities: addresses.group(:city).count,
            most_used_city: addresses.group(:city).count.max_by { |_, count| count }&.first,
            address_creation_timeline: addresses.group_by_month(:created_at).count
          }
        }
      end

      # Bulk import addresses
      # @param user [User] User to import addresses for
      # @param addresses_data [Array] Array of address data
      # @return [Hash] Import result
      def bulk_import_addresses(user:, addresses_data:)
        return { success: false, error: 'User not found' } unless user
        return { success: false, error: 'Addresses data is required' } if addresses_data.blank?

        results = {
          total: addresses_data.size,
          successful: 0,
          failed: 0,
          errors: []
        }

        addresses_data.each_with_index do |address_data, index|
          result = create_address(user: user, **address_data)
          if result[:success]
            results[:successful] += 1
          else
            results[:failed] += 1
            results[:errors] << "Address #{index + 1}: #{result[:error]}"
          end
        end

        {
          success: results[:failed] == 0,
          results: results,
          message: "Import completed: #{results[:successful]} successful, #{results[:failed]} failed"
        }
      end

      private

      # Generate address data hash
      # @param address [UserAddress] Address to generate data for
      # @return [Hash] Address data
      def address_data(address)
        {
          id: address.id,
          user_id: address.user_id,
          address_type: address.address_type,
          full_name: address.full_name,
          phone: address.phone,
          address_line1: address.address_line1,
          address_line2: address.address_line2,
          city: address.city,
          state: address.state,
          postal_code: address.postal_code,
          country: address.country,
          is_default: address.is_default,
          full_address: address.full_address,
          short_address: address.short_address,
          created_at: address.created_at,
          updated_at: address.updated_at
        }
      end
    end
  end
end
