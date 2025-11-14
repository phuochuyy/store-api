# frozen_string_literal: true

module Users
  class AddressCreationService
    class << self
      # @param user [User] User to create address for
      # @param address_params [Hash] Address parameters
      # @return [Hash] Result with success status
      def create_address(user:, **address_params)
        return { success: false, error: 'User not found' } unless user

        validation_result = validate_address_params(address_params)
        return validation_result unless validation_result[:success]

        processed_params = process_address_params(address_params)
        handle_default_address(user, processed_params)

        address = user.user_addresses.build(processed_params)
        build_creation_response(address)
      rescue StandardError => e
        Rails.logger.error "Address creation error: #{e.message}"
        {
          success: false,
          error: 'Failed to create address',
          details: e.message
        }
      end

      # @param address [UserAddress] Address to update
      # @param address_params [Hash] Update parameters
      # @return [Hash] Result with success status
      def update_address(address:, **address_params)
        return { success: false, error: 'Address not found' } unless address

        validation_result = validate_address_params(address_params)
        return validation_result unless validation_result[:success]

        processed_params = process_address_params(address_params)
        handle_default_address_update(address, processed_params)

        update_result = address.update(processed_params)
        build_update_response(address, update_result)
      rescue StandardError => e
        Rails.logger.error "Address update error: #{e.message}"
        {
          success: false,
          error: 'Failed to update address',
          details: e.message
        }
      end

      # @param address [UserAddress] Address to delete
      # @return [Hash] Result with success status
      def delete_address(address)
        return { success: false, error: 'Address not found' } unless address

        if address.destroy
          {
            success: true,
            message: 'Address deleted successfully'
          }
        else
          {
            success: false,
            error: 'Failed to delete address',
            details: address.errors.full_messages
          }
        end
      rescue StandardError => e
        Rails.logger.error "Address deletion error: #{e.message}"
        {
          success: false,
          error: 'Failed to delete address',
          details: e.message
        }
      end

      private

      def validate_address_params(address_params)
        required_fields = %w[full_name address_line1 city postal_code country]
        missing_fields = required_fields.select { |field| address_params[field.to_sym].blank? }

        if missing_fields.any?
          {
            success: false,
            error: "Missing required fields: #{missing_fields.join(', ')}"
          }
        else
          { success: true }
        end
      end

      def process_address_params(address_params)
        processed = address_params.dup
        processed[:address_type] ||= 'shipping'
        processed
      end

      def handle_default_address(user, address_params)
        return unless address_params[:is_default] == true

        user.user_addresses.where(address_type: address_params[:address_type]).find_each do |addr|
          addr.update!(is_default: false)
        end
      end

      def handle_default_address_update(address, address_params)
        return unless address_params[:is_default] == true

        address.user.user_addresses
               .where(address_type: address.address_type)
               .where.not(id: address.id)
               .find_each do |addr|
          addr.update!(is_default: false)
        end
      end

      def build_creation_response(address)
        if address.save
          {
            success: true,
            address: AddressDataService.address_data(address),
            message: 'Address created successfully'
          }
        else
          {
            success: false,
            error: 'Failed to create address',
            details: address.errors.full_messages
          }
        end
      end

      def build_update_response(address, success)
        if success
          {
            success: true,
            address: AddressDataService.address_data(address),
            message: 'Address updated successfully'
          }
        else
          {
            success: false,
            error: 'Failed to update address',
            details: address.errors.full_messages
          }
        end
      end
    end
  end
end
