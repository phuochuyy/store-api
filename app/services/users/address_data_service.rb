# frozen_string_literal: true

module Users
  class AddressDataService
    class << self
      # Get user addresses with filters
      # @param user [User] User to get addresses for
      # @param filters [Hash] Filter parameters
      # @return [Hash] Result with addresses
      def get_user_addresses(user:, **filters)
        return { success: false, error: 'User not found' } unless user

        addresses = build_addresses_query(user, filters)
        {
          success: true,
          addresses: addresses.map { |address| address_data(address) },
          total_count: addresses.count
        }
      rescue StandardError => e
        Rails.logger.error "Get user addresses error: #{e.message}"
        {
          success: false,
          error: 'Failed to retrieve addresses',
          details: e.message
        }
      end

      # Get default address for user
      # @param user [User] User to get default address for
      # @param address_type [String] Type of address (shipping/billing)
      # @return [Hash] Result with default address
      def get_default_address(user, address_type = 'shipping')
        return { success: false, error: 'User not found' } unless user

        default_address = user.user_addresses.find_by(
          address_type: address_type,
          is_default: true
        )

        if default_address
          {
            success: true,
            address: address_data(default_address)
          }
        else
          {
            success: false,
            error: "No default #{address_type} address found"
          }
        end
      end

      # Set default address
      # @param address [UserAddress] Address to set as default
      # @return [Hash] Result with success status
      def set_default_address(address)
        return { success: false, error: 'Address not found' } unless address

        address.set_as_default!
        {
          success: true,
          message: 'Default address updated successfully'
        }
      rescue StandardError => e
        Rails.logger.error "Set default address error: #{e.message}"
        {
          success: false,
          error: 'Failed to set default address',
          details: e.message
        }
      end

      # Bulk import addresses
      # @param user [User] User to import addresses for
      # @param addresses_data [Array<Hash>] Array of address data
      # @return [Hash] Result with import summary
      def bulk_import_addresses(user:, addresses_data:)
        return { success: false, error: 'User not found' } unless user
        return { success: false, error: 'Addresses data is required' } if addresses_data.blank?

        import_results = {
          total: addresses_data.size,
          successful: 0,
          failed: 0,
          errors: []
        }

        addresses_data.each_with_index do |address_data, index|
          result = create_single_address(user, address_data)
          if result[:success]
            import_results[:successful] += 1
          else
            import_results[:failed] += 1
            import_results[:errors] << "Row #{index + 1}: #{result[:error]}"
          end
        end

        {
          success: import_results[:failed] == 0,
          import_summary: import_results,
          message: "Import completed: #{import_results[:successful]} successful, #{import_results[:failed]} failed"
        }
      rescue StandardError => e
        Rails.logger.error "Bulk import addresses error: #{e.message}"
        {
          success: false,
          error: 'Bulk import failed',
          details: e.message
        }
      end

      # Serialize address data
      # @param address [UserAddress] Address to serialize
      # @return [Hash] Serialized address data
      def address_data(address)
        return {} unless address

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

      private

      def build_addresses_query(user, filters)
        addresses = user.user_addresses

        addresses = addresses.where(address_type: filters[:address_type]) if filters[:address_type].present?
        addresses = addresses.where(is_default: filters[:is_default]) if filters[:is_default].present?
        addresses = addresses.where(city: filters[:city]) if filters[:city].present?
        addresses = addresses.where(country: filters[:country]) if filters[:country].present?

        addresses.order(:created_at)
      end

      def create_single_address(user, address_data)
        AddressCreationService.create_address(user: user, **address_data)
      end
    end
  end
end
