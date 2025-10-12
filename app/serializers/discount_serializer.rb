class DiscountSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :discount_type, :value, :minimum_amount,
             :maximum_discount, :usage_limit, :used_count, :start_date, :end_date,
             :is_active, :code, :applies_to, :applies_to_ids, :conditions,
             :created_at, :updated_at

  attribute :available, key: :is_available
  attribute :current, key: :is_current
  attribute :expired, key: :is_expired
  attribute :within_usage_limit, key: :within_usage_limit

  def available
    object.available?
  end

  def current
    object.current?
  end

  def expired
    object.expired?
  end

  def within_usage_limit
    object.within_usage_limit?
  end

  def conditions
    return nil if object.conditions.blank?
    
    if object.conditions.is_a?(String)
      JSON.parse(object.conditions)
    else
      object.conditions
    end
  rescue JSON::ParserError
    object.conditions
  end
end
