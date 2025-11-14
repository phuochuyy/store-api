# frozen_string_literal: true

module Users
  class AddressService
    class << self
      # @param user [User] User to create address for
      # @param address_params [Hash] Address parameters
      # @return [Hash] Result with success status
      def create_address(user:, **address_params)
        AddressCreationService.create_address(user: user, **address_params)
      end

      # @param user [User] User to get addresses for
      # @param filters [Hash] Filter parameters
      # @return [Hash] Result with addresses
      def get_user_addresses(user:, **filters)
        AddressDataService.get_user_addresses(user: user, **filters)
      end

      # @param user [User] User to get default address for
      # @param address_type [String] Type of address (shipping/billing)
      # @return [Hash] Result with default address
      def get_default_address(user, address_type = 'shipping')
        AddressDataService.get_default_address(user, address_type)
      end

      # @param address [UserAddress] Address to set as default
      # @return [Hash] Result with success status
      def default_address=(address)
        return unless address

        address.set_as_default!
      rescue StandardError => e
        Rails.logger.error "Set default address error: #{e.message}"
        raise e
      end

      # @param address [UserAddress] Address to update
      # @param address_params [Hash] Update parameters
      # @return [Hash] Result with success status
      def update_address(address:, **address_params)
        AddressCreationService.update_address(address: address, **address_params)
      end

      # @param address [UserAddress] Address to delete
      # @return [Hash] Result with success status
      delegate :delete_address, to: :AddressCreationService

      # Bulk import addresses
      # @param user [User] User to import addresses for
      # @param addresses_data [Array<Hash>] Array of address data
      # @return [Hash] Result with import summary
      def bulk_import_addresses(user:, addresses_data:)
        AddressDataService.bulk_import_addresses(user: user, addresses_data: addresses_data)
      end

      # @param address_data [Hash] Address data to validate
      # @return [Hash] Validation result
      def validate_address_format(address_data)
        return { success: false, error: 'Address data is required' } if address_data.blank?

        validation_errors = []
        validation_errors.concat(validate_required_fields(address_data))
        validation_errors.concat(validate_address_format_fields(address_data))

        if validation_errors.empty?
          {
            success: true,
            message: 'Address format is valid'
          }
        else
          {
            success: false,
            errors: validation_errors,
            message: 'Address format has errors'
          }
        end
      end

      # @param user [User] User to get statistics for
      # @return [Hash] Address statistics
      def get_address_statistics(user)
        return { success: false, error: 'User not found' } unless user

        addresses = user.user_addresses
        {
          success: true,
          statistics: {
            total_addresses: addresses.count,
            shipping_addresses: addresses.where(address_type: 'shipping').count,
            billing_addresses: addresses.where(address_type: 'billing').count,
            default_addresses: addresses.where(is_default: true).count,
            countries: addresses.distinct.pluck(:country),
            cities: addresses.distinct.pluck(:city)
          }
        }
      end

      private

      def validate_required_fields(address_data)
        required_fields = %w[full_name address_line1 city postal_code country]
        missing_fields = required_fields.select { |field| address_data[field.to_sym].blank? }

        if missing_fields.any?
          ["Missing required fields: #{missing_fields.join(', ')}"]
        else
          []
        end
      end

      def validate_address_format_fields(address_data)
        errors = []

        if address_data[:postal_code].present?
          postal_code = address_data[:postal_code].to_s.strip
          errors << 'Invalid postal code format' unless postal_code.match?(/\A\d{5}(-\d{4})?\z/) # US ZIP code format
        end

        if address_data[:phone].present?
          phone = address_data[:phone].to_s.strip
          errors << 'Invalid phone number format' unless phone.match?(/\A\+?[\d\s\-()]+\z/)
        end

        errors
      end
    end
  end
end
