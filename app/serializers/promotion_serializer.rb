class PromotionSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :promotion_type, :conditions, :benefits,
             :start_date, :end_date, :is_active, :usage_limit, :used_count,
             :priority, :stackable, :created_at, :updated_at

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

  def benefits
    return nil if object.benefits.blank?
    
    if object.benefits.is_a?(String)
      JSON.parse(object.benefits)
    else
      object.benefits
    end
  rescue JSON::ParserError
    object.benefits
  end
end
