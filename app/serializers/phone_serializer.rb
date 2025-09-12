class PhoneSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :price, :stock_quantity, :image_url, :specifications, :created_at, :updated_at

  belongs_to :brand
  belongs_to :category

  def image_url
    if object.image.attached?
      Rails.application.routes.url_helpers.rails_blob_url(object.image, only_path: true)
    else
      object.read_attribute(:image_url)
    end
  end
end
