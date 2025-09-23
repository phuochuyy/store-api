class Phones::PhoneService
  class << self
    def list_phones(filters: {}, pagination: {})
      phones = Phone.includes(:brand, :category)
      phones = apply_filters(phones, filters)
      phones = paginate(phones, pagination)
      
      {
        phones: phones.map { |phone| PhoneSerializer.new(phone).as_json },
        pagination: pagination_meta(phones)
      }
    end

    def find_phone(id)
      phone = Phone.includes(:brand, :category).find(id)
      {
        phone: PhoneSerializer.new(phone).as_json,
        related_phones: get_related_phones(phone)
      }
    end

    def create_phone(params)
      phone = Phone.new(params)
      
      if phone.save
        { success: true, phone: PhoneSerializer.new(phone).as_json }
      else
        { success: false, errors: phone.errors.full_messages }
      end
    end

    def update_phone(id, params)
      phone = Phone.find(id)
      
      if phone.update(params)
        { success: true, phone: PhoneSerializer.new(phone).as_json }
      else
        { success: false, errors: phone.errors.full_messages }
      end
    end

    def delete_phone(id)
      phone = Phone.find(id)
      phone.destroy
      { success: true }
    end

    def upload_image(phone, image)
      if image.present?
        phone.image.attach(image)
        { success: true, image_url: phone.image.attached? ? Rails.application.routes.url_helpers.rails_blob_url(phone.image) : nil }
      else
        { success: false, error: "No image provided" }
      end
    end

    def remove_image(phone)
      phone.image.purge if phone.image.attached?
      { success: true }
    end

    private

    def apply_filters(phones, filters)
      phones = phones.where(brand_id: filters[:brand_id]) if filters[:brand_id].present?
      phones = phones.where(category_id: filters[:category_id]) if filters[:category_id].present?
      phones = phones.where("name ILIKE ?", "%#{filters[:search]}%") if filters[:search].present?
      phones = phones.where("price >= ?", filters[:min_price]) if filters[:min_price].present?
      phones = phones.where("price <= ?", filters[:max_price]) if filters[:max_price].present?
      phones = phones.available unless filters[:include_unavailable]
      phones
    end

    def paginate(phones, pagination)
      page = pagination[:page] || 1
      per_page = pagination[:per_page] || 10
      phones.page(page).per(per_page)
    end

    def pagination_meta(paginated_phones)
      {
        current_page: paginated_phones.current_page,
        total_pages: paginated_phones.total_pages,
        total_count: paginated_phones.total_count,
        per_page: paginated_phones.limit_value
      }
    end

    def get_related_phones(phone)
      phone.brand.phones
           .where.not(id: phone.id)
           .limit(4)
           .map { |p| PhoneSerializer.new(p).as_json }
    end
  end
end
