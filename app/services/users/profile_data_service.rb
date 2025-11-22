# frozen_string_literal: true

module Users
  # rubocop:disable Metrics/AbcSize
  class ProfileDataService
    class << self
      # @param user [User] User to get profile for
      # @return [Hash] Profile data
      def profile_data(user)
        return {} unless user

        {
          id: user.id,
          email: user.email,
          first_name: user.first_name,
          last_name: user.last_name,
          display_name: user.display_name,
          phone: user.phone,
          date_of_birth: user.date_of_birth,
          gender: user.gender,
          bio: user.bio,
          avatar_url: if user.avatar.present?
                        user.avatar.attached? ? Rails.application.routes.url_helpers.url_for(user.avatar) : nil
                      end,
          preferences: extract_preferences(user),
          addresses: extract_addresses(user),
          created_at: user.created_at,
          updated_at: user.updated_at
        }
      end

      # @param user [User] User to get profile for
      # @return [Hash] Public profile data
      def public_profile_data(user)
        return {} unless user

        base_data = {
          id: user.id,
          display_name: user.display_name,
          bio: user.bio,
          avatar_url: if user.avatar.present?
                        user.avatar.attached? ? Rails.application.routes.url_helpers.url_for(user.avatar) : nil
                      end
        }

        # Add additional data (simplified - no privacy level in current schema)
        base_data.merge(
          first_name: user.first_name,
          last_name: user.last_name,
          created_at: user.created_at
        )
      end

      # @param user [User] User to get statistics for
      # @return [Hash] User statistics
      def user_statistics(user)
        return {} unless user

        {
          total_orders: user.orders.count,
          total_spent: user.orders.sum(:total_amount),
          favorite_categories: favorite_categories(user),
          recent_activity: recent_activity(user),
          account_age: account_age(user)
        }
      end

      private

      def extract_preferences(user)
        {
          email_notifications_enabled: user.email_notifications_enabled?,
          sms_notifications_enabled: user.sms_notifications_enabled?,
          push_notifications_enabled: user.push_notifications_enabled?,
          preferences: user.preferences || {}
        }
      end

      def extract_addresses(user)
        user.user_addresses.map do |address|
          {
            id: address.id,
            address_type: address.address_type,
            full_name: address.full_name,
            address_line1: address.address_line1,
            address_line2: address.address_line2,
            city: address.city,
            state: address.state,
            postal_code: address.postal_code,
            country: address.country,
            phone: address.phone,
            is_default: address.is_default
          }
        end
      end

      def favorite_categories(user)
        user.orders.joins(order_items: { product: :category })
            .group('categories.name')
            .count
            .sort_by { |_, count| -count }
            .first(5)
            .to_h
      end

      def recent_activity(user)
        {
          last_order: user.orders.order(created_at: :desc).first&.created_at,
          last_login: user.last_sign_in_at,
          orders_this_month: user.orders.where(created_at: 1.month.ago..).count
        }
      end

      def account_age(user)
        days = (Time.current - user.created_at) / 1.day
        {
          days: days.to_i,
          years: (days / 365).to_i,
          months: (days / 30).to_i
        }
      end
    end
    # rubocop:enable Metrics/AbcSize
  end
end
